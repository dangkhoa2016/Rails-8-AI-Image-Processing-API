# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ImageLab::AI::ModelRegistryTest < ActiveSupport::TestCase
  def test_loads_the_verified_sigmoid_fixture_and_runs_a_cpu_inference
    model = ImageLab::AI::ModelRegistry.fetch!(:onnx_smoke)

    assert_equal [ { name: "x", type: "tensor(float)", shape: [ 3, 4, 5 ] } ], normalize_ports(model.inputs)
    assert_equal [ { name: "y", type: "tensor(float)", shape: [ 3, 4, 5 ] } ], normalize_ports(model.outputs)

    output = model.predict({ "x" => zero_tensor }).fetch("y")

    assert_equal 60, output.flatten.length
    assert output.flatten.all? { |value| (value - 0.5).abs < 0.0001 }
  end

  def test_shares_one_model_across_concurrent_callers
    registry = ImageLab::AI::ModelRegistry.new
    model_ids = 8.times.map do
      Thread.new { registry.fetch!(:onnx_smoke).object_id }
    end.map(&:value)

    assert_equal 1, model_ids.uniq.length
  end

  def test_rejects_models_that_are_not_part_of_the_spike
    error = assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::ModelRegistry.fetch!(:u2netp)
    end

    assert_equal "AI model is unavailable", error.message
  end

  def test_rejects_a_fixture_whose_checksum_does_not_match_its_manifest
    Dir.mktmpdir do |directory|
      fixture_path = File.join(directory, "sigmoid.onnx")
      manifest_path = File.join(directory, "sigmoid.yml")
      File.binwrite(fixture_path, File.binread(ImageLab::AI::SmokeFixture::PATH) + "corrupt")
      File.write(manifest_path, File.read(ImageLab::AI::SmokeFixture::MANIFEST_PATH))

      error = assert_raises(ImageLab::Errors::AiUnavailable) do
        ImageLab::AI::SmokeFixture.default(path: fixture_path, manifest_path: manifest_path)
      end

      assert_equal "AI model is unavailable", error.message
    end
  end

  private

  def zero_tensor
    Array.new(3) { Array.new(4) { Array.new(5, 0.0) } }
  end

  def normalize_ports(ports)
    ports.map do |port|
      {
        name: port.fetch(:name).to_s,
        type: port.fetch(:type).to_s,
        shape: port.fetch(:shape)
      }
    end
  end
end
