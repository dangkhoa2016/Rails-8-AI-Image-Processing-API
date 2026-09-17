# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

class GenerateU2netpPreprocessingReferenceTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/models/generate_u2netp_preprocessing_reference.py").to_s

  test "rejects an unknown reference-generator option before requiring build dependencies" do
    _stdout, stderr, status = Open3.capture3("python3", SCRIPT, "--unexpected-option")

    assert_not status.success?
    assert_match(/unrecognized arguments: --unexpected-option/, stderr)
  end

  test "creates a missing output parent before atomically writing reference content" do
    Dir.mktmpdir("u2netp-preprocessing-reference-test-") do |directory|
      output = File.join(directory, "nested", "reference.yml")
      program = <<~PYTHON
        import importlib.util
        import sys
        from pathlib import Path

        specification = importlib.util.spec_from_file_location("reference", sys.argv[1])
        reference = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(reference)
        reference.write_atomically(Path(sys.argv[2]), "reference\\n")
      PYTHON

      _stdout, stderr, status = Open3.capture3("python3", "-c", program, SCRIPT, output)

      assert status.success?, stderr
      assert_equal "reference\n", File.read(output)
      assert_equal 0o644, File.stat(output).mode & 0o777
    end
  end
end
