# frozen_string_literal: true

require "thread"
require_relative "birefnet_manifest"
require_relative "birefnet/preprocessor"
require_relative "birefnet/restore"
require_relative "model_registry"
require_relative "u2netp"
require_relative "../errors"

module ImageLab
  module AI
    module Birefnet
      DEFAULT_MAX_CONCURRENCY = 1

      def self.call(image, manifest: BirefnetManifest.load!, model: ModelRegistry.fetch!(:birefnet), limiter: nil)
        limiter ||= U2netp.default_limiter
        tensor = Preprocessor.call(image, manifest:)
        limiter.with_token do
          response = model.predict({ manifest.input_name => nested(tensor) })

          Restore.new(output: response.fetch(manifest.output_name), source_width: image.width, source_height: image.height)
        end
      rescue ImageLab::Errors::AiUnavailable
        raise
      rescue StandardError
        raise ImageLab::Errors::AiUnavailable, BirefnetManifest::UNAVAILABLE_MESSAGE
      end

      def self.nested(tensor)
        nested_values(tensor.values.dup, tensor.shape)
      end

      def self.nested_values(values, shape)
        return values.shift if shape.empty?

        dimension, *remaining = shape
        Array.new(dimension) { nested_values(values, remaining) }
      end
      private_class_method :nested_values
      private_class_method :nested
    end
  end
end