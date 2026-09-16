# frozen_string_literal: true

require_relative "color"
require_relative "parameters"

module ImageLab
  module Operations
    class Brightness
      def self.call(image, operation)
        Parameters.exact!(operation, "brightness", [ "amount" ])
        amount = Parameters.number!(operation, "amount", -1.0..1.0)
        return image if amount.zero?

        color, alpha = Color.split_alpha(image)

        Color.join_alpha(Color.srgb(color).linear(1, amount * 255), alpha)
      end
    end
  end
end
