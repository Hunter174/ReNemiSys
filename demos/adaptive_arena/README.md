# Adaptive goblin arena (isolated prototype; issue #1)

This **separate Godot 4.4.1 project** does not change or load ReNemiSys's existing game scenes, SaLMon or MLGodotKit. It is a first, deliberately small RL **tabular** baseline, not a trained neural-network opponent or a real combat game. A single learned Q-table is shared by all goblins. Each goblin supplies its own persistent courage/ambition and a rolling five-move estimate of the player's observed style. The model cannot see the opponent's *next* move. Godot's abstract combat environment computes outcomes, then offline Q-learning updates the shared weights; live inference never trains. Only authoritative game code could eventually grant an epiphany event. Training happens in a headless script, never in a physics tick.

```sh
# From ReNemiSys/: train, exercise assertions and save local pretrained Q weights.
Godot-4.4.1 --headless --path demos/adaptive_arena --script res://arena_check.gd
# After successful training, launch the synthetic rendered display.
Godot-4.4.1 --path demos/adaptive_arena --rendering-method gl_compatibility
# For a reproducible 20-second rendered frame-time report, set ARENA_AUTORUN=1.
```

The JSON artifact is saved under Godot's `user://adaptive_policy_v1.json` (outside the Git tree) with version/action schema and a SHA-256 integrity check. It is not exported or a secure signature. The local demo verifies identical weights on reload, malformed artifact rejection, action masks, safe choice for unseen states without mutating weights, personality-dependent low-health tactics, absence of a mid-fight trait rewrite, and an explicitly authorized, idempotent epiphany event. Four scripted training archetypes (rush, dodge right/left, kite) and a separate seeded stochastic opponent that changes dodge bias mid-fight test whether remembered behavior changes tactics. The payoff mechanics are authored **for this toy environment**; performance here is not evidence of realistic combat strategy or robustness against unseen players.

On this laptop, one Godot 4.4.1 headless run reported **0.346 ms p95** for selecting actions for **20 goblins in total**, including game-side observation and mask handling (400 samples); a separate non-headless 20-second synthetic scene reported **1.553 ms p95** per 20-goblin decision burst, frame-interval p95 **16.845 ms**, max **20.145 ms**. These are not worst-case or actual-game guarantees; no GPU inference benchmark was run. The opponent that switched between stochastic dodge preferences yielded 48.2 aggregate toy reward versus −70.0 for a fixed `pressure` opponent, and actions switched with the observations. Do not generalize this authored payoff metric to fighting ability.

**Next:** build a genuine collision/stamina/damage encounter using ReNemiSys's actual entities in a *separate integration step*, compare against stronger fixed baselines and held-out player strategies, define persistent player-style memory across loops, and validate MLGodotKit's shared pretrained neural-weight lifecycle under [Hunter174/MLGodotKit#50](https://github.com/Hunter174/MLGodotKit/issues/50) (with serialization tracked in #35 there). SaLMon remains separate; a future game orchestrator may pass validated, infrequent diplomatic/strategic character proposals through the authoritative epiphany ledger. Neither issue is closed by this baseline.
