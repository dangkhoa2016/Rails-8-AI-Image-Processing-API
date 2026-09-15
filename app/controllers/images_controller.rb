# frozen_string_literal: true

require "json"

class ImagesController < ApplicationController
  include UserAccessControl

  before_action :require_authenticated_user
  rescue_from ImageLab::Errors::InvalidImage,
              ImageLab::Errors::UnsupportedFormat,
              ImageLab::Errors::UploadTooLarge,
              ImageLab::Errors::PixelLimitExceeded,
              ImageLab::Errors::InvalidOperation,
              ImageLab::Errors::UnsupportedOperation,
              ImageLab::Errors::OperationLimitExceeded,
              with: :unprocessable_image_input

  def capabilities
    render json: {
      version: "v1",
      operations: ImageLab::OperationRegistry.available,
      request_content_type: "multipart/form-data",
      response_content_type: "image/png"
    }
  end

  def process_image
    uploaded_image = params.require(:image)
    ImageLab::OperationRegistry.validate!(parse_operations)

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    image = ImageLab::Input.call(uploaded_image).image
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

  def unprocessable_image_input(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  def set_image_metadata_headers(image, started_at)
    response.headers["X-Image-Width"] = image.width.to_s
    response.headers["X-Image-Height"] = image.height.to_s
    response.headers["X-Image-Format"] = "png"
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000
    response.headers["X-Processing-Time-Ms"] = elapsed_ms.round.to_s
  end
end
