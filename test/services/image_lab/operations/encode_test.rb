# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLabOperationsEncodeTest < ActiveSupport::TestCase
  test "encodes JPEG and WebP with a bounded quality" do
    image = Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar)

    jpeg = ImageLab::Operations::Encode.call(image, format: "jpeg", quality: 80)
    webp = ImageLab::Operations::Encode.call(image, format: "webp", quality: 80)

    assert_equal "image/jpeg", jpeg.content_type
    assert_equal "image/webp", webp.content_type
    assert jpeg.bytes.bytesize.positive?
    assert webp.bytes.bytesize.positive?
  end

  test "defaults to PNG and rejects invalid output settings" do
    image = Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar)

    png = ImageLab::Operations::Encode.call(image, format: nil, quality: nil)

    assert_equal "image/png", png.content_type
    assert_equal "png", png.format
    assert png.bytes.start_with?("\x89PNG\r\n\x1A\n".b)
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Encode.call(image, format: "png", quality: 80) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Encode.call(image, format: "jpeg", quality: 101) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::Operations::Encode.call(image, format: "tiff", quality: nil) }
  end

  test "strips EXIF orientation and GPS metadata from every output format" do
    image = Vips::Image.new_from_buffer(exif_orientation_with_gps_jpeg, "")
    assert_includes image.get_fields, "exif-ifd3-GPSLatitude"
    assert_includes image.get_fields, "exif-ifd3-GPSLongitude"

    %w[png jpeg webp].each do |format|
      result = ImageLab::Operations::Encode.call(image, format:, quality: format == "png" ? nil : 85)
      output = Vips::Image.new_from_buffer(result.bytes, "")

      assert_empty output.get_fields.grep(/exif|gps|orientation|comment/i), "#{format} retained metadata"
    end
  end
end
