#!/usr/bin/env python3
"""Development fixtures for physical consent/denial; headless time is NOT rendered latency."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def outcome(godot, project, case, agents, enabled, injection=None, contact_recovery=True):
    env = {k: v for k, v in os.environ.items() if not k.startswith("ARENA_")}
    env.update(ARENA_CROWD_DEV="1", ARENA_CROWD_CASE=case, ARENA_DEV_SEED="900",
               ARENA_V3="1", ARENA_REFINED="1", ARENA_USE_PHYSICS_POLICY="1",
               ARENA_SINGLE_TEAM="learned", ARENA_AGENTS=str(agents), ARENA_AUTORUN="1",
               ARENA_RETREAT_REQUESTS="1" if enabled else "0",
               ARENA_CROWD_SEPARATION_TRIAL="1" if contact_recovery else "0")
    if injection:
        env[injection] = "1"
    result = subprocess.run([str(godot), "--headless", "--fixed-fps", "240", "--path", str(project),
                             "res://physics_arena.tscn"], env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=25, check=False)
    lines = [line for line in result.stdout.splitlines() if line.startswith("PHYSICS_ARENA ")]
    if result.returncode or len(lines) != 1:
        raise RuntimeError(f"{case}/{agents}/{enabled}/{injection}: {result.stdout[-1600:]}")
    line = lines[0]
    if (f"active_agents={agents}" not in line or "legal_violations=0" not in line
            or "policy_variant=v3" not in line
            or f"contact_recovery={str(contact_recovery).lower()}" not in line):
        raise ValueError("Wrong policy, contact recovery, illegal action or wrong fixture size")

    def field(pattern):
        match = re.search(pattern, line)
        if not match:
            raise ValueError(f"Missing output field {pattern}")
        return match.group(1)

    counts = json.loads(field(r"request_counts=(\{.*?\}) actor_overlap_violations="))
    overlap = int(field(r"actor_overlap_violations=(\d+)"))
    max_recovery = float(field(r"max_contact_correction_px=([\d.]+)"))
    if max_recovery > 2.001:
        raise ValueError("A collision correction exceeded its bounded per-tick motion")
    rows = json.loads(field(r"episode_outcomes=(\[.*?\]) noisy_variant="))
    if len(rows) != 4 or overlap:
        raise ValueError(f"Overlapping actors or missing phases: {case}/{agents} overlaps={overlap}")
    if any(x["goblins_defeated"] < 0 or x["player_hp"] > 100.0 for x in rows):
        raise ValueError("Corrupt game-owned HP/death accounting")
    progress = [x["egress_px"] for x in rows]
    escape = [x["escape_time_s"] for x in rows]
    if case == "approve":
        if enabled and not injection:
            if counts["yield"] < 1 or min(progress) < 30.0 or min(escape) < 0.0 or max(escape) > 1.2:
                raise ValueError("Approval did not enable physical escape within the bounded window")
        elif injection:
            if max(progress) > 2.0 or max(escape) >= 0.0 or counts["yield"]:
                raise ValueError("Invalid consent was executed")
            expected = "invalid" if injection == "ARENA_CROWD_STALE" else "expired"
            if counts[expected] < 4:
                raise ValueError("Stale/expired responses not explicitly rejected")
        elif max(progress) > 2.0 or max(escape) >= 0.0:
            raise ValueError("Baseline did not reproduce the dogpile")
    if case in ("deny", "edge") and (counts["deny"] < 4 or max(progress) > 2.0):
        raise ValueError("Rational refusal/wall did not prevent forced movement")
    if case in ("counter", "edge_open") and (counts["counter"] < 1 or min(progress) < 30.0):
        raise ValueError("Alternative corridor did not enable independent retreat")
    if case == "edge_open" and counts["yield"]:
        raise ValueError("Open wall exit must not require another goblin's consent")
    if case == "relay" and (counts["yield"] < 1 or min(progress) < 30.0):
        raise ValueError("Two-hop outward relay did not allow physical exit")
    if case == "contested" and (counts["yield"] < 1 or counts["conflicts"] < 1 or counts["counter"] < 1
                                or min(x["second_egress_px"] for x in rows) < 30.0
                                or any(not 0.0 <= x["second_escape_time_s"] <= 1.2 for x in rows)):
        raise ValueError("Rejected helper booking prevented the other requester from taking an open route")
    if case == "multiple" and (counts["yield"] < 2 or min(x["second_egress_px"] for x in rows) < 30.0):
        raise ValueError("One of the simultaneous requesters was trapped")
    if case in ("death", "unload") and (counts["cancelled"] < 1 or min(progress) < 30.0):
        raise ValueError("Leaving actor did not revoke the old plan or free the corridor")
    return {"case": case, "agents": agents, "consent": enabled, "injection": injection,
            "contact_recovery": contact_recovery,
            "responses": counts, "egress_px": progress[0], "first_escape_s": escape[0],
            "overlaps": overlap}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--no-contact-recovery", action="store_true", help="Compare legacy development physics; NOT the default #13 variant")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot executable not found")
    cases = [("approve", n, mode, None) for n in (8, 10, 20) for mode in (False, True)]
    cases.extend((case, 10, True, None) for case in ("deny", "counter", "relay", "edge", "edge_open", "multiple", "contested", "death", "unload"))
    cases.extend(("approve", 10, True, injection) for injection in ("ARENA_CROWD_STALE", "ARENA_CROWD_EXPIRE"))
    for case, agents, enabled, injection in cases:
        print("RETREAT_PHYSICS_CHECK", json.dumps(outcome(args.godot, Path(__file__).resolve().parent,
                                                        case, agents, enabled, injection, not args.no_contact_recovery), sort_keys=True), flush=True)
    print(f"RETREAT_PHYSICS_CHECK cases={len(cases)} failures=0")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Retreat physics check failed: {exc}", file=sys.stderr)
        sys.exit(1)
