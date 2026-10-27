#!/bin/bash
set -euo pipefail
app_path="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
# Match the exact build path, never terminate another installed copy by name.
python3 - "$app_path/Contents/MacOS/GudengMac" <<'PY'
import os
import signal
import subprocess
import sys
import time

executable = sys.argv[1]
rows = subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True).splitlines()
pids = [int(parts[0]) for row in rows if len(parts := row.strip().split(None, 1)) == 2 and parts[1] == executable]
for pid in pids:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
remaining = pids
for _ in range(50):
    remaining = []
    for pid in pids:
        try:
            os.kill(pid, 0)
            remaining.append(pid)
        except ProcessLookupError:
            pass
    if not remaining:
        break
    time.sleep(0.1)
if remaining:
    sys.exit("旧实例未退出，停止启动；请手动退出谷蹬后重试。")
PY
open "$app_path"
