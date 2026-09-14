# frozen_string_literal: true

require "json"
require_relative "../services/image_lab/pipeline"
require_relative "../services/image_lab/operations/encode"

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
              ImageLab::Errors::OutputLimitExceeded,
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
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ImageLab::Input.with_image(uploaded_image) do |input|
      image = ImageLab::Pipeline.call(
        input,
        parse_operations,
        max_output_pixels: ImageLab::OperationRegistry.env_limit("IMAGE_MAX_OUTPUT_PIXELS", 25_000_000)
      )
      encoded = ImageLab::Operations::Encode.call(image, format: params[:format], quality: parse_quality)

      response.headers["Cache-Control"] = "no-store"
      set_image_metadata_headers(image, started_at, encoded.format)
      send_data encoded.bytes, type: encoded.content_type, disposition: "inline"
    end
  end

  private

  def parse_operations
    value = params.require(:operations)
    return unless value.is_a?(String)

    JSON.parse(value)
  rescue JSON::ParserError, TypeError
    nil
  end

  def parse_quality
    return if params[:quality].nil?

    Integer(params[:quality], 10)
  rescue ArgumentError, TypeError
    raise ImageLab::Errors::InvalidOperation, "quality must be an integer from 1 to 100"
  end

  def unprocessable_entity!(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def unprocessable_image_input(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  def set_image_metadata_headers(image, started_at, format)
    response.headers["X-Image-Width"] = image.width.to_s
    response.headers["X-Image-Height"] = image.height.to_s
    response.headers["X-Image-Format"] = format
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000
    response.headers["X-Processing-Time-Ms"] = elapsed_ms.round.to_s
  end
end
