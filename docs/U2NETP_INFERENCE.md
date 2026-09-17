# U²-NetP CPU inference and foreground masks

`ImageLab::AI::U2netp.call(vips_image)` is an internal service. It returns an
`ImageLab::AI::Mask`; `mask.image` is a continuous, one-band `float`
`Vips::Image` at the input image dimensions. This service has no HTTP endpoint,
does not compose an alpha image, and does not remove a background by itself.
Those application behaviors begin in Phase 18.

## Runtime contract

The service performs Ruby/Vips preprocessing, ONNX Runtime CPU inference, and
mask postprocessing in one process. The model is lazy-loaded once per
`ImageLab::AI::ModelRegistry` instance. Before it is opened, the service checks
ignored local `var/models/u2netp.onnx` against `config/models/u2netp.yml` for
its declared filename, byte size, and SHA-256, then checks the exact ONNX port
contract:

| Port | Type | Shape |
| --- | --- | --- |
| `input` | `tensor(float)` | `[1, 3, 320, 320]` |
| `d0` | `tensor(float)` | `[1, 1, 320, 320]` |

It never downloads or converts a model. A missing, invalid, corrupt, or
incompatible artifact, malformed output, Vips failure, or ONNX failure returns
only `AI model is unavailable` at this boundary.

The `d0` values must be finite. They are globally min-max normalized into
`0.0..1.0`; a constant output becomes an all-zero mask to avoid division by
zero and conservatively select no foreground. The 320 × 320 mask is resized
linearly to the source dimensions and clamped to the same range. Thresholding,
feathering, and compositing are intentionally absent.

## CPU concurrency

`IMAGE_AI_MAX_CONCURRENCY` is a positive integer and defaults to `1`. It limits
only ONNX `predict` calls per process; preprocessing and Vips mask creation are
not serialized. ONNX Runtime remains in sequential mode with one inter-op and
one intra-op thread. Do not tune these defaults from CPU count alone; benchmark
concurrency values 1, 2, and 4 first.

## Optional local operator smoke check

In a controlled environment with Docker and upstream network access, install a
fresh ignored artifact through the existing qualification workflow:

```bash
script/models/qualify_u2netp
bundle exec rails runner '
  pixels = Array.new(12) { |index| [100, 150, 200][index % 3] }
  image = Vips::Image.new_from_memory(pixels.pack("C*"), 2, 2, 3, :uchar).copy(interpretation: :srgb)
  mask = ImageLab::AI::U2netp.call(image).image
  values = mask.write_to_memory.unpack("f*")
  puts({ width: mask.width, height: mask.height, bands: mask.bands, format: mask.format, min: values.min, max: values.max }.to_json)
'
```

The runner should print a two-by-two, one-band `float` mask whose extrema are
in `0.0..1.0`. This is a local acceptance check, not CI. Do not commit the
artifact; remove only the exact ignored `var/models/u2netp.onnx` file after
recording the result if it is no longer needed.

## CI boundary

CI tests registry, tensor serialization, concurrency, output validation, and
Vips mask behavior with deterministic fake ONNX sessions. It does not qualify a
model, download weights, write `var/models/`, or run a model binary.
