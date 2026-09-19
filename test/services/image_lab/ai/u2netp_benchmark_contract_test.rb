# frozen_string_literal: true

require "test_helper"

class ImageLab::AI::U2netpBenchmarkContractTest < ActiveSupport::TestCase
  test "the 8 GB benchmark fails closed without a verified memory limit and requires canonical workloads" do
    script = Rails.root.join("script/benchmark_u2netp_cpu_8gb.rb").read

    assert_includes script, "NO_VERIFIED_8GB_MEMORY_LIMIT"
    assert_includes script, "8 * 1024 * 1024 * 1024"
    assert_includes script, "[ 512, 512 ]"
    assert_includes script, "[ 1024, 1024 ]"
    assert_includes script, "[ 1920, 1080 ]"
    assert_includes script, "[ 4000, 3000 ]"
    assert_includes script, "NO_OOM_ON_8GB=PASS"
    assert_includes script, "SESSION_REUSE=PASS"
  end
end
