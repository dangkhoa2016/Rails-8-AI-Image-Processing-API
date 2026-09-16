FROM ruby:3.3.12-slim@sha256:79f7a07363931fde1a5b312dee281fd62ddf56c33bdba0c2622af9b4621182fb

WORKDIR /workspace

# Historical snapshot access: apt requires check-valid-until=no because the
# frozen snapshot release files have already passed their normal expiry window.
RUN printf 'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260915T000000Z/ trixie main\n' > /etc/apt/sources.list.d/snapshot.list && \
    rm -f /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential=12.12 \
      curl=8.14.1-2+deb13u5 \
      git=1:2.47.3-0+deb13u1 \
      jq=1.7.1-6+deb13u3 \
      libpq-dev=17.11-0+deb13u1 \
      libvips42t64=8.16.1-1+deb13u1 \
      pkg-config=1.8.1-4 \
      python3=3.13.5-1 \
      unzip=6.0-29+deb13u1 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV BUNDLE_FROZEN=true
ENV BUNDLE_PATH=/usr/local/bundle

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY docker/release-gate/entrypoint.sh /usr/local/bin/release-gate-entrypoint
RUN chmod +x /usr/local/bin/release-gate-entrypoint

ENTRYPOINT ["/usr/local/bin/release-gate-entrypoint"]
