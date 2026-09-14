# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "vips"

class ImageLabBenchmarkWorkloadsTest < ActiveSupport::TestCase
  test "defines every required workload without dynamic dispatch" do
    assert_equal %w[decode_encode resize crop rotate grayscale blur sharpen tint mixed_5 mixed_10],
      ImageLab::Benchmark::Workloads.all.map(&:name)
  end

  test "runs the registered mixed workload against a real fixture" do
    with_fixture do |fixture|
      result = ImageLab::Benchmark::Workloads.call(ImageLab::Benchmark::Workloads.all.last, fixture:, max_output_pixels: 25_000_000)

      assert result.bytes.start_with?("\x89PNG\r\n\x1A\n".b)
    end
  end

  test "uses the established output limit error" do
    assert_raises(ImageLab::Errors::OutputLimitExceeded) { ImageLab::Benchmark::Workloads.verify_output_limit! }
  end

  private

  def with_fixture
    Dir.mktmpdir("benchmark-workload") do |directory|
      path = File.join(directory, "fixture.png")
      Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar).resize(1000).write_to_file(path)
      yield ImageLab::Benchmark::Fixture.new("fixture", path, "png", File.size(path), 1000, 1000, false)
    end
  end
end
