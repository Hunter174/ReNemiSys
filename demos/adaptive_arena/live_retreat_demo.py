#!/usr/bin/env python3
"""Launch the *rendered*, interactive, isolated Godot 4.4.1 consent viewer.

This only reads a versioned existing user:// policy; it never trains weights,
loads SaLMon, touches the main game, or runs sealed evaluation seeds.
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys

V3_SHA256 = "1b46652d17e7966d8dba63696e7cb9dfe67a32d63a2c4911bf2119a16ee162e1"
CASES = ("approve", "deny", "counter", "relay", "edge_open", "contested",
         "natural", "multiple", "edge", "unload")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, help="Godot 4.4.1 console executable (or set GODOT_BIN)")
    parser.add_argument("--case", choices=CASES, default="approve")
    parser.add_argument("--agents", type=int, choices=(8, 10, 20), default=10)
    parser.add_argument("--seed", type=int, default=900, help="Development seed 900–907 only")
    parser.add_argument("--consent-off", action="store_true", help="Paired blocked route, same collision recovery")
    parser.add_argument("--legacy-contact", action="store_true", help="Explicit old development physics, not the v2 default")
    parser.add_argument("--smoke", action="store_true", help="2-second developer-only auto-exit")
    parser.add_argument("--screenshot", action="store_true", help="With --smoke, save a rendered user:// preview PNG")
    args = parser.parse_args()
    if args.seed not in range(900, 908):
        parser.error("Live fixtures only allow development seeds 900–907")
    if args.screenshot and not args.smoke:
        parser.error("--screenshot requires --smoke")
    godot = args.godot or os.getenv("GODOT_BIN") or shutil.which("godot")
    if not godot or not Path(godot).is_file():
        parser.error("Godot 4.4.1 binary not found; pass --godot /path/to/Godot_v4.4.1-stable_win64_console.exe")
    version = subprocess.run([str(Path(godot).resolve()), "--version"], capture_output=True,
                             text=True, timeout=12, check=False)
    if version.returncode or not version.stdout.strip().startswith("4.4.1."):
        parser.error(f"This local viewer is validated with Godot 4.4.1; got: {version.stdout.strip() or version.stderr.strip()}")
    appdata = os.getenv("APPDATA")
    if not appdata:
        parser.error("APPDATA is missing; cannot locate Godot's external user:// policy")
    artifact = Path(appdata) / "Godot" / "app_userdata" / "Adaptive Goblin Arena (isolated prototype)" / "physics_policy_v3.json"
    if not artifact.is_file():
        parser.error(f"Frozen v3 policy missing: {artifact}. Reproduce the offline v3 training in demos/adaptive_arena/README.md first; do not put weights in Git.")
    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
    if digest != V3_SHA256:
        parser.error(f"Wrong local-only v3 snapshot SHA-256 {digest}; expected {V3_SHA256}. Never silently substitute another policy.")
    env = {key: value for key, value in os.environ.items() if not key.startswith("ARENA_")}
    env.update(ARENA_CROWD_LIVE="1", ARENA_CROWD_DEV="1", ARENA_CROWD_CASE=args.case,
               ARENA_DEV_SEED=str(args.seed), ARENA_V3="1", ARENA_REFINED="1",
               ARENA_USE_PHYSICS_POLICY="1", ARENA_SINGLE_TEAM="learned",
               ARENA_AGENTS=str(args.agents), ARENA_RETREAT_REQUESTS="0" if args.consent_off else "1")
    if args.legacy_contact:
        env["ARENA_CROWD_SEPARATION_TRIAL"] = "0"
    if args.smoke:
        env["ARENA_CROWD_LIVE_SMOKE"] = "1"
    if args.screenshot:
        env["ARENA_CROWD_LIVE_SCREENSHOT"] = "1"
    project = Path(__file__).resolve().parent
    print(f"Launching isolated rendered viewer: {args.case}, agents={args.agents}, consent={'OFF' if args.consent_off else 'ON'}, seed={args.seed}", flush=True)
    print("1–9/0 scenarios | N consent | R reset | Tab next development seed | S slow motion | Space pause | Esc quit. This is NOT #15 blind evidence.", flush=True)
    command = [str(Path(godot).resolve()), "--path", str(project), "--rendering-method", "gl_compatibility", "res://retreat_live_demo.tscn"]
    if args.smoke:
        if not args.screenshot:
            command.insert(1, "--headless") # A screenshot must render an actual window.
        result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=25, check=False)
        print(result.stdout, end="")
        if result.returncode or "RETREAT_LIVE_READY " not in result.stdout or "RETREAT_LIVE_SMOKE " not in result.stdout:
            raise RuntimeError("Viewer did not initialize and render its development scene")
        return
    raise SystemExit(subprocess.call(command, env=env))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Live retreat demo failed: {exc}", file=sys.stderr)
        sys.exit(1)
