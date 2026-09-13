# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "tempfile"
require "vips"

class ImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("image-contract@example.local")
    @upload_tempfiles = []
  end

  teardown { @upload_tempfiles.each(&:close!) }

  test "capabilities require authentication" do
    get "/images/capabilities", as: :json

    assert_response :unauthorized
  end

  test "processing requires authentication" do
    post "/images/process", params: { operations: "[]" }

    assert_response :unauthorized
  end

  test "capabilities report the v1 empty operation set" do
    get "/images/capabilities", headers: authenticated_headers, as: :json

    assert_response :success
    assert_equal(
      {
        "version" => "v1",
        "operations" => [],
        "request_content_type" => "multipart/form-data",
        "response_content_type" => "image/png"
      },
      json_response
    )
  end

  test "processing rejects a missing image" do
    post "/images/process", params: { operations: "[]" }, headers: authenticated_headers

    assert_response :unprocessable_entity
    assert json_response.fetch("error").present?
  end

  test "processing rejects missing operations" do
    post "/images/process", params: { image: tiny_png_upload }, headers: authenticated_headers

    assert_response :unprocessable_entity
    assert json_response.fetch("error").present?
  end

  test "processing rejects malformed operations" do
    post "/images/process", params: { image: tiny_png_upload, operations: "not-json" }, headers: authenticated_headers

    assert_response :unprocessable_entity
    assert json_response.fetch("error").present?
  end

  test "processing rejects non-empty operations" do
    post "/images/process", params: { image: tiny_png_upload, operations: '[{"name":"resize_to_fit"}]' }, headers: authenticated_headers

    assert_response :unprocessable_entity
    assert json_response.fetch("error").present?
  end

  test "processing maps invalid and unsupported uploads to JSON 422" do
    post "/images/process", params: { image: upload_from_bytes("".b, "empty.png"), operations: "[]" }, headers: authenticated_headers

    assert_response :unprocessable_entity
    assert json_response.fetch("error").present?

    tiff = Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar).write_to_buffer(".tiff")
    post "/images/process", params: { image: upload_from_bytes(tiff, "image.png"), operations: "[]" }, headers: authenticated_headers

    assert_response :unprocessable_entity
    assert json_response.fetch("error").present?
  end

  test "processing maps byte and dimension limits to JSON 422" do
    with_env("IMAGE_MAX_UPLOAD_BYTES" => "1") do
      post "/images/process", params: { image: upload_from_bytes(tiny_png_bytes, "tiny.png"), operations: "[]" }, headers: authenticated_headers

      assert_response :unprocessable_entity
      assert json_response.fetch("error").present?
    end

    with_env("IMAGE_MAX_DIMENSION" => "1") do
      post "/images/process", params: { image: upload_from_bytes(two_pixel_png_bytes, "wide.png"), operations: "[]" }, headers: authenticated_headers

      assert_response :unprocessable_entity
      assert json_response.fetch("error").present?
    end
  end

  test "processing returns an in-memory PNG with metadata and no-store caching" do
    post "/images/process", params: { image: tiny_png_upload, operations: "[]" }, headers: authenticated_headers

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_equal "1", response.headers.fetch("X-Image-Width")
    assert_equal "1", response.headers.fetch("X-Image-Height")
    assert_equal "png", response.headers.fetch("X-Image-Format")
    assert_operator response.headers.fetch("X-Processing-Time-Ms").to_i, :>=, 0
    assert response.body.start_with?("\x89PNG\r\n\x1A\n".b)
  end

  private

  def authenticated_headers
    jwt_auth_headers_for(@user, { "Accept" => "application/json" })
  end

  def tiny_png_upload
    upload_from_bytes(tiny_png_bytes, "tiny.png")
  end

  def upload_from_bytes(bytes, filename)
    tempfile = Tempfile.new([ "phase-5", File.extname(filename) ])
    @upload_tempfiles << tempfile
    tempfile.binmode
    tempfile.write(bytes)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "image/png", true)
  end

  def tiny_png_bytes
    Vips::Image.new_from_memory([ 255, 0, 0 ].pack("C*"), 1, 1, 3, :uchar).write_to_buffer(".png")
  end

  def two_pixel_png_bytes
    Vips::Image.new_from_memory([ 255, 0, 0, 0, 255, 0 ].pack("C*"), 2, 1, 3, :uchar).write_to_buffer(".png")
  end

  def with_env(overrides)
    previous = overrides.to_h { |key, _value| [ key, ENV[key] ] }
    ENV.update(overrides)
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
