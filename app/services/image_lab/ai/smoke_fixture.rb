# frozen_string_literal: true

require "digest"
require "yaml"

module ImageLab
  module AI
    class SmokeFixture
      PATH = Rails.root.join("test/fixtures/files/onnx/sigmoid.onnx").freeze
      MANIFEST_PATH = PATH.sub_ext(".yml").freeze
      UNAVAILABLE_MESSAGE = "AI model is unavailable"

      Definition = Data.define(:path, :input, :output)

      def self.default(path: PATH, manifest_path: MANIFEST_PATH)
        manifest = YAML.safe_load_file(manifest_path, aliases: false)
        verify_manifest!(manifest, path)

        Definition.new(path: path.to_s, input: manifest.fetch("input"), output: manifest.fetch("output"))
      rescue ImageLab::Errors::AiUnavailable
        raise
      rescue Errno::ENOENT, Psych::Exception, KeyError, TypeError
        raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
      end

      def self.verify_manifest!(manifest, path)
        expected_manifest = {
          "name" => "onnx_smoke",
          "source_url" => "https://raw.githubusercontent.com/onnx/onnx/v1.22.0/onnx/backend/test/data/node/test_sigmoid/model.onnx",
          "source_revision" => "v1.22.0",
          "license" => "Apache-2.0",
          "sha256" => "c9ea45be3dd00fd43865a739458c74c1f7c7fd325faf8294009f43ae9c0628dd",
          "file_size" => 105,
          "input" => { "name" => "x", "type" => "tensor(float)", "shape" => [ 3, 4, 5 ] },
          "output" => { "name" => "y", "type" => "tensor(float)", "shape" => [ 3, 4, 5 ] }
        }

        unless manifest == expected_manifest && File.size(path) == manifest.fetch("file_size") &&
            Digest::SHA256.file(path).hexdigest == manifest.fetch("sha256")
          raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
        end
      rescue Errno::ENOENT, KeyError, TypeError
        raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
      end

      private_class_method :verify_manifest!
    end
  end
end
