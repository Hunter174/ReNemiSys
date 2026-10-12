#!/usr/bin/env python3
"""Frozen, paired physics evaluation; stdlib only. No collection or training.

Predeclared seeds must match physics_arena.gd. Headless --fixed-fps speeds up
simulation: its timing figures are NOT representative rendered-frame timings.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

SEEDS = (31001, 31009, 31019, 31033, 31051, 31063, 31069, 31079)
NOVEL_SEEDS = (41011, 41023, 41047, 41059, 41071, 41081, 41093, 41101)
NOVEL_STYLES = ("feint", "burst_kite", "orbit_flip", "stop_go")
TEAMS = ("learned", "fixed", "conservative", "authored_fsm")
STYLES = ("dodge_right", "dodge_left", "rush", "kite")


def field(line, before, after):
    match = re.search(re.escape(before) + r"(.*?)" + re.escape(after), line)
    if match is None:
        raise ValueError(f"Missing evaluation field: {before}")
    return json.loads(match.group(1))


def evaluate(godot, project, seed, duel, novel=False, refined=False):
    env = os.environ.copy()
    for name in ("ARENA_COLLECT", "ARENA_APPEND", "ARENA_TRAIN_SEED", "ARENA_EVAL_SEED", "ARENA_FINAL_SEED"):
        env.pop(name, None)
    env.update(ARENA_USE_PHYSICS_POLICY="1", ARENA_NOISY="1", ARENA_EXTENDED="1",
               ARENA_AUTORUN="1", ARENA_DUEL="1" if duel else "0", ARENA_HELDOUT_SEED=str(seed),
               ARENA_NOVEL="1" if novel else "0", ARENA_REFINED="1" if refined else "0")
    result = subprocess.run([str(godot), "--headless", "--fixed-fps", "240", "--path", str(project),
                             "res://physics_arena.tscn"], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30, check=False)
    lines = [line for line in result.stdout.splitlines() if line.startswith("PHYSICS_ARENA ")]
    if result.returncode or len(lines) != 1 or "legal_violations=0" not in lines[0] or "paired_inputs=true" not in lines[0]:
        raise RuntimeError(f"seed={seed} duel={duel} exit={result.returncode}:\n{result.stdout[-3500:]}")
    line = lines[0]
    if f"duel={str(duel).lower()}" not in line or "source=physics" not in line or f"scenario={'novel' if novel else 'standard'}" not in line:
        raise ValueError("Wrong evaluation configuration or physics weights unavailable")
    teams = field(line, " modes=", " duel=")
    if teams != list(TEAMS):
        raise ValueError(f"Unexpected baselines: {teams}")
    episodes = field(line, " episode_outcomes=", " noisy_variant=")
    hits = field(line, " hits_by_policy=", " modes=")
    tactics = field(line, " phase_tactics=", " phase_hits=")
    if len(episodes) != 16:
        raise ValueError(f"Expected 16 paired bouts: {len(episodes)}")
    styles = NOVEL_STYLES if novel else STYLES
    for index, bout in enumerate(episodes):
        if bout["style"] != styles[index % 4] or bout["team"] != TEAMS[index // 4]:
            raise ValueError("Bout order/identity changed")
        if bout["outcome"] not in ("goblins_win", "player_win", "timeout"):
            raise ValueError("Invalid bout outcome")
        if bout["opponent_trace"] != episodes[index % 4]["opponent_trace"] or bout["starts"] != episodes[index % 4]["starts"]:
            raise ValueError("Opponent/style starts were not paired")
    return {"seed": seed, "duel": duel, "episodes": episodes, "hits": hits, "phase_tactics": tactics}


def summarize(runs, styles=STYLES):
    summary = {}
    for duel in (False, True):
        records = [run for run in runs if run["duel"] == duel]
        category = "duel" if duel else "ten_goblins"
        summary[category] = {}
        for team in TEAMS:
            bouts = [bout for run in records for bout in run["episodes"] if bout["team"] == team]
            summary[category][team] = {
                "bouts": len(bouts), "wins": sum(b["outcome"] == "goblins_win" for b in bouts),
                "losses": sum(b["outcome"] == "player_win" for b in bouts),
                "timeouts": sum(b["outcome"] == "timeout" for b in bouts),
                "damage_to_player": round(sum((3 if duel else 100) - b["player_hp"] for b in bouts), 1),
                "goblins_defeated": sum(b["goblins_defeated"] for b in bouts),
                "hits": sum(run["hits"][team] for run in records),
                "by_style_damage": {style: round(sum((3 if duel else 100) - b["player_hp"] for b in bouts if b["style"] == style), 1) for style in styles},
            }
        summary[category]["learned_beat_fixed_damage_seeds"] = sum(
            sum((3 if duel else 100) - b["player_hp"] for b in run["episodes"] if b["team"] == "learned") >
            sum((3 if duel else 100) - b["player_hp"] for b in run["episodes"] if b["team"] == "fixed")
            for run in records)
        summary[category]["learned_reversal_tactics"] = {
            style: {action: sum(run["phase_tactics"].get(f"{style}_{action}", 0) for run in records)
                    for action in ("pressure", "flank_right", "flank_left", "guard", "retreat")}
            for style in styles[:2]}
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True, help="Godot 4.4.1 console executable")
    parser.add_argument("--output", type=Path, help="Optional local JSON report, outside Git")
    parser.add_argument("--novel", action="store_true", help="Use newly frozen, training-excluded player movement archetypes")
    parser.add_argument("--refined", action="store_true", help="Load a separately trained refined policy, not the previous baseline")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error(f"Godot executable missing: {args.godot}")
    project = Path(__file__).resolve().parent
    seeds = NOVEL_SEEDS if args.novel else SEEDS
    runs = []
    for duel in (False, True):
        for seed in seeds:
            runs.append(evaluate(args.godot, project, seed, duel, args.novel, args.refined))
            print(f"paired run ok: seed={seed} duel={duel}", flush=True)
    report = {"predeclared_heldout_seeds": seeds, "scenario": "novel" if args.novel else "standard",
              "policy": "refined" if args.refined else "original", "summary": summarize(runs, NOVEL_STYLES if args.novel else STYLES), "runs": runs,
              "limitation": "Headless fixed-fps: not rendered-frame timing or main-game evaluation; do not tune to these seeds."}
    print(json.dumps(report["summary"], indent=2))
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Local report: {args.output}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Evaluation failed: {exc}", file=sys.stderr)
        sys.exit(1)
