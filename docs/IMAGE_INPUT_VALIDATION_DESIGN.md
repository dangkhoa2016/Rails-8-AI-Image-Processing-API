# Image input validation design (Phase 5)

## Purpose and scope

Phase 5 introduces `ImageLab::Input`, the single boundary that qualifies an
uploaded image before image processing. It replaces the Phase 4 controller's
direct upload decode path, so all accepted inputs have passed the same byte,
decode, format, dimension, pixel, and page checks.

This is an input-safety phase. It does not add a named image operation,
storage, background work, AI inference, a new route, or a new dependency.

## Components and data flow

`app/services/image_lab/input.rb` owns byte-bounded IO reading, Vips decode,
and image-property validation. Its public entry point accepts an uploaded IO
and returns a qualified Vips image without decoding it a second time:

```ruby
qualified = ImageLab::Input.call(upload)
qualified.image # Vips::Image
```

`app/services/image_lab/errors.rb` defines the domain errors raised by this
boundary:

```text
ImageLab::Errors::InvalidImage
ImageLab::Errors::UnsupportedFormat
ImageLab::Errors::UploadTooLarge
ImageLab::Errors::PixelLimitExceeded
```

`ImagesController#process_image` calls `ImageLab::Input` after its existing
authentication and `operations` validation. It then PNG-encodes
`qualified.image`, preserving the existing Phase 4 response headers and
success status. The controller rescues only these four domain exceptions and
returns the established single-key JSON error response with HTTP 422. It does
not turn programming, infrastructure, or unrelated Vips failures into client
validation errors.

## Input policy

The service validates actual decoded content. It never trusts the client
filename, filename extension, declared MIME type, or an upload object's
reported size.

It reads no more than `max_upload_bytes + 1` bytes from the upload IO. An empty
buffer or a Vips decoder error raises `InvalidImage`; a buffer larger than the
limit raises `UploadTooLarge`. The bounded buffer is the one passed to Vips,
so the service never reads an unbounded upload before validation.

Only decoded JPEG, PNG, and WebP images are accepted. Vips's actual loader or
decoded format metadata determines the classification. SVG, PDF, PS, EPS,
TIFF, GIF animation, AVIF, remote URLs, and every unrecognised decoder are
unsupported. An image with more than one page or frame is also unsupported,
including animated WebP or another allowed-looking container with multiple
pages.

For an accepted static format, the service rejects either dimension above the
configured maximum and rejects a width-times-height value above the configured
pixel maximum. A dimension or pixel failure raises `PixelLimitExceeded`.

## Configuration

These environment variables have the following initial defaults:

| Variable | Default | Meaning |
| --- | ---: | --- |
| `IMAGE_MAX_UPLOAD_BYTES` | `10485760` | Maximum bytes read from one upload (10 MiB). |
| `IMAGE_MAX_INPUT_PIXELS` | `25000000` | Maximum decoded width multiplied by height. |
| `IMAGE_MAX_DIMENSION` | `8192` | Maximum decoded width or height. |

The service allows explicit limit keyword arguments for unit tests. Production
calls use the environment values. These are safety guardrails, not throughput
or performance claims, and later benchmark work may revise them.

## HTTP behavior

No route changes are introduced. `GET /images/capabilities` continues to
report `operations: []`. `POST /images/process` continues to require Devise/JWT
authentication and `operations: []`; after Phase 5 it also requires a qualified
upload.

All Phase 5 input-policy failures return:

```json
{
  "error": "..."
}
```

with `422 Unprocessable Entity`. The exact error message may identify the
policy class, but clients must rely on the HTTP status and error field shape,
not internal Vips exception text.

## Test strategy

Service tests run before implementation and use real Vips data with tempfiles
or in-memory buffers, never Vips mocks. They cover valid JPEG, PNG, and WebP;
zero-byte content; truncated JPEG; an allowed image under a fake extension;
an unsupported decoded format; an image exceeding a dimension limit; an image
exceeding a pixel limit; and a multi-page/frame image when the installed Vips
runtime can create a deterministic fixture.

Controller integration tests prove an authenticated valid PNG still produces a
PNG response, while every domain error is rendered as JSON 422. Existing Phase
4 authentication, empty-operations, cache-control, and metadata guarantees
remain covered.

## Explicit non-goals

- Client filename, extension, and declared MIME matching are not policy inputs.
- No image transformation is added; the supported operations array remains
  empty.
- No upload persistence, Active Storage, database migration, job, queue, or
  remote URL download is added.
- No metadata stripping or EXIF orientation policy is added; those belong to a
  later dedicated phase.
- No benchmark is claimed for the initial limits.
