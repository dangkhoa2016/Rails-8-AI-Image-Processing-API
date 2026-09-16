# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ImageLabBenchmarkRunnerTest < ActiveSupport::TestCase
  test "records one warm-up and five samples in quick mode" do
    Dir.mktmpdir("vips-benchmark") do |directory|
      result = ImageLab::Benchmark::Runner.run!(quick: true, output_directory: directory, worker_count: 1)

      result.fetch("workloads").each do |workload|
        assert_equal 1, workload.fetch("warmup_runs")
        assert_equal 5, workload.fetch("samples").length
      end
      assert_path_exists File.join(directory, "vips-cpu-8gb-result.json")
    end
  end

  test "records unsafe memory as not run" do
    Dir.mktmpdir("vips-benchmark") do |directory|
      result = ImageLab::Benchmark::Runner.run!(
        quick: true,
        output_directory: directory,
        worker_count: 2,
        memory_reader: -> { 1.gigabyte - 1 }
      )

      assert_equal "NOT_RUN_UNSAFE_MEMORY", result.dig("concurrency", 1, "status")
    end
  end
end
