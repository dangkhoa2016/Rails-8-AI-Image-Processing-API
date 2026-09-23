# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ImageLab::AI::MobileSamManifestTest < ActiveSupport::TestCase
  test "loads the frozen M2 MobileSAM contract" do
    manifest = ImageLab::AI::MobileSamManifest.load!

    assert_equal "mobile_sam_vit_t", manifest.name
    assert_equal 1024, manifest.preprocess_size
    assert_equal [ 123.675, 116.28, 103.53 ], manifest.pixel_mean
    assert_equal [ 58.395, 57.12, 57.375 ], manifest.pixel_std
    assert_equal [ 1, 2, 3 ], manifest.point_tokens
    assert_equal 0, manifest.box_token
    assert_equal 0.0, manifest.threshold
    assert_equal "mobile_sam_vit_t_image_encoder.onnx", manifest.encoder.fetch("filename")
    assert_equal "mobile_sam_prompt_mask_decoder.onnx", manifest.decoder.fetch("filename")
  end

  test "rejects mutations to frozen model port authority" do
    data = YAML.safe_load_file(ImageLab::AI::MobileSamManifest::MANIFEST_PATH, permitted_classes: [], aliases: false)
    data["decoder"]["outputs"][0]["name"] = "wrong"

    Dir.mktmpdir do |directory|
      path = File.join(directory, "mobile_sam.yml")
      File.write(path, YAML.dump(data))
      assert_raises(ImageLab::Errors::AiUnavailable) { ImageLab::AI::MobileSamManifest.load!(path:) }
    end
  end

  test "verifies exact pinned artifacts and fails closed on corruption" do
    manifest = ImageLab::AI::MobileSamManifest.load!

    Dir.mktmpdir do |directory|
      encoder_path = File.join(directory, manifest.encoder.fetch("filename"))
      File.binwrite(encoder_path, "wrong")
      error = assert_raises(ImageLab::Errors::AiUnavailable) do
        manifest.verify_artifact!(path: encoder_path, kind: :encoder)
      end
      assert_equal "AI model is unavailable", error.message
    end
  end
end
