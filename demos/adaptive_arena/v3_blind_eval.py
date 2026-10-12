#!/usr/bin/env python3
"""Blind, process-isolated V3 combat gate. NO training. Never tune on its seeds.

Run only after v3 weights/config are frozen. --dry-run uses seed 700 and v2
weights solely to test infrastructure; it refuses the sealed held-out seeds.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

SEEDS = (61001, 61013, 61027, 61039, 61051, 61069, 61081, 61097)
STYLES = ("wall_switch", "bait_hold", "reach_cycle", "cross_feint")
TEAMS = ("learned", "fixed", "conservative", "authored_fsm")


def field(line, prefix, suffix):
    match = re.search(re.escape(prefix) + r"(.*?)" + re.escape(suffix), line)
    if not match:
        raise ValueError(f"Missing {prefix.strip()}")
    return json.loads(match.group(1))


def run(godot, project, seed, duel, team, dry_run, baseline_v2):
    env = os.environ.copy()
    for key in tuple(env):
        if key.startswith("ARENA_"):
            env.pop(key)
    env.update(ARENA_V3_BLIND="1", ARENA_V3="1" if not (dry_run or baseline_v2) else "0",
               ARENA_BLIND_DRY_RUN="1" if dry_run else "0",
               ARENA_BLIND_V2_BASELINE="1" if baseline_v2 else "0", ARENA_REFINED="1",
               ARENA_USE_PHYSICS_POLICY="1", ARENA_LONG_BOUT="1", ARENA_AGENTS="10",
               ARENA_SINGLE_TEAM=team, ARENA_DUEL=str(int(duel)), ARENA_AUTORUN="1")
    if not dry_run:
        env["ARENA_HELDOUT_SEED"] = str(seed)
    else:
        env["ARENA_DEV_SEED"] = str(seed)
    result = subprocess.run([str(godot), "--headless", "--fixed-fps", "240", "--path", str(project),
                             "res://physics_arena.tscn"], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30, check=False)
    lines = [line for line in result.stdout.splitlines() if line.startswith("PHYSICS_ARENA ")]
    if result.returncode or len(lines) != 1:
        raise RuntimeError(f"seed={seed} duel={duel} team={team} exit={result.returncode}:\n{result.stdout[-2600:]}")
    line = lines[0]
    if ("legal_violations=0" not in line or "paired_inputs=true" not in line
            or "source=physics" not in line or "scenario=v3_blind" not in line
            or f"policy_variant={'v3_dry_run' if dry_run else ('v2_blind_baseline' if baseline_v2 else 'v3')}" not in line
            or f"duel={str(duel).lower()}" not in line or ("active_agents=1" if duel else "active_agents=10") not in line):
        raise ValueError(f"Incorrect configuration or invalid game outcome: {line[-1100:]}")
    if field(line, " modes=", " duel=") != [team]:
        raise ValueError("Another policy ran in the same process")
    bouts = field(line, " episode_outcomes=", " noisy_variant=")
    hits = field(line, " hits_by_policy=", " modes=")[team]
    if len(bouts) != 4 or any(b["style"] != STYLES[i] or b["team"] != team for i, b in enumerate(bouts)):
        raise ValueError("Expected four phase snapshots of ONE continuous bout")
    if any(b["outcome"] not in ("goblins_win", "player_win", "timeout") for b in bouts):
        raise ValueError("Invalid win/loss/timeout")
    for before, after in zip(bouts, bouts[1:]):
        if after["player_hp"] > before["player_hp"] or after["goblins_defeated"] < before["goblins_defeated"]:
            raise ValueError("Long-bout HP/deaths must not reset between phases")
    if not 0 <= bouts[-1]["player_hp"] <= (3 if duel else 100):
        raise ValueError("Invalid final player HP")
    return {"team": team, "seed": seed, "duel": duel, "phase_snapshots": bouts,
            "final": bouts[-1], "hits": hits}


def evaluate(godot, project, seeds, dry_run, baseline_v2):
    runs = []
    for duel in (False, True):
        for seed in seeds:
            pieces = [run(godot, project, seed, duel, team, dry_run, baseline_v2) for team in TEAMS]
            for phase in range(4):
                first = pieces[0]["phase_snapshots"][phase]
                if any(p["phase_snapshots"][phase]["starts"] != first["starts"] or
                       p["phase_snapshots"][phase]["opponent_trace"] != first["opponent_trace"] for p in pieces[1:]):
                    raise ValueError("Mismatched initial slots or opponent rule contract across processes")
            runs.extend(pieces)
            print(f"{'DRY_RUN' if dry_run else 'SEALED'} paired long bout ok seed={seed} duel={duel}", flush=True)
    return runs


def summarize(runs):
    summary = {}
    for duel in (False, True):
        mode = "duel" if duel else "group"
        summary[mode] = {}
        for team in TEAMS:
            rows = [r for r in runs if r["duel"] == duel and r["team"] == team]
            summary[mode][team] = {
                "bouts": len(rows), "wins": sum(r["final"]["outcome"] == "goblins_win" for r in rows),
                "losses": sum(r["final"]["outcome"] == "player_win" for r in rows),
                "timeouts": sum(r["final"]["outcome"] == "timeout" for r in rows),
                "hits": sum(r["hits"] for r in rows),
                "goblins_defeated": sum(r["final"]["goblins_defeated"] for r in rows),
                "per_phase_damage": {style: sum(((3 if duel else 100) if i == 0 else r["phase_snapshots"][i-1]["player_hp"]) -
                                                r["phase_snapshots"][i]["player_hp"] for r in rows)
                                     for i, style in enumerate(STYLES)},
            }
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="Raw local report OUTSIDE Git; never pre-open the blind set")
    parser.add_argument("--dry-run", action="store_true", help="Infrastructure only: seed 700/v2; NOT blind v3 results")
    parser.add_argument("--baseline-v2", action="store_true", help="Sealed baseline comparison; run only after v3 is frozen")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 4.4.1 console binary missing")
    if args.dry_run and args.baseline_v2:
        parser.error("Choose dry-run or sealed baseline, not both")
    if not args.dry_run and not args.output:
        parser.error("Blind evaluation requires an explicit report path outside Git")
    project = Path(__file__).resolve().parent
    if args.output and args.output.resolve().is_relative_to(project.parents[1]):
        parser.error("Keep raw blind outcomes outside the ReNemiSys Git checkout")
    runs = evaluate(args.godot, project, (700,) if args.dry_run else SEEDS, args.dry_run, args.baseline_v2)
    report = {"schema": 1, "predeclared_seeds": (700,) if args.dry_run else SEEDS,
              "protocol": "v3-blind-v1-long-continuous-bout", "dry_run": args.dry_run,
              "policy": "v2_baseline" if args.baseline_v2 else ("v2_dry_run" if args.dry_run else "v3"),
              "summary": summarize(runs), "runs": runs,
              "caveat": "Seeded scripted physics prototype, not held-out proof of main-game combat or rendered timing."}
    print(json.dumps(report["summary"], indent=2))
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Local report: {args.output}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Blind evaluator failed: {exc}", file=sys.stderr)
        sys.exit(1)
