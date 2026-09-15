# frozen_string_literal: true

module ImageLab
  module AI
    class ModelRegistry
      SUPPORTED_MODELS = [ :onnx_smoke ].freeze
      SESSION_OPTIONS = {
        execution_mode: :sequential,
        inter_op_num_threads: 1,
        intra_op_num_threads: 1
      }.freeze

      def self.fetch!(name)
        @default ||= new
        @default.fetch!(name)
      end

      def initialize
        @models = {}
        @mutex = Mutex.new
      end

      def fetch!(name)
        raise ImageLab::Errors::AiUnavailable, SmokeFixture::UNAVAILABLE_MESSAGE unless SUPPORTED_MODELS.include?(name.to_sym)

        @mutex.synchronize do
          @models[:onnx_smoke] ||= build_smoke_model
        end
      rescue ImageLab::Errors::AiUnavailable
        raise
      rescue StandardError
        raise ImageLab::Errors::AiUnavailable, SmokeFixture::UNAVAILABLE_MESSAGE
      end

      private

      def build_smoke_model
        fixture = SmokeFixture.default
        model = OnnxRuntime::Model.new(fixture.path, **SESSION_OPTIONS)

        unless normalize_ports(model.inputs) == [ fixture.input ] && normalize_ports(model.outputs) == [ fixture.output ]
          raise ImageLab::Errors::AiUnavailable, SmokeFixture::UNAVAILABLE_MESSAGE
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
