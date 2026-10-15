#!/usr/bin/env python3
"""Reproduce the authored live dogpile's actual Godot collision/escape contrast."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    launcher = Path(__file__).with_name("live_retreat_demo.py")
    for enabled in (False, True):
        command = [sys.executable, str(launcher), "--godot", str(args.godot),
                   "--case", "coward_dogpile", "--smoke", "--smoke-at", "1.2"]
        if not enabled:
            command.append("--consent-off")
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=30, check=False)
        line = next((row for row in result.stdout.splitlines() if row.startswith("RETREAT_LIVE_SMOKE ")), "")
        if result.returncode or not line or "overlaps=0" not in line:
            raise RuntimeError(f"Bad dogpile fixture (consent={enabled}): {result.stdout[-1400:]}")
        field = lambda name: float(re.search(r"\b" + name + r"=(-?[\d.]+)", line).group(1))
        replies = json.loads(re.search(r"\breplies=(\{.*?\}) elapsed=", line).group(1))
        escaped, time, yielded = field("escape_px"), field("first30_s"), replies["yield"]
        if enabled and (escaped < 30.0 or not 0.0 <= time <= 1.2 or yielded < 1):
            raise ValueError("Coward selected retreat, but approval did not physically clear the dogpile")
        if not enabled and (escaped > 2.0 or time >= 0.0 or yielded != 0):
            raise ValueError("No-consent dogpile moved an ally or silently escaped")
        print(f"RETREAT_LIVE_PHYSICS consent={enabled} escape_px={escaped:.1f} first30_s={time:.2f} yields={int(yielded)}", flush=True)
    print("RETREAT_LIVE_PHYSICS cases=2 failures=0")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, AttributeError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Live dogpile check failed: {exc}", file=sys.stderr)
        sys.exit(1)
