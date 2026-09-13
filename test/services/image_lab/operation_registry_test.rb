# frozen_string_literal: true

require "test_helper"

class ImageLab::OperationRegistryTest < ActiveSupport::TestCase
  test "reports and validates the initial empty operation set" do
    assert_equal [], ImageLab::OperationRegistry.available
    assert_equal [], ImageLab::OperationRegistry.validate!([])
  end

  test "rejects non-arrays and malformed entries" do
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::OperationRegistry.validate!(nil) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::OperationRegistry.validate!([ {} ]) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::OperationRegistry.validate!([ { "op" => 1 } ]) }
    assert_raises(ImageLab::Errors::InvalidOperation) { ImageLab::OperationRegistry.validate!([ { "op" => " " } ]) }
  end

  test "rejects an explicitly named but unregistered operation" do
    assert_raises(ImageLab::Errors::UnsupportedOperation) do
      ImageLab::OperationRegistry.validate!([ { "op" => "resize_to_fit" } ])
    end
  end

  test "rejects a count above the supplied maximum" do
    assert_raises(ImageLab::Errors::OperationLimitExceeded) do
      ImageLab::OperationRegistry.validate!([ { "op" => "one" }, { "op" => "two" } ], max_operations: 1)
    end
  end

  test "uses 16 for invalid environment values" do
    [ "", "0", "-1", "not-a-number" ].each do |value|
      with_env("IMAGE_MAX_OPERATIONS" => value) do
        assert_equal 16, ImageLab::OperationRegistry.env_limit("IMAGE_MAX_OPERATIONS", 16)
      end
    end
  end

  private

  def with_env(overrides)
    previous = overrides.to_h { |key, _value| [ key, ENV[key] ] }
    ENV.update(overrides)
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
