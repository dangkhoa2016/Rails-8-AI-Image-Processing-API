# Image processing HTTP contract (v1)

## Purpose and scope

This document defines the authenticated HTTP boundary for deterministic image
processing. Phase 4 established the boundary; Phases 5 through 8 added
qualified input handling and the currently available transforms.

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
  "operations": [
    "resize_to_fit", "resize_to_fill", "crop", "rotate", "flip", "grayscale",
    "brightness", "contrast", "saturation", "tint", "blur", "sharpen", "background"
  ],
  "request_content_type": "multipart/form-data",
  "response_content_type": "image/png"
}
```

The endpoint derives this list from the explicit registry and must not advertise
another operation.

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

### Color and filter operations

The following Phase 8 operation objects are accepted in the ordered
`operations` array. Each object must contain exactly the listed fields; JSON
number values must be finite numbers, not strings or booleans.

| Operation | Fields | Bounds |
| --- | --- | --- |
| `brightness`, `contrast`, `saturation` | `amount` | `-1.0..1.0`; zero is unchanged |
| `tint` | `color`, `strength` | strict `#RRGGBB`; `strength` `0.0..1.0` |
| `blur` | `sigma` | `0.1..20.0` |
| `sharpen` | `amount` | `0.0..1.0`; zero is unchanged |
| `background` | `color` | strict `#RRGGBB`; input must have alpha |

Brightness, contrast, saturation and tint preserve an existing alpha channel.
For a non-zero color adjustment, color data is converted to sRGB before the
mapping is applied; `amount: 0` for brightness, contrast, or saturation returns
the input representation unchanged. `background` is intentional alpha
composition: it flattens the image onto the opaque RGB color and always returns
three-band sRGB output. The implementation exposes no raw Vips method,
coefficient, color-name, shorthand hex, or CSS-color parameter.

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

Missing `image`, a missing or malformed `operations` value, an unsupported
operation, invalid operation parameter, invalid output setting, or qualified
input that violates byte/format/decode/dimension/pixel guards returns `422
Unprocessable Entity`.

## Test contract

`test/controllers/images_controller_test.rb` proves the boundary with real
in-memory PNG bytes and no mocks:

1. unauthenticated capability and process requests return `401`;
2. authenticated invalid input and malformed/unsupported operations return `422`;
3. a tiny PNG processed with a registered color operation returns transformed
   PNG bytes, `Cache-Control: no-store`, and the declared metadata headers;
4. capabilities returns exactly the explicit registry set.

## Explicit non-goals

This API does not persist uploads/results, enqueue work, expose public
capabilities, accept remote image URLs, expose arbitrary Vips invocation, apply
metadata/orientation policy, or add AI inference. Those responsibilities belong
to later phases.
