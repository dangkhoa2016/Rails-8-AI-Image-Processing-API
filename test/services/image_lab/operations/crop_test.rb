# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsCropTest < ActiveSupport::TestCase
  test "crops an in-bounds rectangle" do
    image = Vips::Image.new_from_memory(Array.new(24, 255).pack("C*"), 4, 2, 3, :uchar)

    result = ImageLab::Operations::Crop.call(
      image,
      { "op" => "crop", "left" => 1, "top" => 0, "width" => 2, "height" => 1 }
    )

    assert_equal [ 2, 1 ], [ result.width, result.height ]
  end

  test "rejects invalid crop coordinates dimensions and bounds" do
    image = Vips::Image.new_from_memory(Array.new(12, 255).pack("C*"), 2, 2, 3, :uchar)

    [
      { "op" => "crop", "left" => -1, "top" => 0, "width" => 1, "height" => 1 },
      { "op" => "crop", "left" => 0, "top" => 0, "width" => 0, "height" => 1 },
      { "op" => "crop", "left" => 1, "top" => 0, "width" => 2, "height" => 1 },
      { "op" => "crop", "left" => "0", "top" => 0, "width" => 1, "height" => 1 }
    ].each do |operation|
      assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Crop.call(image, operation) }
    end
  end
end
