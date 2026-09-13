# frozen_string_literal: true

require_relative "color"
require_relative "parameters"

module ImageLab
  module Operations
    class Saturation
      def self.call(image, operation)
        Parameters.exact!(operation, "saturation", [ "amount" ])
        amount = Parameters.number!(operation, "amount", -1.0..1.0)
        return image if amount.zero?

        color, alpha = Color.split_alpha(image)
        hsv = Color.srgb(color).colourspace(:hsv)
        adjusted = hsv.extract_band(0).bandjoin(hsv.extract_band(1).linear(1 + amount, 0)).bandjoin(hsv.extract_band(2))

        Color.join_alpha(adjusted.colourspace(:srgb), alpha)
      end
    end
  end
end
