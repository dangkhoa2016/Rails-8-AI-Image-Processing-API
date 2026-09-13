# frozen_string_literal: true

require_relative "../errors"

module ImageLab
  module Operations
    class Flip
      MODES = { "horizontal" => :horizontal, "vertical" => :vertical }.freeze

      def self.call(image, operation)
        mode = MODES[operation["mode"]] if operation.is_a?(Hash)
        raise Errors::InvalidOperation, "mode must be horizontal or vertical" unless mode

        image.flip(mode)
      end
    end
  end
end
