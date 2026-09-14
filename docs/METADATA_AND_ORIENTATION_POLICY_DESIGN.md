# Metadata and orientation policy design

## Goal

Image output is privacy-safe and visually predictable. The public API never
returns upload metadata in Phase 9.

## Fixed processing order

`ImageLab::Input` verifies the decoded loader and page count, then applies
libvips `autorot` before dimension and pixel checks. This honors the input's
EXIF orientation and removes the EXIF orientation tag from the working image.

The ordered image-operation pipeline remains unchanged. The final encoder
always writes PNG, JPEG, and WebP with libvips `strip`, so the response has no
EXIF, GPS, camera/device, serial, thumbnail, author, comment, ICC, or
orientation metadata carried over from the upload.

## Public contract

There is no `preserve_metadata` option. Supplying an unknown request parameter
cannot opt out of stripping; output metadata removal is unconditional.

## Test coverage

The test suite embeds a real JPEG fixture containing EXIF orientation `6` and
GPS coordinates. It proves that decoding produces the correctly rotated pixel
layout, the final API JPEG has the normalized dimensions, and every supported
output encoder removes EXIF, GPS, orientation, and comment fields.
