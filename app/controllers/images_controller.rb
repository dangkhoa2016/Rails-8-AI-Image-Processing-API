# frozen_string_literal: true

require "json"
require "vips"

class ImagesController < ApplicationController
  include UserAccessControl

  before_action :require_authenticated_user

  def capabilities
    render json: {
      version: "v1",
      operations: [],
      request_content_type: "multipart/form-data",
      response_content_type: "image/png"
    }
  end

  def process_image
    uploaded_image = params.require(:image)
    operations = parse_operations
    return unprocessable_entity!("operations must be a JSON array") unless operations.is_a?(Array)
    return unprocessable_entity!("operations must be an empty JSON array in v1") unless operations.empty?

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    image = Vips::Image.new_from_buffer(uploaded_image.read, "")
    png = image.write_to_buffer(".png")

    response.headers["Cache-Control"] = "no-store"
    set_image_metadata_headers(image, started_at)
    send_data png, type: "image/png", disposition: "inline"
  end

  private

  def parse_operations
    value = params.require(:operations)
    return unless value.is_a?(String)

    JSON.parse(value)
  rescue JSON::ParserError, TypeError
    nil
  end

  def unprocessable_entity!(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def set_image_metadata_headers(image, started_at)
    response.headers["X-Image-Width"] = image.width.to_s
    response.headers["X-Image-Height"] = image.height.to_s
    response.headers["X-Image-Format"] = "png"
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000
    response.headers["X-Processing-Time-Ms"] = elapsed_ms.round.to_s
  end
end
