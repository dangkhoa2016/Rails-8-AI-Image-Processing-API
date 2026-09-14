# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsFilterOperationsTest < ActiveSupport::TestCase
  test "blur softens a bright center pixel with a bounded sigma" do
    result = ImageLab::Operations::Blur.call(center_pixel_image, { "op" => "blur", "sigma" => 1.0 })

    assert_operator result.getpoint(2, 2).first, :<, 255
    assert_operator result.getpoint(2, 2).first, :>, 0
  end

  test "sharpen amount zero leaves pixels unchanged" do
    image = edge_image

    result = ImageLab::Operations::Sharpen.call(image, { "op" => "sharpen", "amount" => 0.0 })

    assert_equal image.getpoint(2, 0), result.getpoint(2, 0)
  end

  test "sharpen amount one changes a boundary pixel with the fixed profile" do
    result = ImageLab::Operations::Sharpen.call(edge_image, { "op" => "sharpen", "amount" => 1.0 })

    assert_operator result.getpoint(2, 0).first, :>, 128
  end

  test "filters reject values outside their bounded public ranges" do
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Blur.call(center_pixel_image, { "op" => "blur", "sigma" => 0 }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Blur.call(center_pixel_image, { "op" => "blur", "sigma" => 20.1 }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Sharpen.call(edge_image, { "op" => "sharpen", "amount" => -0.1 }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Sharpen.call(edge_image, { "op" => "sharpen", "amount" => 1.1 }) }
  end

  private

  def center_pixel_image
    pixels = Array.new(5 * 5 * 3, 0)
    pixels[(2 * 5 + 2) * 3, 3] = [ 255, 255, 255 ]
    Vips::Image.new_from_memory(pixels.pack("C*"), 5, 5, 3, :uchar).copy(interpretation: :srgb)
  end

  def edge_image
    pixels = [ 0, 0, 0, 0, 0, 0, 128, 128, 128, 255, 255, 255, 255, 255, 255 ]
    Vips::Image.new_from_memory(pixels.pack("C*"), 5, 1, 3, :uchar).copy(interpretation: :srgb)
  end
end
