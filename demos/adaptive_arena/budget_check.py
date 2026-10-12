#!/usr/bin/env python3
"""Development-only synthetic timeout/revision tests, NOT frame benchmarks."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


def run(godot, project, case):
    env = os.environ.copy()
    for name in tuple(env):
        if name.startswith("ARENA_"):
            env.pop(name)
    env.update(ARENA_V3="1", ARENA_REFINED="1", ARENA_USE_PHYSICS_POLICY="1",
               ARENA_SINGLE_TEAM="learned", ARENA_AGENTS="20", ARENA_AUTORUN="1",
               ARENA_FRAME_BUDGET_MS="1.2" if case == "stall" else "100")
    if case == "stall":
        env["ARENA_FAKE_SLOW_US"] = "3000"
    elif case == "stale":
        env["ARENA_FORCE_STALE"] = "1"
    result = subprocess.run([str(godot), "--headless", "--fixed-fps", "240", "--path", str(project),
                             "res://physics_arena.tscn"], env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=25, check=False)
    lines = [line for line in result.stdout.splitlines() if line.startswith("PHYSICS_ARENA ")]
    if result.returncode or len(lines) != 1:
        raise RuntimeError(f"{case} failed: {result.stdout[-1600:]}")
    line = lines[0]
    if "legal_violations=0" not in line or "policy_variant=v3" not in line or "active_agents=20" not in line:
        raise ValueError("Invalid test outcome")
    metrics = {}
    for key in ("budgeted_bursts", "timeout_fallbacks", "stale_fallbacks"):
        match = re.search(r"\b" + key + r"=(\d+)", line)
        if not match:
            raise ValueError(f"Missing {key}")
        metrics[key] = int(match.group(1))
    bursts = metrics["budgeted_bursts"]
    if bursts < 80:
        raise ValueError("Too few decision bursts")
    if case == "stall" and (metrics["timeout_fallbacks"] != bursts * 20 or metrics["stale_fallbacks"]):
        raise ValueError("Slow batch was not atomically rejected")
    if case == "stale" and (metrics["stale_fallbacks"] != bursts * 20 or metrics["timeout_fallbacks"]):
        raise ValueError("Stale choices were not atomically rejected")
    if case == "normal" and (metrics["stale_fallbacks"] or metrics["timeout_fallbacks"]):
        raise ValueError("Valid model choices were replaced without a cause")
    return metrics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot console binary missing")
    for name in ("normal", "stall", "stale"):
        print(f"BUDGET_CHECK {name} {run(args.godot, Path(__file__).resolve().parent, name)}", flush=True)
    print("BUDGET_CHECK failures=0; a synchronous stall CAN still miss the deadline")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Budget check failed: {exc}", file=sys.stderr)
        sys.exit(1)
