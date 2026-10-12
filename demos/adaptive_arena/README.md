# Adaptive goblin arena (isolated prototype; issue #1)

This **separate Godot 4.4.1 project** does not change or load ReNemiSys's existing game scenes, SaLMon or MLGodotKit. It is a first, deliberately small RL **tabular** baseline, not a trained neural-network opponent or a real combat game. A single learned Q-table is shared by all goblins. Each goblin supplies its own persistent courage/ambition and a rolling five-move estimate of the player's observed style. The model cannot see the opponent's *next* move. Godot's abstract combat environment computes outcomes, then offline Q-learning updates the shared weights; live inference never trains. Only authoritative game code could eventually grant an epiphany event. Training happens in a headless script, never in a physics tick.

```sh
# From ReNemiSys/: train, exercise assertions and save local pretrained Q weights.
Godot-4.4.1 --headless --path demos/adaptive_arena --script res://arena_check.gd
# After successful training, launch the synthetic rendered display.
Godot-4.4.1 --path demos/adaptive_arena --rendering-method gl_compatibility
# For a reproducible 20-second rendered frame-time report, set ARENA_AUTORUN=1.
# A SECOND, separate physics scene runs paired 10-goblin learned/fixed encounters
# against the same scripted player in sequential 20s blocks (40s total):
ARENA_AUTORUN=1 Godot-4.4.1 --path demos/adaptive_arena --rendering-method gl_compatibility res://physics_arena.tscn
# Separately, test a seeded stochastic *physics* opponent not seen during abstract training:
ARENA_NOISY=1 ARENA_AUTORUN=1 Godot-4.4.1 --headless --path demos/adaptive_arena res://physics_arena.tscn

# Issue #2: OFFLINE physics training. --fixed-fps accelerates collection; its wall-clock
# frame metrics are NOT gameplay benchmarks. Weights and rollouts stay in user://.
ARENA_COLLECT=1 ARENA_NOISY=1 ARENA_TRAIN_SEED=222 Godot-4.4.1 --headless --fixed-fps 240 --path demos/adaptive_arena res://physics_arena.tscn
for seed in {223..237}; do
  ARENA_COLLECT=1 ARENA_APPEND=1 ARENA_NOISY=1 ARENA_TRAIN_SEED="$seed" Godot-4.4.1 --headless --fixed-fps 240 --path demos/adaptive_arena res://physics_arena.tscn
done
Godot-4.4.1 --headless --path demos/adaptive_arena --script res://physics_train.gd
# One preselected evaluation seed, never included in training; DO NOT tune to it:
ARENA_USE_PHYSICS_POLICY=1 ARENA_NOISY=1 ARENA_FINAL_SEED=29011 ARENA_AUTORUN=1 Godot-4.4.1 --headless --fixed-fps 240 --path demos/adaptive_arena res://physics_arena.tscn
# Rendered gameplay timing: omit --fixed-fps and the held-out seed.
ARENA_USE_PHYSICS_POLICY=1 ARENA_NOISY=1 ARENA_AUTORUN=1 Godot-4.4.1 --path demos/adaptive_arena --rendering-method gl_compatibility res://physics_arena.tscn

# Next issue #2 gate: frozen evaluation of four policies under eight *different*
# held-out seeds, in paired ten-goblin encounters AND one-on-one fights.
# Requires the physics-trained user:// artifact. Python 3 standard library only.
python demos/adaptive_arena/heldout_eval.py --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/arena-report.json
# Developer-only non-held-out 80s rendered version of four team policies:
ARENA_USE_PHYSICS_POLICY=1 ARENA_NOISY=1 ARENA_EXTENDED=1 ARENA_AUTORUN=1 Godot-4.4.1 --path demos/adaptive_arena --rendering-method gl_compatibility res://physics_arena.tscn

# Refined v2: predeclared TRAINING-ONLY seeds, original artifact/rollouts left intact.
for seed in {500..531}; do
  ARENA_COLLECT=1 ARENA_REFINED=1 ARENA_NOISY=1 ARENA_TRAIN_SEED="$seed" ARENA_APPEND="$([ "$seed" = 500 ] && echo 0 || echo 1)" Godot-4.4.1 --headless --fixed-fps 240 --path demos/adaptive_arena res://physics_arena.tscn
done
ARENA_REFINED_TRAIN=1 Godot-4.4.1 --headless --path demos/adaptive_arena --script res://physics_train.gd
# Novel archetypes and seeds were frozen before this refinement. Use *new*,
# process-isolated seeds 42013..42131 for an independent comparison:
python demos/adaptive_arena/heldout_eval.py --novel --isolated --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/original.json
python demos/adaptive_arena/heldout_eval.py --novel --isolated --refined --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/refined.json
# Refined development-only rendered CPU/frame timing, never --fixed-fps:
ARENA_REFINED=1 ARENA_USE_PHYSICS_POLICY=1 ARENA_NOISY=1 ARENA_EXTENDED=1 ARENA_AUTORUN=1 Godot-4.4.1 --path demos/adaptive_arena --rendering-method gl_compatibility res://physics_arena.tscn
# A SECOND independently frozen opponent reacts to past NPC actions, visible
# stamina/HP and distance. Fresh processes: one policy per bout, eight new seeds.
python demos/adaptive_arena/heldout_eval.py --reactive --isolated --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/reactive-original.json
python demos/adaptive_arena/heldout_eval.py --reactive --isolated --refined --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/reactive-refined.json
# One active learned team for a 20s rendered 8/10/20-agent full-pass timing check:
for agents in 8 10 20; do
  ARENA_AGENTS="$agents" ARENA_SINGLE_TEAM=learned ARENA_REFINED=1 ARENA_USE_PHYSICS_POLICY=1 ARENA_NOISY=1 ARENA_AUTORUN=1 Godot-4.4.1 --path demos/adaptive_arena --rendering-method gl_compatibility res://physics_arena.tscn
done
Godot-4.4.1 --headless --path demos/adaptive_arena --script res://policy_select_check.gd
# V3: strictly training-only seeds; --fixed-fps is collection acceleration only.
for seed in {800..831}; do
  ARENA_COLLECT=1 ARENA_V3=1 ARENA_REFINED=1 ARENA_NOISY=1 ARENA_TRAIN_SEED="$seed" ARENA_APPEND="$([ "$seed" = 800 ] && echo 0 || echo 1)" Godot-4.4.1 --headless --fixed-fps 240 --path demos/adaptive_arena res://physics_arena.tscn
done
ARENA_V3_TRAIN=1 Godot-4.4.1 --headless --path demos/adaptive_arena --script res://physics_train.gd
# Only development cases until #7 timing passes; do NOT open sealed 610xx fights.
python demos/adaptive_arena/v3_diagnostic.py --v3 --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/v3-dev.json
python demos/adaptive_arena/v3_blind_eval.py --dry-run --godot /path/to/Godot_v4.4.1-stable_win64_console.exe
```

The shared-policy JSON artifact is saved under Godot's `user://adaptive_policy_v1.json` (outside the Git tree) with version/action schema and a SHA-256 integrity check. A *separate*, validated game-owned `user://goblin_personality_v1.json` snapshot demonstrates persistence of courage/ambition, bounded player memory and the already-applied epiphany IDs across reload. Neither file is exported or cryptographically authenticated; do not accept either as an untrusted network player instruction. The local demo verifies identical weights on reload, malformed artifact rejection, action masks, safe choice for unseen states without mutating weights, personality-dependent low-health tactics, absence of an ordinary mid-fight trait rewrite, and an explicitly authorized, idempotent epiphany event that survives a save/reload. Four scripted training archetypes (rush, dodge right/left, kite) and a separate seeded stochastic opponent that changes dodge bias mid-fight test whether remembered behavior changes tactics. The payoff mechanics are authored **for this toy environment**; performance here is not evidence of realistic combat strategy or robustness against unseen players.

On this laptop, separate Godot 4.4.1 headless runs reported **0.346–0.560 ms p95** for selecting actions for **20 goblins in total**, including game-side observation and mask handling (400 samples); a later run measured **1.354 ms p99** and **464 ms offline training**. These vary with CPU load; not every 20-agent group finishes under 1 ms. A separate non-headless 20-second synthetic scene reported **1.553 ms p95** per 20-goblin decision burst, frame-interval p95 **16.845 ms**, max **20.145 ms**. These are not worst-case or actual-game guarantees; no GPU inference benchmark was run. The opponent that switched between stochastic dodge preferences yielded 48.2 aggregate toy reward versus −70.0 for a fixed `pressure` opponent, and actions switched with the observations. Do not generalize this authored payoff metric to fighting ability.

`physics_arena.tscn` uses actual Godot `CharacterBody2D`/walls, `Area2D` hit overlaps, stamina-limited legal actions and authoritative damage. It runs paired sequential learned/fixed-pressure episodes against the same scripted movement schedule and starting slots; the scene **asserts hashes of both teams' starts and observed opponent-style schedules match**. `ARENA_COLLECT=1` stores `(observed state, executed legal action, next legal actions, damage dealt/taken reward, terminal)` after each decision in a bounded checksummed `user://physics_rollouts_v1.json`. Exploratory actions are used ONLY while collecting, not during rendered gameplay. The separate `physics_train.gd` replays those transitions and saves `user://physics_policy_v1.json`; it never updates weights in `_physics_process`. One 16-seed collection (222–237) generated **14,692 transitions**, 90 distinct observed state/action pairs and 18 Q states; 12 offline epochs took **1,645 ms** on this laptop. No player-style label or next player move is provided to the reward; actual hit/health changes drive it. Version-2 policy artifacts hash the exact serialized weight string, avoiding JSON float roundtrip checksum failures; old local version-1 weights can still load.

The **preselected, held-out stochastic physics run** (seed 29011 with position jitter; collected seeds exclude it) produced **91 learned hits versus 112 fixed hits**, zero goblin defeats for either side. The learned policy exploited right dodge better (34 versus 24 hits), but lost to fixed pressure on left dodge, rush and kite. This is a remaining quality failure, **not** a generalization win. A separate non-headless 40-second development scene with ten active goblins measured **90 learned versus 109 fixed hits**, p50/p95/p99 **0.271/0.921/1.145 ms** per ten-goblin observation/policy pass, rendered frame interval p95 **18.688 ms**, max **21.258 ms**, with zero invalid actions. The `--fixed-fps` headless runs simulate faster than real time and **must not** be quoted as frame-time measurements. The older #1 abstract-trained results were from a less strictly paired arena and should not be compared numerically with these checksummed paired episodes. This simplified scene still is not ReNemiSys's main game and has no real win/loss balance certification.

### Stronger paired baselines and win/loss gate (issue #2 still open)

`ARENA_EXTENDED=1` adds **conservative guard/retreat** and a hand-authored **observation-based FSM** (the same past visible player-motion beliefs and legal masks as the learned policy; no future scripted-style oracle). Each team is run separately using the *same* ten starting slots, opponent-style schedule and deterministic collision target priority. Baseline actor memory is reset on team changes. `ARENA_DUEL=1` runs one goblin against one 3-HP player, with a 4-HP goblin; on death all further actions stop until the next 5-second bout. Each bout reports a literal player death, goblin death, or timeout. Ten-goblin bouts use a 100-HP player and are mostly a **damage/survival** measure, not a useful win-rate test. Neither mode models the main game.

`heldout_eval.py` freezes **eight seeds (31001, 31009, 31019, 31033, 31051, 31063, 31069, 31079)**, disjoint from all collection seeds and the earlier single seed 29011. For each seed and mode (ten-goblin and duel) it asserts legal actions, correct physics artifact, matched starts/opponent schedule, policy identity and valid outcomes; raw per-bout results can be written **outside Git**. No held-out seed may be used for collection. With the existing pretrained weights and stochastic script, 32 bouts per policy per mode produced:

| Policy | Ten-goblin hits / goblins defeated | 1v1 goblin wins / losses / timeouts |
| --- | ---: | ---: |
| Physics-trained shared policy | 772 / 7 | 18 / 14 / 0 |
| Fixed pressure | 866 / 2 | 16 / 16 / 0 |
| Conservative | 55 / 0 | 1 / 0 / 31 |
| Observation-based FSM | 657 / 2 | **28 / 4 / 0** |

Ten-goblin bouts were **all timeouts**. Learned damage exceeded fixed pressure in only **2/8 seeds**, though it was better in 7/8 one-on-one seeds; learned survival was worse in the group. Its observed style reversal is also weak: in ten-goblin runs its flank-right/flank-left counts were **755/342** on right-dodge, and **737/242** after switching to left-dodge. In duels, it chose flank-left **zero** times on left-dodge. This is a concrete tactical failure, not evidence of adaptation. The authored FSM won more duels; the model does **not** outperform all baselines. A separate 80-second Windows Godot 4.4.1 **rendered development** run with ten active fighters measured observation-to-action p50/p95/p99 **0.283/0.932/1.261 ms**, frame interval p95 **18.507 ms**, max **22.216 ms**. No sub-millisecond p99 guarantee follows. Headless `--fixed-fps` evaluation is accelerated and yields no real-time gameplay latency measurement.

### Refined observation, genuinely new movements, fresh-process comparison

Before any new-style evaluation, `11f0a10` fixed **four untrained player patterns** (rapid side-to-side feint, burst/kite, reversing orbit, stop/go) and their evaluation seeds. Inspecting *training-only* rollouts then showed the old state omitted the player's current visible velocity and distance; the old Q-table often preferred pressure/right flank even when trailing memory reported left dodge. `ARENA_REFINED=1` appends the **current, game-observed motion cue** and a three-band distance to the existing persistent-personality/rolling-memory observation. It neither receives the player's scripted style nor changes saved personality. Thirty-two separate ten-goblin physics collections (seeds 500–531, never any evaluation seed) produced **29,276** transitions, **905** state/action pairs and **194** shared Q states; 12 offline training epochs took **3,393 ms** on this CPU. The local, separately validated `user://physics_policy_v2.json` has SHA-256 `aa4858af6ef4413088e8665bb556b12a05ff196a311a48bfdc4697c549436572` on this machine; original v1 weights and data were not overwritten. Collection explicitly rejects duel/novel scenarios and unknown training seeds; the trainer verifies the complete 500–531 seed set. Training never runs in the combat frame.

The first novel-style evaluation (sequential policy modes) revealed a **fairness issue**: earlier teams' physics/contact state could change later teams' outcomes despite matching starting slots and intended schedules. Its numbers are exploratory only. The **new, separately frozen seeds** (42013, 42017, 42043, 42061, 42073, 42089, 42101, 42131) therefore use `--isolated`: each policy starts in a **fresh Godot process**, with the runner checking matched initial slots and the precommitted five-second movement schedule across processes. This proves planned inputs, not identical trajectories once opponent behavior reacts to different goblin movements. All runs had zero illegal actions and a validated physics-policy artifact.

| Policy (32 bouts each; eight fresh seeds) | Ten-goblin hits / goblins defeated | 1v1 wins / losses / timeouts |
| --- | ---: | ---: |
| Original physics v1 | 919 / 2 | 20 / 12 / 0 |
| **Refined physics v2** | **985 / 6** | **29 / 3 / 0** |
| Fixed pressure (identical in both runs) | 964 / 4 | 16 / 16 / 0 |
| Conservative (identical) | 21 / 0 | 0 / 0 / 32 |
| Observation FSM (identical) | 618 / 2 | 21 / 11 / 0 |

Group bouts **all timed out**; refined damage beat fixed pressure in **5/8** seeds, but the player defeated more refined goblins (6 vs 4), including three during feints. Its three duel losses were all against stop/go. This is still a **survival/fairness tradeoff**, not uniform improvement. The novel *movement styles* were never trained on, but they remain scripted archetypes in one simplified arena; eight seeds are not independent opponent designs or real-game validation. Refined ten-agent rendered *development* timing: observation+policy p50/p95/p99 **0.310/1.048/1.525 ms**, frame p95/max **18.886/22.735 ms** on this Windows/Godot 4.4.1 CPU setup. The p95 pass is no longer sub-millisecond; headless fixed-fps reports cannot replace these measurements. The early training-only right/left phase diagnostic changed from predominantly right flanks in both phases to **48 right vs 44 left** in right-dodge and **29 right vs 52 left** in left-dodge; the fresh novel tests measured wins/damage, not a separate causal reversal proof.

### Independently frozen reactive opponent, agent-count timing (issue #2 still open)

Commit `9ff868f` froze **eight new seeds** (51001, 51011, 51023, 51047, 51059, 51071, 51083, 51103) and four *reactive* player strategies **before their evaluation**. Unlike earlier scripts, this opponent chooses movement from the nearest goblin's previously visible tactic, stamina, HP or range (counter-tactic, hunt-injured, range-control, tire-out). It does not inspect weights or future choices; NPCs still see only physical velocity, never the opponent's named strategy. Collection **refuses** this mode and these seeds. Each team is evaluated in a fresh process with the same placements and opponent **rule contract**. A reactive player cannot follow an identical trajectory against different policies; its contract hash is not evidence of identical movement. Zero-hit defensive bouts are legal outcomes, not test failures.

| Policy (32 reactive bouts/team) | Ten-goblin hits / goblins defeated | 1v1 goblin wins / losses / timeouts |
| --- | ---: | ---: |
| Original physics v1 | 838 / 6 | 8 / 18 / 6 |
| Refined physics v2 | **866 / 3** | **18 / 9 / 5** |
| Fixed pressure (unchanged across runs) | 664 / 5 | 15 / 16 / 1 |
| Conservative (unchanged) | 0 / 0 | 0 / 0 / 32 |
| Authored FSM (unchanged) | 619 / 2 | **30 / 0 / 2** |

All group bouts timed out. Refined group damage beat pressure in **7/8 seeds**, but the authored FSM's duels were far stronger: refined **lost all eight tire-out duels** (the FSM won them). This reveals a specific stamina-vulnerability / reactive-opponent generalization gap; **do not train to these held-out seeds or retest on them as though unseen**.

Inference selection was simplified without altering tie breaks, legal masks or policy weights. `policy_select_check.gd` exhaustively checked **13,392 choices** over loaded v1/v2 states, all nonempty legal masks in both orders, unseen states and ties; zero failures. In one before/after Windows Godot 4.4.1 **rendered** development run (non-held-out seed 991, one team for 20 seconds; not a controlled benchmark), full-active observation-to-policy p50/p95/p99 in ms:

| Agents | Before select change | After select change | After frame p95 / p99 (ms) | Full passes |
| --- | --- | --- | --- | ---: |
| 8 | 0.280 / 0.472 / 0.937 | 0.225 / 0.423 / 0.600 | 17.102 / 17.840 | 92 |
| 10 | 0.311 / 0.602 / 1.181 | 0.272 / 0.414 / 0.517 | 17.171 / 18.270 | 87 |
| 20 | 0.579 / 0.976 / 4.352 | 0.491 / 0.792 / 1.350 | 17.426 / 19.528 | 92 |

These are measurements, **not repeatable p99 guarantees** or a proof of speedup; host CPU variation can dominate tails. The full-pass filter excludes bursts after an NPC dies; it never substitutes fast fallback actions for model decisions. Fixed-fps headless runs report combat outcomes only, not frame latency. No GPU, main-game, export or production claim is made.

### V3 contract diagnostic (#3, design only)

See [V3_COMBAT_CONTRACT.md](V3_COMBAT_CONTRACT.md) for a **frozen, not yet trained** v3 observation/reward design and explicit development budgets. The standard-library runner `python demos/adaptive_arena/v3_diagnostic.py --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/v3-diagnostic.json` instruments 32 development-only Godot physics fights (seeds 700–707), validating legal masks, state/cue separation, stamina/HP/distance, identity stability and authoritative damage. Against a distinct post-attack-lunge perturbation, the existing v2 policy lost **7/8** duels instead of **2/8** versus a rush phase on the same development starts. Crucially, near *spent* actions had zero wounds in both duel variants, while near *fragile but attack-legal* actions were wounded more often; this observational association is **not** proof that stamina caused the frozen reactive losses. No held-out seed, learned weight or main-game file changed. The game-authoritative stamina mask is exact even when JSON text rounds a value just below 2 to `2.0`.

### V3 offline training status (#5; blind suite UNOPENED)

#4 froze [V3_BLIND_PROTOCOL.md](V3_BLIND_PROTOCOL.md) in `9bbba50` **before** v3 training. Its eight 610xx seeds/opponent modes are forbidden for collection and diagnostics; `v3_blind_eval.py --dry-run` uses only development seed 700 and v2 weights to test fresh-process **continuous** bouts without opening sealed scores. Normal blind evaluation rejects missing/non-v3 artifacts and v2 observation keys. No outcome from that suite has been inspected.

The separate v3 collector uses 32 **training-only** seeds 800–831 and two different training-only player responses, recording versioned `v3:` state and reconstructible game-authoritative hit/HP/stamina reward components. Its 29,395 transitions cover 2,490 observed state/action pairs and 803 shared Q states; neither live physics nor Godot saves train weights. Offline deterministic 20-epoch replay takes about 6.3 s on this CPU and writes `user://physics_policy_v3.json` (SHA-256 `1b46652d17e7966d8dba63696e7cb9dfe67a32d63a2c4911bf2119a16ee162e1`, local only). Earlier 12- and 16-epoch candidates were evaluated ONLY on the preselected 700–707 development suite: 12 lost the lunge damage budget, 16 raised normal group deaths. The frozen 20-epoch candidate **meets the development-only quality thresholds**: 8/8 wins (v2: 1/8) versus post-attack lunge; standard group damage/deaths 755/6 (v2: 765/7); lunge group damage/deaths 656/5 (v2: 727/6). This is model selection on development cases, not independent validation.

**Rendered CPU timing/overload (#7):** [PERFORMANCE_GATE.md](PERFORMANCE_GATE.md) has three repeated 8-, 10- and 20-agent runs, static Godot memory, frame intervals and development-only synchronous-stall/stale-revision tests. One intermediate 20-agent set missed the provisional p99 budget (p99 2.350/2.673/2.556 ms); moving test-environment reads out of the NPC hot loop gave follow-up p99 **2.194/1.606/1.810 ms** in three runs, but **does not prove a worst-case bound**. A synthetic 3ms blocking backend produced legal guard fallbacks after ~4ms, NOT sub-budget learned choices; all prior policy proposals in a stale burst were rejected. The crowd egress/ally-consent problem is an **opt-in, development-only work-in-progress** in [RETREAT_REQUEST_CONTRACT.md](RETREAT_REQUEST_CONTRACT.md) (#13): recipients can consent, refuse or suggest a counter-route in one local combat update without any LLM. Its 15 scripted 8–20-body physics checks pass, but natural fights still have residual Godot contact penetration and did not improve group survival overall; do **not** claim #13 done or tune #14 on these opened development seeds. No frozen 610xx blind result has been opened. Weights stay outside Git and exported PCKs; #2 remains open. Longer bouts and main-game constraints still need verification. Validate a pretrained MLGodotKit neural network in this same arena only if a baseline generalizes, using [MLGodotKit#50](https://github.com/Hunter174/MLGodotKit/issues/50)'s snapshot/export gate. Existing ReNemiSys entities, MLGodotKit and SaLMon remain uncoupled; future SaLMon diplomatic proposals must be game-authorized. #2 remains open.
