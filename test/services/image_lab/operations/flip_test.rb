# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsFlipTest < ActiveSupport::TestCase
  test "flips horizontal pixels" do
    image = Vips::Image.new_from_memory([ 255, 0, 0, 0, 255, 0 ].pack("C*"), 2, 1, 3, :uchar)

    result = ImageLab::Operations::Flip.call(image, { "op" => "flip", "mode" => "horizontal" })

    assert_equal [ 0, 255, 0 ], result.getpoint(0, 0)
  end

  test "permits vertical mode and rejects unknown modes" do
    image = Vips::Image.new_from_memory([ 255, 0, 0, 0, 255, 0 ].pack("C*"), 1, 2, 3, :uchar)

    assert_equal [ 0, 255, 0 ], ImageLab::Operations::Flip.call(image, { "op" => "flip", "mode" => "vertical" }).getpoint(0, 0)
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Flip.call(image, { "op" => "flip", "mode" => "diagonal" }) }
  end

  test "rejects unknown flip parameters" do
    image = Vips::Image.new_from_memory([ 255, 0, 0, 0, 255, 0 ].pack("C*"), 1, 2, 3, :uchar)

    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::Operations::Flip.call(image, { "op" => "flip", "mode" => "vertical", "unexpected" => true })
    end
  end
end
