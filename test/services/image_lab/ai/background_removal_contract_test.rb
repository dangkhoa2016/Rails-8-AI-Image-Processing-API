# frozen_string_literal: true

require "test_helper"

class ImageLab::AI::BackgroundRemovalContractTest < ActiveSupport::TestCase
  test "the public quality harness is present and requires an external real-model case manifest" do
    script = Rails.root.join("script/qualify_u2netp_background_removal.rb").read

    assert_includes script, 'ENV.fetch("U2NETP_QUALITY_CASES")'
    assert_includes script, "minimum_iou"
    assert_includes script, "U2NETP_BACKGROUND_REMOVAL_QUALITY=PASS"
    assert_includes script, "ImageLab::AI::U2netp.call(source).image"
  end
end
