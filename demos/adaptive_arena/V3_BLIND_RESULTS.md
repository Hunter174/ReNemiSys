# Once-opened blind results, v3-blind-v1 (#6; no retuning)

The opponent, 8 seeds, success budgets and continuous-bout protocol were frozen in [V3_BLIND_PROTOCOL.md](V3_BLIND_PROTOCOL.md) (`9bbba50`) **before** v3 training. Additive counters in [V3_BLIND_TELEMETRY.md](V3_BLIND_TELEMETRY.md) were committed in `597d45a` **before** either sealed run. Both separate immutable local-only reports were generated once with Godot 4.4.1 CPU, process-isolated per seed/team/mode, and marked read-only outside Git:

| Report | Local-only path | SHA-256 |
| --- | --- | --- |
| v2 baseline | `C:/Users/7568316/AppData/Local/Temp/v3-blind-20261012-230947-v2.json` | `1a7c7c91cf1e4512f69cebceaf1a470ec62eef4f6b058e66894ac0c6c618691b` |
| v3 | `C:/Users/7568316/AppData/Local/Temp/v3-blind-20261012-230947-v3.json` | `cbb91e162773e38fb3151907bc068f4dfdfa9180f1496db4f2cbc32ba27c6a72` |

Separate local artifacts were verified before evaluation: v2 SHA-256 `aa4858af6ef4413088e8665bb556b12a05ff196a311a48bfdc4697c549436572`, v3 SHA-256 `1b46652d17e7966d8dba63696e7cb9dfe67a32d63a2c4911bf2119a16ee162e1`. No weight changed and no 610xx case entered training. 64 processes per report: eight seeds × (group, duel) × (learned, fixed, conservative, authored FSM). All 256 cross-report phase snapshots had matching seeded start hashes and *opponent rule* hashes. Actual trajectories may diverge because the opponent reacts to current game state. Zero illegal actions; all phase HP/death counters monotonic, all runs completed.

## Frozen comparative thresholds: PASS within this narrow experiment

| Metric | v2 learned | v3 learned | Precommitted criterion |
| --- | ---: | ---: | --- |
| Duel wins / losses / timeouts (8 independent **bouts**) | 0 / 8 / 0 | **8 / 0 / 0** | Wins >= v2; losses <= v2: PASS |
| Group hits / damage to player (8 bouts) | 666 | **650** | >=90% of 666 (=599.4): PASS (97.6%) |
| Group goblins defeated | 34 | **19** | <=34: PASS |
| Group player defeats / timeouts | 1 / 7 | **1 / 7** | Report; NO improvement in this outcome |
| Goblins killed while stamina <2 (group) | 5 | **5** | Descriptive; low stamina co-occurs with a lethal hit, NOT proven causal |
| Decision samples at stamina <2 (group) | 1457 | **659** | Descriptive, unnormalized across changing survival/time; NOT a per-actor rate |

Per-seed group final damage and goblins defeated (one continuous 20s fight per seed, **not four independent phases**):

| Seed | v2 damage / dead | v3 damage / dead | Authored FSM damage / dead |
| --- | --- | --- | --- |
| 61001 | 76 / 3 | 91 / 4 | 59 / 2 |
| 61013 | 100 / 3 | 88 / 2 | 49 / 1 |
| 61027 | 88 / 4 | 62 / 3 | 88 / 0 |
| 61039 | 89 / 5 | 94 / 3 | 57 / 1 |
| 61051 | 90 / 5 | 68 / 2 | 83 / 3 |
| 61069 | 45 / 5 | 100 / 2 | 64 / 3 |
| 61081 | 87 / 5 | 59 / 1 | 55 / 2 |
| 61097 | 91 / 4 | 88 / 2 | 67 / 2 |

All eight v3 duels won; all eight v2 duels lost; authored FSM also won all eight. **Every duel ended in the first `wall_switch` phase**, so the duel result says NOTHING about later style reversals or long-fight endurance. Eight starts and one reactive scripted opponent are limited evidence, not a significance or main-game win-rate claim. Other group baselines on the same v3 report: fixed pressure 644 damage / 29 dead / 2 player defeats; conservative 0 damage / 0 dead / 8 timeouts; authored FSM 522 damage / **14 dead** / 0 player defeats. V3 still lost more goblins than that FSM despite dealing more damage. No blind result certifies team coordination.

## Reversals, observed actions, and fairness boundary

Group per-phase v2 -> v3 damage: `wall_switch` **188 -> 149**, `bait_hold` **199 -> 144**, `reach_cycle` **174 -> 188**, `cross_feint` **105 -> 169**. V3's selected retreat actions by phase were 51 / 140 / 79 / 106 versus v2's 100 / 66 / 23 / 4; v3 guard actions were 351 / 477 / 642 / 662 versus v2's 300 / 572 / 679 / 520. This demonstrates changed *aggregate* visible-motion responses, not proof an individual adapted correctly: surviving-agent mix, distance, HP and stamina also change. Raw report retains every per-seed phase snapshot, hit counter and action count.

Player motion and previous NPC actions are observable to the policy, not the hidden scripted phase label or future trajectory. Nothing in these counters evaluates animation/attack windup visibility or a human player's sense of fairness/telegraphing; **that gate remains unvalidated**. Headless `--fixed-fps 240` is accelerated evaluation, not rendered CPU timing. This is the **opt-out/uncoordinated** arena: #13's ally-consent movement is disabled and has its own unresolved natural-contact/attrition tradeoff. Both reports are now opened; NEVER tune to 610xx or reuse them as fresh evidence. A new movement rule or policy requires a different precommitted opponent/seed suite. #2 remains open; no main-game integration is certified.
