#!/usr/bin/env python3
"""Keep reusable business modules independent of UI and platform notification frameworks."""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
sources = root / "Packages/Gudeng/Sources"
ui_imports = {"SwiftUI", "AppKit", "UIKit", "Observation", "Combine", "UserNotifications"}
forbidden = {
    "GudengCore": ui_imports | {"GudengRuntime", "GudengKit"},
    "GudengRuntime": ui_imports | {"GudengKit"},
}
pattern = re.compile(r"^\s*(?:(?:@preconcurrency|@testable|public|internal|package|private|fileprivate)\s+)*import\s+(\w+)", re.MULTILINE)
errors = []
for module, denied in forbidden.items():
    for path in sorted((sources / module).rglob("*.swift")):
        for match in pattern.finditer(path.read_text()):
            if match.group(1) in denied:
                errors.append(f"{path.relative_to(root)}: forbidden import {match.group(1)}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("Module boundaries OK: Core and Runtime are independent of UI frameworks.")
