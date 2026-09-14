# frozen_string_literal: true

require_relative "parameters"

module ImageLab
  module Operations
    class Sharpen
      def self.call(image, operation)
        Parameters.exact!(operation, "sharpen", [ "amount" ])
        amount = Parameters.number!(operation, "amount", 0.0..1.0)
        return image if amount.zero?

        image.sharpen(sigma: 1.0, m1: amount * 2.0, m2: amount * 10.0)
      end
    end
  end
end
