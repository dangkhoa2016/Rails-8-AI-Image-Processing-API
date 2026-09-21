# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "vips"

class ImagesSegmentRealModelTest < ActionDispatch::IntegrationTest
  setup do
    skip "set MOBILESAM_REAL_MODEL_TEST=1 to run canonical MobileSAM endpoint parity" unless ENV["MOBILESAM_REAL_MODEL_TEST"] == "1"

    @authority_root = ENV["MOBILESAM_M2_AUTHORITY_ROOT"].to_s
    skip "set MOBILESAM_M2_AUTHORITY_ROOT to the recovered M2 authority directory" if @authority_root.empty?

    @fixture_path = File.join(@authority_root, "fixtures/mobilesam-picture1-canonical.png")
    @prompt_authority = JSON.parse(File.read(File.join(@authority_root, "evidence/prompt-authority.json")))
    @user = confirmed_user("mobile-sam-real@example.local")
  end

  test "segment endpoint preserves canonical point box parity and negative point contract" do
    with_env("IMAGE_AI_ENABLED" => "true") do
      point = @prompt_authority.fetch("point_positive")
      response_image = segment({
        type: "point", x: point.fetch("x"), y: point.fetch("y"), label: point.fetch("label")
      })
      assert_exact_mask(response_image, File.join(@authority_root, "ruby/point-binary-mask.png"))

      box = @prompt_authority.fetch("box")
      response_image = segment({
        type: "box", x0: box.fetch("x0"), y0: box.fetch("y0"), x1: box.fetch("x1"), y1: box.fetch("y1")
      })
      assert_exact_mask(response_image, File.join(@authority_root, "ruby/box-binary-mask.png"))

      negative = @prompt_authority.fetch("point_negative")
      response_image = segment({
        type: "point", x: negative.fetch("x"), y: negative.fetch("y"), label: negative.fetch("label")
      })
      assert_equal [ 769, 770, 1 ], [ response_image.width, response_image.height, response_image.bands ]
      assert_empty(response_image.write_to_memory.bytes.uniq - [ 0, 255 ])
    end
  end

  private

  def segment(prompt)
    post "/images/segment", params: {
      image: Rack::Test::UploadedFile.new(@fixture_path, "image/png", true),
      prompt: JSON.generate(prompt)
    }, headers: jwt_auth_headers_for(@user, { "Accept" => "image/png" })

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    Vips::Image.new_from_buffer(response.body, "")
  end

  def assert_exact_mask(actual, expected_path)
    expected = Vips::Image.new_from_file(expected_path)
    assert_equal [ expected.width, expected.height, expected.bands ], [ actual.width, actual.height, actual.bands ]
    assert_equal expected.write_to_memory, actual.write_to_memory
  end

  def with_env(overrides)
    previous = overrides.to_h { |key, _value| [ key, ENV[key] ] }
    ENV.update(overrides)
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
