#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists the tests in Minitest files without running them, as JSON in the shape
# of RSpec's dry run, so inventory.rb can report on a Minitest suite.
#
# Usage, from the project root:
#   bundle exec ruby -Itest minitest_inventory.rb --out inventory.json [--docs docs.txt] <test files...>
#   bundle exec ruby -Itest minitest_inventory.rb --source-only --out inventory.json <test files...>
#
# Minitest has no dry run, so this loads the test files (which boots the app,
# as an RSpec dry run does) and asks Minitest which tests it would run, through
# the public API its own runner uses: Runnable.runnables and runnable_methods.
# A Prism parse of the same files is an independent check: it recovers each
# test's name as written, finds `skip` calls, and catches `def test_` methods
# that a later definition replaced. When the two disagree, it warns instead of
# guessing.
#
# --source-only skips loading and lists what the parse finds. Use it when
# loading fails; it can't see tests generated in loops or shared modules.
# --docs writes the tests in file order, for diffing before and after.
#
# Needs Prism, which ships with Ruby 3.3+ (add the prism gem on older Rubies).

require 'json'
require 'prism'

# A test as written in the source, found by parsing rather than loading.
WrittenTest = Struct.new(:file, :line, :name, :skipped, :scope) do
  # The name a reader would use: the string given to `test` or `it`, or a
  # `def test_` method's name in words.
  def description
    name.start_with?('test_') ? name.delete_prefix('test_').tr('_', ' ') : name
  end
end

# Finds tests in one file's syntax tree: `test "..."`, `it "..."`, and
# `specify "..."` blocks, and `def test_...` methods.
class SourceScan < Prism::Visitor
  attr_reader :tests

  def initialize(file)
    super()
    @file = file
    @scope = []
    @tests = []
  end

  def visit_class_node(node)
    within(node.constant_path.slice) { super }
  end

  def visit_module_node(node)
    within(node.constant_path.slice) { super }
  end

  def visit_call_node(node)
    record(node, written_name(node), node.block) if test_block?(node)
    within(described(node)) { super }
  end

  def visit_def_node(node)
    record(node, node.name.to_s, node.body) if node.name.start_with?('test_')
    super
  end

  private

  def within(name)
    @scope.push(name)
    yield
  ensure
    @scope.pop
  end

  def record(node, name, body)
    return unless name

    finder = SkipFinder.new
    body&.accept(finder)
    @tests << WrittenTest.new(@file, node.location.start_line, name, finder.found, @scope.compact.join('::'))
  end

  def test_block?(node)
    node.receiver.nil? && %i[test it specify].include?(node.name) && node.block
  end

  def written_name(node)
    argument = node.arguments&.arguments&.first
    argument.is_a?(Prism::StringNode) ? argument.unescaped : nil
  end

  # `describe "..."` blocks scope Minitest::Spec tests the way a class does.
  def described(node)
    return unless describe_block?(node)

    argument = node.arguments&.arguments&.first
    argument.is_a?(Prism::StringNode) ? argument.unescaped : argument&.slice
  end

  def describe_block?(node)
    node.receiver.nil? && node.name == :describe && node.block
  end
end

# Looks for a bare `skip` call anywhere inside a test's body.
class SkipFinder < Prism::Visitor
  attr_reader :found

  def visit_call_node(node)
    @found ||= node.receiver.nil? && node.name == :skip
    super
  end
end

# The tests in the given files, as Minitest would run them (or as the source
# shows them, with --source-only), and anything that looks wrong about them.
class Inventory
  attr_reader :examples, :warnings

  def initialize(files, source_only:)
    @files = files
    @written = files.flat_map { |file| scan(file) }
    @warnings = redefinitions.map { |group| redefined_warning(group) }
    @examples = source_only ? from_source : from_minitest
  end

  def to_json(*)
    JSON.generate(version: 'minitest-inventory', examples: examples, warnings: warnings)
  end

  # One line per test, in file order, for diffing before and after.
  def docs
    examples.group_by { |example| example[:file_path] }.map do |file, tests|
      ["#{file.delete_prefix('./')}:", *tests.map do |test|
                                         "  #{test[:line_number]}  #{test[:full_description]}"
                                       end].join("\n")
    end.join("\n\n") << "\n"
  end

  private

  def scan(file)
    visitor = SourceScan.new(file)
    Prism.parse_file(file).value.accept(visitor)
    visitor.tests
  end

  def from_source
    (@written - replaced).sort_by { |test| [test.file, test.line] }
                         .map { |test| example(test.scope, test.description, test.file, test.line, test.skipped) }
  end

  def from_minitest
    examples = loaded.map do |klass, method, file, line|
      written = written_at(file, line)
      description = written&.description || method.sub(/\Atest_(\d{4}_)?/, '').tr('_', ' ')
      example(klass.name, description, file, line, written&.skipped)
    end
    check_against_source(examples)
    examples
  end

  # Minitest's runner asks each runnable class for its runnable_methods.
  # Test.runnable_methods shuffles with the run's seed, which only a run sets.
  def loaded
    Minitest.seed ||= 0
    tests = Minitest::Runnable.runnables.flat_map do |klass|
      klass.runnable_methods.filter_map do |method|
        file, line = klass.instance_method(method).source_location
        [klass, method, file, line] if @files.include?(file)
      end
    end
    tests.sort_by { |_klass, method, file, line| [file, line, method] }
  end

  def example(scope, description, file, line, skipped)
    { description: description, full_description: [scope, description].reject(&:empty?).join(' '),
      file_path: "./#{relative(file)}", line_number: line, status: skipped ? 'pending' : 'passed' }
  end

  def written_at(file, line)
    @written.find { |test| test.file == file && test.line == line }
  end

  # A test the source shows that Minitest won't run, or the reverse, means one
  # of the two views is wrong.
  def check_against_source(examples)
    found = examples.map { |example| [example[:file_path], example[:line_number]] }.uniq
    warn_unrun(found)
    warn_unwritten(found - @written.map { |test| location(test) })
  end

  def warn_unrun(found)
    (@written - replaced).reject { |test| found.include?(location(test)) }.each do |test|
      @warnings << "#{relative(test.file)}:#{test.line} is written as a test but Minitest won't run it"
    end
  end

  def warn_unwritten(locations)
    locations.each do |path, line|
      @warnings << "#{path.delete_prefix('./')}:#{line} defines tests the source can't show " \
                   '(a loop or a shared module?)'
    end
  end

  def location(test)
    ["./#{relative(test.file)}", test.line]
  end

  # `def test_x` twice in one class silently keeps only the last one.
  def redefinitions
    @written.select { |test| test.name.start_with?('test_') }
            .group_by { |test| [test.file, test.scope, test.name] }.values.select { |group| group.size > 1 }
  end

  def replaced
    redefinitions.flat_map { |group| group[0...-1] }
  end

  def redefined_warning(group)
    "#{relative(group.first.file)}: #{group.first.name} is defined at lines #{group.map(&:line).join(', ')}; " \
      'only the last one runs'
  end

  def relative(file)
    file.delete_prefix("#{Dir.pwd}/")
  end
end

def option(name)
  flag = ARGV.index(name)
  flag && ARGV.slice!(flag, 2).last
end

out = option('--out')
docs = option('--docs')
source_only = !ARGV.delete('--source-only').nil?
USAGE = 'Usage: bundle exec ruby -Itest minitest_inventory.rb [--source-only] [--out FILE] [--docs FILE] <files...>'
abort USAGE if ARGV.empty?

files = ARGV.map { |path| File.expand_path(path) }
unless source_only
  ENV['RAILS_ENV'] ||= 'test'
  files.each { |file| require file }
end

inventory = Inventory.new(files, source_only: source_only)
out ? File.write(out, inventory.to_json) : puts(inventory.to_json)
File.write(docs, inventory.docs) if docs
inventory.warnings.each { |warning| warn "warning: #{warning}" }
$stdout.flush
# Leave without running at_exit hooks, so Minitest's autorun never starts a run
exit!(0)
