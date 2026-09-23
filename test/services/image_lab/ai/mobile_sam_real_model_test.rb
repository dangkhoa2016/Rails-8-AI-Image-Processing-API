# frozen_string_literal: true

require "test_helper"
require "json"
require "vips"

class ImageLab::AI::MobileSamRealModelTest < ActiveSupport::TestCase
  setup do
    skip "set MOBILESAM_REAL_MODEL_TEST=1 to run canonical MobileSAM parity" unless ENV["MOBILESAM_REAL_MODEL_TEST"] == "1"

    @authority_root = ENV["MOBILESAM_M2_AUTHORITY_ROOT"].to_s
    skip "set MOBILESAM_M2_AUTHORITY_ROOT to the recovered M2 authority directory" if @authority_root.empty?

    @fixture_path = File.join(@authority_root, "fixtures/mobilesam-picture1-canonical.png")
    @prompt_authority_path = File.join(@authority_root, "evidence/prompt-authority.json")
    @point_mask_path = File.join(@authority_root, "ruby/point-binary-mask.png")
    @box_mask_path = File.join(@authority_root, "ruby/box-binary-mask.png")

    [ @fixture_path, @prompt_authority_path, @point_mask_path, @box_mask_path ].each do |path|
      assert File.file?(path), "missing canonical M2 authority file: #{path}"
    end

    @image = Vips::Image.new_from_file(@fixture_path)
    @authority = JSON.parse(File.read(@prompt_authority_path))
  end

  test "positive point and box are pixel-identical to canonical M2 masks" do
    with_env("IMAGE_AI_ENABLED" => "true") do
      positive = @authority.fetch("point_positive")
      point_mask = ImageLab::AI::MobileSam.call(@image, prompt: {
        "type" => "point",
        "x" => positive.fetch("x"),
        "y" => positive.fetch("y"),
        "label" => positive.fetch("label")
      })

      box = @authority.fetch("box")
      box_mask = ImageLab::AI::MobileSam.call(@image, prompt: {
        "type" => "box",
        "x0" => box.fetch("x0"),
        "y0" => box.fetch("y0"),
        "x1" => box.fetch("x1"),
        "y1" => box.fetch("y1")
      })

      assert_equal Vips::Image.new_from_file(@point_mask_path).write_to_memory, point_mask.write_to_memory
      assert_equal Vips::Image.new_from_file(@box_mask_path).write_to_memory, box_mask.write_to_memory
      assert_equal :uchar, point_mask.format
      assert_equal :uchar, box_mask.format
    end
  end

  test "negative point returns source-sized binary uchar mask and sessions are cached" do
    negative = @authority.fetch("point_negative")

    mask = with_env("IMAGE_AI_ENABLED" => "true") do
      ImageLab::AI::MobileSam.call(@image, prompt: {
        "type" => "point",
        "x" => negative.fetch("x"),
        "y" => negative.fetch("y"),
        "label" => negative.fetch("label")
      })
    end

    assert_equal [ @image.width, @image.height, 1 ], [ mask.width, mask.height, mask.bands ]
    assert_equal :uchar, mask.format
    assert_empty(mask.write_to_memory.bytes.uniq - [ 0, 255 ])

    assert_same ImageLab::AI::ModelRegistry.fetch!(:mobile_sam_encoder),
      ImageLab::AI::ModelRegistry.fetch!(:mobile_sam_encoder)
    assert_same ImageLab::AI::ModelRegistry.fetch!(:mobile_sam_decoder),
      ImageLab::AI::ModelRegistry.fetch!(:mobile_sam_decoder)
  end

  private

  def with_env(overrides)
    previous = overrides.to_h { |key, _value| [ key, ENV[key] ] }
    ENV.update(overrides)
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
