# frozen_string_literal: true

require "digest"
require "yaml"

module ImageLab
  module AI
    class MobileSamManifest
      MANIFEST_PATH = Rails.root.join("config/models/mobile_sam.yml").freeze
      UNAVAILABLE_MESSAGE = "AI model is unavailable"
      SHA256_PATTERN = /\A[a-f0-9]{64}\z/

      Definition = Data.define(:data) do
        def name = data.fetch("name")
        def encoder = data.fetch("encoder")
        def decoder = data.fetch("decoder")
        def preprocess_size = data.fetch("preprocessing").fetch("size")
        def pixel_mean = data.fetch("preprocessing").fetch("mean")
        def pixel_std = data.fetch("preprocessing").fetch("std")
        def point_tokens = data.fetch("postprocessing").fetch("point_tokens")
        def box_token = data.fetch("postprocessing").fetch("box_token")
        def threshold = data.fetch("postprocessing").fetch("threshold")

        def artifact(kind)
          data.fetch(kind.to_s)
        end

        def verify_artifact!(path:, kind:)
          declaration = artifact(kind)
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
        raise_unavailable unless manifest.is_a?(Hash)
        expected = %w[name upstream_repository upstream_revision encoder decoder preprocessing postprocessing license]
        raise_unavailable unless manifest.keys.sort == expected.sort
        raise_unavailable unless manifest.fetch("name") == "mobile_sam_vit_t"
        raise_unavailable unless manifest.fetch("upstream_repository") == "https://github.com/ChaoningZhang/MobileSAM"
        raise_unavailable unless manifest.fetch("upstream_revision") == "f706ad9c4eb7f219c00d9050e46328518ffb65d2"
        raise_unavailable unless manifest.fetch("license") == "Apache-2.0"

        expected_encoder = {
          "filename" => "mobile_sam_vit_t_image_encoder.onnx",
          "sha256" => "8bd9bd6fa57c5b664e972a2869dbf1f446ff5465889c3cb4f80d5f7cfe870988",
          "file_size" => 27_969_729,
          "input" => { "name" => "image", "dtype" => "tensor(float)", "shape" => [ 1, 3, 1024, 1024 ] },
          "output" => { "name" => "image_embeddings", "dtype" => "tensor(float)", "shape" => [ 1, 256, 64, 64 ] }
        }
        expected_decoder = {
          "filename" => "mobile_sam_prompt_mask_decoder.onnx",
          "sha256" => "abf884441fcc095f21af4e39e782a84f9fc83b3af06b6d2f0c6f85641b50dbf7",
          "file_size" => 16_509_691,
          "inputs" => [
            { "name" => "image_embeddings", "dtype" => "tensor(float)", "shape" => [ 1, 256, 64, 64 ] },
            { "name" => "point_coords", "dtype" => "tensor(float)", "shape" => [ 1, "num_points", 2 ] },
            { "name" => "point_labels", "dtype" => "tensor(float)", "shape" => [ 1, "num_points" ] },
            { "name" => "mask_input", "dtype" => "tensor(float)", "shape" => [ 1, 1, 256, 256 ] },
            { "name" => "has_mask_input", "dtype" => "tensor(float)", "shape" => [ 1 ] },
            { "name" => "orig_im_size", "dtype" => "tensor(float)", "shape" => [ 2 ] }
          ],
          "outputs" => [
            { "name" => "masks", "dtype" => "tensor(float)", "shape" => [ "Resizemasks_dim_0", "Resizemasks_dim_1", "Resizemasks_dim_2", "Resizemasks_dim_3" ] },
            { "name" => "iou_predictions", "dtype" => "tensor(float)", "shape" => [ "Gemmiou_predictions_dim_0", 4 ] },
            { "name" => "low_res_masks", "dtype" => "tensor(float)", "shape" => [ "Reshapelow_res_masks_dim_0", "Reshapelow_res_masks_dim_1", "Reshapelow_res_masks_dim_2", "Reshapelow_res_masks_dim_3" ] }
          ]
        }
        raise_unavailable unless manifest.fetch("encoder") == expected_encoder
        raise_unavailable unless manifest.fetch("decoder") == expected_decoder
        raise_unavailable unless manifest.fetch("preprocessing") == {
          "size" => 1024, "resize" => "linear",
          "mean" => [ 123.675, 116.28, 103.53 ], "std" => [ 58.395, 57.12, 57.375 ]
        }
        raise_unavailable unless manifest.fetch("postprocessing") == {
          "threshold" => 0.0, "point_tokens" => [ 1, 2, 3 ], "box_token" => 0
        }
      end

      def self.raise_unavailable
        raise ImageLab::Errors::AiUnavailable, UNAVAILABLE_MESSAGE
      end
      private_class_method :raise_unavailable
    end
  end
end
