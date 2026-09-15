# frozen_string_literal: true

require "test_helper"

class ImageLab::AI::TensorTest < ActiveSupport::TestCase
  test "stores finite values as float32 with immutable shape and values" do
    tensor = ImageLab::AI::Tensor.new(shape: [ 1, 2 ], values: [ 0.1, -2.5 ])

    assert_equal [ 1, 2 ], tensor.shape
    assert_equal 2, tensor.count
    assert_in_delta 0.1, tensor.at(0, 0), 1e-7
    assert_in_delta(-2.5, tensor.at(0, 1), 1e-7)
    assert_equal 8, tensor.bytes.bytesize
    assert tensor.shape.frozen?
    assert tensor.values.frozen?
    assert tensor.bytes.frozen?
    assert_raises(FrozenError) { tensor.values << 4.0 }
  end

  test "rejects a shape, count, value, or coordinate outside its contract" do
    assert_raises(ArgumentError) { ImageLab::AI::Tensor.new(shape: [], values: []) }
    assert_raises(ArgumentError) { ImageLab::AI::Tensor.new(shape: [ 1, 2 ], values: [ 1.0 ]) }
    assert_raises(ArgumentError) { ImageLab::AI::Tensor.new(shape: [ 1 ], values: [ Float::NAN ]) }
    assert_raises(ArgumentError) { ImageLab::AI::Tensor.new(shape: [ 1 ], values: [ Float::INFINITY ]) }
    assert_raises(ArgumentError) { ImageLab::AI::Tensor.new(shape: [ 1 ], values: [ Float::MAX ]) }
    assert_raises(IndexError) { ImageLab::AI::Tensor.new(shape: [ 1 ], values: [ 1.0 ]).at(1) }
  end
end
