# frozen_string_literal: true

require "vips"
require "fileutils"
require "tempfile"
require_relative "errors"

module ImageLab
  class Input
    Result = Data.define(:image)
    DEFAULT_MAX_UPLOAD_BYTES = 10 * 1024 * 1024
    DEFAULT_MAX_INPUT_PIXELS = 25_000_000
    DEFAULT_MAX_DIMENSION = 8_192
    ALLOWED_LOADERS = %w[jpegload jpegload_buffer pngload pngload_buffer webpload webpload_buffer].freeze

    def self.call(upload, max_upload_bytes: env_limit("IMAGE_MAX_UPLOAD_BYTES", DEFAULT_MAX_UPLOAD_BYTES), max_input_pixels: env_limit("IMAGE_MAX_INPUT_PIXELS", DEFAULT_MAX_INPUT_PIXELS), max_dimension: env_limit("IMAGE_MAX_DIMENSION", DEFAULT_MAX_DIMENSION))
      new(upload, max_upload_bytes:, max_input_pixels:, max_dimension:).call
    end

    def self.with_image(upload, max_upload_bytes: env_limit("IMAGE_MAX_UPLOAD_BYTES", DEFAULT_MAX_UPLOAD_BYTES), max_input_pixels: env_limit("IMAGE_MAX_INPUT_PIXELS", DEFAULT_MAX_INPUT_PIXELS), max_dimension: env_limit("IMAGE_MAX_DIMENSION", DEFAULT_MAX_DIMENSION), temporary_directory: nil, &block)
      new(upload, max_upload_bytes:, max_input_pixels:, max_dimension:, temporary_directory:).with_image(&block)
    end

    def self.default_temporary_directory
      base = Rails.root.join("tmp/image_lab")
      Rails.env.test? ? base.join("process-#{Process.pid}") : base
    end

    def self.env_limit(name, default)
      value = Integer(ENV.fetch(name, default.to_s), 10)
      raise ArgumentError, "#{name} must be positive" unless value.positive?

      value
    end

    def initialize(upload, max_upload_bytes:, max_input_pixels:, max_dimension:, temporary_directory: nil)
      @upload = upload
      @max_upload_bytes = max_upload_bytes
      @max_input_pixels = max_input_pixels
      @max_dimension = max_dimension
      @temporary_directory = temporary_directory || self.class.default_temporary_directory
    end

    def call
      buffer = read_buffer
      Result.new(image: qualify(Vips::Image.new_from_buffer(buffer, "")))
    rescue Vips::Error
      raise Errors::InvalidImage, "image cannot be decoded"
    end

    def with_image
      buffer = read_buffer
      tempfile = Tempfile.new([ "image-lab-", ".upload" ], temp_directory)
      tempfile.binmode
      tempfile.write(buffer)
      tempfile.flush

      yield qualify_file(tempfile.path)
    ensure
      tempfile&.close!
    end

    private

    def read_buffer
      raise Errors::InvalidImage, "image is missing" unless @upload.respond_to?(:read)

      buffer = @upload.read(@max_upload_bytes + 1).to_s.b
      raise Errors::UploadTooLarge, "image exceeds upload limit" if buffer.bytesize > @max_upload_bytes
      raise Errors::InvalidImage, "image is empty" if buffer.empty?

      buffer
    end

    def qualify(image)
      raise Errors::UnsupportedFormat, "image format is unsupported" unless ALLOWED_LOADERS.include?(loader_for(image))
      raise Errors::UnsupportedFormat, "multi-page images are unsupported" if page_count(image) > 1

      image = image.autorot
      raise Errors::PixelLimitExceeded, "image exceeds dimension limit" if image.width > @max_dimension || image.height > @max_dimension
      raise Errors::PixelLimitExceeded, "image exceeds pixel limit" if image.width * image.height > @max_input_pixels

      image
    end

    def qualify_file(path)
      qualify(Vips::Image.new_from_file(path))
    rescue Vips::Error
      raise Errors::InvalidImage, "image cannot be decoded"
    end

    def temp_directory
      FileUtils.mkdir_p(@temporary_directory)
      @temporary_directory
    end

    def loader_for(image)
      image.get("vips-loader") if image.get_typeof("vips-loader") != 0
    end

    def page_count(image)
      image.get_typeof("n-pages") == 0 ? 1 : image.get("n-pages").to_i
    end
  end
end
