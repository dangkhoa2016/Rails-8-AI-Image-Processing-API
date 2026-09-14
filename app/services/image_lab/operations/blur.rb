# frozen_string_literal: true

require_relative "parameters"

module ImageLab
  module Operations
    class Blur
      def self.call(image, operation)
        Parameters.exact!(operation, "blur", [ "sigma" ])

        image.gaussblur(Parameters.number!(operation, "sigma", 0.1..20.0))
      end
    end
  end
end
