# frozen_string_literal: true

require "vips"
require_relative "../../errors"
require_relative "../birefnet_manifest"

module ImageLab
  module AI
    module Birefnet
      class Restore
        MODEL_WIDTH = 1024
        MODEL_HEIGHT = 1024
        OUTPUT_SHAPE = [ 1, 1, MODEL_HEIGHT, MODEL_WIDTH ].freeze

        attr_reader :image

        def self.call(output:, source_width:, source_height:)
          new(output:, source_width:, source_height:).image
        end

        def initialize(output:, source_width:, source_height:)
          width = positive_dimension!(source_width)
          height = positive_dimension!(source_height)
          probabilities = sigmoid_values(flatten_output(output))
          model_image = Vips::Image.new_from_memory(probabilities.pack("f*"), MODEL_WIDTH, MODEL_HEIGHT, 1, :float)
          @image = clamp(model_image.resize(width.to_f / MODEL_WIDTH, vscale: height.to_f / MODEL_HEIGHT, kernel: :linear))
        rescue Vips::Error, ArgumentError, TypeError, NoMethodError
          raise ImageLab::Errors::AiUnavailable, BirefnetManifest::UNAVAILABLE_MESSAGE
        end

        private

        def flatten_output(output)
          flatten_level(output, OUTPUT_SHAPE)
        end

        def flatten_level(value, dimensions)
          return [ Float(value) ] if dimensions.empty?

          raise ArgumentError unless value.is_a?(Array) && value.length == dimensions.first

          value.flat_map { |child| flatten_level(child, dimensions.drop(1)) }
        end

        def sigmoid_values(values)
          raise ArgumentError unless values.length == MODEL_WIDTH * MODEL_HEIGHT && values.all?(&:finite?)

          values.map { |value| 1.0 / (1.0 + Math.exp(-value)) }
        end

        def clamp(image)
          lower = (image < 0.0).ifthenelse(0.0, image)
          (lower > 1.0).ifthenelse(1.0, lower)
        end

        def positive_dimension!(value)
          dimension = Integer(value)
          raise ArgumentError unless dimension.positive?

          dimension
        end
      end
    end
  end
end