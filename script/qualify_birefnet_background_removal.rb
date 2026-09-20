#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "vips"
require_relative "../config/environment"

CASES_PATH = ENV.fetch("BIREFNET_QUALITY_CASES") do
  abort "BIREFNET_QUALITY_CASES must point to a JSON quality-case manifest"
end
THRESHOLD = Float(ENV.fetch("BIREFNET_MASK_THRESHOLD", "0.5"))
MINIMUM_MEAN_IOU = Float(ENV.fetch("BIREFNET_QUALITY_MIN_MEAN_IOU", "0.732990690691228"))
MINIMUM_MEDIAN_IOU = Float(ENV.fetch("BIREFNET_QUALITY_MIN_MEDIAN_IOU", "0.8590935898017511"))

manifest = JSON.parse(File.read(CASES_PATH), symbolize_names: true)
cases = Array(manifest.fetch(:cases))
abort "quality manifest must contain at least one case" if cases.empty?

results = cases.map do |entry|
  image_path = File.expand_path(entry.fetch(:image), File.dirname(CASES_PATH))
  reference_path = File.expand_path(entry.fetch(:reference_mask), File.dirname(CASES_PATH))
  minimum_iou = Float(entry.fetch(:minimum_iou))

  source = Vips::Image.new_from_file(image_path).autorot
  reference = Vips::Image.new_from_file(reference_path).extract_band(0)
  predicted = ImageLab::AI::Birefnet.call(source).image

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
    r3_reference_iou: entry[:r3_reference_iou],
    r3_delta: entry[:r3_reference_iou] && (iou - Float(entry[:r3_reference_iou])),
    pass: iou >= minimum_iou
  }
end

puts JSON.pretty_generate(results)

ious = results.map { |result| result.fetch(:iou) }
sorted = ious.sort
median_iou = if sorted.length.even?
               (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2.0
else
               sorted[sorted.length / 2]
end
mean_iou = ious.sum / ious.length
summary = {
  pass_count: results.count { |result| result.fetch(:pass) },
  fail_count: results.count { |result| !result.fetch(:pass) },
  mean_iou: mean_iou,
  median_iou: median_iou,
  minimum_mean_iou: MINIMUM_MEAN_IOU,
  minimum_median_iou: MINIMUM_MEDIAN_IOU,
  mean_pass: mean_iou >= MINIMUM_MEAN_IOU,
  median_pass: median_iou >= MINIMUM_MEDIAN_IOU,
  worst_case: results.min_by { |result| result.fetch(:iou) }.fetch(:name),
  minimum_case_iou: ious.min
}
puts JSON.pretty_generate(summary)

passed = results.all? { |result| result.fetch(:pass) } && summary.fetch(:mean_pass) && summary.fetch(:median_pass)
abort "BIREFNET_BACKGROUND_REMOVAL_QUALITY=FAIL" unless passed
puts "BIREFNET_BACKGROUND_REMOVAL_QUALITY=PASS"
