# frozen_string_literal: true

require_relative "errors"
require_relative "operations/resize_to_fit"
require_relative "operations/resize_to_fill"
require_relative "operations/crop"
require_relative "operations/rotate"
require_relative "operations/flip"
require_relative "operations/grayscale"

module ImageLab
  class OperationRegistry
    DEFAULT_MAX_OPERATIONS = 16
    OPERATIONS = {
      "resize_to_fit" => Operations::ResizeToFit,
      "resize_to_fill" => Operations::ResizeToFill,
      "crop" => Operations::Crop,
      "rotate" => Operations::Rotate,
      "flip" => Operations::Flip,
      "grayscale" => Operations::Grayscale
    }.freeze

    def self.available
      OPERATIONS.keys
    end

    def self.validate!(operations, max_operations: env_limit("IMAGE_MAX_OPERATIONS", DEFAULT_MAX_OPERATIONS))
      raise Errors::InvalidOperation, "operations must be a JSON array" unless operations.is_a?(Array)
      raise Errors::OperationLimitExceeded, "operations exceed the maximum count" if operations.size > max_operations

      operations.each do |operation|
        name = operation.fetch("op") if operation.is_a?(Hash)
        raise Errors::InvalidOperation, "each operation must include a non-empty op string" unless name.is_a?(String) && name.strip.present?
        raise Errors::UnsupportedOperation, "operation is unsupported" unless OPERATIONS.key?(name)
      end

      operations
    rescue KeyError
      raise Errors::InvalidOperation, "each operation must include a non-empty op string"
    end

    def self.resolve!(operations)
      validate!(operations).map { |operation| [ OPERATIONS.fetch(operation.fetch("op")), operation ] }
    end

    def self.env_limit(name, default)
      value = Integer(ENV.fetch(name, default.to_s), 10)
      value.positive? ? value : default
    rescue ArgumentError, TypeError
      default
    end
  end
end
