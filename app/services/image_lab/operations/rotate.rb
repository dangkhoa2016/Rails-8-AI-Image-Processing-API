# frozen_string_literal: true

require_relative "../errors"

module ImageLab
  module Operations
    class Rotate
      ANGLES = { 90 => :d90, 180 => :d180, 270 => :d270 }.freeze

      def self.call(image, operation)
        degrees = operation["degrees"] if operation.is_a?(Hash)
        angle = ANGLES[degrees]
        raise Errors::InvalidOperation, "degrees must be 90, 180, or 270" unless angle

        image.rot(angle)
      end
    end
  end
end
