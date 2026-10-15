# Watch goblin retreat requests live (isolated Godot arena; ReNemiSys #16)

From `ReNemiSys/` on this Windows/Godot **4.4.1 CPU** setup:

```powershell
python demos/adaptive_arena/live_retreat_demo.py --godot ../SaLMon/build/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe
```

A Godot window opens with **ten nearby goblins surrounding the player**, including **#0, a low-HP (1), low-courage (0.2) coward** trapped behind #1. A *clearly labeled authored fixture rule* gives that coward a legal retreat intention; #1 independently consents to clear space and #0 physically escapes. The scene starts in **slow motion** so you can see the decision and replays every 20 simulated seconds. This is a spatial/permission demo, **NOT proof the shared v3 policy learned cowardice**; use `7` for an actual natural-policy fight, where retreat is not guaranteed. Blue is the stationary player, orange circles are goblins. Orange `retreat` labels identify requesters; a **green** arrow/body denotes an ally voluntarily sidestepping; **red** is refusal; **yellow** is an independently open counter-route. The HUD shows requester/recipient IDs, accepted/refused/counter/conflict counts, real physical egress distance and the time to escape 30px. Decisions are *synchronous local combat rules*, never SaLMon, an LLM queue, a remote request or a forced personality change. Godot validates the chosen path and damage.

| Key | Live case / action |
| --- | --- |
| `1` | Default **scripted coward dogpile**: nearby crowd, wounded coward #0 retreats, #1 may consent |
| `2` | Wounded ally rationally refuses; nobody forces it aside |
| `3` | Wounded ally refuses, requester uses another legal corridor |
| `4` | Two-hop local space request |
| `5` | Wall blocks the outward lane but leaves an open sideways escape |
| `6` | Two requesters contest one helper; only independently legal routes execute |
| `7` | Natural *development-only* v3 shared-policy tactics against the moving scripted player (not a guaranteed retreat) |
| `8` | Two requesters with separate helpers |
| `9` | Wall and both side routes blocked: legal guard/refusal |
| `0` | Approved helper unloads, invalidating its old plan |
| `N` | Toggle ally requests ON/OFF and reset the same fixture (recovery stays identical) |
| `R` | Reset the current fixture; `Tab` cycles **only** development seeds 900–907 |
| `S` / `Space` / `Esc` | Slow motion (0.35×; makes brief consent easier to see) / pause / close |

Optional launch cases: `--case approve` (the earlier *two-body* physics fixture), `--case deny`, `--case contested`, `--case natural`, `--consent-off`, `--agents 8` or `--agents 20`. The **default 10-agent** view shows the full authored crowd best.

For a short **physical contrast** on this same scripted development case, run `python demos/adaptive_arena/retreat_live_physics_check.py --godot /path/to/Godot_v4.4.1-stable_win64_console.exe`. With consent **OFF**, the coward tried retreating but moved only **1.0px** in 1.2 simulated seconds (zero approvals). With consent **ON**, three local approvals let it escape **105.8px**, first crossing 30px in **0.55 simulated seconds**, with no >1px final goblin overlaps in either check. This demonstrates the *specific authored layout*, not a new held-out or learned-policy success. You can run `--smoke --screenshot` to make a brief **rendered** preview (0.34 simulated seconds in the dogpile, 2 seconds in other cases) at `user://retreat_live_preview.png` in the Godot app userdata directory; this is a still image, not combat evaluation. `--smoke` alone is headless and cannot verify the visual presentation. `retreat_live_check.gd` exercises the development-only keyboard/reset and persistent-identity boundary; neither mode uses sealed evaluation seeds.

The launcher **refuses missing or mismatched** external `user://physics_policy_v3.json` (SHA-256 `1b46652d17e7966d8dba63696e7cb9dfe67a32d63a2c4911bf2119a16ee162e1`); it never copies weights into Git or exported PCKs. If absent, follow the offline-training steps in [README.md](README.md) before launching. This script intentionally strips inherited `ARENA_*` variables and sets the restrictive 900–907 Godot fixture contract. Launching the scene directly without it is rejected.

**Scope:** This is a view of #13's deliberately scripted physics exercises, **not** the main ReNemiSys game, a recorded win-rate, a subsecond deadline guarantee, or proof of human-facing combat fairness. The `natural` case also uses previously opened development starts, not a fresh generalization test. [#15](https://github.com/Hunter174/ReNemiSys/issues/15) still owns the newly frozen movement/collision and rendered CPU gate; #8 and #14 remain gated. There is no SaLMon call or character-identity modification in the live loop.
