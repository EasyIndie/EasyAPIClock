#!/usr/bin/env python3
"""Check the universal app's declared and Mach-O deployment targets; never launches it."""
import plistlib
import re
import subprocess
import sys
from pathlib import Path


def version(value):
    parts = tuple(int(piece) for piece in value.split("."))
    return (parts + (0, 0, 0))[:3]


def main():
    app = Path(sys.argv[1])
    expected = sys.argv[2] if len(sys.argv) > 2 else "13.0"
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    declared = info.get("LSMinimumSystemVersion", "")
    if version(declared) != version(expected):
        raise ValueError(f"Info.plist minimum {declared!r}, expected {expected}")
    binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = set(subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split())
    if architectures != {"arm64", "x86_64"}:
        raise ValueError(f"Expected arm64 + x86_64, found {sorted(architectures)}")
    for architecture in sorted(architectures):
        output = subprocess.check_output(
            ["xcrun", "vtool", "-arch", architecture, "-show-build", str(binary)], text=True
        )
        minimum = re.search(r"\bminos\s+([\d.]+)", output)
        if minimum is None or version(minimum.group(1)) != version(expected):
            raise ValueError(f"{architecture}: unexpected deployment metadata\n{output}")
        print(f"{architecture}: minimum macOS {minimum.group(1)}")
    print(f"Universal app metadata OK: {app}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, IndexError, subprocess.CalledProcessError) as error:
        print(f"macOS build verification failed: {error}", file=sys.stderr)
        sys.exit(1)
