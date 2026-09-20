# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLab::AI::BackgroundRemovalTest < ActiveSupport::TestCase
  test "fails closed when AI is disabled" do
    with_env("IMAGE_AI_ENABLED" => "false") do
      error = assert_raises(ImageLab::Errors::AiUnavailable) do
        ImageLab::AI::BackgroundRemoval.call(rgb_image, mask_provider: mask_provider([ 1.0, 1.0 ]))
      end

      assert_equal "AI model is unavailable", error.message
    end
  end

  test "adds a foreground mask as alpha without changing source geometry" do
    with_env("IMAGE_AI_ENABLED" => "true") do
      result = ImageLab::AI::BackgroundRemoval.call(
        rgb_image,
        mask_provider: mask_provider([ 1.0, 0.0 ])
      )

      assert_equal [ 2, 1, 4 ], [ result.width, result.height, result.bands ]
      assert_equal 255.0, result.getpoint(0, 0).last
      assert_equal 0.0, result.getpoint(1, 0).last
    end
  end

  test "composites transparent pixels onto an explicit solid background" do
    with_env("IMAGE_AI_ENABLED" => "true") do
      result = ImageLab::AI::BackgroundRemoval.call(
        rgb_image,
        background: "#FFFFFF",
        mask_provider: mask_provider([ 1.0, 0.0 ])
      )

      assert_equal [ 2, 1, 3 ], [ result.width, result.height, result.bands ]
      assert_equal [ 255.0, 0.0, 0.0 ], result.getpoint(0, 0)
      assert_equal [ 255.0, 255.0, 255.0 ], result.getpoint(1, 0)
    end
  end

  test "selects the integrated A2 BiRefNet provider by default" do
    with_env("IMAGE_AI_ENABLED" => "true") do
      mask = Vips::Image.new_from_memory([ 1.0, 1.0 ].pack("f*"), 2, 1, 1, :float)
      provider_called = false
      fake_call = ->(_image) { provider_called = true; FakeMask.new(mask) }

      ImageLab::AI::Birefnet.stub(:call, fake_call) do
        result = ImageLab::AI::BackgroundRemoval.call(rgb_image)

        assert_equal [ 2, 1, 4 ], [ result.width, result.height, result.bands ]
      end

      assert provider_called
    end
  end

  test "rejects invalid background and feather inputs before inference output is encoded" do
    with_env("IMAGE_AI_ENABLED" => "true") do
      assert_raises(ImageLab::Errors::InvalidOperation) do
        ImageLab::AI::BackgroundRemoval.call(
          rgb_image,
          background: "white",
          mask_provider: mask_provider([ 1.0, 1.0 ])
        )
      end

      assert_raises(ImageLab::Errors::InvalidOperation) do
        ImageLab::AI::BackgroundRemoval.call(
          rgb_image,
          feather: ImageLab::AI::BackgroundRemoval::MAX_FEATHER + 1,
          mask_provider: mask_provider([ 1.0, 1.0 ])
        )
      end
    end
  end

  private

  FakeMask = Struct.new(:image)

  def rgb_image
    Vips::Image.new_from_memory(
      [ 255, 0, 0, 0, 255, 0 ].pack("C*"),
      2,
      1,
      3,
      :uchar
    ).copy(interpretation: :srgb)
  end

  def mask_provider(values)
    mask = Vips::Image.new_from_memory(values.pack("f*"), 2, 1, 1, :float)
    Class.new do
      define_singleton_method(:call) { |_image| FakeMask.new(mask) }
    end
  end

  def with_env(overrides)
    previous = overrides.to_h { |key, _value| [ key, ENV[key] ] }
    ENV.update(overrides)
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
