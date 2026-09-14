# frozen_string_literal: true

require_relative "../errors"
require_relative "parameters"

module ImageLab
  module Operations
    class ResizeToFit
      def self.call(image, operation, max_dimension: 8_192)
        Parameters.exact!(operation, "resize_to_fit", %w[width height])

        image.thumbnail_image(
          dimension!(operation, "width", max_dimension),
          height: dimension!(operation, "height", max_dimension)
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
