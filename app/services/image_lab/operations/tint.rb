# frozen_string_literal: true

require_relative "color"
require_relative "parameters"

module ImageLab
  module Operations
    class Tint
      def self.call(image, operation)
        Parameters.exact!(operation, "tint", [ "color", "strength" ])
        rgb = Parameters.rgb!(operation, "color")
        strength = Parameters.number!(operation, "strength", 0.0..1.0)
        color, alpha = Color.split_alpha(image)
        result = Color.srgb(color).linear(1 - strength, rgb.map { |component| component * strength })

        Color.join_alpha(result, alpha)
      end
    end
  end
end
