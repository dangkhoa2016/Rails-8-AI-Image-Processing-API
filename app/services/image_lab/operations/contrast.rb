# frozen_string_literal: true

require_relative "color"
require_relative "parameters"

module ImageLab
  module Operations
    class Contrast
      def self.call(image, operation)
        Parameters.exact!(operation, "contrast", [ "amount" ])
        amount = Parameters.number!(operation, "amount", -1.0..1.0)
        factor = 1 + amount
        color, alpha = Color.split_alpha(image)

        Color.join_alpha(color.linear(factor, 128 * (1 - factor)), alpha)
      end
    end
  end
end
