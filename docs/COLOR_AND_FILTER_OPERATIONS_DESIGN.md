# Color and filter operations design (Phase 8)

## Purpose and scope

Phase 8 adds seven deterministic, non-AI editing operations to the existing
authenticated image pipeline. They are explicit registry entries; clients
cannot select arbitrary Vips methods or coefficients.

This phase adds no route, dependency, persistence, job, remote URL ingestion,
metadata/orientation policy, or AI runtime.

## Public operation contract

Every operation is a JSON object in the existing `operations` array. It accepts
only the keys listed below; an unknown field, a string in place of a JSON
number, a boolean, a non-finite number, or an out-of-range value is a domain
validation error and retains the existing JSON 422 response shape.

| operation | accepted fields | contract |
| --- | --- | --- |
| `brightness` | `amount` | finite JSON number from `-1.0` through `1.0`; `0` is unchanged |
| `contrast` | `amount` | finite JSON number from `-1.0` through `1.0`; `0` is unchanged |
| `saturation` | `amount` | finite JSON number from `-1.0` through `1.0`; `0` is unchanged |
| `tint` | `color`, `strength` | upper/lower case `#RRGGBB`; finite JSON number from `0.0` through `1.0` |
| `blur` | `sigma` | finite JSON number from `0.1` through `20.0` |
| `sharpen` | `amount` | finite JSON number from `0.0` through `1.0`; `0` is unchanged |
| `background` | `color` | upper/lower case `#RRGGBB`; requires an input with alpha |

`#RRGGBB` is normalized only internally. Shorthand hex, CSS names, `rgb(...)`,
and alpha hex are intentionally not accepted.

## Deterministic mappings

Brightness maps the public amount to a bounded byte-domain offset. Contrast
scales about the fixed 128 midpoint. Saturation uses a fixed sRGB-to-HSV-to-sRGB
conversion and scales the HSV saturation channel; `-1` removes chroma and `1`
increases it, subject to the output color range.

Tint performs a deterministic per-channel blend between sRGB pixels and the
validated RGB color. Blur uses the bounded Gaussian sigma. Sharpen maps the
single public amount onto a fixed, internal sharpen profile; Vips's remaining
sharpen options are never public request parameters.

Color transforms preserve an existing alpha band. `background` is the one
intentional alpha operation: it validates alpha is present, then flattens onto
the supplied opaque RGB color and returns a three-band sRGB image.

## Integration boundaries

The operation registry has exactly these additional controlled names:

```text
brightness
contrast
saturation
tint
blur
sharpen
background
```

Each operation is a focused class beneath `ImageLab::Operations`; a small
internal color helper parses hex and separates/rejoins alpha where necessary.
`ImageLab::Pipeline` continues to resolve the registry in request order and to
enforce the existing output-pixel limit after every operation. The controller
does not branch on image operation names.

## Test strategy

Tests use real, in-memory Vips images. They prove representative pixel changes
for brightness, contrast, saturation and tint; no-op boundaries and invalid
input; blur and sharpen behavior with bounded inputs; alpha-preserving tint;
and background flattening. Registry, pipeline and authenticated capabilities
tests prove that only the declared operations are exposed and executable.
