# frozen_string_literal: true

require_relative "../errors"

module ImageLab
  module Operations
    module Parameters
      HEX_COLOR = /\A#[0-9a-fA-F]{6}\z/

      def self.exact!(operation, name, fields)
        expected_keys = [ "op", *fields ].sort
        return if operation.is_a?(Hash) && operation["op"] == name && operation.keys.sort == expected_keys

        raise Errors::InvalidOperation, "#{name} has invalid parameters"
      end

      def self.number!(operation, name, range)
        value = operation[name]
        return value if value.is_a?(Numeric) && value.finite? && range.cover?(value)

        raise Errors::InvalidOperation, "#{name} is outside the allowed range"
      end

      def self.rgb!(operation, name)
        value = operation[name]
        raise Errors::InvalidOperation, "#{name} must be a #RRGGBB color" unless value.is_a?(String) && HEX_COLOR.match?(value)

        value.delete_prefix("#").scan(/../).map { |component| component.to_i(16) }
      end
    end
  end
end
