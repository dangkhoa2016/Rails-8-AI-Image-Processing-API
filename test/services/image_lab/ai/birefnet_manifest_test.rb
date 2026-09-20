# frozen_string_literal: true

require "test_helper"
require "digest"
require "tmpdir"
require "yaml"

class ImageLab::AI::BirefnetManifestTest < ActiveSupport::TestCase
  test "loads the committed A2 manifest with the frozen AI contract" do
    manifest = ImageLab::AI::BirefnetManifest.load!

    assert_equal "birefnet_general_full", manifest.name
    assert_equal "input_image", manifest.input_name
    assert_equal [ 1, 3, 1024, 1024 ], manifest.input_shape
    assert_equal "tensor(float)", manifest.input_dtype
    assert_equal "output_image", manifest.output_name
    assert_equal [ 1, 1, 1024, 1024 ], manifest.output_shape
    assert_equal "tensor(float)", manifest.output_dtype
    assert_equal 1024, manifest.preprocess_size
    assert_equal 0.5, manifest.postprocess_threshold
    assert_equal "BiRefNet-general-epoch_244.onnx", manifest.onnx_filename
    assert_equal "https://github.com/ZhengPeng7/BiRefNet/releases/download/v1/BiRefNet-general-epoch_244.onnx", manifest.onnx_download_url
  end

  test "verifies a declared ONNX artifact and rejects a corrupt one" do
    Dir.mktmpdir("birefnet-manifest-test-") do |directory|
      artifact_path = File.join(directory, "BiRefNet-general-epoch_244.onnx")
      artifact_contents = "verified ONNX artifact\n"
      File.binwrite(artifact_path, artifact_contents)
      manifest_path = File.join(directory, "birefnet.yml")
      File.write(manifest_path, YAML.dump(valid_manifest(onnx_sha256: Digest::SHA256.hexdigest(artifact_contents), onnx_size: artifact_contents.bytesize)))

      manifest = ImageLab::AI::BirefnetManifest.load!(path: manifest_path)
      assert_nil manifest.verify_artifact!(path: artifact_path, kind: :onnx)

      corrupt_path = File.join(directory, "corrupt.onnx")
      File.binwrite(corrupt_path, "corrupt\n")
      error = assert_raises(ImageLab::Errors::AiUnavailable) { manifest.verify_artifact!(path: corrupt_path, kind: :onnx) }
      assert_equal "AI model is unavailable", error.message
    end
  end

  test "rejects a manifest that mutates the frozen A2 authority" do
    noncanonical = valid_manifest.merge("output_name" => "wrong")

    error = assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::BirefnetManifest.load!(path: write_manifest(noncanonical))
    end

    assert_equal "AI model is unavailable", error.message
  end

  test "fails closed on a manifest that omits a required key" do
    noncanonical = valid_manifest.reject { |key, _| key == "license" }

    assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::BirefnetManifest.load!(path: write_manifest(noncanonical))
    end
  end

  private

  def write_manifest(hash)
    path = File.join(Dir.mktmpdir("birefnet-manifest-test-"), "birefnet.yml")
    File.write(path, YAML.dump(hash))
    path
  end

  def valid_manifest(onnx_sha256: "58f621f00f5d756097615970a88a791584600dcf7c45b18a0a6267535a1ebd3c", onnx_size: 972_666_916)
    {
      "name" => "birefnet_general_full",
      "upstream_repository" => "https://github.com/ZhengPeng7/BiRefNet",
      "upstream_revision" => "a0cf9925880620000aa2d1948d61bf659ddfdfaa",
      "onnx" => {
        "download_url" => "https://github.com/ZhengPeng7/BiRefNet/releases/download/v1/BiRefNet-general-epoch_244.onnx",
        "filename" => "BiRefNet-general-epoch_244.onnx",
        "sha256" => onnx_sha256,
        "file_size" => onnx_size,
        "opset" => 17,
        "ir_version" => 8,
        "nodes" => 21_968
      },
      "input_name" => "input_image",
      "input_shape" => [ 1, 3, 1024, 1024 ],
      "input_dtype" => "tensor(float)",
      "output_name" => "output_image",
      "output_shape" => [ 1, 1, 1024, 1024 ],
      "output_dtype" => "tensor(float)",
      "preprocessing" => {
        "resize" => "bilinear",
        "size" => 1024,
        "mean" => [ 0.485, 0.456, 0.406 ],
        "std" => [ 0.229, 0.224, 0.225 ]
      },
      "postprocessing" => {
        "activation" => "sigmoid",
        "restore" => "bilinear",
        "threshold" => 0.5
      },
      "license" => "MIT"
    }
  end
end
