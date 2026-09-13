# frozen_string_literal: true

require_relative "../errors"

module ImageLab
  module Operations
    class Crop
      def self.call(image, operation)
        left = coordinate!(operation, "left")
        top = coordinate!(operation, "top")
        width = dimension!(operation, "width")
        height = dimension!(operation, "height")
        raise Errors::InvalidOperation, "crop rectangle is outside the image" if left + width > image.width || top + height > image.height

        image.crop(left, top, width, height)
      end

      def self.coordinate!(operation, name)
        value = operation[name] if operation.is_a?(Hash)
        return value if value.is_a?(Integer) && value >= 0

        raise Errors::InvalidOperation, "#{name} must be a non-negative integer"
      end

      def self.dimension!(operation, name)
        value = operation[name] if operation.is_a?(Hash)
        return value if value.is_a?(Integer) && value.positive?

        raise Errors::InvalidOperation, "#{name} must be a positive integer"
      end
      private_class_method :coordinate!, :dimension!
    end
  end
end
