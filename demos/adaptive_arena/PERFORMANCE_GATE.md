# Isolated CPU combat timing and overload gate (ReNemiSys #7)

Local Windows Godot 4.4.1, gl_compatibility, CPU; physics v3 shared policy, one learned team for 20 *rendered* seconds with the development-only scenario (no blind 610xx opponent). An observation-to-action pass contains state, visible motion cue, legal mask and one model lookup per living goblin; only passes with ALL agents alive are counted for the full-pass percentiles. No GPU, exported game, production entities, reproducible worst-case guarantee or headless wall-clock inference claim.

## Repeated rendered runs after hoisting synthetic-test environment settings out of the combat hot loop

Three **separate** 20-second runs per agent count. Numbers are p50/p95/p99 milliseconds of full-active observation-to-action, frame interval p95/p99 milliseconds, `Performance.MEMORY_STATIC` MiB (Godot allocator monitor, **not process peak RSS**) and full-active passes. Zero illegal actions, timeout fallbacks and stale fallbacks in all ordinary runs.

| Agents | Run 1 full action | Run 2 full action | Run 3 full action | Frame p95/p99 range | Static MiB | Full passes |
| --- | --- | --- | --- | --- | ---: | ---: |
| 8 | 0.339/0.753/0.964 | 0.332/0.542/0.694 | 0.334/0.558/1.017 | 17.205–17.428 / 18.110–18.698 | 27.0 | 92 each |
| 10 | 0.402/0.605/0.985 | 0.400/0.715/1.347 | 0.389/0.746/1.198 | 17.199–17.449 / 17.895–18.696 | 27.1 | 92 each |
| 20 | 0.699/1.201/2.350 | 0.690/1.093/2.673 | 0.701/1.014/2.556 | 17.446–17.719 / 19.015–19.212 | 27.6 | 88 each |

The 20-agent provisional p95 <=1.2 ms and p99 <=2.5 ms target was **not met in this set** (one p95=1.201 and two p99s >2.5). A previous version read test environment variables inside every NPC hot loop and had 20-agent p99 up to 4.471 ms. Hoisting those reads and rerunning three development scenes gave 20-agent full-pass p50/p95/p99 **0.545/0.905/2.194**, **0.550/0.825/1.606**, **0.568/1.015/1.810** ms; frame p95 **17.468/17.370/17.561**, p99 **18.845/18.923/18.954** ms. These follow-up measurements satisfy the provisional target in those three runs, but still do **not** establish a CPU worst-case guarantee; one large OS/GC scheduling outlier can reappear. Do not use headless `--fixed-fps 240` measurements to make gameplay frame claims.

## Bounded synthetic fallback (not a faster model decision)

`python demos/adaptive_arena/budget_check.py --godot /path/to/Godot_v4.4.1-stable_win64_console.exe` executes three development-only 20-agent scenarios and rejects illegal actions or unexpected outcomes. Normal 100ms budget: 92 decision bursts, zero fallbacks. One synchronous 3ms fake backend stall per burst under a 1.2ms budget: **92 bursts, 1,840 legal guard fallbacks**, no selected action from the invalid burst executed; observed p95 observation-to-**fallback** was ~4.0ms despite the 1.2ms budget. Forced game-owned revision change during selection under a generous budget: 92 bursts, **1,840 stale-choice legal guard fallbacks**, zero timeout fallbacks. These demonstrate atomic batch invalidation, but **synchronous work cannot be cancelled retroactively** and a fallback does not count as a timely learned decision. All injection flags are refused in collection, diagnostics, blind evaluation and non-20-agent scenes.

The body-block/dogpile problem is separate: model inference under 1ms does not imply an actor can physically execute retreat. Consent-based collision-safe coordination is tracked in #13, with future tuning #14. Any new movement physics invalidates direct comparison to this pre-coordination combat baseline unless re-evaluated under a new versioned contract.
