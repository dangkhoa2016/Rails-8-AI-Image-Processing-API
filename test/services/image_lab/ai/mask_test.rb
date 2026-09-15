# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLab::AI::MaskTest < ActiveSupport::TestCase
  test "normalizes finite U2-NetP output into one float mask" do
    mask = ImageLab::AI::Mask.new(
      output: output_with { |row, column| row * 320 + column },
      source_width: 320,
      source_height: 320
    )

    assert_equal [ 320, 320, 1, :float ], [ mask.image.width, mask.image.height, mask.image.bands, mask.image.format ]
    pixels = mask.image.write_to_memory.unpack("f*")
    assert pixels.all? { |value| value.finite? && value.between?(0.0, 1.0) }
    assert_in_delta 0.0, pixels.min, 1e-6
    assert_in_delta 1.0, pixels.max, 1e-6
  end

  test "resizes the mask to the original image dimensions" do
    mask = ImageLab::AI::Mask.new(
      output: output_with { |row, column| row * 320 + column },
      source_width: 7,
      source_height: 5
    )

    assert_equal [ 7, 5, 1, :float ], [ mask.image.width, mask.image.height, mask.image.bands, mask.image.format ]
    assert mask.image.write_to_memory.unpack("f*").all? { |value| value.finite? && value.between?(0.0, 1.0) }
  end

  test "maps a constant U2-NetP output to an empty foreground mask" do
    mask = ImageLab::AI::Mask.new(output: output_with { 9.5 }, source_width: 3, source_height: 2)

    assert_equal Array.new(6, 0.0), mask.image.write_to_memory.unpack("f*")
  end

  test "rejects malformed output and invalid source dimensions" do
    invalid_outputs = [ [], Array.new(320) { Array.new(320, 1.0) }, output_with { Float::NAN }, output_with { Float::INFINITY } ]

    invalid_outputs.each do |output|
      error = assert_raises(ImageLab::Errors::AiUnavailable) do
        ImageLab::AI::Mask.new(output:, source_width: 1, source_height: 1)
      end
      assert_equal "AI model is unavailable", error.message
    end

    assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::Mask.new(output: output_with { 1.0 }, source_width: 0, source_height: 1)
    end
  end

  private

  def output_with
    [ [ Array.new(320) { |row| Array.new(320) { |column| yield(row, column) } } ] ]
  end
end
