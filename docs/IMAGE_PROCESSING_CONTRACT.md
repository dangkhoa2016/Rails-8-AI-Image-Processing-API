# Image processing HTTP contract (Phase 4)

## Purpose and scope

This document defines the first authenticated HTTP boundary for image processing.
It deliberately establishes the request and response contract before Phase 5 adds
central input validation and before later phases add transformation operations.

The contract is version `v1`. It does not add API keys, public access, upload
persistence, background jobs, or AI functionality.

## Authentication

Both endpoints require the project's existing Devise/JWT authentication. An
unauthenticated request receives the established JSON unauthorized response.

## Endpoints

### `GET /images/capabilities`

Returns the capabilities that are actually available at the time of the request:

```json
{
  "version": "v1",
  "operations": [],
  "request_content_type": "multipart/form-data",
  "response_content_type": "image/png"
}
```

The current implemented operations are `resize_to_fit`, `resize_to_fill`,
`crop`, `rotate`, `flip`, and `grayscale`. The endpoint derives this list from
the explicit registry and must not advertise another operation.

### `POST /images/process`

The request uses `multipart/form-data` and reserves these fields:

| Field | Phase 4 behavior |
| --- | --- |
| `image` | Required uploaded image. |
| `operations` | Required JSON array of flat operation objects, applied in order. |
| `format` | Optional exact lower-case `png` (default), `jpeg`, or `webp`. |
| `quality` | Optional integer `1..100` for JPEG/WebP; defaults to 85 and is invalid for PNG. |

A valid request supplies a qualified uploaded image and operations that the
registry supports. The endpoint decodes and transforms in memory with Vips,
then encodes the selected output format.

Successful responses have:

```text
HTTP 200
Content-Type: image/png, image/jpeg, or image/webp
Cache-Control: no-store
```

They also include these response metadata headers:

```text
X-Image-Width
X-Image-Height
X-Image-Format
X-Processing-Time-Ms
```

## Errors

Contract errors return a single JSON error field:

```json
{
  "error": "..."
}
```

Missing `image`, a missing or malformed `operations` value, and a non-empty
operations array return `422 Unprocessable Entity`. Detailed file limits, format
allowlists, pixel limits, and decoder-safety rules are intentionally deferred to
`ImageLab::Input` in Phase 5.

## Test contract

`test/controllers/images_controller_test.rb` proves the boundary with real
in-memory PNG bytes and no mocks:

1. unauthenticated capability and process requests return `401`;
2. authenticated process request without `image` returns `422` and `error`;
3. malformed `operations` returns `422` and `error`;
4. a tiny PNG with `operations: []` returns PNG bytes, `Cache-Control: no-store`,
   and the declared metadata headers;
5. capabilities returns version `v1` and an empty operations list.

## Explicit non-goals

This phase does not validate upload sizes or content policy, implement named image
operations, persist uploads/results, enqueue work, expose public capabilities, or
add AI inference. Those responsibilities belong to later phases.
