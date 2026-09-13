# frozen_string_literal: true

module ImageLab
  module Operations
    module Color
      def self.split_alpha(image)
        return [ image, nil ] unless image.has_alpha?

        [ image.extract_band(0, n: image.bands - 1), image.extract_band(image.bands - 1) ]
      end

      def self.join_alpha(image, alpha)
        alpha.nil? ? image : image.bandjoin(alpha)
      end

      def self.srgb(image)
        image.colourspace(:srgb)
      end
    end
  end
end
