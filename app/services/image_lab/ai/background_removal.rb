# frozen_string_literal: true

require "vips"
require_relative "../errors"
require_relative "../operations/color"
require_relative "birefnet"
require_relative "u2netp"

module ImageLab
  module AI
    class BackgroundRemoval
      MAX_FEATHER = 20
      ENABLED_VALUES = %w[true false].freeze

      def self.enabled?
        value = ENV.fetch("IMAGE_AI_ENABLED", "false").downcase
        raise Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE unless ENABLED_VALUES.include?(value)

        value == "true"
      end

      def self.call(image, background: nil, feather: 0, mask_provider: Birefnet)
        raise Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE unless enabled?

        feather = normalize_feather(feather)
        mask = mask_provider.call(image).image
        mask = mask.gaussblur(feather) if feather.positive?
        mask = clamp(mask)

        color, existing_alpha = Operations::Color.split_alpha(image)
        rgb = Operations::Color.srgb(color)
        alpha = mask.cast(:float)
        alpha *= normalize_existing_alpha(existing_alpha) if existing_alpha
        alpha = (alpha * 255.0).cast(:uchar)
        rgba = rgb.bandjoin(alpha).copy(interpretation: :srgb)

        return rgba if background.nil? || background.to_s.empty?

        rgba.flatten(background: parse_background(background))
      rescue Errors::InvalidOperation, Errors::AiUnavailable
        raise
      rescue Vips::Error, ArgumentError, TypeError, NoMethodError
        raise Errors::AiUnavailable, U2netpManifest::UNAVAILABLE_MESSAGE
      end

      def self.normalize_feather(value)
        value = 0 if value.nil?
        value = Integer(value, 10) unless value.is_a?(Integer)
        unless value.between?(0, MAX_FEATHER)
          raise Errors::InvalidOperation, "feather must be an integer from 0 to #{MAX_FEATHER}"
        end

        value
      rescue ArgumentError, TypeError
        raise Errors::InvalidOperation, "feather must be an integer from 0 to #{MAX_FEATHER}"
      end
      private_class_method :normalize_feather

      def self.parse_background(value)
        match = /\A#([0-9a-fA-F]{6})\z/.match(value.to_s)
        raise Errors::InvalidOperation, "background must use #RRGGBB" unless match

        match[1].scan(/../).map { |component| component.to_i(16) }
      end
      private_class_method :parse_background

      def self.normalize_existing_alpha(alpha)
        scale = case alpha.format
        when :uchar then 255.0
        when :ushort then 65_535.0
        when :char then 127.0
        when :short then 32_767.0
        else 1.0
        end
        alpha.cast(:float) / scale
      end
      private_class_method :normalize_existing_alpha

      def self.clamp(image)
        lower = (image < 0.0).ifthenelse(0.0, image)
        (lower > 1.0).ifthenelse(1.0, lower)
      end
      private_class_method :clamp
    end
  end
end
