# frozen_string_literal: true

module ImageLab
  module AI
    class MobileSam
      class Preprocessor
        Result = Data.define(:tensor, :width, :height, :resized_width, :resized_height)

        def self.call(image, manifest:)
          source = image.colourspace("srgb")
          source = source.flatten if source.bands == 4
          raise ImageLab::Errors::InvalidOperation, "segmentation requires RGB input" unless source.bands == 3
          raise ImageLab::Errors::InvalidOperation, "segmentation requires 8-bit input" unless source.format == :uchar

          width = source.width
          height = source.height
          size = manifest.preprocess_size
          scale = size.to_f / [ width, height ].max
          new_width = (width * scale + 0.5).floor
          new_height = (height * scale + 0.5).floor

          resized = source.resize(new_width.to_f / width, vscale: new_height.to_f / height, kernel: :linear)
          unless resized.width == new_width && resized.height == new_height
            raise ImageLab::Errors::AiUnavailable, MobileSamManifest::UNAVAILABLE_MESSAGE
          end

          bytes = resized.write_to_memory.unpack("C*")
          plane_size = size * size
          flat = Array.new(3 * plane_size, 0.0)

          3.times do |channel|
            mean = manifest.pixel_mean.fetch(channel)
            std = manifest.pixel_std.fetch(channel)
            new_height.times do |y|
              row_offset = (channel * plane_size) + (y * size)
              byte_offset = (y * new_width * 3) + channel
              new_width.times do |x|
                flat[row_offset + x] = (bytes[byte_offset + (x * 3)] - mean) / std
              end
            end
          end

          tensor = [ 3.times.map do |channel|
            size.times.map { |y| flat.slice((channel * plane_size) + (y * size), size) }
          end ]

          Result.new(
            tensor: tensor,
            width: width,
            height: height,
            resized_width: new_width,
            resized_height: new_height
          )
        end
      end
    end
  end
end
