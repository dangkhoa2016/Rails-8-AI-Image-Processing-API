# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsTintTest < ActiveSupport::TestCase
  test "blends validated RGB tint color at the requested strength" do
    result = ImageLab::Operations::Tint.call(rgb_image([ 100, 150, 200 ]), { "op" => "tint", "color" => "#ff0000", "strength" => 0.5 })

    assert_equal [ 177.5, 75.0, 100.0 ], result.getpoint(0, 0)
  end

  test "preserves alpha while tinting color bands" do
    image = Vips::Image.new_from_memory([ 100, 150, 200, 128 ].pack("C*"), 1, 1, 4, :uchar).copy(interpretation: :srgb)

    result = ImageLab::Operations::Tint.call(image, { "op" => "tint", "color" => "#ff0000", "strength" => 0.5 })

    assert_equal 4, result.bands
    assert_equal 128.0, result.getpoint(0, 0).last
  end

  test "converts CMYK input to sRGB before tinting" do
    image = Vips::Image.new_from_memory([ 0, 255, 255, 0 ].pack("C*"), 1, 1, 4, :uchar).copy(interpretation: :cmyk)

    result = ImageLab::Operations::Tint.call(image, { "op" => "tint", "color" => "#000000", "strength" => 0.0 })

    assert_equal image.colourspace(:srgb).getpoint(0, 0), result.getpoint(0, 0)
  end

  test "rejects malformed colors and invalid strengths" do
    image = rgb_image([ 1, 2, 3 ])

    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Tint.call(image, { "op" => "tint", "color" => "#fff", "strength" => 0.5 }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Tint.call(image, { "op" => "tint", "color" => "#00ff00", "strength" => 1.1 }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Tint.call(image, { "op" => "tint", "color" => "#00ff00", "strength" => "0.5" }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Tint.call(image, { "op" => "tint", "color" => "#00ff00", "strength" => 0.5, "extra" => true }) }
  end

  private

  def rgb_image(pixel)
    Vips::Image.new_from_memory(pixel.pack("C*"), 1, 1, 3, :uchar).copy(interpretation: :srgb)
  end
end
