# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsRotateTest < ActiveSupport::TestCase
  test "rotates 90 degrees and swaps dimensions" do
    image = Vips::Image.new_from_memory(Array.new(18, 255).pack("C*"), 2, 3, 3, :uchar)

    result = ImageLab::Operations::Rotate.call(image, { "op" => "rotate", "degrees" => 90 })

    assert_equal [ 3, 2 ], [ result.width, result.height ]
  end

  test "permits only the documented right angles" do
    image = Vips::Image.new_from_memory(Array.new(18, 255).pack("C*"), 2, 3, 3, :uchar)

    assert_equal [ 2, 3 ], ImageLab::Operations::Rotate.call(image, { "op" => "rotate", "degrees" => 180 }).then { |result| [ result.width, result.height ] }
    assert_equal [ 3, 2 ], ImageLab::Operations::Rotate.call(image, { "op" => "rotate", "degrees" => 270 }).then { |result| [ result.width, result.height ] }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Rotate.call(image, { "op" => "rotate", "degrees" => 45 }) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Rotate.call(image, { "op" => "rotate", "degrees" => "90" }) }
  end

  test "rejects unknown rotate parameters" do
    image = Vips::Image.new_from_memory(Array.new(18, 255).pack("C*"), 2, 3, 3, :uchar)

    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::Rotate.call(image, { "op" => "rotate", "degrees" => 90, "unexpected" => true })
    end
  end
end
