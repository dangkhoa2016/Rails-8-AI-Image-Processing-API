# frozen_string_literal: true

require_relative "u2netp_manifest"

module ImageLab
  module AI
    class ModelRegistry
      SUPPORTED_MODELS = [ :onnx_smoke, :u2netp ].freeze
      U2NETP_DIRECTORY = Rails.root.join("var/models").freeze
      SESSION_OPTIONS = {
        execution_mode: :sequential,
        inter_op_num_threads: 1,
        intra_op_num_threads: 1
      }.freeze

      def self.fetch!(name)
        @default ||= new
        @default.fetch!(name)
      end

      def initialize(model_factory: OnnxRuntime::Model, smoke_fixture: SmokeFixture, u2netp_manifest_loader: -> { U2netpManifest.load! }, u2netp_directory: U2NETP_DIRECTORY, u2netp_path: nil)
        @models = {}
        @mutex = Mutex.new
        @model_factory = model_factory
        @smoke_fixture = smoke_fixture
        @u2netp_manifest_loader = u2netp_manifest_loader
        @u2netp_directory = u2netp_directory.to_s
        @u2netp_path = u2netp_path&.to_s
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
        name == :onnx_smoke ? build_smoke_model : build_u2netp_model
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
