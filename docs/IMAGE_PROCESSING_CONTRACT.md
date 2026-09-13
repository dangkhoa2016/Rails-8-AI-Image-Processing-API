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

`operations` is intentionally empty in Phase 4. The endpoint must not advertise
`resize_to_fit`, `rotate`, or another operation until that operation is implemented
and qualified.

### `POST /images/process`

The request uses `multipart/form-data` and reserves these fields:

| Field | Phase 4 behavior |
| --- | --- |
| `image` | Required uploaded image. |
| `operations` | Required JSON array. Only `[]` is accepted in Phase 4. |
| `format` | Reserved for a future output choice; current output is always PNG. |
| `quality` | Reserved for a future output-quality choice; it has no Phase 4 output effect. |

A valid Phase 4 request supplies an uploaded image and `operations: []`. The
endpoint decodes the image in memory with Vips and returns PNG bytes. This is a
contract smoke path, not an input-validation or transformation pipeline.

Successful responses have:

```text
HTTP 200
Content-Type: image/png
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
