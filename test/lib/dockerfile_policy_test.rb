# frozen_string_literal: true

require "test_helper"

class DockerfilePolicyTest < ActiveSupport::TestCase
  test "copies the committed lockfile before bundle install" do
    dockerfile = Rails.root.join("Dockerfile").read
    copy_position = dockerfile.index("COPY Gemfile Gemfile.lock ./")
    bundle_position = dockerfile.index("RUN bundle install")

    refute_nil copy_position
    refute_nil bundle_position
    assert_operator copy_position, :<, bundle_position
  end

  test "uses the documented default Ruby" do
    assert_includes Rails.root.join("Dockerfile").read, "ARG RUBY_VERSION=3.3"
  end

  test "installs PostgreSQL runtime and build libraries" do
    dockerfile = Rails.root.join("Dockerfile").read

    assert_includes dockerfile, "libpq5"
    assert_includes dockerfile, "libpq-dev"
    refute_match(/apt-get install.*\bsqlite3\b/, dockerfile)
    assert_includes dockerfile, 'ENV BUNDLE_DEPLOYMENT="1"'
  end
end
