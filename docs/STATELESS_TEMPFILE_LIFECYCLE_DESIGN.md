# Stateless temporary-file lifecycle design

## Goal

Image processing uses a short-lived application-owned source file without
adding persistent media storage.

## Lifecycle

`ImagesController#process_image` calls `ImageLab::Input.with_image` and keeps
the entire Vips pipeline, encoder, and `send_data` call inside its block.

1. `ImageLab::Input` reads the bounded upload and rejects a missing, empty, or
   over-limit body before decoding.
2. A binary `Tempfile` with a generated name is created in
   `Rails.root/tmp/image_lab`; no client filename contributes to its path.
3. Vips decodes that file, qualifies it, and runs orientation normalization.
4. The controller transforms it and keeps the encoded response as its existing
   in-memory buffer.
5. The block's `ensure` closes and unlinks the source tempfile on success,
   validation failure after file creation, decoder failure, or an exception
   raised by downstream processing.

The result remains a `send_data` buffer, so Rails does not retain a response
that depends on a deleted file.

## Scope limits

This phase creates no `images` table, Active Storage attachment, durable media
directory, or background job. `tmp/image_lab` is an application runtime
scratch directory only; each generated file is removed before the request
finishes.

## Test coverage

Real Vips input tests observe a generated app-owned file during the processing
block and assert that the directory is empty after normal completion, invalid
input/decode errors, and a downstream exception.
