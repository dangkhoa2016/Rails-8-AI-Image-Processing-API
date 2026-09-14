# frozen_string_literal: true

require "test_helper"

class ImageLabBenchmarkSafetyTest < ActiveSupport::TestCase
  test "uses exact memory and RSS boundaries" do
    assert ImageLab::Benchmark::Safety.admit_concurrency?(mem_available_bytes: 1.gigabyte)
    assert_not ImageLab::Benchmark::Safety.admit_concurrency?(mem_available_bytes: 1.gigabyte - 1)
    assert_not ImageLab::Benchmark::Safety.aggregate_rss_safe?(worker_rss_bytes: 6.gigabytes + 1)
    peaks = [ 100.megabytes, 105.megabytes, 106.megabytes, 108.megabytes, 131.megabytes ]
    assert ImageLab::Benchmark::Safety.rss_growth_pass?(peaks:)
    assert_not ImageLab::Benchmark::Safety.rss_growth_pass?(peaks: peaks.first(4) + [ 132.megabytes ])
  end

  test "uses the lower cgroup headroom when the runtime has a memory limit" do
    available = ImageLab::Benchmark::Safety.mem_available_bytes(
      proc_reader: -> { 2.gigabytes },
      cgroup_reader: -> { 512.megabytes }
    )

    assert_equal 512.megabytes, available
  end
end
