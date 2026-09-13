# frozen_string_literal: true

require_relative "color"
require_relative "parameters"

module ImageLab
  module Operations
    class Background
      def self.call(image, operation)
        Parameters.exact!(operation, "background", [ "color" ])
        raise Errors::InvalidOperation, "background requires an alpha image" unless image.has_alpha?

        color, alpha = Color.split_alpha(image)
        Color.join_alpha(Color.srgb(color), alpha).flatten(background: Parameters.rgb!(operation, "color"))
      end
    end
  end
end
