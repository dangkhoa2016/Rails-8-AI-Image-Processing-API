# frozen_string_literal: true

module ImageLab
  module Operations
    class ResizeToFill
      def self.call(image, operation, max_dimension:)
        image.thumbnail_image(
          dimension!(operation, "width", max_dimension),
          height: dimension!(operation, "height", max_dimension),
          crop: :centre
        )
      end

      def self.dimension!(operation, name, max_dimension)
        value = operation[name] if operation.is_a?(Hash)
        return value if value.is_a?(Integer) && value.positive? && value <= max_dimension

        raise Errors::InvalidOperation, "#{name} must be a positive integer within the dimension limit"
      end
      private_class_method :dimension!
    end
  end
end
