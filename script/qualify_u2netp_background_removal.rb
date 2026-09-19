#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "vips"
require_relative "../config/environment"

CASES_PATH = ENV.fetch("U2NETP_QUALITY_CASES") do
  abort "U2NETP_QUALITY_CASES must point to a JSON quality-case manifest"
end
THRESHOLD = Float(ENV.fetch("U2NETP_MASK_THRESHOLD", "0.5"))

manifest = JSON.parse(File.read(CASES_PATH), symbolize_names: true)
cases = Array(manifest.fetch(:cases))
abort "quality manifest must contain at least one case" if cases.empty?

results = cases.map do |entry|
  image_path = File.expand_path(entry.fetch(:image), File.dirname(CASES_PATH))
  reference_path = File.expand_path(entry.fetch(:reference_mask), File.dirname(CASES_PATH))
  minimum_iou = Float(entry.fetch(:minimum_iou))

  source = Vips::Image.new_from_file(image_path).autorot
  reference = Vips::Image.new_from_file(reference_path).extract_band(0)
  predicted = ImageLab::AI::U2netp.call(source).image

  unless predicted.width == reference.width && predicted.height == reference.height
    abort "geometry mismatch for #{entry.fetch(:name)}"
  end

  predicted_binary = predicted > THRESHOLD
  reference_binary = reference > (reference.max.to_f <= 1.0 ? THRESHOLD : 127.5)
  intersection = (predicted_binary & reference_binary).avg.to_f / 255.0 * predicted.width * predicted.height
  union = (predicted_binary | reference_binary).avg.to_f / 255.0 * predicted.width * predicted.height
  iou = union.zero? ? 1.0 : intersection / union

  {
    name: entry.fetch(:name),
    width: predicted.width,
    height: predicted.height,
    threshold: THRESHOLD,
    iou: iou,
    minimum_iou: minimum_iou,
    pass: iou >= minimum_iou
  }
end

puts JSON.pretty_generate(results)
abort "U2NETP_BACKGROUND_REMOVAL_QUALITY=FAIL" unless results.all? { |result| result.fetch(:pass) }
puts "U2NETP_BACKGROUND_REMOVAL_QUALITY=PASS"
