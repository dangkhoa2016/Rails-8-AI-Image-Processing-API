# ONNX Runtime feasibility spike

## Purpose and boundary

This is a narrow CPU-only integration spike. It establishes that the Ruby
application can lazily load a tiny ONNX model, run one deterministic inference,
and reuse that model safely within one process. It is not an image-processing
feature or a production qualification.

The implementation is deliberately limited to `onnx_smoke` in
`ImageLab::AI::ModelRegistry`. The registry has a process-local mutex and uses
sequential execution with one inter-op and one intra-op thread. No route,
controller, job, user input, model download, GPU configuration, Python
service, or production AI operation is introduced.

## Test fixture provenance

The only ONNX artifact is the test fixture
`test/fixtures/files/onnx/sigmoid.onnx`:

- Upstream source: <https://raw.githubusercontent.com/onnx/onnx/v1.22.0/onnx/backend/test/data/node/test_sigmoid/model.onnx>
- Upstream revision: `v1.22.0`
- License: Apache-2.0
- SHA-256: `c9ea45be3dd00fd43865a739458c74c1f7c7fd325faf8294009f43ae9c0628dd`
- Size: 105 bytes
- Contract: input `x` and output `y`, both `tensor(float)` with shape
  `[3, 4, 5]`; zero input must produce sigmoid output near `0.5`.

`ImageLab::AI::SmokeFixture` verifies the manifest, byte size, and SHA-256
before the native session is created. A changed or missing fixture becomes the
generic `ImageLab::Errors::AiUnavailable` error instead of being loaded.

## How it is verified

The focused test is:

```bash
bin/rails test test/services/image_lab/ai/model_registry_test.rb
```

CI runs that test before the complete suite for Ruby 3.2, 3.3, and 4.0. The
release acceptance record records the observed matrix and canonical Docker
results once they have been executed.
