# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsGrayscaleTest < ActiveSupport::TestCase
  test "converts an RGB image to one gray band" do
    image = Vips::Image.new_from_memory([ 255, 0, 0, 0, 255, 0 ].pack("C*"), 2, 1, 3, :uchar)

    result = ImageLab::Operations::Grayscale.call(image, { "op" => "grayscale" })

    assert_equal 1, result.bands
  end

  test "rejects extra parameters" do
    image = Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar)

    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::Grayscale.call(image, { "op" => "grayscale", "mode" => "unexpected" })
    end
  end
end
