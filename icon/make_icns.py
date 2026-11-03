#!/usr/bin/env python3
"""Resize icon.png into an iconset and compile to AppIcon.icns."""

import os
import shutil
import subprocess
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "icon.png")
ICONSET = os.path.join(HERE, "AppIcon.iconset")
ICNS = os.path.join(HERE, "AppIcon.icns")

SIZES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def main() -> int:
    if not os.path.isfile(SRC):
        print(f"missing: {SRC}", file=sys.stderr)
        return 1

    if os.path.isdir(ICONSET):
        shutil.rmtree(ICONSET)
    os.makedirs(ICONSET)

    base = Image.open(SRC).convert("RGBA")
    for size, name in SIZES:
        resized = base.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(ICONSET, name), format="PNG")

    subprocess.run(["iconutil", "-c", "icns", "-o", ICNS, ICONSET], check=True)
    print(f"wrote: {ICNS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
