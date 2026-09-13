# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabPipelineTest < ActiveSupport::TestCase
  test "applies operations in request order" do
    image = Vips::Image.new_from_memory([ 255, 0, 0, 0, 255, 0 ].pack("C*"), 2, 1, 3, :uchar)

    result = ImageLab::Pipeline.call(image, [
      { "op" => "rotate", "degrees" => 90 },
      { "op" => "grayscale" }
    ], max_output_pixels: 10)

    assert_equal [ 1, 2 ], [ result.width, result.height ]
    assert_equal 1, result.bands
  end

  test "rejects output above the pixel limit" do
    image = Vips::Image.new_from_memory(Array.new(12, 255).pack("C*"), 2, 2, 3, :uchar)

    assert_raises(ImageLab::Errors::OutputLimitExceeded) do
      ImageLab::Pipeline.call(image, [ { "op" => "rotate", "degrees" => 90 } ], max_output_pixels: 3)
    end
  end

  test "chains grayscale and background through the registered pipeline" do
    image = Vips::Image.new_from_memory([ 100, 150, 200, 128 ].pack("C*"), 1, 1, 4, :uchar).copy(interpretation: :srgb)

    result = ImageLab::Pipeline.call(image, [
      { "op" => "grayscale" },
      { "op" => "background", "color" => "#ffffff" }
    ], max_output_pixels: 10)

    assert_equal 3, result.bands
    assert_equal :srgb, result.interpretation
    assert_equal [ 200.0, 200.0, 200.0 ], result.getpoint(0, 0)
  end
end
