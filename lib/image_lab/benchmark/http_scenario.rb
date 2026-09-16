# frozen_string_literal: true

require "json"
require "rack/test"
require "securerandom"
require "tempfile"
require Rails.root.join("lib/jwt_auth_header")

module ImageLab
  module Benchmark
    module HttpScenario
      module_function

      PASSWORD = "Password1!"

      def call(fixture:)
        session = ActionDispatch::Integration::Session.new(Rails.application)
        user = create_confirmed_benchmark_user
        token = sign_in_and_extract_bearer_token(session, user)
        scratch_directory = ImageLab::Input.default_temporary_directory
        before = scratch_entries(scratch_directory)
        client_upload = client_upload_for(fixture)

        session.post(
          "/images/process",
          params: { image: Rack::Test::UploadedFile.new(client_upload.path, content_type_for(fixture), true), operations: "[]" },
          headers: bearer_headers(token)
        )

        response_record(session.response, before == scratch_entries(scratch_directory))
      ensure
        client_upload&.close!
        user&.destroy!
      end

      def create_confirmed_benchmark_user
        suffix = SecureRandom.hex(7)
        User.create!(
          email: "benchmark-#{suffix}@example.local",
          username: "benchmark_#{suffix}",
          password: PASSWORD,
          password_confirmation: PASSWORD,
          confirmed_at: Time.current
        )
      end
      private_class_method :create_confirmed_benchmark_user

      def sign_in_and_extract_bearer_token(session, user)
        session.post(
          "/users/sign_in",
          params: { user: { email: user.email, password: PASSWORD } },
          as: :json
        )

        payload = JSON.parse(session.response.body)
        token = payload["token"]
        raise "benchmark sign-in failed with status #{session.response.status}" unless session.response.status == 200 && token.present?

        token
      end
      private_class_method :sign_in_and_extract_bearer_token

      def client_upload_for(fixture)
        tempfile = Tempfile.new([ "vips-benchmark-http", File.extname(fixture.path) ])
        tempfile.binmode
        IO.copy_stream(fixture.path, tempfile)
        tempfile.rewind
        tempfile
      end
      private_class_method :client_upload_for

      def content_type_for(fixture)
        fixture.format == "jpeg" ? "image/jpeg" : "image/#{fixture.format}"
      end
      private_class_method :content_type_for

      def bearer_headers(token)
        { "Accept" => "application/json", JwtAuthHeader.name => "Bearer #{token}" }
      end
      private_class_method :bearer_headers

      def response_record(response, tempfile_cleanup_pass)
        {
          "status" => response.status,
          "output_bytes" => response.body.bytesize,
          "output_width" => integer_header(response, "X-Image-Width"),
          "output_height" => integer_header(response, "X-Image-Height"),
          "tempfile_cleanup_pass" => tempfile_cleanup_pass
        }
      end
      private_class_method :response_record

      def integer_header(response, name)
        Integer(response.headers[name], 10)
      rescue ArgumentError, TypeError
        nil
      end
      private_class_method :integer_header

      def scratch_entries(directory)
        Dir.exist?(directory) ? Dir.children(directory).sort : []
      end
      private_class_method :scratch_entries
    end
  end
end
