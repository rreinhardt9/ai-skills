#!/usr/bin/env ruby
# frozen_string_literal: true

# Compares two SimpleCov .resultset.json files and reports lines and branches
# that lost or gained coverage. Exits 1 when anything lost coverage.
#
# Usage: ruby coverage_diff.rb BEFORE.json AFTER.json [--include app/,lib/] [--root DIR]
#
# Paths are reported relative to --root, which defaults to the current
# directory, so run it from the project root.

require 'json'

# Coverage for one resultset, keyed by project-relative path.
class Resultset
  def initialize(path, includes, root)
    @includes = includes
    @root = root
    @files = merge(JSON.parse(File.read(path)))
  end

  def paths
    @files.keys
  end

  def covered_lines(path)
    lines = @files.dig(path, :lines) || []
    lines.each_index.select { |i| lines[i].to_i.positive? }.map { |i| i + 1 }
  end

  def covered_branches(path)
    (@files.dig(path, :branches) || {}).select { |_key, count| count.positive? }.keys.sort_by { |key| branch_line(key) }
  end

  # The source line of a branch, from SimpleCov's "[:if, id, line, ...]" key.
  def self.branch_line((condition, _arm))
    condition.delete('[]').split(', ')[2].to_i
  end

  private

  def branch_line(key)
    self.class.branch_line(key)
  end

  # A resultset holds one entry per command name; a line counts as covered
  # when any of them covered it.
  def merge(data)
    data.each_value.with_object({}) do |run, files|
      run.fetch('coverage').each do |path, entry|
        relative = relative_path(path)
        next unless relative

        add(files[relative] ||= { lines: [], branches: Hash.new(0) }, entry)
      end
    end
  end

  # Older SimpleCov versions store a file's entry as a bare array of line counts.
  def add(file, entry)
    entry = { 'lines' => entry } if entry.is_a?(Array)
    add_lines(file[:lines], entry.fetch('lines', []))
    add_branches(file[:branches], entry.fetch('branches', nil) || {})
  end

  def add_lines(totals, counts)
    counts.each_with_index do |count, i|
      totals[i] = totals[i].to_i + count unless count.nil?
    end
  end

  def add_branches(totals, conditions)
    conditions.each do |condition, arms|
      arms.each { |arm, count| totals[[condition, arm]] += count }
    end
  end

  def relative_path(path)
    prefix = "#{@root}/"
    return unless path.start_with?(prefix)

    relative = path.delete_prefix(prefix)
    relative if @includes.any? { |include| relative.start_with?(include) }
  end
end

# The difference between two resultsets, one direction at a time.
class CoverageDiff
  def initialize(before, after)
    @before = before
    @after = after
  end

  def lost
    changes(@before, @after)
  end

  def gained
    changes(@after, @before)
  end

  private

  def changes(from, to)
    from.paths.sort.filter_map do |path|
      lines = from.covered_lines(path) - to.covered_lines(path)
      branches = from.covered_branches(path) - to.covered_branches(path)
      [path, lines, branches] unless lines.empty? && branches.empty?
    end
  end
end

def branch_label(key)
  type = key.last.delete('[]:').split(', ').first
  "#{type} branch at line #{Resultset.branch_line(key)}"
end

def report(title, changes)
  puts "== #{title}"
  puts '   none' if changes.empty?
  changes.each do |path, lines, branches|
    puts path
    puts "   lines: #{lines.join(', ')}" unless lines.empty?
    branches.each { |branch| puts "   #{branch_label(branch)}" }
  end
  puts
end

def option(name, default)
  flag = ARGV.index(name)
  return default unless flag

  value = ARGV.delete_at(flag + 1)
  ARGV.delete_at(flag)
  value
end

includes = option('--include', 'app/,lib/').split(',')
root = File.expand_path(option('--root', Dir.pwd))
abort 'Usage: ruby coverage_diff.rb BEFORE.json AFTER.json [--include app/,lib/] [--root DIR]' unless ARGV.size == 2

diff = CoverageDiff.new(Resultset.new(ARGV[0], includes, root), Resultset.new(ARGV[1], includes, root))
report('Lost coverage (covered before, not after)', diff.lost)
report('Gained coverage (covered after, not before)', diff.gained)
exit(diff.lost.empty? ? 0 : 1)
