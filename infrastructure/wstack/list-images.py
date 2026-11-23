#!/usr/bin/env python3
"""List the container images referenced by rendered Kubernetes manifests.

Reads the output of `helm template` (a stream of YAML documents) from a file or
stdin and prints each image reference once, sorted. Every string value of an
`image` key counts, wherever it sits (containers, initContainers, any list or
mapping form), so quoting and indentation don't matter.

Usage: helm template x CHART | infrastructure/wstack/list-images.py
       infrastructure/wstack/list-images.py rendered.yaml
"""
from __future__ import annotations

import sys
from collections.abc import Iterator
from typing import Any

import yaml


def images(node: Any) -> Iterator[str]:
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "image" and isinstance(value, str) and value.strip():
                yield value.strip()
            else:
                yield from images(value)
    elif isinstance(node, list):
        for item in node:
            yield from images(item)


def list_images(text: str) -> list[str]:
    found: set[str] = set()
    for doc in yaml.safe_load_all(text):
        found.update(images(doc))
    return sorted(found)


def main(argv: list[str]) -> int:
    text = open(argv[1]).read() if len(argv) > 1 else sys.stdin.read()
    for ref in list_images(text):
        print(ref)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
