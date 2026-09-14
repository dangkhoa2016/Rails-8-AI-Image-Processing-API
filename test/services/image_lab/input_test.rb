# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"
require "vips"

class ImageLab::InputTest < ActiveSupport::TestCase
  test "returns a decoded Vips image for JPEG, PNG, and WebP" do
    %w[.jpg .png .webp].each do |suffix|
      result = ImageLab::Input.call(StringIO.new(rgb_image.write_to_buffer(suffix)))

      assert_instance_of Vips::Image, result.image
      assert_equal 2, result.image.width
      assert_equal 1, result.image.height
    end
  end

  test "raises the domain error classes for missing and over-limit bytes" do
    assert_raises(ImageLab::Errors::InvalidImage) { ImageLab::Input.call(nil) }
    assert_raises(ImageLab::Errors::UploadTooLarge) do
      ImageLab::Input.call(StringIO.new("ab"), max_upload_bytes: 1)
    end
  end

  test "rejects empty and truncated image data as invalid" do
    assert_raises(ImageLab::Errors::InvalidImage) { ImageLab::Input.call(StringIO.new("")) }
    assert_raises(ImageLab::Errors::InvalidImage) { ImageLab::Input.call(StringIO.new("\xFF\xD8\xFF\xE0".b)) }
  end

  test "uses decoded content instead of the filename and rejects TIFF" do
    png_upload = StringIO.new(rgb_image.write_to_buffer(".png"))
    png_upload.define_singleton_method(:original_filename) { "not-an-image.txt" }
    assert_instance_of Vips::Image, ImageLab::Input.call(png_upload).image

    tiff_upload = StringIO.new(rgb_image.write_to_buffer(".tiff"))
    assert_raises(ImageLab::Errors::UnsupportedFormat) { ImageLab::Input.call(tiff_upload) }
  end

  test "rejects decoded dimension and pixel excess" do
    png = rgb_image.write_to_buffer(".png")
    assert_raises(ImageLab::Errors::PixelLimitExceeded) do
      ImageLab::Input.call(StringIO.new(png), max_dimension: 1)
    end
    assert_raises(ImageLab::Errors::PixelLimitExceeded) do
      ImageLab::Input.call(StringIO.new(png), max_input_pixels: 1)
    end
  end

  test "uses configured environment limits by default" do
    png = rgb_image.write_to_buffer(".png")

    with_env("IMAGE_MAX_UPLOAD_BYTES" => "1") do
      assert_raises(ImageLab::Errors::UploadTooLarge) { ImageLab::Input.call(StringIO.new(png)) }
    end
    with_env("IMAGE_MAX_DIMENSION" => "1") do
      assert_raises(ImageLab::Errors::PixelLimitExceeded) { ImageLab::Input.call(StringIO.new(png)) }
    end
    with_env("IMAGE_MAX_INPUT_PIXELS" => "1") do
      assert_raises(ImageLab::Errors::PixelLimitExceeded) { ImageLab::Input.call(StringIO.new(png)) }
    end
  end

  test "honors EXIF orientation before returning the image" do
    source = Vips::Image.new_from_buffer(exif_orientation_with_gps_jpeg, "")
    image = ImageLab::Input.call(StringIO.new(exif_orientation_with_gps_jpeg)).image

    assert_equal [ 1, 2 ], [ image.width, image.height ]
    assert_equal source.getpoint(0, 0), image.getpoint(0, 0)
    assert_equal source.getpoint(1, 0), image.getpoint(0, 1)
    assert_not_includes image.get_fields, "orientation"
    assert_not_includes image.get_fields, "exif-ifd0-Orientation"
  end

  test "removes its app-owned temporary upload after a successful processing block" do
    with_image_lab_temp_directory do |directory|
      paths_during_processing = nil

      ImageLab::Input.with_image(StringIO.new(rgb_image.write_to_buffer(".png")), temporary_directory: directory) do |image|
        paths_during_processing = image_lab_temp_paths(directory)
        assert_equal 2, image.width
      end

      assert_equal 1, paths_during_processing.length
      assert_empty image_lab_temp_paths(directory)
    end
  end

  test "removes its app-owned temporary upload after validation and Vips decode failures" do
    with_image_lab_temp_directory do |directory|
      assert_raises(ImageLab::Errors::InvalidImage) do
        ImageLab::Input.with_image(StringIO.new(""), temporary_directory: directory) { flunk }
      end
      assert_empty image_lab_temp_paths(directory)

      tiff = rgb_image.write_to_buffer(".tiff")
      assert_raises(ImageLab::Errors::UnsupportedFormat) do
        ImageLab::Input.with_image(StringIO.new(tiff), temporary_directory: directory) { flunk }
      end
      assert_empty image_lab_temp_paths(directory)

      assert_raises(ImageLab::Errors::InvalidImage) do
        ImageLab::Input.with_image(StringIO.new("\xFF\xD8\xFF\xE0".b), temporary_directory: directory) { flunk }
      end
      assert_empty image_lab_temp_paths(directory)
    end
  end

  test "removes its app-owned temporary upload when processing raises" do
    with_image_lab_temp_directory do |directory|
      path = nil

      assert_raises(RuntimeError) do
        ImageLab::Input.with_image(StringIO.new(rgb_image.write_to_buffer(".png")), temporary_directory: directory) do
          path = image_lab_temp_paths(directory).fetch(0)
          raise "client disconnected"
        end
      end

      assert_not File.exist?(path)
      assert_empty image_lab_temp_paths(directory)
    end
  end

  test "does not translate a Vips processing error into an invalid upload" do
    with_image_lab_temp_directory do |directory|
      assert_raises(Vips::Error) do
        ImageLab::Input.with_image(StringIO.new(rgb_image.write_to_buffer(".png")), temporary_directory: directory) do
          raise Vips::Error, "pipeline failed"
        end
      end

      assert_empty image_lab_temp_paths(directory)
    end
  end

  private

  def rgb_image
    Vips::Image.new_from_memory([ 255, 0, 0, 0, 255, 0 ].pack("C*"), 2, 1, 3, :uchar)
  end

  def with_env(overrides)
    previous = overrides.to_h { |key, _value| [ key, ENV[key] ] }
    ENV.update(overrides)
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def image_lab_temp_paths(directory)
    Dir.children(directory).map { |name| File.join(directory, name) }
  end

  def with_image_lab_temp_directory
    Dir.mktmpdir("image-lab-test-", Rails.root.join("tmp")) { |directory| yield directory }
  end
end
