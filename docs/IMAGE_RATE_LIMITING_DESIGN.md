# Image-processing rate limiting

## Purpose

`POST /images/process` performs bounded but CPU-intensive image decoding,
transformation, and encoding. This policy places a request-level guard in
front of that work without changing authentication or the processing contract.

## Policy

Rack::Attack allows 30 image-processing requests per 60 seconds per request
IP address. The 31st request in that window receives the established JSON
`429 Too Many Requests` response and its `Retry-After` header.

The key is `req.ip`, using the source project's existing Rack::Attack and
proxy/IP handling. It does not trust a client-supplied forwarding header and
does not parse a JWT in rate-limiting middleware. Rack::Attack runs before the
controller authentication boundary, so an IP-plus-user key would require a
separate, explicitly designed authentication-aware limit in a later phase.

`GET /images/capabilities` is not an expensive processing workload and is not
covered by this throttle. The existing `/up` safelist, auth throttles, and
global API ceiling remain unchanged.

## Verification

The integration tests submit authenticated multipart PNG requests through the
real Rack middleware. They prove that 30 requests pass, the next receives
`429` with `Retry-After`, a distinct IP remains independent, and an exhausted
image-processing budget does not throttle `/up` or sign-in.

## Tuning

Thirty requests per minute is the initial pre-benchmark policy from the
project plan. Phase 12 benchmark evidence must inform any production tuning;
AI workloads will receive their own stricter policy when introduced.
