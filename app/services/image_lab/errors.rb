# frozen_string_literal: true

module ImageLab
  module Errors
    class InvalidImage < StandardError; end
    class UnsupportedFormat < StandardError; end
    class UploadTooLarge < StandardError; end
    class PixelLimitExceeded < StandardError; end
    class InvalidOperation < StandardError; end
    class UnsupportedOperation < StandardError; end
    class OperationLimitExceeded < StandardError; end
    class OutputLimitExceeded < StandardError; end
    class AiUnavailable < StandardError; end
  end
end
