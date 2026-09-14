# frozen_string_literal: true

module ImageLab
  module Benchmark
    module Measurements
      module_function

      def capture(proc_reader: method(:read_rss_bytes), clock: Process)
        samples = []
        running = true
        sampler = Thread.new do
          while running
            value = proc_reader.call
            samples << value if value
            sleep 0.05
          end
        end
        started = clock.clock_gettime(Process::CLOCK_MONOTONIC)
        cpu_started = clock.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
        value = yield
        finished = clock.clock_gettime(Process::CLOCK_MONOTONIC)
        cpu_finished = clock.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
        wall_ms = (finished - started) * 1_000
        cpu_ms = (cpu_finished - cpu_started) * 1_000

        [ value, { "wall_ms" => wall_ms, "cpu_ms" => cpu_ms, "rss_avg_bytes" => samples.empty? ? nil : samples.sum.fdiv(samples.length), "rss_peak_bytes" => samples.max, "cpu_utilization_percent" => wall_ms.positive? ? cpu_ms.fdiv(wall_ms) * 100 : nil } ]
      ensure
        running = false
        sampler&.join
      end

      def summary(samples)
        samples.first.keys.to_h do |key|
          values = samples.filter_map { |sample| sample[key] }.sort
          [ key, { "median" => values[values.length / 2], "min" => values.first, "max" => values.last } ]
        end
      end

      def read_rss_bytes
        match = File.read("/proc/self/status").match(/^VmRSS:\s+(\d+)\s+kB$/)
        match && match[1].to_i * 1024
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
