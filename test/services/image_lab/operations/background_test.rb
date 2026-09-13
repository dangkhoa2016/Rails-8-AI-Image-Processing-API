# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsBackgroundTest < ActiveSupport::TestCase
  test "flattens an alpha image onto a strict RGB background" do
    image = Vips::Image.new_from_memory([ 100, 150, 200, 128 ].pack("C*"), 1, 1, 4, :uchar).copy(interpretation: :srgb)

    result = ImageLab::Operations::Background.call(image, { "op" => "background", "color" => "#ffffff" })

    assert_equal 3, result.bands
    assert_equal [ 177.0, 202.0, 227.0 ], result.getpoint(0, 0)
  end

  test "requires alpha and rejects malformed colors" do
    opaque = Vips::Image.new_from_memory([ 1, 2, 3 ].pack("C*"), 1, 1, 3, :uchar).copy(interpretation: :srgb)
    alpha = Vips::Image.new_from_memory([ 1, 2, 3, 4 ].pack("C*"), 1, 1, 4, :uchar).copy(interpretation: :srgb)

    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Background.call(opaque, { "op" => "background", "color" => "#ffffff" }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Background.call(alpha, { "op" => "background", "color" => "blue" }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Background.call(alpha, { "op" => "background", "color" => "#ffffff", "extra" => true }) }
  end

  test "flattens grayscale alpha images to three-band sRGB" do
    image = Vips::Image.new_from_memory([ 146, 128 ].pack("C*"), 1, 1, 2, :uchar).copy(interpretation: :b_w)

    result = ImageLab::Operations::Background.call(image, { "op" => "background", "color" => "#ffffff" })

    assert_equal 3, result.bands
    assert_equal :srgb, result.interpretation
    assert_equal [ 200.0, 200.0, 200.0 ], result.getpoint(0, 0)
  end
end
