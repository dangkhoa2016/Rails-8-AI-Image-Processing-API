# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLab::AI::U2netpTest < ActiveSupport::TestCase
  test "preprocesses into the manifest input and returns a source-sized mask" do
    model = RecordingModel.new("d0" => constant_output(2.0))
    image = rgb_image(width: 6, height: 4)

    mask = ImageLab::AI::U2netp.call(
      image,
      manifest: manifest,
      model:,
      limiter: ImageLab::AI::U2netp::InferenceLimiter.new(1)
    )

    assert_equal [ "input" ], model.request.keys
    assert_equal [ 1, 3, 320, 320 ], nested_shape(model.request.fetch("input"))
    assert_equal [ 6, 4, 1, :float ], [ mask.image.width, mask.image.height, mask.image.bands, mask.image.format ]
    assert_equal Array.new(24, 0.0), mask.image.write_to_memory.unpack("f*")
  end

  test "fails closed when ONNX omits the manifest output" do
    error = assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::U2netp.call(
        rgb_image,
        manifest: manifest,
        model: RecordingModel.new({}),
        limiter: ImageLab::AI::U2netp::InferenceLimiter.new(1)
      )
    end

    assert_equal "AI model is unavailable", error.message
  end

  test "withholds the second inference token and returns a token after failure" do
    limiter = ImageLab::AI::U2netp::InferenceLimiter.new(1)
    started = Queue.new
    release = Queue.new
    second_started = Queue.new
    first = Thread.new { limiter.with_token { started << true; release.pop } }
    started.pop
    second = Thread.new { limiter.with_token { second_started << true } }

    assert_raises(ThreadError) { second_started.pop(true) }
    release << true
    first.join
    second.join
    assert_equal true, second_started.pop
    assert_raises(RuntimeError) { limiter.with_token { raise "predict failed" } }
    assert_equal :available, limiter.with_token { :available }
  end

  test "fails closed for an invalid default concurrency value" do
    previous = ENV["IMAGE_AI_MAX_CONCURRENCY"]
    ENV["IMAGE_AI_MAX_CONCURRENCY"] = "0"
    ImageLab::AI::U2netp.instance_variable_set(:@default_limiter, nil)

    error = assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::U2netp.call(rgb_image, manifest: manifest, model: RecordingModel.new("d0" => constant_output(1.0)))
    end

    assert_equal "AI model is unavailable", error.message
  ensure
    previous.nil? ? ENV.delete("IMAGE_AI_MAX_CONCURRENCY") : ENV["IMAGE_AI_MAX_CONCURRENCY"] = previous
    ImageLab::AI::U2netp.instance_variable_set(:@default_limiter, nil)
  end

  private

  class RecordingModel
    attr_reader :request

    def initialize(response)
      @response = response
    end

    def predict(request)
      @request = request
      @response
    end
  end

  def manifest
    @manifest ||= Struct.new(:input_name, :input_shape, :output_name, :output_shape).new(
      "input",
      [ 1, 3, 320, 320 ],
      "d0",
      [ 1, 1, 320, 320 ]
    )
  end

  def rgb_image(width: 1, height: 1)
    pixels = Array.new(width * height) { [ 100, 150, 200 ] }.flatten
    Vips::Image.new_from_memory(pixels.pack("C*"), width, height, 3, :uchar).copy(interpretation: :srgb)
  end

  def constant_output(value)
    [ [ Array.new(320) { Array.new(320, value) } ] ]
  end

  def nested_shape(value)
    return [] unless value.is_a?(Array)

    [ value.length, *nested_shape(value.first) ]
  end
end
