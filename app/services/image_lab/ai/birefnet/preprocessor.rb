# frozen_string_literal: true

require "vips"
require_relative "../tensor"
require_relative "../birefnet_manifest"
require_relative "../../errors"

module ImageLab
  module AI
    module Birefnet
      class Preprocessor
        INPUT_SHAPE = [ 1, 3, 1024, 1024 ].freeze
        SIZE = 1024
        MEANS = [ 0.485, 0.456, 0.406 ].freeze
        DEVIATIONS = [ 0.229, 0.224, 0.225 ].freeze
        CHANNELS = 3

        def self.call(image, manifest: BirefnetManifest.load!)
          raise_unavailable unless manifest.input_shape == INPUT_SHAPE && manifest.preprocess_size == SIZE

          canonical = canonical_rgb(image)
          resized = canonical.resize(SIZE.to_f / canonical.width, vscale: SIZE.to_f / canonical.height, kernel: :linear).cast(:float)
          interleaved = resized.write_to_memory.unpack("f*")
          raise_unavailable unless interleaved.length == CHANNELS * SIZE * SIZE && interleaved.all?(&:finite?)

          Tensor.new(shape: INPUT_SHAPE, values: nchw_values(interleaved))
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

        def self.nchw_values(interleaved)
          values = Array.new(CHANNELS * SIZE * SIZE)
          SIZE.times do |row|
            row_base = row * SIZE * CHANNELS
            SIZE.times do |column|
              pixel_base = row_base + column * CHANNELS
              CHANNELS.times do |channel|
                value = interleaved.fetch(pixel_base + channel) / 255.0
                values[channel * SIZE * SIZE + row * SIZE + column] = (value - MEANS.fetch(channel)) / DEVIATIONS.fetch(channel)
              end
            end
          end
          values
        end
        private_class_method :nchw_values

        def self.raise_unavailable
          raise Errors::AiUnavailable, BirefnetManifest::UNAVAILABLE_MESSAGE
        end
        private_class_method :raise_unavailable
      end
    end
  end
end
