# frozen_string_literal: true

require_relative "birefnet_manifest"
require_relative "u2netp_manifest"

module ImageLab
  module AI
    class ModelRegistry
      SUPPORTED_MODELS = [ :onnx_smoke, :u2netp, :birefnet ].freeze
      U2NETP_DIRECTORY = Rails.root.join("var/models").freeze
      BIREFNET_DIRECTORY = Rails.root.join("var/models").freeze
      SESSION_OPTIONS = {
        execution_mode: :sequential,
        inter_op_num_threads: 1,
        intra_op_num_threads: 1
      }.freeze
      BIREFNET_SESSION_OPTIONS = SESSION_OPTIONS.merge(enable_cpu_mem_arena: false).freeze

      def self.fetch!(name)
        @default ||= new
        @default.fetch!(name)
      end

      def initialize(model_factory: OnnxRuntime::Model, smoke_fixture: SmokeFixture, u2netp_manifest_loader: -> { U2netpManifest.load! }, u2netp_directory: U2NETP_DIRECTORY, u2netp_path: nil, birefnet_manifest_loader: -> { BirefnetManifest.load! }, birefnet_directory: BIREFNET_DIRECTORY, birefnet_path: nil)
        @models = {}
        @mutex = Mutex.new
        @model_factory = model_factory
        @smoke_fixture = smoke_fixture
        @u2netp_manifest_loader = u2netp_manifest_loader
        @u2netp_directory = u2netp_directory.to_s
        @u2netp_path = u2netp_path&.to_s
        @birefnet_manifest_loader = birefnet_manifest_loader
        @birefnet_directory = birefnet_directory.to_s
        @birefnet_path = birefnet_path&.to_s
      end

      def fetch!(name)
        name = name.to_sym
        raise ImageLab::Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE unless SUPPORTED_MODELS.include?(name)

        @mutex.synchronize do
          @models[name] ||= build_model(name)
        end
      rescue ImageLab::Errors::AiUnavailable
        raise
      rescue StandardError
        raise ImageLab::Errors::AiUnavailable, SmokeFixture::UNAVAILABLE_MESSAGE
      end

      private

      def build_model(name)
        case name
        when :onnx_smoke then build_smoke_model
        when :u2netp then build_u2netp_model
        when :birefnet then build_birefnet_model
        end
      end

      def build_smoke_model
        fixture = @smoke_fixture.default
        model = @model_factory.new(fixture.path, **SESSION_OPTIONS)

        unless normalize_ports(model.inputs) == [ fixture.input ] && normalize_ports(model.outputs) == [ fixture.output ]
          raise ImageLab::Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
        end

        model
      end

      def build_u2netp_model
        manifest = @u2netp_manifest_loader.call
        path = @u2netp_path || File.join(@u2netp_directory, manifest.onnx_filename)
        manifest.verify_artifact!(path:, kind: :onnx)
        model = @model_factory.new(path, **SESSION_OPTIONS)
        expected_input = { "name" => manifest.input_name, "type" => manifest.input_dtype, "shape" => manifest.input_shape }
        expected_output = { "name" => manifest.output_name, "type" => manifest.output_dtype, "shape" => manifest.output_shape }

        unless normalize_ports(model.inputs) == [ expected_input ] && normalize_ports(model.outputs) == [ expected_output ]
          raise ImageLab::Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
        end

        model
      end

      def build_birefnet_model
        manifest = @birefnet_manifest_loader.call
        path = @birefnet_path || File.join(@birefnet_directory, manifest.onnx_filename)
        manifest.verify_artifact!(path:)
        model = @model_factory.new(path, **BIREFNET_SESSION_OPTIONS)
        expected_input = { "name" => manifest.input_name, "type" => manifest.input_dtype, "shape" => manifest.input_shape }
        expected_output = { "name" => manifest.output_name, "type" => manifest.output_dtype, "shape" => manifest.output_shape }

        unless normalize_ports(model.inputs) == [ expected_input ] && normalize_ports(model.outputs) == [ expected_output ]
          raise ImageLab::Errors::AiUnavailable, BirefnetManifest::UNAVAILABLE_MESSAGE
        end

        model
      end

      def normalize_ports(ports)
        ports.map do |port|
          {
            "name" => port.fetch(:name).to_s,
            "type" => port.fetch(:type).to_s,
            "shape" => port.fetch(:shape)
          }
        end
      end
    end
  end
end
