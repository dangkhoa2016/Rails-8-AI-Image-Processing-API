# frozen_string_literal: true

require "vips"
require "test_helper"

class VipsRuntimeTest < ActiveSupport::TestCase
  test "loads libvips and processes an in-memory image" do
    assert_operator Vips.version(0), :>, 0

    image = Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar)
    resized_image = image.resize(2)
    encoded_image = resized_image.write_to_buffer(".png")

    assert_equal 2, resized_image.width
    assert_equal 2, resized_image.height
    assert encoded_image.start_with?("\x89PNG\r\n\x1A\n".b), "expected a PNG-encoded image"
  end
end
