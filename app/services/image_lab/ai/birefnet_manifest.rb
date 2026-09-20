# frozen_string_literal: true

require "digest"
require "yaml"

module ImageLab
  module AI
    class BirefnetManifest
      MANIFEST_PATH = Rails.root.join("config/models/birefnet.yml").freeze
      UNAVAILABLE_MESSAGE = "AI model is unavailable"
      SHA256_PATTERN = /\A[a-f0-9]{64}\z/

      Definition = Data.define(:data) do
        def name
          data.fetch("name")
        end

        def input_name
          data.fetch("input_name")
        end

        def input_shape
          data.fetch("input_shape")
        end

        def input_dtype
          data.fetch("input_dtype")
        end

        def output_name
          data.fetch("output_name")
        end

        def output_shape
          data.fetch("output_shape")
        end

        def output_dtype
          data.fetch("output_dtype")
        end

        def preprocess_size
          data.fetch("preprocessing").fetch("size")
        end

        def postprocess_threshold
          data.fetch("postprocessing").fetch("threshold")
        end

        def onnx_filename
          data.fetch("onnx").fetch("filename")
        end

        def onnx_download_url
          data.fetch("onnx").fetch("download_url")
        end

        def verify_artifact!(path:, kind: :onnx)
          declaration = data.fetch(kind.to_s)

          unless File.basename(path) == declaration.fetch("filename") &&
              File.size(path) == declaration.fetch("file_size") &&
              Digest::SHA256.file(path).hexdigest == declaration.fetch("sha256")
            raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
          end
        rescue Errno::ENOENT, KeyError, TypeError
          raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
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
          name upstream_repository upstream_revision onnx
          input_name input_shape input_dtype output_name output_shape output_dtype
          preprocessing postprocessing license
        ]
        require_keys!(manifest, expected_keys)

        raise_unavailable unless manifest.fetch("name") == "birefnet_general_full"
        raise_unavailable unless manifest.fetch("upstream_repository") == "https://github.com/ZhengPeng7/BiRefNet"
        raise_unavailable unless manifest.fetch("upstream_revision") == "a0cf9925880620000aa2d1948d61bf659ddfdfaa"
        raise_unavailable unless manifest.fetch("input_name") == "input_image" && manifest.fetch("input_shape") == [ 1, 3, 1024, 1024 ]
        raise_unavailable unless manifest.fetch("input_dtype") == "tensor(float)"
        raise_unavailable unless manifest.fetch("output_name") == "output_image" && manifest.fetch("output_shape") == [ 1, 1, 1024, 1024 ]
        raise_unavailable unless manifest.fetch("output_dtype") == "tensor(float)" && manifest.fetch("license") == "MIT"

        validate_onnx!(manifest.fetch("onnx"))
        validate_preprocessing!(manifest.fetch("preprocessing"))
        validate_postprocessing!(manifest.fetch("postprocessing"))
      end

      def self.validate_onnx!(onnx)
        require_keys!(onnx, %w[download_url filename sha256 file_size opset ir_version nodes])

        raise_unavailable unless onnx.fetch("filename") == "BiRefNet-general-epoch_244.onnx"
        raise_unavailable unless onnx.fetch("download_url") == "https://github.com/ZhengPeng7/BiRefNet/releases/download/v1/BiRefNet-general-epoch_244.onnx"
        raise_unavailable unless SHA256_PATTERN.match?(onnx.fetch("sha256"))
        raise_unavailable unless onnx.fetch("file_size").is_a?(Integer) && onnx.fetch("file_size").positive?
        raise_unavailable unless onnx.fetch("opset") == 17 && onnx.fetch("ir_version") == 8 && onnx.fetch("nodes") == 21_968
      end

      def self.validate_preprocessing!(preprocessing)
        expected = {
          "resize" => "bilinear",
          "size" => 1024,
          "mean" => [ 0.485, 0.456, 0.406 ],
          "std" => [ 0.229, 0.224, 0.225 ]
        }

        raise_unavailable unless preprocessing == expected
      end

      def self.validate_postprocessing!(postprocessing)
        expected = {
          "activation" => "sigmoid",
          "restore" => "bilinear",
          "threshold" => 0.5
        }

        raise_unavailable unless postprocessing == expected
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
