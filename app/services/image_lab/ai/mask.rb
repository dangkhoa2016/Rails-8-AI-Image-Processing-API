# frozen_string_literal: true

require "vips"
require_relative "../errors"
require_relative "u2netp_manifest"

module ImageLab
  module AI
    class Mask
      MODEL_WIDTH = 320
      MODEL_HEIGHT = 320

      attr_reader :image

      def initialize(output:, source_width:, source_height:)
        width = positive_dimension!(source_width)
        height = positive_dimension!(source_height)
        values = flatten_output(output)
        normalized = normalize(values)
        model_image = Vips::Image.new_from_memory(normalized.pack("f*"), MODEL_WIDTH, MODEL_HEIGHT, 1, :float)
        @image = clamp(model_image.resize(width.to_f / MODEL_WIDTH, vscale: height.to_f / MODEL_HEIGHT, kernel: :linear))
      rescue Vips::Error, ArgumentError, TypeError, NoMethodError
        raise ImageLab::Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
      end

      private

      def flatten_output(output)
        flatten_level(output, [ 1, 1, MODEL_HEIGHT, MODEL_WIDTH ])
      end

      def flatten_level(value, dimensions)
        return [ Float(value) ] if dimensions.empty?

        raise ArgumentError unless value.is_a?(Array) && value.length == dimensions.first

        value.flat_map { |child| flatten_level(child, dimensions.drop(1)) }
      end

      def normalize(values)
        raise ArgumentError unless values.all?(&:finite?)

        minimum = values.min
        maximum = values.max
        return Array.new(values.length, 0.0) if minimum == maximum

        values.map { |value| (value - minimum) / (maximum - minimum) }
      end

      def clamp(image)
        lower_clamped = (image < 0.0).ifthenelse(0.0, image)
        (lower_clamped > 1.0).ifthenelse(1.0, lower_clamped)
      end

      def positive_dimension!(value)
        dimension = Integer(value)
        raise ArgumentError unless dimension.positive?

        dimension
      end
    end
  end
end
