# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsColorAdjustmentsTest < ActiveSupport::TestCase
  test "brightness maps a bounded public amount to a pixel offset" do
    result = ImageLab::Operations::Brightness.call(rgb_image([ 100, 150, 200 ]), { "op" => "brightness", "amount" => 0.2 })

    assert_equal [ 151.0, 201.0, 251.0 ], result.getpoint(0, 0)
  end

  test "contrast scales RGB around the fixed midpoint" do
    result = ImageLab::Operations::Contrast.call(rgb_image([ 64, 128, 192 ]), { "op" => "contrast", "amount" => 0.5 })

    assert_equal [ 32.0, 128.0, 224.0 ], result.getpoint(0, 0)
  end

  test "saturation at minus one removes chroma" do
    result = ImageLab::Operations::Saturation.call(rgb_image([ 64, 128, 192 ]), { "op" => "saturation", "amount" => -1.0 })

    assert_equal [ 192.0, 192.0, 192.0 ], result.getpoint(0, 0)
  end

  test "brightness and contrast convert CMYK input to sRGB before adjustment" do
    image = cmyk_image

    brightness = ImageLab::Operations::Brightness.call(image, { "op" => "brightness", "amount" => 0.1 })
    contrast = ImageLab::Operations::Contrast.call(image, { "op" => "contrast", "amount" => 0.5 })

    assert_equal image.colourspace(:srgb).linear(1, 25.5).getpoint(0, 0), brightness.getpoint(0, 0)
    assert_equal image.colourspace(:srgb).linear(1.5, -64).getpoint(0, 0), contrast.getpoint(0, 0)
  end

  test "zero amount leaves grayscale alpha images unchanged" do
    image = grayscale_alpha_image

    [ [ ImageLab::Operations::Brightness, "brightness" ], [ ImageLab::Operations::Contrast, "contrast" ], [ ImageLab::Operations::Saturation, "saturation" ] ].each do |operation, name|
      result = operation.call(image, { "op" => name, "amount" => 0.0 })

      assert_equal image.bands, result.bands
      assert_equal image.write_to_memory, result.write_to_memory
    end
  end

  test "color adjustments reject invalid amounts and unexpected fields" do
    [
      [ ImageLab::Operations::Brightness, "brightness" ],
      [ ImageLab::Operations::Contrast, "contrast" ],
      [ ImageLab::Operations::Saturation, "saturation" ]
    ].each do |operation, name|
      assert_raises(ImageLab::Errors::InvalidOperation) { operation.call(rgb_image([ 1, 2, 3 ]), { "op" => name, "amount" => "0" }) }
      assert_raises(ImageLab::Errors::InvalidOperation) { operation.call(rgb_image([ 1, 2, 3 ]), { "op" => name, "amount" => 1.1 }) }
      assert_raises(ImageLab::Errors::InvalidOperation) { operation.call(rgb_image([ 1, 2, 3 ]), { "op" => name, "amount" => Float::NAN }) }
      assert_raises(ImageLab::Errors::InvalidOperation) { operation.call(rgb_image([ 1, 2, 3 ]), { "op" => name, "amount" => 0, "extra" => true }) }
    end
  end

  private

  def rgb_image(pixel)
    Vips::Image.new_from_memory(pixel.pack("C*"), 1, 1, 3, :uchar).copy(interpretation: :srgb)
  end

  def cmyk_image
    Vips::Image.new_from_memory([ 0, 255, 255, 0 ].pack("C*"), 1, 1, 4, :uchar).copy(interpretation: :cmyk)
  end

  def grayscale_alpha_image
    Vips::Image.new_from_memory([ 100, 128 ].pack("C*"), 1, 1, 2, :uchar).copy(interpretation: :b_w)
  end
end
