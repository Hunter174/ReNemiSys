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
ISOLATED_SEEDS = (42013, 42017, 42043, 42061, 42073, 42089, 42101, 42131)
REACTIVE_SEEDS = (51001, 51011, 51023, 51047, 51059, 51071, 51083, 51103)
REACTIVE_STYLES = ("counter_tactic", "hunt_injured", "range_control", "tire_out")
NOVEL_STYLES = ("feint", "burst_kite", "orbit_flip", "stop_go")
TEAMS = ("learned", "fixed", "conservative", "authored_fsm")
STYLES = ("dodge_right", "dodge_left", "rush", "kite")


def field(line, before, after):
    match = re.search(re.escape(before) + r"(.*?)" + re.escape(after), line)
    if match is None:
        raise ValueError(f"Missing evaluation field: {before}")
    return json.loads(match.group(1))


def evaluate(godot, project, seed, duel, novel=False, refined=False, team=None, reactive=False):
    env = os.environ.copy()
    for name in ("ARENA_COLLECT", "ARENA_APPEND", "ARENA_TRAIN_SEED", "ARENA_EVAL_SEED", "ARENA_FINAL_SEED"):
        env.pop(name, None)
    env.update(ARENA_USE_PHYSICS_POLICY="1", ARENA_NOISY="0" if reactive else "1", ARENA_EXTENDED="1",
               ARENA_AUTORUN="1", ARENA_DUEL="1" if duel else "0", ARENA_HELDOUT_SEED=str(seed),
               ARENA_NOVEL="1" if novel else "0", ARENA_REACTIVE="1" if reactive else "0",
               ARENA_AGENTS="10", ARENA_REFINED="1" if refined else "0")
    env.pop("ARENA_SINGLE_TEAM", None)
    if team:
        env["ARENA_SINGLE_TEAM"] = team
    result = subprocess.run([str(godot), "--headless", "--fixed-fps", "240", "--path", str(project),
                             "res://physics_arena.tscn"], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30, check=False)
    lines = [line for line in result.stdout.splitlines() if line.startswith("PHYSICS_ARENA ")]
    if result.returncode or len(lines) != 1 or "legal_violations=0" not in lines[0] or "paired_inputs=true" not in lines[0]:
        raise RuntimeError(f"seed={seed} duel={duel} exit={result.returncode}:\n{result.stdout[-3500:]}")
    line = lines[0]
    if (f"duel={str(duel).lower()}" not in line or "source=physics" not in line
            or f"scenario={'reactive' if reactive else ('novel' if novel else 'standard')}" not in line
            or f"policy_variant={'refined' if refined else 'original'}" not in line):
        raise ValueError("Wrong evaluation configuration or physics weights unavailable")
    teams = field(line, " modes=", " duel=")
    if teams != ([team] if team else list(TEAMS)):
        raise ValueError(f"Unexpected baselines: {teams}")
    episodes = field(line, " episode_outcomes=", " noisy_variant=")
    hits = field(line, " hits_by_policy=", " modes=")
    tactics = field(line, " phase_tactics=", " phase_hits=")
    if len(episodes) != (4 if team else 16):
        raise ValueError(f"Expected paired bouts: {len(episodes)}")
    styles = REACTIVE_STYLES if reactive else (NOVEL_STYLES if novel else STYLES)
    for index, bout in enumerate(episodes):
        if bout["style"] != styles[index % 4] or bout["team"] != (team if team else TEAMS[index // 4]):
            raise ValueError("Bout order/identity changed")
        if bout["outcome"] not in ("goblins_win", "player_win", "timeout"):
            raise ValueError("Invalid bout outcome")
        if not team and (bout["opponent_trace"] != episodes[index % 4]["opponent_trace"] or bout["starts"] != episodes[index % 4]["starts"]):
            raise ValueError("Opponent/style starts were not paired")
    return {"seed": seed, "duel": duel, "episodes": episodes, "hits": hits, "phase_tactics": tactics}


def evaluate_isolated(godot, project, seed, duel, refined, reactive=False):
    # Fresh Godot process per team prevents prior combat from affecting later
    # physics/contact caches. Pair inputs are checked ACROSS processes here.
    pieces = [evaluate(godot, project, seed, duel, novel=not reactive, refined=refined, team=team, reactive=reactive) for team in TEAMS]
    first = pieces[0]["episodes"]
    for piece in pieces[1:]:
        for a, b in zip(first, piece["episodes"]):
            if a["style"] != b["style"] or a["starts"] != b["starts"] or a["opponent_trace"] != b["opponent_trace"]:
                raise ValueError(f"Cross-process start/opponent-contract mismatch for seed={seed} duel={duel}")
    return {"seed": seed, "duel": duel, "episodes": [b for piece in pieces for b in piece["episodes"]],
            "hits": {team: pieces[i]["hits"][team] for i, team in enumerate(TEAMS)},
            "phase_tactics": pieces[0]["phase_tactics"]}


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
        summary[category]["learned_reversal_tactics" if styles == STYLES else "learned_first_two_style_tactics"] = {
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
    parser.add_argument("--isolated", action="store_true", help="Fresh process per policy; separate frozen seeds for each opponent")
    parser.add_argument("--reactive", action="store_true", help="New held-out opponent responds to visible NPC actions (not identical trajectories)")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error(f"Godot executable missing: {args.godot}")
    project = Path(__file__).resolve().parent
    if args.reactive and (args.novel or not args.isolated):
        parser.error("--reactive requires --isolated and excludes --novel")
    if args.isolated and not (args.novel or args.reactive):
        parser.error("--isolated requires --novel or --reactive")
    seeds = REACTIVE_SEEDS if args.reactive else (ISOLATED_SEEDS if args.isolated else (NOVEL_SEEDS if args.novel else SEEDS))
    runs = []
    for duel in (False, True):
        for seed in seeds:
            runs.append(evaluate_isolated(args.godot, project, seed, duel, args.refined, args.reactive) if args.isolated
                        else evaluate(args.godot, project, seed, duel, args.novel, args.refined))
            print(f"paired run ok: seed={seed} duel={duel}", flush=True)
    report = {"predeclared_heldout_seeds": seeds,
              "scenario": "reactive" if args.reactive else ("novel" if args.novel else "standard"),
              "process_isolated": args.isolated,
              "policy": "refined" if args.refined else "original",
              "summary": summarize(runs, REACTIVE_STYLES if args.reactive else (NOVEL_STYLES if args.novel else STYLES)), "runs": runs,
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
