# frozen_string_literal: true

require "vips"
require_relative "corpus"

module ImageLab
  module Benchmark
    Workload = Data.define(:name, :operations, :format)

    module Workloads
      module_function

      ALL = [
        Workload.new("decode_encode", [], "png"),
        Workload.new("resize", [ { "op" => "resize_to_fit", "width" => 1280, "height" => 720 } ], "png"),
        Workload.new("crop", [ { "op" => "crop", "left" => 0, "top" => 0, "width" => 512, "height" => 512 } ], "png"),
        Workload.new("rotate", [ { "op" => "rotate", "degrees" => 90 } ], "png"),
        Workload.new("grayscale", [ { "op" => "grayscale" } ], "png"),
        Workload.new("blur", [ { "op" => "blur", "sigma" => 1.5 } ], "png"),
        Workload.new("sharpen", [ { "op" => "sharpen", "amount" => 0.5 } ], "png"),
        Workload.new("tint", [ { "op" => "tint", "color" => "#336699", "strength" => 0.4 } ], "png"),
        Workload.new("mixed_5", [ { "op" => "resize_to_fit", "width" => 1280, "height" => 720 }, { "op" => "rotate", "degrees" => 90 }, { "op" => "brightness", "amount" => 0.1 }, { "op" => "blur", "sigma" => 1.5 }, { "op" => "sharpen", "amount" => 0.5 } ], "png"),
        Workload.new("mixed_10", [ { "op" => "resize_to_fit", "width" => 1280, "height" => 720 }, { "op" => "crop", "left" => 0, "top" => 0, "width" => 640, "height" => 360 }, { "op" => "rotate", "degrees" => 90 }, { "op" => "flip", "mode" => "horizontal" }, { "op" => "brightness", "amount" => 0.1 }, { "op" => "contrast", "amount" => 0.1 }, { "op" => "saturation", "amount" => 0.1 }, { "op" => "tint", "color" => "#336699", "strength" => 0.4 }, { "op" => "blur", "sigma" => 1.5 }, { "op" => "sharpen", "amount" => 0.5 } ], "png")
      ].freeze

      def all
        ALL
      end

      def call(workload, fixture:, max_output_pixels:)
        image = Vips::Image.new_from_file(fixture.path)
        transformed = Pipeline.call(image, workload.operations, max_output_pixels:)
        Operations::Encode.call(transformed, format: workload.format, quality: nil)
      end

      def verify_output_limit!
        image = Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar)
        Pipeline.call(image, [ { "op" => "resize_to_fill", "width" => 2, "height" => 2 } ], max_output_pixels: 1)
      end
    end
  end
end
