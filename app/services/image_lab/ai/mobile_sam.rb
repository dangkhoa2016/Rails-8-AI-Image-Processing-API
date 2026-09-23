# frozen_string_literal: true

require "json"
require "vips"
require_relative "../errors"
require_relative "mobile_sam_manifest"
require_relative "model_registry"
require_relative "u2netp"
require_relative "mobile_sam/preprocessor"

module ImageLab
  module AI
    class MobileSam
      ENABLED_VALUES = %w[true false].freeze

      def self.enabled?
        value = ENV.fetch("IMAGE_AI_ENABLED", "false").downcase
        raise Errors::AiUnavailable, MobileSamManifest::UNAVAILABLE_MESSAGE unless ENABLED_VALUES.include?(value)
        value == "true"
      end

      def self.parse_prompt(value)
        prompt = JSON.parse(value.to_s)
        raise Errors::InvalidOperation, "prompt must be a JSON object" unless prompt.is_a?(Hash)
        prompt
      rescue JSON::ParserError, TypeError
        raise Errors::InvalidOperation, "prompt must be valid JSON"
      end

      def self.call(image, prompt:, manifest: MobileSamManifest.load!,
                    encoder: ModelRegistry.fetch!(:mobile_sam_encoder),
                    decoder: ModelRegistry.fetch!(:mobile_sam_decoder),
                    limiter: U2netp.default_limiter)
        raise Errors::AiUnavailable, MobileSamManifest::UNAVAILABLE_MESSAGE unless enabled?

        prep = Preprocessor.call(image, manifest:)
        decoder_prompt = normalize_prompt(prompt, prep)

        output = limiter.with_token do
          embedding = encoder.predict({ "image" => prep.tensor }).fetch("image_embeddings")
          ensure_shape!(embedding, [ 1, 256, 64, 64 ])

          decoder.predict({
            "image_embeddings" => embedding,
            "point_coords" => [ decoder_prompt.fetch(:coords) ],
            "point_labels" => [ decoder_prompt.fetch(:labels) ],
            "mask_input" => zero_mask,
            "has_mask_input" => [ 0.0 ],
            "orig_im_size" => [ prep.height.to_f, prep.width.to_f ]
          })
        end

        masks = output.fetch("masks")
        iou = output.fetch("iou_predictions")
        low_res = output.fetch("low_res_masks")
        ensure_finite!(masks, iou, low_res)
        ensure_shape!(masks, [ 1, 4, prep.height, prep.width ])
        ensure_shape!(low_res, [ 1, 4, 256, 256 ])
        ensure_shape!(iou, [ 1, 4 ])

        token = if decoder_prompt.fetch(:type) == "point"
          manifest.point_tokens.max_by { |index| iou.fetch(0).fetch(index) }
        else
          manifest.box_token
        end

        render_mask(masks.fetch(0).fetch(token), prep.width, prep.height, manifest.threshold)
      rescue Errors::InvalidOperation, Errors::AiUnavailable
        raise
      rescue KeyError, IndexError, Vips::Error, ArgumentError, TypeError, NoMethodError
        raise Errors::AiUnavailable, MobileSamManifest::UNAVAILABLE_MESSAGE
      end

      def self.normalize_prompt(prompt, prep)
        type = prompt["type"]
        case type
        when "point" then normalize_point(prompt, prep)
        when "box" then normalize_box(prompt, prep)
        else
          raise Errors::InvalidOperation, "prompt type must be point or box"
        end
      end
      private_class_method :normalize_prompt

      def self.normalize_point(prompt, prep)
        require_exact_keys!(prompt, %w[type x y label])
        x = finite_number!(prompt["x"], "x")
        y = finite_number!(prompt["y"], "y")
        label = prompt["label"]
        raise Errors::InvalidOperation, "point label must be 0 or 1" unless label.is_a?(Integer) && [ 0, 1 ].include?(label)
        validate_coordinate!(x, prep.width, "x")
        validate_coordinate!(y, prep.height, "y")

        {
          type: "point",
          coords: [ [ x * prep.resized_width.to_f / prep.width, y * prep.resized_height.to_f / prep.height ], [ 0.0, 0.0 ] ],
          labels: [ label.to_f, -1.0 ]
        }
      end
      private_class_method :normalize_point

      def self.normalize_box(prompt, prep)
        require_exact_keys!(prompt, %w[type x0 y0 x1 y1])
        x0 = finite_number!(prompt["x0"], "x0")
        y0 = finite_number!(prompt["y0"], "y0")
        x1 = finite_number!(prompt["x1"], "x1")
        y1 = finite_number!(prompt["y1"], "y1")
        validate_coordinate!(x0, prep.width, "x0")
        validate_coordinate!(x1, prep.width, "x1")
        validate_coordinate!(y0, prep.height, "y0")
        validate_coordinate!(y1, prep.height, "y1")
        raise Errors::InvalidOperation, "box coordinates must satisfy x0 < x1 and y0 < y1" unless x0 < x1 && y0 < y1

        {
          type: "box",
          coords: [
            [ x0 * prep.resized_width.to_f / prep.width, y0 * prep.resized_height.to_f / prep.height ],
            [ x1 * prep.resized_width.to_f / prep.width, y1 * prep.resized_height.to_f / prep.height ]
          ],
          labels: [ 2.0, 3.0 ]
        }
      end
      private_class_method :normalize_box

      def self.require_exact_keys!(prompt, keys)
        raise Errors::InvalidOperation, "prompt contains unsupported fields" unless prompt.keys.sort == keys.sort
      end
      private_class_method :require_exact_keys!

      def self.finite_number!(value, name)
        raise Errors::InvalidOperation, "#{name} must be a number" unless value.is_a?(Numeric)

        number = value.to_f
        raise Errors::InvalidOperation, "#{name} must be finite" unless number.finite?

        number
      end
      private_class_method :finite_number!

      def self.validate_coordinate!(value, bound, name)
        return if value >= 0.0 && value < bound
        raise Errors::InvalidOperation, "#{name} is outside image bounds"
      end
      private_class_method :validate_coordinate!

      def self.zero_mask
        @zero_mask ||= [ [ Array.new(256) { Array.new(256, 0.0) } ] ].freeze
      end
      private_class_method :zero_mask

      def self.ensure_shape!(value, expected)
        shape = []
        cursor = value
        while cursor.is_a?(Array)
          shape << cursor.length
          break if cursor.empty?
          cursor = cursor.first
        end
        raise Errors::AiUnavailable, MobileSamManifest::UNAVAILABLE_MESSAGE unless shape == expected
      end
      private_class_method :ensure_shape!

      def self.ensure_finite!(*values)
        values.each do |value|
          raise Errors::AiUnavailable, MobileSamManifest::UNAVAILABLE_MESSAGE unless value.flatten.all? { |item| item.to_f.finite? }
        end
      end
      private_class_method :ensure_finite!

      def self.render_mask(logits, width, height, threshold)
        raw = logits.flatten.pack("e*")
        image = Vips::Image.new_from_memory(raw, width, height, 1, "float")
        ((image > threshold) * 255).cast(:uchar).copy(interpretation: :b_w)
      end
      private_class_method :render_mask
    end
  end
end
