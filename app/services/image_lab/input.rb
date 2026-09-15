# frozen_string_literal: true

require "vips"
require_relative "errors"

module ImageLab
  class Input
    Result = Data.define(:image)
    DEFAULT_MAX_UPLOAD_BYTES = 10 * 1024 * 1024
    DEFAULT_MAX_INPUT_PIXELS = 25_000_000
    DEFAULT_MAX_DIMENSION = 8_192
    ALLOWED_LOADERS = %w[jpegload_buffer pngload_buffer webpload_buffer].freeze

    def self.call(upload, max_upload_bytes: env_limit("IMAGE_MAX_UPLOAD_BYTES", DEFAULT_MAX_UPLOAD_BYTES), max_input_pixels: env_limit("IMAGE_MAX_INPUT_PIXELS", DEFAULT_MAX_INPUT_PIXELS), max_dimension: env_limit("IMAGE_MAX_DIMENSION", DEFAULT_MAX_DIMENSION))
      new(upload, max_upload_bytes:, max_input_pixels:, max_dimension:).call
    end

    def self.env_limit(name, default)
      value = Integer(ENV.fetch(name, default.to_s), 10)
      raise ArgumentError, "#{name} must be positive" unless value.positive?

      value
    end

    def initialize(upload, max_upload_bytes:, max_input_pixels:, max_dimension:)
      @upload = upload
      @max_upload_bytes = max_upload_bytes
      @max_input_pixels = max_input_pixels
      @max_dimension = max_dimension
    end

    def call
      buffer = read_buffer
      raise Errors::InvalidImage, "image is empty" if buffer.empty?

      image = Vips::Image.new_from_buffer(buffer, "")
      raise Errors::UnsupportedFormat, "image format is unsupported" unless ALLOWED_LOADERS.include?(loader_for(image))
      raise Errors::UnsupportedFormat, "multi-page images are unsupported" if page_count(image) > 1
      raise Errors::PixelLimitExceeded, "image exceeds dimension limit" if image.width > @max_dimension || image.height > @max_dimension
      raise Errors::PixelLimitExceeded, "image exceeds pixel limit" if image.width * image.height > @max_input_pixels

      Result.new(image: image)
    rescue Vips::Error
      raise Errors::InvalidImage, "image cannot be decoded"
    end

    private

    def read_buffer
      raise Errors::InvalidImage, "image is missing" unless @upload.respond_to?(:read)

      buffer = @upload.read(@max_upload_bytes + 1).to_s.b
      raise Errors::UploadTooLarge, "image exceeds upload limit" if buffer.bytesize > @max_upload_bytes

      buffer
    end

    def loader_for(image)
      image.get("vips-loader") if image.get_typeof("vips-loader") != 0
    end

    def page_count(image)
      image.get_typeof("n-pages") == 0 ? 1 : image.get("n-pages").to_i
    end
  end
end
