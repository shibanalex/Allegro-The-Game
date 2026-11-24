#!/usr/bin/env python3
"""Safely regenerate 2D normal maps & CanvasTexture resources from edited PNG tilesets without touching source art."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_lighting_assets  # noqa: E402


def main() -> None:
    build_lighting_assets.build_normals_and_materials()


if __name__ == "__main__":
    main()
