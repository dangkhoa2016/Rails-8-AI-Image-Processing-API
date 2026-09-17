#!/usr/bin/env python3
"""Convert the upstream U-2-NetP state dictionary into a static ONNX model."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


INPUT_SHAPE = (1, 3, 320, 320)
OPSET_VERSION = 17


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-directory", required=True, type=Path)
    parser.add_argument("--weights", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()

    if not arguments.source_directory.is_dir():
        parser.error(f"source directory is not a directory: {arguments.source_directory}")
    if not (arguments.source_directory / "model" / "u2net.py").is_file():
        parser.error("source directory does not contain model/u2net.py")
    if not arguments.weights.is_file():
        parser.error(f"weights file does not exist: {arguments.weights}")
    if arguments.output.exists():
        parser.error(f"output file already exists: {arguments.output}")

    return arguments


def build_model(source_directory: Path, weights: Path):
    sys.path.insert(0, str(source_directory / "model"))

    import torch
    from u2net import U2NETP

    model = U2NETP(3, 1)
    state_dictionary = torch.load(weights, map_location="cpu", weights_only=True)
    model.load_state_dict(state_dictionary)
    model.eval()
    return model, torch


def main() -> None:
    arguments = parse_arguments()
    model, torch = build_model(arguments.source_directory, arguments.weights)

    class FirstOutput(torch.nn.Module):
        def __init__(self, wrapped_model):
            super().__init__()
            self.wrapped_model = wrapped_model

        def forward(self, tensor):
            return self.wrapped_model(tensor)[0]

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        FirstOutput(model),
        torch.zeros(INPUT_SHAPE, dtype=torch.float32),
        arguments.output,
        input_names=["input"],
        output_names=["d0"],
        opset_version=OPSET_VERSION,
        do_constant_folding=True,
    )


if __name__ == "__main__":
    main()
