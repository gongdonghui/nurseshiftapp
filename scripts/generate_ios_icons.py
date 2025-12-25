#!/usr/bin/env python3
"""
Generate iOS app icons from nurseshift_pro.png.

Run from repo root:
  python scripts/generate_ios_icons.py
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    source = root / "nurseshift_pro.png"
    asset_dir = root / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = asset_dir / "Contents.json"

    data = json.loads(contents.read_text())
    for entry in data.get("images", []):
        filename = entry.get("filename")
        if not filename:
            continue
        size = entry.get("size", "0x0").split("x")[0]
        scale = entry.get("scale", "1x").replace("x", "")
        try:
            base = float(size)
            multiplier = int(scale)
        except ValueError:
            continue
        dimension = int(base * multiplier)
        dest = asset_dir / filename
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "sips",
                "-z",
                str(dimension),
                str(dimension),
                str(source),
                "--out",
                str(dest),
            ],
            check=True,
        )
        print(f"Generated {dest.name} ({dimension}x{dimension})")


if __name__ == "__main__":
    main()
