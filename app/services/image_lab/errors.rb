# frozen_string_literal: true

module ImageLab
  module Errors
    class InvalidImage < StandardError; end
    class UnsupportedFormat < StandardError; end
    class UploadTooLarge < StandardError; end
    class PixelLimitExceeded < StandardError; end
  end
end
