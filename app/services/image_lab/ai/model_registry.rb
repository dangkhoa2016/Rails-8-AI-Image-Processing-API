# frozen_string_literal: true

require_relative "birefnet_manifest"
require_relative "mobile_sam_manifest"
require_relative "u2netp_manifest"

module ImageLab
  module AI
    class ModelRegistry
      SUPPORTED_MODELS = [ :onnx_smoke, :u2netp, :birefnet, :mobile_sam_encoder, :mobile_sam_decoder ].freeze
      U2NETP_DIRECTORY = Rails.root.join("var/models").freeze
      BIREFNET_DIRECTORY = Rails.root.join("var/models").freeze
      MOBILE_SAM_DIRECTORY = Rails.root.join("var/models").freeze
      SESSION_OPTIONS = {
        execution_mode: :sequential,
        inter_op_num_threads: 1,
        intra_op_num_threads: 1
      }.freeze
      BIREFNET_SESSION_OPTIONS = SESSION_OPTIONS.merge(enable_cpu_mem_arena: false).freeze
      MOBILE_SAM_SESSION_OPTIONS = BIREFNET_SESSION_OPTIONS

      def self.fetch!(name)
        @default ||= new
        @default.fetch!(name)
      end

      def initialize(model_factory: OnnxRuntime::Model, smoke_fixture: SmokeFixture, u2netp_manifest_loader: -> { U2netpManifest.load! }, u2netp_directory: U2NETP_DIRECTORY, u2netp_path: nil, birefnet_manifest_loader: -> { BirefnetManifest.load! }, birefnet_directory: BIREFNET_DIRECTORY, birefnet_path: nil, mobile_sam_manifest_loader: -> { MobileSamManifest.load! }, mobile_sam_directory: MOBILE_SAM_DIRECTORY, mobile_sam_encoder_path: nil, mobile_sam_decoder_path: nil)
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
        @mobile_sam_manifest_loader = mobile_sam_manifest_loader
        @mobile_sam_directory = mobile_sam_directory.to_s
        @mobile_sam_encoder_path = mobile_sam_encoder_path&.to_s
        @mobile_sam_decoder_path = mobile_sam_decoder_path&.to_s
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
        when :mobile_sam_encoder then build_mobile_sam_model(:encoder)
        when :mobile_sam_decoder then build_mobile_sam_model(:decoder)
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

      def build_mobile_sam_model(kind)
        manifest = @mobile_sam_manifest_loader.call
        declaration = manifest.artifact(kind)
        path = case kind
        when :encoder then @mobile_sam_encoder_path
        when :decoder then @mobile_sam_decoder_path
        end
        path ||= File.join(@mobile_sam_directory, declaration.fetch("filename"))
        manifest.verify_artifact!(path:, kind:)
        model = @model_factory.new(path, **MOBILE_SAM_SESSION_OPTIONS)

        expected_inputs = if kind == :encoder
          [ port(declaration.fetch("input")) ]
        else
          declaration.fetch("inputs").map { |item| port(item) }
        end
        expected_outputs = if kind == :encoder
          [ port(declaration.fetch("output")) ]
        else
          declaration.fetch("outputs").map { |item| port(item) }
        end

        unless normalize_ports(model.inputs) == expected_inputs && normalize_ports(model.outputs) == expected_outputs
          raise ImageLab::Errors::AiUnavailable, MobileSamManifest::UNAVAILABLE_MESSAGE
        end

        model
      end

      def port(value)
        { "name" => value.fetch("name"), "type" => value.fetch("dtype"), "shape" => value.fetch("shape") }
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
