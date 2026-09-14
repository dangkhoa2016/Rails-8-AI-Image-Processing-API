# frozen_string_literal: true

require "fileutils"
require "json"
require "rbconfig"
require "tmpdir"
require "time"
require "vips"
require_relative "corpus"
require_relative "http_scenario"
require_relative "measurements"
require_relative "safety"
require_relative "workloads"

module ImageLab
  module Benchmark
    module Runner
      module_function

      RESULT_FILENAME = "vips-cpu-8gb-result.json"
      SAMPLE_COUNT = 5

      def run!(quick:, output_directory:, worker_count:, memory_reader: Safety.method(:mem_available_bytes))
        raise ArgumentError, "worker_count must be positive" unless worker_count.positive?

        FileUtils.mkdir_p(output_directory)
        result = nil

        Dir.mktmpdir("vips-benchmark") do |parent|
          corpus_directory = File.join(parent, "vips-corpus")
          fixtures = Corpus.create!(directory: corpus_directory)
          result = build_result(
            fixtures:,
            quick:,
            worker_count:,
            memory_reader:
          )
          File.write(File.join(output_directory, RESULT_FILENAME), JSON.pretty_generate(result))
        ensure
          Corpus.cleanup!(directory: corpus_directory) if corpus_directory
        end

        result
      end

      def run_worker!(fixture_path:, workload_name:, result_path:)
        fixture = fixture_from_path(fixture_path)
        workload = Workloads.all.find { |candidate| candidate.name == workload_name }
        raise ArgumentError, "unknown workload #{workload_name.inspect}" unless workload

        result = execute_workload(workload, fixture)
        FileUtils.mkdir_p(File.dirname(result_path))
        File.write(result_path, JSON.generate(result))
        result
      end

      def successful?(result)
        result.fetch("gates").values.all? { |gate| gate.fetch("status") == "PASS" } &&
          result.fetch("concurrency").all? { |record| record.fetch("status") == "PASS" }
      end

      def build_result(fixtures:, quick:, worker_count:, memory_reader:)
        selected_fixtures = quick ? [ fixtures.first ] : fixtures
        selected_workloads = quick ? Workloads.all.select { |workload| workload.name == "mixed_5" } : Workloads.all
        workloads = selected_fixtures.product(selected_workloads).map do |fixture, workload|
          execute_workload(workload, fixture)
        end
        http_scenarios = selected_fixtures.map { |fixture| execute_http_scenario(fixture) }
        concurrency = run_concurrency(
          fixture: selected_fixtures.first,
          worker_count:,
          memory_reader:
        )

        {
          "schema_version" => 1,
          "generated_at" => Time.now.utc.iso8601,
          "environment" => environment,
          "corpus" => fixtures.map { |fixture| fixture_record(fixture) },
          "workloads" => workloads,
          "http_scenarios" => http_scenarios,
          "concurrency" => concurrency,
          "gates" => gates_for(workloads:, http_scenarios:, concurrency:)
        }
      end
      private_class_method :build_result

      def execute_workload(workload, fixture)
        Workloads.call(workload, fixture:, max_output_pixels: ImageLab::OperationRegistry.env_limit("IMAGE_MAX_OUTPUT_PIXELS", 25_000_000))
        samples = SAMPLE_COUNT.times.map { measured_workload_sample(workload, fixture) }
        {
          "name" => workload.name,
          "operations" => workload.operations,
          "format" => workload.format,
          "fixture" => fixture_record(fixture),
          "warmup_runs" => 1,
          "samples" => samples,
          "summary" => Measurements.summary(samples)
        }
      rescue StandardError => error
        failed_workload_record(workload, fixture, error)
      end
      private_class_method :execute_workload

      def measured_workload_sample(workload, fixture)
        encoded, metrics = Measurements.capture do
          Workloads.call(
            workload,
            fixture:,
            max_output_pixels: ImageLab::OperationRegistry.env_limit("IMAGE_MAX_OUTPUT_PIXELS", 25_000_000)
          )
        end
        output = Vips::Image.new_from_buffer(encoded.bytes, "")

        metrics.merge(
          "input_bytes" => fixture.bytes,
          "input_width" => fixture.width,
          "input_height" => fixture.height,
          "output_bytes" => encoded.bytes.bytesize,
          "output_width" => output.width,
          "output_height" => output.height
        )
      end
      private_class_method :measured_workload_sample

      def failed_workload_record(workload, fixture, error)
        {
          "name" => workload.name,
          "operations" => workload.operations,
          "format" => workload.format,
          "fixture" => fixture_record(fixture),
          "warmup_runs" => 0,
          "samples" => [],
          "summary" => {},
          "error" => "#{error.class}: #{error.message}"
        }
      end
      private_class_method :failed_workload_record

      def execute_http_scenario(fixture)
        record, metrics = Measurements.capture { HttpScenario.call(fixture:) }
        fixture_record(fixture).merge(metrics).merge(record)
      rescue StandardError => error
        fixture_record(fixture).merge("error" => "#{error.class}: #{error.message}")
      end
      private_class_method :execute_http_scenario

      def run_concurrency(fixture:, worker_count:, memory_reader:)
        (1..worker_count).map do |workers|
          unless Safety.admit_concurrency?(mem_available_bytes: memory_reader.call)
            concurrency_record(workers, "NOT_RUN_UNSAFE_MEMORY")
          else
            run_worker_group(fixture, workers)
          end
        end
      end
      private_class_method :run_concurrency

      def run_worker_group(fixture, workers)
        Dir.mktmpdir("vips-worker-results") do |directory|
          workers_by_pid = workers.times.to_h do |index|
            result_path = File.join(directory, "worker-#{index}.json")
            [ spawn_worker(fixture.path, result_path), result_path ]
          end
          aggregate_rss_peak, exit_statuses = monitor_workers(workers_by_pid)

          if aggregate_rss_peak == :unsafe
            concurrency_record(workers, "NOT_RUN_UNSAFE_MEMORY")
          elsif exit_statuses.values.all?(&:success?) && workers_by_pid.values.all? { |path| File.exist?(path) }
            concurrency_record(
              workers,
              "PASS",
              aggregate_rss_peak_bytes: aggregate_rss_peak,
              worker_samples: workers_by_pid.values.map { |path| JSON.parse(File.read(path)) }
            )
          else
            concurrency_record(workers, "FAIL_WORKER_EXIT")
          end
        end
      end
      private_class_method :run_worker_group

      def spawn_worker(fixture_path, result_path)
        Process.spawn(
          { "RAILS_ENV" => Rails.env },
          RbConfig.ruby,
          Rails.root.join("script/benchmark_vips_cpu_8gb.rb").to_s,
          "--worker",
          "--fixture", fixture_path,
          "--workload", "mixed_5",
          "--result", result_path,
          out: File::NULL,
          err: File::NULL
        )
      end
      private_class_method :spawn_worker

      def monitor_workers(workers_by_pid)
        aggregate_rss_peak = nil
        remaining = workers_by_pid.keys
        exit_statuses = {}

        until remaining.empty?
          active = remaining.reject do |pid|
            result = Process.waitpid2(pid, Process::WNOHANG)
            exit_statuses[pid] = result.last if result
            result
          end
          aggregate_rss = active.sum { |pid| rss_bytes_for(pid).to_i }
          aggregate_rss_peak = [ aggregate_rss_peak, aggregate_rss ].compact.max

          unless Safety.aggregate_rss_safe?(worker_rss_bytes: aggregate_rss)
            active.each { |pid| Process.kill("TERM", pid) rescue Errno::ESRCH }
            active.each { |pid| Process.wait2(pid) rescue Errno::ECHILD }
            return [ :unsafe, exit_statuses ]
          end

          remaining = active
          sleep 0.05 unless remaining.empty?
        end

        [ aggregate_rss_peak, exit_statuses ]
      end
      private_class_method :monitor_workers

      def concurrency_record(workers, status, aggregate_rss_peak_bytes: nil, worker_samples: [])
        {
          "workers" => workers,
          "status" => status,
          "aggregate_rss_peak_bytes" => aggregate_rss_peak_bytes,
          "worker_samples" => worker_samples
        }
      end
      private_class_method :concurrency_record

      def gates_for(workloads:, http_scenarios:, concurrency:)
        workload_samples = workloads.flat_map { |workload| workload.fetch("samples") }
        {
          "NO_OOM" => gate(workloads.all? { |workload| workload.fetch("samples").length == SAMPLE_COUNT } && concurrency.all? { |record| record.fetch("status") == "PASS" }),
          "NO_UNBOUNDED_RSS_GROWTH" => gate(workloads.all? { |workload| Safety.rss_growth_pass?(peaks: workload.fetch("samples").map { |sample| sample["rss_peak_bytes"] }) }),
          "TEMPFILE_CLEANUP" => gate(http_scenarios.all? { |scenario| scenario["tempfile_cleanup_pass"] }),
          "OUTPUT_LIMITS_ENFORCED" => output_limit_gate,
          "SAMPLES_RECORDED" => gate(workload_samples.length == workloads.length * SAMPLE_COUNT)
        }
      end
      private_class_method :gates_for

      def gate(passed)
        { "status" => passed ? "PASS" : "FAIL" }
      end
      private_class_method :gate

      def output_limit_gate
        Workloads.verify_output_limit!
        gate(false)
      rescue ImageLab::Errors::OutputLimitExceeded
        gate(true)
      rescue StandardError
        gate(false)
      end
      private_class_method :output_limit_gate

      def fixture_from_path(path)
        image = Vips::Image.new_from_file(path)
        Fixture.new(File.basename(path, ".*"), path, format_from_path(path), File.size(path), image.width, image.height, image.has_alpha?)
      end
      private_class_method :fixture_from_path

      def fixture_record(fixture)
        {
          "name" => fixture.name,
          "path" => fixture.path,
          "format" => fixture.format,
          "bytes" => fixture.bytes,
          "width" => fixture.width,
          "height" => fixture.height,
          "alpha" => fixture.alpha
        }
      end
      private_class_method :fixture_record

      def format_from_path(path)
        File.extname(path).delete_prefix(".").sub("jpg", "jpeg")
      end
      private_class_method :format_from_path

      def rss_bytes_for(pid)
        match = File.read("/proc/#{pid}/status").match(/^VmRSS:\s+(\d+)\s+kB$/)
        match && match[1].to_i * 1024
      rescue Errno::ENOENT
        nil
      end
      private_class_method :rss_bytes_for

      def environment
        {
          "ruby" => RUBY_DESCRIPTION,
          "vips" => [ 0, 1, 2 ].map { |part| Vips.version(part) }.join("."),
          "cpu_model" => cpu_model,
          "cpu_cores" => File.read("/proc/cpuinfo").scan(/^processor\s*:/).length,
          "ram_bytes" => proc_memory_value("MemTotal"),
          "mem_available_bytes" => Safety.mem_available_bytes,
          "cgroup_memory_limit_bytes" => Safety.cgroup_memory_limit_bytes,
          "os" => os_release,
          "kernel" => File.read("/proc/sys/kernel/osrelease").strip,
          "docker" => { "in_container" => File.exist?("/.dockerenv"), "image" => ENV["BENCHMARK_DOCKER_IMAGE"] }
        }
      end
      private_class_method :environment

      def cpu_model
        File.read("/proc/cpuinfo")[/^model name\s*:\s*(.+)$/, 1]
      rescue Errno::ENOENT
        nil
      end
      private_class_method :cpu_model

      def proc_memory_value(name)
        match = File.read("/proc/meminfo").match(/^#{Regexp.escape(name)}:\s+(\d+)\s+kB$/)
        match && match[1].to_i * 1024
      rescue Errno::ENOENT
        nil
      end
      private_class_method :proc_memory_value

      def os_release
        File.read("/etc/os-release")[/^PRETTY_NAME=(.*)$/, 1]&.delete_prefix('"')&.delete_suffix('"')
      rescue Errno::ENOENT
        nil
      end
      private_class_method :os_release
    end
  end
end
