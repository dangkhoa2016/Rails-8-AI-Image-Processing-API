# frozen_string_literal: true

require_relative "../errors"

module ImageLab
  module Operations
    class Encode
      Result = Data.define(:bytes, :content_type, :format)

      def self.call(image, format:, quality:)
        format ||= "png"
        raise Errors::InvalidOperation, "format is unsupported" unless %w[png jpeg webp].include?(format)
        raise Errors::InvalidOperation, "PNG does not accept quality" if format == "png" && !quality.nil?

        quality = 85 if quality.nil? && format != "png"
        unless format == "png" || quality.is_a?(Integer) && quality.between?(1, 100)
          raise Errors::InvalidOperation, "quality must be an integer from 1 to 100"
        end

        case format
        when "png"
          Result.new(bytes: image.write_to_buffer(".png"), content_type: "image/png", format: "png")
        when "jpeg"
          Result.new(bytes: image.write_to_buffer(".jpg[Q=#{quality}]"), content_type: "image/jpeg", format: "jpeg")
        when "webp"
          Result.new(bytes: image.write_to_buffer(".webp[Q=#{quality}]"), content_type: "image/webp", format: "webp")
        end
      end
    end
  end
end
