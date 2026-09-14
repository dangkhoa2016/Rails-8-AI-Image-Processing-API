# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class ImageLabBenchmarkCorpusTest < ActiveSupport::TestCase
  test "autoloads the fixture record without first loading the corpus" do
    fixture = ImageLab::Benchmark::Fixture.new("fixture", "/tmp/fixture.png", "png", 1, 1, 1, false)

    assert_equal "fixture", fixture.name
  end

  test "creates every required source class with its documented dimensions" do
    Dir.mktmpdir("vips-benchmark-parent") do |parent|
      fixtures = ImageLab::Benchmark::Corpus.create!(directory: File.join(parent, "vips-corpus"))

      assert_equal %w[full_hd_jpeg large_jpeg square_png transparent_png webp], fixtures.map(&:name)
      assert_equal [ 1920, 1080, "jpeg" ], [ fixtures[0].width, fixtures[0].height, fixtures[0].format ]
      assert_equal [ 4000, 3000, "jpeg" ], [ fixtures[1].width, fixtures[1].height, fixtures[1].format ]
      assert_equal [ 4096, 4096, "png" ], [ fixtures[2].width, fixtures[2].height, fixtures[2].format ]
      assert_equal [ "png", true ], [ fixtures[3].format, fixtures[3].alpha ]
      assert_equal "webp", fixtures[4].format
      assert fixtures.all? { |fixture| fixture.bytes.positive? && File.file?(fixture.path) }
    end
  end

  test "removes only the named benchmark corpus directory" do
    Dir.mktmpdir("vips-benchmark-parent") do |parent|
      directory = File.join(parent, "vips-corpus")
      sentinel = File.join(parent, "keep.txt")
      File.write(sentinel, "keep")
      ImageLab::Benchmark::Corpus.create!(directory:)

      ImageLab::Benchmark::Corpus.cleanup!(directory:)

      assert_not File.exist?(directory)
      assert File.exist?(sentinel)
    end
  end
end
