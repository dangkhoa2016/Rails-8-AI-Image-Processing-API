# frozen_string_literal: true

require_relative "operation_registry"

module ImageLab
  class Pipeline
    def self.call(image, operations, max_output_pixels:)
      validate_output_size!(image, max_output_pixels)

      OperationRegistry.resolve!(operations).reduce(image) do |result, (operation_class, operation)|
        transformed = operation_class.call(result, operation)
        validate_output_size!(transformed, max_output_pixels)

        transformed
      end
    end

    def self.validate_output_size!(image, max_output_pixels)
      return if image.width * image.height <= max_output_pixels

      raise Errors::OutputLimitExceeded, "image exceeds output pixel limit"
    end
    private_class_method :validate_output_size!
  end
end
