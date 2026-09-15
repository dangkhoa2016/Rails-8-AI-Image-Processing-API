# frozen_string_literal: true

module ImageLab
  module AI
    class Tensor
      attr_reader :shape

      def initialize(shape:, values:)
        @shape = validate_shape(shape).freeze
        @count = @shape.reduce(:*)
        materialized_values = values.map { |value| Float(value) }
        raise ArgumentError, "tensor values do not match shape" unless materialized_values.length == @count
        raise ArgumentError, "tensor values must be finite" unless materialized_values.all?(&:finite?)

        @bytes = materialized_values.pack("e*").freeze
        @values = @bytes.unpack("e*").freeze
      end

      def count
        @count
      end

      def values
        @values
      end

      def bytes
        @bytes
      end

      def at(*coordinates)
        raise IndexError, "tensor coordinate rank does not match shape" unless coordinates.length == @shape.length

        flat_index = coordinates.zip(@shape).reduce(0) do |offset, (coordinate, dimension)|
          unless coordinate.is_a?(Integer) && coordinate.between?(0, dimension - 1)
            raise IndexError, "tensor coordinate is out of bounds"
          end

          offset * dimension + coordinate
        end
        @values.fetch(flat_index)
      end

      private

      def validate_shape(shape)
        dimensions = Array(shape)
        raise ArgumentError, "tensor shape must not be empty" if dimensions.empty?
        unless dimensions.all? { |dimension| dimension.is_a?(Integer) && dimension.positive? }
          raise ArgumentError, "tensor dimensions must be positive integers"
        end

        dimensions
      end
    end
  end
end
