# frozen_string_literal: true

require "thread"
require_relative "mask"
require_relative "model_registry"
require_relative "u2netp_manifest"
require_relative "u2netp/preprocessor"
require_relative "../errors"

module ImageLab
  module AI
    module U2netp
      DEFAULT_MAX_CONCURRENCY = 1
      LIMITER_MUTEX = Mutex.new

      class InferenceLimiter
        def initialize(limit)
          limit = Integer(limit)
          raise ArgumentError unless limit.positive?

          @tokens = Queue.new
          limit.times { @tokens << true }
        end

        def with_token
          token = @tokens.pop
          yield
        ensure
          @tokens << token if token
        end
      end

      def self.call(image, manifest: U2netpManifest.load!, model: ModelRegistry.fetch!(:u2netp), limiter: nil)
        limiter ||= default_limiter
        tensor = Preprocessor.call(image, manifest:)
        response = limiter.with_token { model.predict({ manifest.input_name => nested_values(tensor.values.dup, tensor.shape) }) }

        Mask.new(output: response.fetch(manifest.output_name), source_width: image.width, source_height: image.height)
      rescue ImageLab::Errors::AiUnavailable
        raise
      rescue StandardError
        raise ImageLab::Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
      end

      def self.default_limiter
        LIMITER_MUTEX.synchronize { @default_limiter ||= InferenceLimiter.new(env_limit) }
      end

      def self.nested_values(values, shape)
        return values.shift if shape.empty?

        dimension, *remaining = shape
        Array.new(dimension) { nested_values(values, remaining) }
      end
      private_class_method :nested_values

      def self.env_limit
        value = Integer(ENV.fetch("IMAGE_AI_MAX_CONCURRENCY", DEFAULT_MAX_CONCURRENCY.to_s), 10)
        raise ArgumentError unless value.positive?

        value
      end
      private_class_method :env_limit
    end
  end
end
