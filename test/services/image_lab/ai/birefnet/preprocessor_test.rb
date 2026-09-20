# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLab::AI::BirefnetPreprocessorTest < ActiveSupport::TestCase
  SIZE = ImageLab::AI::Birefnet::Preprocessor::SIZE

  test "normalizes a constant RGB pixel through the /255 ImageNet contract" do
    tensor = ImageLab::AI::Birefnet::Preprocessor.call(constant_rgb_image([ 255, 128, 64 ]))
    red = (255.0 / 255.0 - 0.485) / 0.229
    green = (128.0 / 255.0 - 0.456) / 0.224
    blue = (64.0 / 255.0 - 0.406) / 0.225

    assert_equal [ 1, 3, 1024, 1024 ], tensor.shape
    assert_in_delta red, tensor.at(0, 0, SIZE / 2, SIZE / 2), 1e-4
    assert_in_delta green, tensor.at(0, 1, SIZE / 2, SIZE / 2), 1e-4
    assert_in_delta blue, tensor.at(0, 2, SIZE / 2, SIZE / 2), 1e-4
  end

  test "uses square aspect-distorting geometry and NCHW channel order" do
    tensor = ImageLab::AI::Birefnet::Preprocessor.call(asymmetric_red_image)

    assert_equal [ 1, 3, 1024, 1024 ], tensor.shape
    assert_operator tensor.at(0, 0, 0, 0), :>, tensor.at(0, 2, 0, 0)
  end

  test "replicates grayscale before channel normalization" do
    tensor = ImageLab::AI::Birefnet::Preprocessor.call(grayscale_image)
    normalized_channels = [
      tensor.at(0, 0, 0, 0) * 0.229 + 0.485,
      tensor.at(0, 1, 0, 0) * 0.224 + 0.456,
      tensor.at(0, 2, 0, 0) * 0.225 + 0.406
    ]

    assert_in_delta normalized_channels.first, normalized_channels.second, 1e-5
    assert_in_delta normalized_channels.first, normalized_channels.third, 1e-5
  end

  test "ignores alpha without mutating the source image" do
    source = rgba_image(alpha: 128)
    before = source.write_to_memory

    original_alpha = ImageLab::AI::Birefnet::Preprocessor.call(source)
    ignored_alpha = ImageLab::AI::Birefnet::Preprocessor.call(rgba_image(alpha: 0))

    assert_equal before, source.write_to_memory
    assert_equal original_alpha.values, ignored_alpha.values
  end

  test "fails closed for an incompatible manifest shape" do
    manifest = Struct.new(:input_shape, :preprocess_size).new([ 1, 3, 1025, 1024 ], SIZE)

    assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::Birefnet::Preprocessor.call(constant_rgb_image([ 255, 255, 255 ]), manifest: manifest)
    end
  end

  private

  def constant_rgb_image(pixel)
    Vips::Image.new_from_memory(pixel.pack("C*"), 1, 1, 3, :uchar).copy(interpretation: :srgb)
  end

  def asymmetric_red_image
    pixels = [ 255, 0, 0 ] + Array.new(2 * 4 * 3 - 3, 0)
    Vips::Image.new_from_memory(pixels.pack("C*"), 2, 4, 3, :uchar).copy(interpretation: :srgb)
  end

  def grayscale_image
    Vips::Image.new_from_memory([ 128 ].pack("C*"), 1, 1, 1, :uchar).copy(interpretation: :b_w)
  end

  def rgba_image(alpha:)
    Vips::Image.new_from_memory([ 100, 150, 200, alpha ].pack("C*"), 1, 1, 4, :uchar).copy(interpretation: :srgb)
  end
end