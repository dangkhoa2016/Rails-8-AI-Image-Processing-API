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

      def mem_available_bytes(proc_reader: method(:proc_mem_available_bytes), cgroup_reader: method(:cgroup_mem_available_bytes))
        [ proc_reader.call, cgroup_reader.call ].compact.min
      end

      def proc_mem_available_bytes
        match = File.read("/proc/meminfo").match(/^MemAvailable:\s+(\d+)\s+kB$/)
        match && match[1].to_i * 1024
      rescue Errno::ENOENT
        nil
      end

      def cgroup_mem_available_bytes
        limit = cgroup_memory_limit_bytes
        return unless limit

        [ limit - Integer(File.read("/sys/fs/cgroup/memory.current").strip, 10), 0 ].max
      rescue Errno::ENOENT, ArgumentError
        nil
      end

      def cgroup_memory_limit_bytes
        value = File.read("/sys/fs/cgroup/memory.max").strip
        return if value == "max"

        Integer(value, 10)
      rescue Errno::ENOENT, ArgumentError
        nil
      end
    end
  end
end
