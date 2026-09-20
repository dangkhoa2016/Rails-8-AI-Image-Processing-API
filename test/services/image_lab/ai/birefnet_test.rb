# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLab::AI::BirefnetTest < ActiveSupport::TestCase
  test "feeds the ONNX input as the positional hash and restores a finite mask" do
    model = RecordingModel.new("output_image" => constant_output(2.0))
    image = rgb_image(width: 6, height: 4)

    mask = ImageLab::AI::Birefnet.call(
      image,
      manifest: manifest,
      model:,
      limiter: ImageLab::AI::U2netp::InferenceLimiter.new(1)
    )

    assert_equal [ "input_image" ], model.input_feed.keys
    assert_equal({}, model.run_options)
    assert_nil model.output_names
    assert_equal [ 1, 3, 1024, 1024 ], nested_shape(model.input_feed.fetch("input_image"))
    assert_equal [ 6, 4, 1, :float ], [ mask.image.width, mask.image.height, mask.image.bands, mask.image.format ]
    assert mask.image.write_to_memory.unpack("f*").all?(&:finite?)
  end

  test "fails closed when ONNX omits the manifest output" do
    error = assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::Birefnet.call(
        rgb_image,
        manifest: manifest,
        model: RecordingModel.new({}),
        limiter: ImageLab::AI::U2netp::InferenceLimiter.new(1)
      )
    end

    assert_equal "AI model is unavailable", error.message
  end

  test "fails closed for an invalid default concurrency value" do
    previous = ENV["IMAGE_AI_MAX_CONCURRENCY"]
    ENV["IMAGE_AI_MAX_CONCURRENCY"] = "0"
    ImageLab::AI::U2netp.instance_variable_set(:@default_limiter, nil)

    error = assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::Birefnet.call(rgb_image, manifest: manifest, model: RecordingModel.new("output_image" => constant_output(1.0)))
    end

    assert_equal "AI model is unavailable", error.message
  ensure
    previous.nil? ? ENV.delete("IMAGE_AI_MAX_CONCURRENCY") : ENV["IMAGE_AI_MAX_CONCURRENCY"] = previous
    ImageLab::AI::U2netp.instance_variable_set(:@default_limiter, nil)
  end

  private

  class RecordingModel
    attr_reader :input_feed, :output_names, :run_options

    def initialize(response)
      @response = response
    end

    def predict(input_feed, output_names: nil, **run_options)
      @input_feed = input_feed
      @output_names = output_names
      @run_options = run_options
      @response
    end
  end

  def manifest
    @manifest ||= Struct.new(:input_name, :input_shape, :preprocess_size, :output_name).new(
      "input_image",
      [ 1, 3, 1024, 1024 ],
      1024,
      "output_image"
    )
  end

  def rgb_image(width: 1, height: 1)
    pixels = Array.new(width * height) { [ 100, 150, 200 ] }.flatten
    Vips::Image.new_from_memory(pixels.pack("C*"), width, height, 3, :uchar).copy(interpretation: :srgb)
  end

  def constant_output(value)
    [ Array.new(1) { Array.new(1024) { Array.new(1024, value) } } ]
  end

  def nested_shape(value)
    return [] unless value.is_a?(Array)

    [ value.length, *nested_shape(value.first) ]
  end
end