# U²-NetP model provenance

This repository records a reproducible, operator-run build path for the
upstream U²-NetP checkpoint. The internal Phase 17 service can load a verified
local ONNX artifact; it does **not** add an API endpoint, a job, GPU support,
or a model binary in Git. See [U²-NetP CPU inference and foreground
masks](U2NETP_INFERENCE.md) for the runtime boundary.

`config/models/u2netp.yml` is the checked-in source of truth. It records the
upstream revision, direct checkpoint URL, checksums and byte sizes, conversion
recipe, and the resulting static ONNX input/output contract. The checkpoint
and ONNX artifact are deliberately local-only under `var/models/`, which is
ignored by Git.

## Qualified inputs and output

| Item | Value |
| --- | --- |
| Upstream source | `https://github.com/xuebinqin/U-2-Net` at `ac7e1c817ecab7c7dff5ce6b1abba61cd213ff29` |
| Checkpoint | `u2netp.pth`, SHA-256 `e7567cde013fb64813973ce6e1ecc25a80c05c3ca7adbc5a54f3c3d90991b854`, 4,683,258 bytes |
| Converter | Python 3.11.9, PyTorch `2.2.2+cpu`, NumPy `1.26.4`, ONNX 1.16.2, opset 17 |
| ONNX candidate | SHA-256 `b9ef1a50fcc223bf630365f97e23e9abfba407a65f7d26e4b744b8eedbbbdaec`, 4,631,564 bytes |
| Input | `input`, `tensor(float)`, `[1, 3, 320, 320]` |
| Output | `d0`, `tensor(float)`, `[1, 1, 320, 320]` |
| Upstream license | Apache-2.0 |

The converter wraps the first U²-NetP output (`[0]`) so the exported model has
one stable output named `d0`. It uses CPU-only static NCHW export; no dynamic
axes or runtime selection is introduced.

## Operator workflow

Run qualification only in a controlled environment with Docker, network access
to the pinned upstream sources, and a Ruby environment that can load
`onnxruntime`:

```bash
script/models/qualify_u2netp --qualify
```

The `--qualify` command clones the pinned upstream revision, downloads the PTH into a
temporary directory, validates its byte size and SHA-256, builds the local
converter image, exports a temporary ONNX candidate, and validates the ONNX
ports with Ruby ONNX Runtime. It prints `onnx_sha256` and `onnx_file_size`; it
never edits the manifest or writes `var/models/`.

Review any newly printed values before manually changing the manifest. After
that review, run the normal install command:

```bash
script/models/qualify_u2netp
```

It repeats the pinned build, validates the candidate checksum and byte size
against the committed manifest, then atomically overwrites the ignored local
artifact at `var/models/u2netp.onnx`. It never changes the manifest.

Fetch the checksum-pinned upstream PTH atomically into the local ignored model
directory with:

```bash
script/models/fetch_u2netp
```

The fetcher downloads into a temporary sibling directory, validates the bytes
against the manifest, then renames the verified file to `var/models/u2netp.pth`.
It may overwrite a previous local copy so correction is possible; it never
changes the checked-in manifest.

## CI boundary

CI runs only local manifest and script tests. It does not execute qualification,
download U²-NetP weights, build the converter image, or write `var/models/`.
The inference service revalidates the local artifact at its boundary and keeps
failures behind the generic `AI model is unavailable` application error.
