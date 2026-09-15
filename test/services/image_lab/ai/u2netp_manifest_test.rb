# frozen_string_literal: true

require "test_helper"
require "digest"
require "tmpdir"
require "yaml"

class ImageLab::AI::U2netpManifestTest < ActiveSupport::TestCase
  test "loads a complete manifest and verifies its declared ONNX artifact" do
    Dir.mktmpdir("u2netp-manifest-test-") do |directory|
      artifact_path = File.join(directory, "u2netp.onnx")
      artifact_contents = "verified ONNX artifact\n"
      File.binwrite(artifact_path, artifact_contents)
      manifest_path = File.join(directory, "u2netp.yml")
      File.write(manifest_path, YAML.dump(valid_manifest(onnx_sha256: Digest::SHA256.hexdigest(artifact_contents), onnx_size: artifact_contents.bytesize)))

      manifest = ImageLab::AI::U2netpManifest.load!(path: manifest_path)

      assert_equal "u2netp", manifest.name
      assert_equal "input", manifest.input_name
      assert_equal [ 1, 3, 320, 320 ], manifest.input_shape
      assert_equal "tensor(float)", manifest.input_dtype
      assert_equal "d0", manifest.output_name
      assert_equal [ 1, 1, 320, 320 ], manifest.output_shape
      assert_equal "tensor(float)", manifest.output_dtype
      assert_equal "u2netp.onnx", manifest.onnx_filename
      assert_nil manifest.verify_artifact!(path: artifact_path, kind: :onnx)
    end
  end

  test "rejects an ONNX artifact whose bytes differ from its manifest checksum" do
    Dir.mktmpdir("u2netp-manifest-test-") do |directory|
      artifact_path = File.join(directory, "u2netp.onnx")
      File.binwrite(artifact_path, "corrupt artifact\n")
      manifest_path = File.join(directory, "u2netp.yml")
      File.write(manifest_path, YAML.dump(valid_manifest(onnx_sha256: "0" * 64, onnx_size: File.size(artifact_path))))
      manifest = ImageLab::AI::U2netpManifest.load!(path: manifest_path)

      error = assert_raises(ImageLab::Errors::AiUnavailable) do
        manifest.verify_artifact!(path: artifact_path, kind: :onnx)
      end

      assert_equal "AI model is unavailable", error.message
    end
  end

  private

  def valid_manifest(onnx_sha256:, onnx_size:)
    {
      "name" => "u2netp",
      "upstream_repository" => "https://github.com/xuebinqin/U-2-Net",
      "upstream_revision" => "ac7e1c817ecab7c7dff5ce6b1abba61cd213ff29",
      "source_weights" => {
        "url" => "https://drive.google.com/uc?export=download&id=1rbSTGKAE-MTxBYHd-51l2hMOQPT_7EPy",
        "filename" => "u2netp.pth",
        "sha256" => "e7567cde013fb64813973ce6e1ecc25a80c05c3ca7adbc5a54f3c3d90991b854",
        "file_size" => 4_683_258
      },
      "conversion_recipe" => {
        "python" => "3.11.9",
        "pytorch" => "2.2.2+cpu",
        "onnx" => "1.16.2",
        "opset" => 17,
        "output_selector" => 0
      },
      "onnx" => {
        "filename" => "u2netp.onnx",
        "sha256" => onnx_sha256,
        "file_size" => onnx_size
      },
      "input_name" => "input",
      "input_shape" => [ 1, 3, 320, 320 ],
      "input_dtype" => "tensor(float)",
      "output_name" => "d0",
      "output_shape" => [ 1, 1, 320, 320 ],
      "output_dtype" => "tensor(float)",
      "license" => "Apache-2.0"
    }
  end
end
