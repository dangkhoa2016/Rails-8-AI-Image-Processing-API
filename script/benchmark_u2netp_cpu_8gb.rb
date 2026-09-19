#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require_relative "../config/environment"

EIGHT_GIB = 8 * 1024 * 1024 * 1024
REQUIRED_GEOMETRIES = [ [ 512, 512 ], [ 1024, 1024 ], [ 1920, 1080 ], [ 4000, 3000 ] ].freeze

manifest_path = ENV.fetch("U2NETP_BENCHMARK_CASES") do
  abort "U2NETP_BENCHMARK_CASES must point to a JSON benchmark manifest"
end

unless ENV.fetch("IMAGE_AI_ENABLED", "false") == "true"
  abort "IMAGE_AI_ENABLED=true is required"
end

unless Integer(ENV.fetch("IMAGE_AI_MAX_CONCURRENCY", "1"), 10) == 1
  abort "IMAGE_AI_MAX_CONCURRENCY=1 is required for authoritative qualification"
end

def cgroup_memory_limit
  candidates = [
    "/sys/fs/cgroup/memory.max",
    "/sys/fs/cgroup/memory/memory.limit_in_bytes"
  ]

  candidates.each do |path|
    next unless File.file?(path)

    value = File.read(path).strip
    next if value.empty? || value == "max"

    return Integer(value, 10)
  rescue ArgumentError
    next
  end
  nil
end

def peak_rss_kib
  line = File.readlines("/proc/self/status").find { |entry| entry.start_with?("VmHWM:") }
  Integer(line.to_s[/\d+/] || 0, 10)
end

limit = cgroup_memory_limit
abort "NO_VERIFIED_8GB_MEMORY_LIMIT" unless limit && limit <= EIGHT_GIB

manifest = JSON.parse(File.read(manifest_path), symbolize_names: true)
cases = Array(manifest.fetch(:cases))
abort "benchmark manifest must contain cases" if cases.empty?

observed_geometries = cases.map do |entry|
  image = Vips::Image.new_from_file(File.expand_path(entry.fetch(:image), File.dirname(manifest_path))).autorot
  [ image.width, image.height ]
end
missing = REQUIRED_GEOMETRIES - observed_geometries
abort "missing required benchmark geometries: #{missing.inspect}" unless missing.empty?

model_before = ImageLab::AI::ModelRegistry.fetch!(:u2netp)
results = []

cases.each do |entry|
  path = File.expand_path(entry.fetch(:image), File.dirname(manifest_path))
  image = Vips::Image.new_from_file(path).autorot
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  mask = ImageLab::AI::U2netp.call(image).image
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

  results << {
    name: entry.fetch(:name),
    width: image.width,
    height: image.height,
    elapsed_seconds: elapsed,
    mask_width: mask.width,
    mask_height: mask.height,
    peak_rss_kib: peak_rss_kib
  }
end

model_after = ImageLab::AI::ModelRegistry.fetch!(:u2netp)
session_reuse = model_before.equal?(model_after)
peak_bytes = peak_rss_kib * 1024

report = {
  memory_limit_bytes: limit,
  peak_rss_bytes: peak_bytes,
  image_ai_max_concurrency: Integer(ENV.fetch("IMAGE_AI_MAX_CONCURRENCY", "1"), 10),
  session_reuse: session_reuse,
  results: results
}
puts JSON.pretty_generate(report)

abort "SESSION_REUSE=FAIL" unless session_reuse
abort "NO_OOM_ON_8GB=FAIL peak RSS exceeded cgroup limit" if peak_bytes > limit

puts "NO_OOM_ON_8GB=PASS"
puts "AI_CONCURRENCY_BOUND=PASS"
puts "SESSION_REUSE=PASS"
puts "NO_PER_REQUEST_MODEL_LOAD=PASS"
