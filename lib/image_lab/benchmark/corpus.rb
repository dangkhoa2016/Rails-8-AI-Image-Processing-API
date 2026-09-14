# frozen_string_literal: true

require "fileutils"
require "vips"

module ImageLab
  module Benchmark
    Fixture = Data.define(:name, :path, :format, :bytes, :width, :height, :alpha)

    module Corpus
      module_function

      SPECS = [
        [ "full_hd_jpeg", 1920, 1080, "jpeg", false ],
        [ "large_jpeg", 4000, 3000, "jpeg", false ],
        [ "square_png", 4096, 4096, "png", false ],
        [ "transparent_png", 1920, 1080, "png", true ],
        [ "webp", 1920, 1080, "webp", false ]
      ].freeze

      def create!(directory:)
        FileUtils.mkdir_p(directory)

        SPECS.map do |name, width, height, format, alpha|
          write_fixture(directory:, name:, width:, height:, format:, alpha:)
        end
      end

      def cleanup!(directory:)
        raise ArgumentError, "expected vips-corpus directory" unless File.basename(directory) == "vips-corpus"

        FileUtils.remove_entry_secure(directory) if File.exist?(directory)
      end

      def write_fixture(directory:, name:, width:, height:, format:, alpha:)
        path = File.join(directory, "#{name}.#{format_extension(format)}")
        image = source_image(alpha:).resize(width, vscale: height)
        image.write_to_file(path)
        decoded = Vips::Image.new_from_file(path)

        Fixture.new(name, path, format, File.size(path), decoded.width, decoded.height, decoded.has_alpha?)
      end
      private_class_method :write_fixture

      def source_image(alpha:)
        values = alpha ? [ 64, 128, 192, 128 ] : [ 64, 128, 192 ]
        Vips::Image.new_from_memory(values.pack("C*"), 1, 1, values.length, :uchar).copy(interpretation: :srgb)
      end
      private_class_method :source_image

      def format_extension(format)
        format == "jpeg" ? "jpg" : format
      end
      private_class_method :format_extension
    end
  end
end
