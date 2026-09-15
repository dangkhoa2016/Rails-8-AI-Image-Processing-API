# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

class ConvertU2netpToOnnxTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/models/convert_u2netp_to_onnx.py").to_s

  test "rejects a missing U-2-Net source directory before attempting conversion" do
    Dir.mktmpdir("u2netp-converter-test-") do |directory|
      missing_source = File.join(directory, "missing-source")
      weights = File.join(directory, "weights.pth")
      output = File.join(directory, "u2netp.onnx")

      _stdout, stderr, status = Open3.capture3(
        "python", SCRIPT,
        "--source-directory", missing_source,
        "--weights", weights,
        "--output", output
      )

      assert_not status.success?
      assert_match(/source directory is not a directory/, stderr)
      assert_not File.exist?(output)
    end
  end
end
