# frozen_string_literal: true

require_relative "operation_registry"

module ImageLab
  class Pipeline
    def self.call(image, operations, max_output_pixels:)
      OperationRegistry.resolve!(operations).reduce(image) do |result, (operation_class, operation)|
        transformed = operation_class.call(result, operation)
        raise Errors::OutputLimitExceeded, "image exceeds output pixel limit" if transformed.width * transformed.height > max_output_pixels

        transformed
      end
    end
  end
end
