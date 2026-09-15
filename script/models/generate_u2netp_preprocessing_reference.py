#!/usr/bin/env python3
"""Generate compact pinned-reference samples for U2NetP preprocessing."""

import argparse
from pathlib import Path
from tempfile import NamedTemporaryFile


UPSTREAM_REPOSITORY = "https://github.com/xuebinqin/U-2-Net"
UPSTREAM_REVISION = "ac7e1c817ecab7c7dff5ce6b1abba61cd213ff29"
SOURCE_FORMULA = "(row * 5 + column * 3 + channel * 17) % 256"
SAMPLE_INDICES = (
    (0, 0, 0, 0),
    (0, 1, 17, 31),
    (0, 2, 159, 159),
    (0, 0, 319, 319),
    (0, 2, 319, 0),
)


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    if arguments.output is None:
        parser.error("the following arguments are required: --output")

    return arguments


def yaml_content(tensor, numpy_version, skimage_version):
    lines = [
        f"upstream_repository: {UPSTREAM_REPOSITORY}",
        f"upstream_revision: {UPSTREAM_REVISION}",
        'python: "3.11.9"',
        f'numpy: "{numpy_version}"',
        f'scikit_image: "{skimage_version}"',
        f'source_formula: "{SOURCE_FORMULA}"',
        "source_shape: [320, 320, 3]",
        "tensor_shape: [1, 3, 320, 320]",
        "samples:",
    ]
    for index in SAMPLE_INDICES:
        lines.extend(
            (
                f"  - index: [{', '.join(map(str, index))}]",
                f"    value: {float(tensor[index])!r}",
            )
        )

    return "\n".join(lines) + "\n"


def write_atomically(output, content):
    output.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(mode="w", encoding="utf-8", dir=output.parent, delete=False) as temporary:
        temporary.write(content)
        temporary_path = Path(temporary.name)

    temporary_path.replace(output)
    output.chmod(0o644)


def main():
    arguments = parse_arguments()

    import numpy as np
    import skimage
    from skimage import transform

    source = np.fromfunction(
        lambda row, column, channel: (row * 5 + column * 3 + channel * 17) % 256,
        (320, 320, 3),
        dtype=int,
    ).astype(np.uint8)
    image = transform.resize(source, (320, 320), mode="constant")
    image = image / np.max(image)
    for channel, (mean, deviation) in enumerate(((0.485, 0.229), (0.456, 0.224), (0.406, 0.225))):
        image[:, :, channel] = (image[:, :, channel] - mean) / deviation
    tensor = np.transpose(image, (2, 0, 1))[np.newaxis, ...].astype(np.float32)

    write_atomically(arguments.output, yaml_content(tensor, np.__version__, skimage.__version__))


if __name__ == "__main__":
    main()
