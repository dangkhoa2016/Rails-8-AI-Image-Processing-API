# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ImageLabBenchmarkHttpScenarioTest < ActiveSupport::TestCase
  test "observes the scratch authority used by real image requests by default" do
    observed_directories = []

    ImageLab::Benchmark::HttpScenario.stub(:scratch_entries, lambda { |directory|
      observed_directories << directory
      []
    }) do
      with_corpus_fixture do |fixture|
        ImageLab::Benchmark::HttpScenario.call(fixture:)
      end
    end

    assert_equal [ ImageLab::Input.default_temporary_directory, ImageLab::Input.default_temporary_directory ],
                 observed_directories
  end

  test "processes a real authenticated multipart fixture and cleans scratch storage" do
    scratch_directory = ImageLab::Input.default_temporary_directory
    before = scratch_entries(scratch_directory)

    with_corpus_fixture do |fixture|
      record = ImageLab::Benchmark::HttpScenario.call(fixture:)

      assert_equal 200, record.fetch("status")
      assert_operator record.fetch("output_bytes"), :>, 0
      assert_operator record.fetch("output_width"), :>, 0
      assert_operator record.fetch("output_height"), :>, 0
      assert record.fetch("tempfile_cleanup_pass")
      assert_equal before, scratch_entries(scratch_directory)
    end
  end

  test "rejects caller-supplied scratch_directory override so observer uses the same authority as real request" do
    unrelated_directory = Dir.mktmpdir("unrelated-observer")

    with_corpus_fixture do |fixture|
      assert_raises(ArgumentError) do
        ImageLab::Benchmark::HttpScenario.call(fixture:, scratch_directory: unrelated_directory)
      end
    end
  ensure
    FileUtils.remove_entry(unrelated_directory) if unrelated_directory && Dir.exist?(unrelated_directory)
  end

  test "observation-only override no longer accepted in call signature" do
    method = ImageLab::Benchmark::HttpScenario.method(:call)
    parameter_names = method.parameters.select { |_, name| name == :scratch_directory }.map(&:last)

    assert_empty parameter_names,
                 "scratch_directory parameter must be removed from HttpScenario.call"
  end

  private

  def with_corpus_fixture
    Dir.mktmpdir("vips-http-scenario") do |parent|
      corpus_directory = File.join(parent, "vips-corpus")
      fixture = ImageLab::Benchmark::Corpus.create!(directory: corpus_directory).first

      yield fixture
    ensure
      ImageLab::Benchmark::Corpus.cleanup!(directory: corpus_directory) if corpus_directory
    end
  end

  def scratch_entries(directory)
    Dir.exist?(directory) ? Dir.children(directory).sort : []
  end
end
