# frozen_string_literal: true

require "test_helper"
require "vips"

class ImageLab::AI::MobileSamTest < ActiveSupport::TestCase
  FakePrep = Data.define(:width, :height, :resized_width, :resized_height)

  test "parses one JSON object and rejects arrays or malformed JSON" do
    assert_equal(
      { "type" => "point", "x" => 1, "y" => 2, "label" => 1 },
      ImageLab::AI::MobileSam.parse_prompt('{"type":"point","x":1,"y":2,"label":1}')
    )

    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::AI::MobileSam.parse_prompt("[]") }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::AI::MobileSam.parse_prompt("{") }

    parsed_string_number = ImageLab::AI::MobileSam.parse_prompt('{"type":"point","x":"1","y":2,"label":1}')
    prep = FakePrep.new(width: 10, height: 10, resized_width: 1024, resized_height: 1024)
    assert_raises(ImageLab::Errors::InvalidOperation) do
      ImageLab::AI::MobileSam.send(:normalize_prompt, parsed_string_number, prep)
    end
  end

  test "point prompt uses M2 coordinate transform and padding semantics" do
    prep = FakePrep.new(width: 769, height: 770, resized_width: 1023, resized_height: 1024)
    prompt = { "type" => "point", "x" => 384, "y" => 385, "label" => 1 }

    normalized = ImageLab::AI::MobileSam.send(:normalize_prompt, prompt, prep)

    assert_equal "point", normalized.fetch(:type)
    assert_in_delta 510.8348504551365, normalized.fetch(:coords)[0][0], 1e-12
    assert_in_delta 512.0, normalized.fetch(:coords)[0][1], 1e-12
    assert_equal [ 0.0, 0.0 ], normalized.fetch(:coords)[1]
    assert_equal [ 1.0, -1.0 ], normalized.fetch(:labels)
  end

  test "box prompt uses M2 labels and exact transformed authority" do
    prep = FakePrep.new(width: 769, height: 770, resized_width: 1023, resized_height: 1024)
    prompt = { "type" => "box", "x0" => 192, "y0" => 192, "x1" => 577, "y1" => 578 }

    normalized = ImageLab::AI::MobileSam.send(:normalize_prompt, prompt, prep)

    assert_equal [ 2.0, 3.0 ], normalized.fetch(:labels)
    assert_in_delta 255.41742522756826, normalized.fetch(:coords)[0][0], 1e-12
    assert_in_delta 255.33506493506493, normalized.fetch(:coords)[0][1], 1e-12
    assert_in_delta 767.5825747724317, normalized.fetch(:coords)[1][0], 1e-12
    assert_in_delta 768.6649350649351, normalized.fetch(:coords)[1][1], 1e-12
  end

  test "renders an 8-bit binary mask" do
    mask = ImageLab::AI::MobileSam.send(:render_mask, [ [ -1.0, 0.1 ] ], 2, 1, 0.0)

    assert_equal :uchar, mask.format
    assert_equal 1, mask.bands
    assert_equal [ 0, 255 ], mask.write_to_memory.bytes
  end

  test "rejects unknown keys labels non-finite values bounds and invalid boxes" do
    prep = FakePrep.new(width: 10, height: 10, resized_width: 1024, resized_height: 1024)

    invalid = [
      { "type" => "point", "x" => 1, "y" => 2, "label" => 2 },
      { "type" => "point", "x" => 10, "y" => 2, "label" => 1 },
      { "type" => "point", "x" => Float::INFINITY, "y" => 2, "label" => 1 },
      { "type" => "point", "x" => 1, "y" => 2, "label" => 1, "extra" => true },
      { "type" => "box", "x0" => 3, "y0" => 1, "x1" => 2, "y1" => 4 }
    ]

    invalid.each do |prompt|
      assert_raises(ImageLab::Errors::InvalidOperation) do
        ImageLab::AI::MobileSam.send(:normalize_prompt, prompt, prep)
      end
    end
  end
end
