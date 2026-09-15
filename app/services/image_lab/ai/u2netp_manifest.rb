# frozen_string_literal: true

require "digest"
require "yaml"

module ImageLab
  module AI
    class U2netpManifest
      MANIFEST_PATH = Rails.root.join("config/models/u2netp.yml").freeze
      UNAVAILABLE_MESSAGE = "AI model is unavailable"
      SHA256_PATTERN = /\A[a-f0-9]{64}\z/

      Definition = Data.define(:data) do
        def name
          data.fetch("name")
        end

        def input_shape
          data.fetch("input_shape")
        end

        def verify_artifact!(path:, kind:)
          declaration = data.fetch(kind.to_s)

          unless File.basename(path) == declaration.fetch("filename") &&
              File.size(path) == declaration.fetch("file_size") &&
              Digest::SHA256.file(path).hexdigest == declaration.fetch("sha256")
            raise ImageLab::Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
          end
        rescue Errno::ENOENT, KeyError, TypeError
          raise ImageLab::Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
        end
      end

      def self.load!(path: MANIFEST_PATH)
        manifest = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
        validate!(manifest)

        Definition.new(data: manifest)
      rescue ImageLab::Errors::AiUnavailable
        raise
      rescue Errno::ENOENT, Psych::Exception, KeyError, TypeError
        raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
      end

      def self.validate!(manifest)
        expected_keys = %w[
          name upstream_repository upstream_revision source_weights conversion_recipe onnx
          input_name input_shape input_dtype output_name output_shape output_dtype license
        ]
        require_keys!(manifest, expected_keys)

        raise_unavailable unless manifest.fetch("name") == "u2netp"
        raise_unavailable unless manifest.fetch("upstream_repository") == "https://github.com/xuebinqin/U-2-Net"
        raise_unavailable unless manifest.fetch("upstream_revision") == "ac7e1c817ecab7c7dff5ce6b1abba61cd213ff29"
        raise_unavailable unless manifest.fetch("input_name") == "input" && manifest.fetch("input_shape") == [ 1, 3, 320, 320 ]
        raise_unavailable unless manifest.fetch("input_dtype") == "tensor(float)"
        raise_unavailable unless manifest.fetch("output_name") == "d0" && manifest.fetch("output_shape") == [ 1, 1, 320, 320 ]
        raise_unavailable unless manifest.fetch("output_dtype") == "tensor(float)" && manifest.fetch("license") == "Apache-2.0"

        validate_source_weights!(manifest.fetch("source_weights"))
        validate_conversion_recipe!(manifest.fetch("conversion_recipe"))
        validate_onnx!(manifest.fetch("onnx"))
      end

      def self.validate_source_weights!(weights)
        expected = {
          "url" => "https://drive.google.com/uc?export=download&id=1rbSTGKAE-MTxBYHd-51l2hMOQPT_7EPy",
          "filename" => "u2netp.pth",
          "sha256" => "e7567cde013fb64813973ce6e1ecc25a80c05c3ca7adbc5a54f3c3d90991b854",
          "file_size" => 4_683_258
        }

        raise_unavailable unless weights == expected
      end

      def self.validate_conversion_recipe!(recipe)
        expected = {
          "python" => "3.11.9",
          "pytorch" => "2.2.2+cpu",
          "onnx" => "1.16.2",
          "opset" => 17,
          "output_selector" => 0
        }

        raise_unavailable unless recipe == expected
      end

      def self.validate_onnx!(onnx)
        require_keys!(onnx, %w[filename sha256 file_size])

        raise_unavailable unless onnx.fetch("filename") == "u2netp.onnx"
        raise_unavailable unless SHA256_PATTERN.match?(onnx.fetch("sha256"))
        raise_unavailable unless onnx.fetch("file_size").is_a?(Integer) && onnx.fetch("file_size").positive?
      end

      def self.require_keys!(value, expected_keys)
        raise_unavailable unless value.is_a?(Hash) && value.keys.sort == expected_keys.sort
      end
      private_class_method :require_keys!

      def self.raise_unavailable
        raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
      end
      private_class_method :raise_unavailable
    end
  end
end
