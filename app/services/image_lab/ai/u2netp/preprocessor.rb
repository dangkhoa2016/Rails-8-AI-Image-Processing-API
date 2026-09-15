# frozen_string_literal: true

require "vips"
require_relative "../tensor"
require_relative "../u2netp_manifest"
require_relative "../../errors"

module ImageLab
  module AI
    module U2netp
      class Preprocessor
        INPUT_SHAPE = [ 1, 3, 320, 320 ].freeze
        MEANS = [ 0.485, 0.456, 0.406 ].freeze
        DEVIATIONS = [ 0.229, 0.224, 0.225 ].freeze
        WIDTH = INPUT_SHAPE[3]
        HEIGHT = INPUT_SHAPE[2]

        def self.call(image, manifest: U2netpManifest.load!)
          raise_unavailable unless manifest.input_shape == INPUT_SHAPE

          canonical = canonical_rgb(image)
          resized = canonical.resize(WIDTH.to_f / canonical.width, vscale: HEIGHT.to_f / canonical.height, kernel: :linear).cast(:float)
          interleaved = resized.write_to_memory.unpack("f*")
          maximum = interleaved.max
          raise_unavailable unless interleaved.all?(&:finite?) && maximum&.finite? && maximum.positive?

          Tensor.new(shape: INPUT_SHAPE, values: nchw_values(interleaved, maximum))
        rescue Vips::Error, TypeError, ArgumentError
          raise_unavailable
        end

        def self.canonical_rgb(image)
          return grayscale_rgb(image) if image.bands == 1

          image.colourspace(:srgb).extract_band(0, n: 3)
        end
        private_class_method :canonical_rgb

        def self.grayscale_rgb(image)
          gray = image.extract_band(0)
          gray.bandjoin([ gray, gray ]).copy(interpretation: :srgb)
        end
        private_class_method :grayscale_rgb

        def self.nchw_values(interleaved, maximum)
          values = Array.new(3 * HEIGHT * WIDTH)
          HEIGHT.times do |row|
            WIDTH.times do |column|
              3.times do |channel|
                source_index = (row * WIDTH + column) * 3 + channel
                target_index = channel * HEIGHT * WIDTH + row * WIDTH + column
                values[target_index] = (interleaved.fetch(source_index) / maximum - MEANS.fetch(channel)) / DEVIATIONS.fetch(channel)
              end
            end
          end
          values
        end
        private_class_method :nchw_values

        def self.raise_unavailable
          raise Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
        end
        private_class_method :raise_unavailable
      end
    end
  end
end
