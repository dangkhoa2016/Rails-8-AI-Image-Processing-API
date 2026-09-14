# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsResizeTest < ActiveSupport::TestCase
  test "resize to fit preserves aspect ratio inside the requested bounds" do
    result = ImageLab::Operations::ResizeToFit.call(
      rgb_image(width: 4, height: 2),
      { "op" => "resize_to_fit", "width" => 3, "height" => 3 },
      max_dimension: 8
    )

    assert_equal [ 3, 2 ], [ result.width, result.height ]
  end

  test "resize to fit rejects dimensions outside the integer limit" do
    image = rgb_image(width: 2, height: 1)

    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::ResizeToFit.call(image, { "op" => "resize_to_fit", "width" => 0, "height" => 1 }, max_dimension: 8)
    end
    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::ResizeToFit.call(image, { "op" => "resize_to_fit", "width" => "2", "height" => 1 }, max_dimension: 8)
    end
    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::ResizeToFit.call(image, { "op" => "resize_to_fit", "width" => 9, "height" => 1 }, max_dimension: 8)
    end
  end

  test "resize to fit rejects unknown parameters" do
    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::ResizeToFit.call(
        rgb_image(width: 2, height: 1),
        { "op" => "resize_to_fit", "width" => 2, "height" => 1, "unexpected" => true },
        max_dimension: 8
      )
    end
  end

  test "resize to fill covers the requested dimensions" do
    result = ImageLab::Operations::ResizeToFill.call(
      rgb_image(width: 4, height: 2),
      { "op" => "resize_to_fill", "width" => 3, "height" => 3 },
      max_dimension: 8
    )

    assert_equal [ 3, 3 ], [ result.width, result.height ]
  end

  test "resize to fill rejects dimensions outside the integer limit" do
    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::ResizeToFill.call(
        rgb_image(width: 2, height: 1),
        { "op" => "resize_to_fill", "width" => 9, "height" => 1 },
        max_dimension: 8
      )
    end
  end

  test "resize to fill rejects unknown parameters" do
    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::ResizeToFill.call(
        rgb_image(width: 2, height: 1),
        { "op" => "resize_to_fill", "width" => 2, "height" => 1, "unexpected" => true },
        max_dimension: 8
      )
    end
  end

  private

  def rgb_image(width:, height:)
    Vips::Image.new_from_memory(Array.new(width * height * 3, 255).pack("C*"), width, height, 3, :uchar)
  end
end
