# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLab::AI::BirefnetRestoreTest < ActiveSupport::TestCase
  test "applies sigmoid and restores a soft mask to the source geometry" do
    output = constant_output(2.0)

    mask = ImageLab::AI::Birefnet::Restore.new(output:, source_width: 6, source_height: 4)

    value = 1.0 / (1.0 + Math.exp(-2.0))
    assert_equal [ 6, 4, 1, :float ], [ mask.image.width, mask.image.height, mask.image.bands, mask.image.format ]
    assert mask.image.write_to_memory.unpack("f*").all? { |v| (v - value).abs < 1e-4 }
  end

  test "keeps the soft mask inside the closed unit interval at a saturated output" do
    mask = ImageLab::AI::Birefnet::Restore.new(output: constant_output(9.0), source_width: 2, source_height: 1).image

    assert mask.write_to_memory.unpack("f*").all? { |v| v < 0.999999 }
  end

  test "fails closed when the output omits the expected geometry" do
    assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::Birefnet::Restore.new(output: [ [ [ [ [ 1.0 ] ] ] ] ], source_width: 6, source_height: 4)
    end
  end

  test "fails closed when the output is not finite" do
    assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::Birefnet::Restore.new(output: constant_output(Float::NAN), source_width: 2, source_height: 1)
    end
  end

  test "fails closed for a non-positive source dimension" do
    assert_raises(ImageLab::Errors::AiUnavailable) do
      ImageLab::AI::Birefnet::Restore.new(output: constant_output(1.0), source_width: 0, source_height: 1)
    end
  end

  private

  def constant_output(value)
    [ Array.new(1) { Array.new(1024) { Array.new(1024, value) } } ]
  end
end