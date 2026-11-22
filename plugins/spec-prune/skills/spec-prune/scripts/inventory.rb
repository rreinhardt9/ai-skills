#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists the examples in an RSpec dry run and flags likely findings: pending
# examples, duplicate names, generic names, code words, and stutter.
#
# Usage:
#   bundle exec rspec --dry-run --format json --out inventory.json <paths...>
#   ruby inventory.rb inventory.json

require 'json'

# One example from RSpec's JSON formatter.
class Example
  STOPWORDS = %w[a an and are as at be by for from in is it of on or that the then this to when with without].freeze
  # Matched against the whole name, so "returns nil for a missing id" passes
  # and a bare "returns nil" doesn't.
  GENERIC = [
    /\A(it )?works\z/, /\Ais (not )?valid\z/, /\Areturns (true|false|nil)\z/, /\Arenders( successfully)?\z/,
    /\bcorrect attributes\b/, /\bhas a valid factory\b/, /\bshould\b/
  ].freeze
  EXCEPTION = /(Error|Exception|NotFound|Invalid)\z/.freeze

  attr_reader :description, :full_description, :file, :line

  def initialize(data)
    @description = data.fetch('description').to_s
    @full_description = data.fetch('full_description').to_s
    @file = data.fetch('file_path').sub(%r{\A\./}, '')
    @line = data.fetch('line_number')
    @status = data['status']
  end

  def location
    "#{file}:#{line}"
  end

  def pending?
    @status == 'pending'
  end

  def generic?
    GENERIC.any? { |pattern| description.downcase.match?(pattern) }
  end

  # Every word of the example's own name already appears in its groups.
  def stutter?
    own = content_words(description)
    own.size >= 2 && (own - content_words(parents)).empty?
  end

  # snake_case and CamelCase words, leaving out the top-level subject (often a
  # class or route), method names (#call, .build), namespaced constants, and
  # exception names, which are a fair way to state an error.
  def code_words
    full_description.split.drop(1).map { |word| word.delete('\'",.()') }.select { |word| code_word?(word) }
  end

  private

  def code_word?(word)
    return false if word.start_with?('#', '.') || word.include?('::') || word.include?('/') || word.match?(EXCEPTION)

    word.match?(/[a-z]_[a-z]/) || word.match?(/\A[A-Z][a-z]+[A-Z]/)
  end

  def parents
    full_description.delete_suffix(description)
  end

  def content_words(text)
    text.downcase.scan(/[a-z0-9']+/).reject { |word| STOPWORDS.include?(word) }.map { |word| stem(word) }.uniq
  end

  def stem(word)
    word.sub(/(ing|es|s)\z/, '')
  end
end

# The whole dry run, with the report built from its examples.
class Inventory
  def initialize(examples)
    @examples = examples
  end

  def report
    [summary, by_file, flags].join("\n")
  end

  private

  def summary
    counts = @examples.group_by { |example| example.file.split('/')[1] }.transform_values(&:size)
    lines = ["# Spec inventory\n", "#{@examples.size} examples, #{@examples.count(&:pending?)} pending\n"]
    lines + counts.sort_by { |_type, count| -count }.map { |type, count| "- #{type}: #{count}" } + ['']
  end

  def by_file
    rows = @examples.group_by(&:file).sort.map do |file, examples|
      pending = examples.count(&:pending?)
      "- #{file}: #{examples.size}#{" (#{pending} pending)" if pending.positive?}"
    end
    ["## By file\n", *rows, '']
  end

  def flags
    ["## Flags\n",
     section('Pending (skipped)', @examples.select(&:pending?)),
     section('Duplicate full names', duplicates),
     section('Generic names', @examples.select(&:generic?)),
     section('Stutter: the name repeats its groups', @examples.select(&:stutter?)),
     code_word_section].join("\n")
  end

  def duplicates
    @examples.group_by(&:full_description).values.select { |group| group.size > 1 }.flatten
  end

  def section(title, examples)
    listing(title, examples.map { |example| "- #{example.location}: #{example.full_description}" })
  end

  def listing(title, rows)
    "### #{title}\n\n#{rows.empty? ? 'none' : rows.join("\n")}\n"
  end

  def code_word_section
    uses = @examples.flat_map { |example| example.code_words.map { |word| [word, example] } }.group_by(&:first)
    rows = uses.sort_by { |_word, found| -found.size }.map { |word, found| code_word_row(word, found.map(&:last)) }
    listing('Code words in names', rows)
  end

  def code_word_row(word, examples)
    count = examples.size == 1 ? '1 example' : "#{examples.size} examples"
    "- `#{word}`: #{count}, first at #{examples.first.location}"
  end
end

abort 'Usage: ruby inventory.rb inventory.json' unless ARGV.size == 1

# Tolerates other output around the JSON, in case it was redirected from stdout.
json_line = File.foreach(ARGV[0]).find { |line| line.include?('{"version"') }
abort "No RSpec JSON found in #{ARGV[0]}" unless json_line
json = json_line[json_line.index('{"version"')..json_line.rindex('}')]
examples = JSON.parse(json).fetch('examples').map { |data| Example.new(data) }
puts Inventory.new(examples).report
