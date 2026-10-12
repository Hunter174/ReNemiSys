# V3 combat contract (frozen design, ReNemiSys #3)

Scope: isolated Godot 4.4.1 physics arena on the local CPU-only Windows laptop. **No v3 weights have been trained.** This is a proposed contract for #4 (freeze fresh blind fights) and #5 (train off-frame). The v1/v2 artifacts, save snapshots and held-out scores remain untouched. Godot, not a policy or LLM, owns hits, HP, stamina, collision, reward and lasting personality changes.

## Evidence from development-only diagnostics

Run `python demos/adaptive_arena/v3_diagnostic.py --godot /path/to/Godot_v4.4.1-stable_win64_console.exe --output /path/outside/git/diagnostic.json` from ReNemiSys/. Eight **development-only** seeds 700–707 use the existing pretrained physics-v2 policy (epsilon 0), a single learned team, separate 1v1 and ten-goblin bouts, and a standard opponent versus a distinct `post_attack_lunge` perturbation. The perturbation moves toward the goblin after its visible attack action/cooldown, otherwise circles; it is **not** the frozen held-out stamina-threshold opponent. Every interval records state, visible cue, exact legal mask, action, stamina/band, own attack recovery, HP, distance, personality, authoritative hit and damage deltas, phase and terminal status. Phase identifies the test fixture for analysis; it is NOT present in the policy state. No data enter training or Git.

One 32-process development run: in the eight 1v1 rush phases, v2 lost **2/8**; against the separate post-attack lunge phase at identical seeded starting slots it lost **7/8**. Over those phases, lunge bouts incurred 24 HP damage during pressure intervals versus 9 in rush. However, across ALL development bouts, near-and-**spent** intervals had 1 wound in 908 group intervals and **zero** in 16 duel intervals: attacks were illegal, so the policy mostly guarded. Near-and-**fragile but attack-legal** `[2,3.5)` intervals suffered 38 wounds in 99 duel-standard intervals and 51 in 121 duel-lunge intervals; near-and-**ready** `>=3.5` suffered 60/218 and 53/211 respectively. Own cooldown `>0.35s` did **not** by itself predict higher wounds in this slice (near fragile/recovering 7/38 standard versus 12/41 lunge); attack action and opponent position differ. These are conditional associations, NOT a randomized causal estimate: defensive action, attack-range selection and opponent feedback confound it. **Do not assert that low stamina itself caused the eight frozen reactive tire-out losses.** The local game code does prove that held-out opponent *changes movement* when the nearest goblin has less than 2 stamina, while the present policy state omits stamina and its own attack recovery. These facts motivate testing a stamina/recovery/threat contract, not claiming a fix.

Godot JSON may round a stamina float very near 2 to `2.0`; the authoritative `stamina_band` and mask are recorded BEFORE serialization. The diagnostic validator checks both and allows only a 0.0001 boundary serialization difference. Diagnostics refuse held-out seeds, other opponents, collection/training and non-v2 inference.

## Frozen v3 observation and event order (proposal; #5 must version it in code)

At each 0.2-second decision, **after** the current player movement/visible velocity but **before** goblin action, build:

`v3:<rolling_belief>:<low_hp>:<tough>:<courage_hi>:<ambition_hi>:<current_motion>:<range>:<stamina>:<recovery>:<threat>`

- Existing bounded last-five *observed* moves (updated **after** selection), low HP `hp <= 3`, tough-enemy flag (currently false), saved courage/ambition each thresholded at 0.5. Persistent values change only through the game-authorized epiphany ledger, never Q-updates.
- Current visible player velocity cue: rush/kite/dodge-right/dodge-left, relative to this NPC; `unknown` if velocity is near zero (do not invent a dodge). Not the hidden fixture name or its next motion.
- Geometric player distance: `contact <= 55`, `closing (55,145]`, `far > 145` pixels. Stamina from **this** goblin: `spent < 2`, `fragile [2,3.5)`, `ready >= 3.5`, bounded to `[0,5]`. The legal mask is *still* computed separately: attacks require stamina `>= 2`; guard/retreat remain legal. An observation never grants an illegal attack.
- Own currently game-known attack recovery: `recovering` when `cooldown > 0.35s`, otherwise `available`. No opponent hidden cooldown/timer. `threat` when the player is within 65 pixels and its **already observed** velocity approaches this goblin (`dot(player_velocity, relative_to_player) > 35 px/s`), else `not_threatened`. Walls may constrain movement; do not pretend this state plans terrain routes.
- The game must recompute state and mask after any revision, reject stale/illegal selections and use a game-owned legal fallback (`guard` if legal, otherwise first permitted action). Never let a model assert damage, resource availability or an epiphany.

The current artifact loader caps states at 512 and 262,144 payload characters; #5 must calculate actual v3 state growth, enforce an explicit bounded v3 state/size budget (at most 4,096 verified keys and 262,144 payload characters or fail clearly), preserve v1/v2 validation, and avoid silently dropping states. Key strings are not a save format for personality.

## Frozen v3 reward and development budgets

Record only game-authoritative event deltas after an executed **legal** action and before the next decision: `dealt` (hits), `taken` (HP lost), and `stamina_spent = max(0, previous_stamina - current_stamina)`; omit hidden opponent intent. Precommitted reward per transition:

`(1 + 0.2 * ambition) * dealt - (1.1 + 0.6 * (1 - courage)) * taken - 0.04 * stamina_spent - 0.015`

At a true terminal/phase boundary add `+0.2 * (1 - courage)` if alive, or `-0.8` on death. Clip/validate each finite reward in `[-10,10]`; bootstrap ONLY through legal next actions when not terminal. This is authored toy reward shaping, **not** proof of optimal fairness; log the separate damage/survival components and fail if reward cannot be reconstructed from authoritative deltas. Do not alter the player's damage rules to flatter a policy.

Before seeing #4 blind results, use development-only seeds (new to #5, distinct from 700–707 and ALL reserved sets) to require **at least 4/8 1v1 wins** and **at most 3/8 goblin losses** in the post-attack-lunge phase (v2 had 1/8 wins and 7/8 losses), >=90% of v2 ten-goblin damage on the same dev starts and no increase in group defeats. These are *pre-blind advancement criteria*, not certification. Report per-style tradeoffs; if budgets fail, stop/revise using development-only data and re-freeze a NEW blind set if #4 has been opened. #7 separately measures rendered 8–20-agent full-action p50/p95/p99, memory and overload; provisional 20-active-agent development target: p95 <= 1.2 ms and p99 <= 2.5 ms across at least three rendered runs, with failure counts. This is not a hard realtime or multi-machine guarantee.
