# frozen_string_literal: true

require "test_helper"

class ImageLabBenchmarkMeasurementsTest < ActiveSupport::TestCase
  test "summarizes literal wall-time samples by median and range" do
    summary = ImageLab::Benchmark::Measurements.summary([
      { "wall_ms" => 11.0 }, { "wall_ms" => 2.0 }, { "wall_ms" => 7.0 }, { "wall_ms" => 5.0 }, { "wall_ms" => 9.0 }
    ])

    assert_equal({ "median" => 7.0, "min" => 2.0, "max" => 11.0 }, summary.fetch("wall_ms"))
  end

  test "represents unavailable RSS observations as nil" do
    sample = ImageLab::Benchmark::Measurements.capture(proc_reader: -> { nil }) { :value }.last

    assert_nil sample.fetch("rss_avg_bytes")
    assert_nil sample.fetch("rss_peak_bytes")
  end
end
