# Deterministic image operations design (Phase 7)

## Purpose and scope

Phase 7 makes the authenticated image endpoint useful without AI. It adds an
explicit Vips pipeline, six deterministic transforms, and the output settings
reserved by Phase 4.

It does not add persistence, Active Storage, routes, jobs, queues, remote URL
ingestion, arbitrary Vips invocation, arbitrary-angle rotation, AI inference,
color filters, metadata/orientation policy, or a new gem.

## Request and pipeline model

`POST /images/process` remains authenticated multipart form data. Its required
`operations` JSON value now holds flat operation objects:

```json
[
  { "op": "resize_to_fit", "width": 800, "height": 600 },
  { "op": "rotate", "degrees": 90 }
]
```

The controller performs this fixed order:

```text
authenticated multipart upload
  -> ImageLab::Input qualification
  -> ImageLab::OperationRegistry validation and resolution
  -> ImageLab::Pipeline ordered transforms
  -> output-pixel check after every transform
  -> explicit output encoding
  -> image response
```

`ImageLab::Pipeline.call(image, operations)` applies operation classes in
request order and returns the final Vips image. Classes receive only a Vips
image and one operation Hash; they do not read controller parameters, encode,
persist, or send HTTP responses.

After this phase, the registry has exactly these controlled public names:

```text
resize_to_fit
resize_to_fill
crop
rotate
flip
grayscale
```

`GET /images/capabilities` derives this list from the registry. The existing
maximum operation count remains 16 by default. No client string is ever used
with `send`, `public_send`, `constantize`, or dynamic dispatch.

## Transform contracts

All transform parameters live beside `op`. JSON number parameters must decode
as integers, never strings, floats, booleans, null, arrays, or objects.
Invalid parameters are domain errors and receive the existing JSON HTTP 422
shape.

### Resize

`resize_to_fit` and `resize_to_fill` require integer `width` and `height`,
both greater than zero and no larger than `IMAGE_MAX_DIMENSION` (default 8192).
Upscaling is allowed only when the result passes the output-pixel guardrail.

`resize_to_fit` preserves aspect ratio inside the requested bounding box, so
its final dimensions can be smaller than a requested dimension.
`resize_to_fill` preserves aspect ratio, covers the requested rectangle, and
uses deterministic center crop; its final dimensions exactly equal the request.

### Crop

`crop` requires integer `left`, `top`, `width`, and `height`. Coordinates are
non-negative; dimensions are positive; and the rectangle must be within the
current pipeline image:

```text
left + width <= image.width
top + height <= image.height
```

Ruby integer arithmetic prevents overflow wrapping for huge JSON integers.
Center, percentage, and aspect-ratio crop modes are later work.

### Rotate, flip, and grayscale

`rotate` requires exactly integer `degrees: 90`, `180`, or `270`.
`flip` requires exactly `mode: "horizontal"` or `"vertical"`.
`grayscale` accepts no keys other than `op` and produces intentional one-band
gray output. Extra grayscale fields are invalid, not silently ignored.

## Output limit and error policy

`IMAGE_MAX_OUTPUT_PIXELS` defaults to `25_000_000`. The pipeline checks
`width * height` after every transform, rejecting an oversized intermediate or
final image before encoding. Missing, blank, non-numeric, or non-positive
configuration uses the safe default.

Domain errors distinguish invalid operation input, unsupported operation names,
operation count, and output size. The controller maps only these known errors,
plus existing input errors, to `{ "error": "..." }` with HTTP 422. Unexpected
Ruby, Vips, database, or infrastructure errors are not presented as client
validation failures.

## Output encoding and response contract

Output encoding uses top-level multipart fields, not an operation:

```text
format: optional; png (default), jpeg, or webp
quality: optional; whole integer 1..100, only for jpeg or webp
```

`format` must be one exact lower-case value. `quality` may be a multipart
decimal string or a programmatic integer; it is normalized to an integer from
1 through 100. Providing quality for PNG is invalid rather than silently
ignored. JPEG and WebP default to quality 85 when omitted.

Encoding runs once after all transforms. The internal encoder is not an
advertised registry operation and cannot appear between transforms.

| format | Content-Type | `X-Image-Format` |
| --- | --- | --- |
| png | `image/png` | `png` |
| jpeg | `image/jpeg` | `jpeg` |
| webp | `image/webp` | `webp` |

Successful responses retain `Cache-Control: no-store`, final width, final
height, and processing-time headers.

## Implementation boundaries

- `app/services/image_lab/pipeline.rb` orchestrates resolved transforms and
  output-pixel checks.
- `app/services/image_lab/operation_registry.rb` explicitly maps the six names
  to concrete classes and retains general request validation.
- `app/services/image_lab/operations/` contains one focused class per
  transform plus the internal encoder.
- `ImagesController` parses output settings, invokes pipeline and encoder, and
  emits the response. It contains no Vips transform branching.

## Test strategy

Tests are written before production code with real in-memory Vips images and
no Vips mocks. Focused tests cover portrait, landscape, and square resize;
exact fill dimensions; crop boundaries; every allowed rotation; both flips;
one-band grayscale; operation ordering; output-pixel rejection; PNG/JPEG/WebP
bytes; quality bounds; and invalid output settings.

Authenticated controller tests cover a qualified upload through ordered
operations, capabilities, all output MIME types, response metadata, and JSON
422 mapping. The complete Rails suite runs on the branch and again on merged
`main`.

## Explicit non-goals

- No arbitrary Vips method or class invocation.
- No arbitrary-angle rotation, color/filter operation, metadata stripping, or
  orientation normalization.
- No asynchronous operation execution, persistence, remote source, AI model,
  dependency, or route change.
