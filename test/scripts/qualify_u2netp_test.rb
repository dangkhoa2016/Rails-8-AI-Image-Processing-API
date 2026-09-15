# frozen_string_literal: true

require "test_helper"
require "open3"

class QualifyU2netpTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/models/qualify_u2netp").to_s

  test "rejects an unknown option before downloading or building a model" do
    _stdout, stderr, status = Open3.capture3("bash", SCRIPT, "--unexpected-option")

    assert_not status.success?
    assert_match(/unknown option: --unexpected-option/, stderr)
  end
end
