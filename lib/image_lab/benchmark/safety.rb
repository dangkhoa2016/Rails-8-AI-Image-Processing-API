# frozen_string_literal: true

module ImageLab
  module Benchmark
    module Safety
      module_function

      MIN_AVAILABLE_MEMORY = 1.gigabyte
      MAX_AGGREGATE_RSS = 6.gigabytes

      def admit_concurrency?(mem_available_bytes:)
        mem_available_bytes.is_a?(Numeric) && mem_available_bytes >= MIN_AVAILABLE_MEMORY
      end

      def aggregate_rss_safe?(worker_rss_bytes:)
        worker_rss_bytes.is_a?(Numeric) && worker_rss_bytes <= MAX_AGGREGATE_RSS
      end

      def rss_growth_pass?(peaks:)
        first = peaks.first
        peaks.length == 5 && first.is_a?(Numeric) && first.positive? && peaks.last <= first * 1.15 + 16.megabytes
      end
    end
  end
end
