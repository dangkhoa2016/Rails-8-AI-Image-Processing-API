# frozen_string_literal: true

require_relative "parameters"

module ImageLab
  module Operations
    class Background
      def self.call(image, operation)
        Parameters.exact!(operation, "background", [ "color" ])
        raise Errors::InvalidOperation, "background requires an alpha image" unless image.has_alpha?

        image.flatten(background: Parameters.rgb!(operation, "color"))
      end
    end
  end
end
