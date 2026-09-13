# frozen_string_literal: true

require_relative "../errors"

module ImageLab
  module Operations
    class Grayscale
      def self.call(image, operation)
        unless operation.is_a?(Hash) && operation.keys == [ "op" ] && operation["op"] == "grayscale"
          raise Errors::InvalidOperation, "grayscale does not accept parameters"
        end

        image.colourspace(:b_w)
      end
    end
  end
end
