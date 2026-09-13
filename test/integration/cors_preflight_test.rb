# frozen_string_literal: true

require "test_helper"

class CorsPreflightTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("cors-preflight@example.local")
  end

  test "preflight allows the configured JWT header" do
    configured_header = Warden::JWTAuth.config.token_header

    preflight(configured_header)

    assert_response :success
    assert_includes allow_headers, configured_header
  end

  test "preflight still allows the standard and legacy Beam headers" do
    preflight("Authorization")
    assert_response :success
    assert_includes allow_headers, "Authorization"

    preflight("X-Authorization")
    assert_response :success
    assert_includes allow_headers, "X-Authorization"
  end

  test "preflight still allows X-Refresh-Token" do
    preflight("X-Refresh-Token")

    assert_response :success
    assert_includes allow_headers, "X-Refresh-Token"
  end

  test "preflight for a header outside the allow-list gets no CORS headers" do
    preflight("X-Bogus-Header")

    assert_response :success
    assert_nil response.headers["Access-Control-Allow-Headers"]
  end

  test "sign in exposes the configured JWT header to browser clients" do
    configured_header = Warden::JWTAuth.config.token_header

    post "/users/sign_in", headers: {
      "Origin" => "http://localhost:4000",
      "Content-Type" => "application/json"
    }, params: {
      user: { email: @user.email, password: "Password1!" }
    }, as: :json

    assert_response :ok

    expose_headers = response.headers["Access-Control-Expose-Headers"]
    assert_includes expose_headers.to_s.split(",").map(&:strip), configured_header
  end

  test "image processing exposes response metadata headers to browser clients" do
    get root_url, headers: { "Origin" => "http://localhost:4000" }

    assert_response :ok
    exposed = response.headers.fetch("Access-Control-Expose-Headers", "").split(",").map(&:strip)
    assert_includes exposed, "X-Image-Width"
    assert_includes exposed, "X-Image-Height"
    assert_includes exposed, "X-Image-Format"
    assert_includes exposed, "X-Processing-Time-Ms"
  end

  private

  def preflight(requested_headers)
    process :options, "/user/me", headers: {
      "Origin" => "http://localhost:4000",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => requested_headers
    }
  end

  def allow_headers
    response.headers.fetch("Access-Control-Allow-Headers", "").split(",").map(&:strip)
  end
end
