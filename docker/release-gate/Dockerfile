FROM ruby:3.3.12-slim@sha256:79f7a07363931fde1a5b312dee281fd62ddf56c33bdba0c2622af9b4621182fb

WORKDIR /workspace

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      jq \
      libpq-dev \
      libvips \
      pkg-config \
      python3 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV BUNDLE_FROZEN=true
ENV BUNDLE_PATH=/usr/local/bundle

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY docker/release-gate/entrypoint.sh /usr/local/bin/release-gate-entrypoint
RUN chmod +x /usr/local/bin/release-gate-entrypoint

ENTRYPOINT ["/usr/local/bin/release-gate-entrypoint"]
