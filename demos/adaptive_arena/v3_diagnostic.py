#!/usr/bin/env python3
"""Reproduce development-only stamina diagnostics; never read blind evaluation seeds.

Godot owns every hit, health change, mask and reward. This report measures
associations; observational bins alone cannot prove why a policy lost.
"""
import argparse
from collections import Counter
import json
import math
import os
from pathlib import Path
import subprocess
import sys

SEEDS = tuple(range(700, 708))
ACTIONS = frozenset(("pressure", "flank_right", "flank_left", "guard", "retreat"))


def run(godot, project, seed, duel, lunge):
    env = os.environ.copy()
    for name in tuple(env):
        if name.startswith("ARENA_"):
            env.pop(name)
    env.update(ARENA_DIAGNOSTIC="1", ARENA_DEV_SEED=str(seed), ARENA_DEV_LUNGE=str(int(lunge)),
               ARENA_DUEL=str(int(duel)), ARENA_REFINED="1", ARENA_USE_PHYSICS_POLICY="1",
               ARENA_SINGLE_TEAM="learned", ARENA_AUTORUN="1", ARENA_AGENTS="10")
    result = subprocess.run([str(godot), "--headless", "--fixed-fps", "240", "--path", str(project),
                             "res://physics_arena.tscn"], env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=30, check=False)
    records = [line.removeprefix("V3_DIAGNOSTIC ") for line in result.stdout.splitlines()
               if line.startswith("V3_DIAGNOSTIC ")]
    checks = [line for line in result.stdout.splitlines() if line.startswith("PHYSICS_ARENA ")]
    if result.returncode or len(records) != 1 or len(checks) != 1 or "legal_violations=0" not in checks[0]:
        raise RuntimeError(f"Failed development run {seed=} {duel=} {lunge=}:\n{result.stdout[-1600:]}")
    if "policy_variant=refined" not in checks[0] or "source=physics" not in checks[0]:
        raise ValueError("Not the pretrained refined physics policy")
    record = json.loads(records[0])
    if record["version"] != 1 or record["seed"] != seed or record["opponent"] != ("post_attack_lunge" if lunge else "standard_noisy"):
        raise ValueError("Unexpected diagnostic schema/opponent")
    if len(record["outcomes"]) != 4 or not record["rows"] or len(record["rows"]) > 2000:
        raise ValueError("Missing or unbounded diagnostic intervals")
    for row in record["rows"]:
        if (row["seed"] != seed or row["action"] not in ACTIONS or row["action"] not in row["legal"]
                or len(row["state"].split(":")) != 7 or row["state"].split(":")[-2] != row["cue"]
                or "post_attack_lunge" in row["state"] or not set(row["legal"]) <= ACTIONS
                or not all(math.isfinite(float(row[key])) for key in ("stamina", "recovery_seconds", "hp", "distance", "dealt", "taken", "courage", "ambition"))
                or not (0 <= row["stamina"] <= 5 and 0 <= row["recovery_seconds"] <= 0.7 and 0 <= row["hp"] <= 4 and 0 <= row["distance"] <= 1200)
                or row["dealt"] < 0 or row["taken"] < 0 or row["cue"] not in ("rush", "kite", "dodge_right", "dodge_left")):
            raise ValueError(f"Invalid authoritative diagnostic transition: {row!r}")
        low_mask = len(row["legal"]) == 2
        if row["stamina_band"] != ("spent" if low_mask else "attack_legal"):
            raise ValueError("Authoritative stamina band and legal action mask disagree")
        # Godot JSON text can round 1.9999999 to 2.0; the game-owned band/mask
        # remain exact. Only accept that narrow serialization boundary case.
        if (row["stamina"] < 2) != low_mask and abs(row["stamina"] - 2) > 0.0001:
            raise ValueError("Stamina and legal action mask disagree away from threshold")
    return {"seed": seed, "duel": duel, "lunge": lunge,
            "rows": record["rows"], "outcomes": record["outcomes"]}


def summarize(runs):
    summary = {}
    for duel in (False, True):
        for lunge in (False, True):
            chosen = [r for r in runs if r["duel"] == duel and r["lunge"] == lunge]
            rows = [row for r in chosen for row in r["rows"]]
            # Range stratification is descriptive, NOT causal adjustment.
            bins = {"near_spent": [r for r in rows if r["distance"] <= 65 and r["stamina_band"] == "spent"],
                    "near_fragile": [r for r in rows if r["distance"] <= 65 and r["stamina_band"] == "attack_legal" and r["stamina"] < 3.5],
                    "near_fragile_recovering": [r for r in rows if r["distance"] <= 65 and r["stamina_band"] == "attack_legal" and r["stamina"] < 3.5 and r["recovery_seconds"] > 0.35],
                    "near_ready": [r for r in rows if r["distance"] <= 65 and r["stamina"] >= 3.5],
                    "near_ready_recovering": [r for r in rows if r["distance"] <= 65 and r["stamina"] >= 3.5 and r["recovery_seconds"] > 0.35],
                    "near_ready_available": [r for r in rows if r["distance"] <= 65 and r["stamina"] >= 3.5 and r["recovery_seconds"] <= 0.35],
                    "far_spent": [r for r in rows if r["distance"] > 65 and r["stamina_band"] == "spent"],
                    "far_ready": [r for r in rows if r["distance"] > 65 and r["stamina"] >= 3.5]}
            summary[f"{'duel' if duel else 'group'}_{'lunge' if lunge else 'standard'}"] = {
                "bouts": len(chosen) * 4,
                "outcomes": dict(Counter(b["outcome"] for r in chosen for b in r["outcomes"])),
                "intervals": len(rows),
                "sample_bins": {name: {"count": len(data), "wounded_intervals": sum(r["taken"] > 0 for r in data),
                                        "damage_taken": round(sum(r["taken"] for r in data), 2),
                                        "hits_dealt": sum(r["dealt"] for r in data),
                                        "actions": dict(Counter(r["action"] for r in data))}
                                for name, data in bins.items()},
            }
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="Optional raw JSON report outside Git")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 4.4.1 console executable not found")
    runs = []
    for duel in (False, True):
        for lunge in (False, True):
            for seed in SEEDS:
                runs.append(run(args.godot, Path(__file__).resolve().parent, seed, duel, lunge))
                print(f"dev-only diagnostics ok seed={seed} duel={duel} lunge={lunge}", flush=True)
    report = {"development_seeds": SEEDS, "policy": "pretrained physics v2, epsilon=0",
              "caveat": "Stamina-bin associations and one scripted perturbation do not establish causal generalization or predict held-out performance.",
              "summary": summarize(runs), "runs": runs}
    print(json.dumps(report["summary"], indent=2))
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Local report: {args.output}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Diagnostic failure: {exc}", file=sys.stderr)
        sys.exit(1)
