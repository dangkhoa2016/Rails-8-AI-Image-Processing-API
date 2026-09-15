# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class FetchU2netpTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/models/fetch_u2netp").to_s

  test "does not publish a partial weights file when curl fails" do
    Dir.mktmpdir("u2netp-fetch-test-") do |directory|
      fake_bin = File.join(directory, "bin")
      model_directory = File.join(directory, "models")
      FileUtils.mkdir_p(fake_bin)
      fake_curl = File.join(fake_bin, "curl")
      File.write(fake_curl, "#!/usr/bin/env bash\nprintf 'network interrupted\\n' >&2\nexit 22\n")
      FileUtils.chmod("u+x", fake_curl)

      _stdout, stderr, status = Open3.capture3(
        { "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}" },
        "bash", SCRIPT,
        "--model-directory", model_directory
      )

      assert_not status.success?
      assert_match(/download failed/, stderr)
      assert_not File.exist?(File.join(model_directory, "u2netp.pth"))
    end
  end
end
