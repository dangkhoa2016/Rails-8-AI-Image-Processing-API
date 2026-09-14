#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "../config/environment"
require_relative "../lib/image_lab/benchmark/runner"

options = { quick: false, output_directory: "tmp/vips-cpu-8gb", worker_count: 3 }

OptionParser.new do |parser|
  parser.banner = "Usage: ruby script/benchmark_vips_cpu_8gb.rb [options]"
  parser.on("--quick", "Run the representative benchmark profile") { options[:quick] = true }
  parser.on("--output DIRECTORY", "Write JSON result to DIRECTORY") { |directory| options[:output_directory] = directory }
  parser.on("--workers COUNT", Integer, "Maximum concurrency level (default: 3)") { |count| options[:worker_count] = count }
  parser.on("--worker", "Run one representative worker process") { options[:worker] = true }
  parser.on("--fixture PATH", "Worker input fixture") { |path| options[:fixture_path] = path }
  parser.on("--workload NAME", "Worker workload name") { |name| options[:workload_name] = name }
  parser.on("--result PATH", "Worker result JSON path") { |path| options[:result_path] = path }
end.parse!

if options[:worker]
  abort "--worker requires --fixture, --workload, and --result" unless options.values_at(:fixture_path, :workload_name, :result_path).all?

  ImageLab::Benchmark::Runner.run_worker!(
    fixture_path: options.fetch(:fixture_path),
    workload_name: options.fetch(:workload_name),
    result_path: options.fetch(:result_path)
  )
else
  result = ImageLab::Benchmark::Runner.run!(
    quick: options.fetch(:quick),
    output_directory: options.fetch(:output_directory),
    worker_count: options.fetch(:worker_count)
  )
  exit(ImageLab::Benchmark::Runner.successful?(result) ? 0 : 1)
end
