extends Node2D
# Isolated combat integration: real Godot physics bodies + overlap-based hits.
# It does NOT alter the existing ReNemiSys main game. The shared policy never trains here.
const Core = preload("res://combat_core.gd")
const RADIUS := 12.0
const ACTION_PERIOD := 0.2
# Frozen before evaluating this extension. These are disjoint from 222–237 and 29011.
const HELDOUT_SEEDS := [31001, 31009, 31019, 31033, 31051, 31063, 31069, 31079]
# Predeclared *new* styles and seeds; neither may enter training. Freeze before tuning.
const NOVEL_SEEDS := [41011, 41023, 41047, 41059, 41071, 41081, 41093, 41101]
# Second, independent set reserved for process-isolated comparison after discovering
# sequential-mode physics carryover. No collection and no model tuning on these.
const ISOLATED_SEEDS := [42013, 42017, 42043, 42061, 42073, 42089, 42101, 42131]
# Reserved for a NEW opponent that responds to visible NPC actions/HP/distance.
const REACTIVE_SEEDS := [51001, 51011, 51023, 51047, 51059, 51071, 51083, 51103]
const REACTIVE_STYLES := ["counter_tactic", "hunt_injured", "range_control", "tire_out"]
# Frozen for v3 ONLY. Never use these seeds or rules in training/diagnostics.
const V3_BLIND_SEEDS := [61001, 61013, 61027, 61039, 61051, 61069, 61081, 61097]
const V3_BLIND_STYLES := ["wall_switch", "bait_hold", "reach_cycle", "cross_feint"]
const NOVEL_STYLES := ["feint", "burst_kite", "orbit_flip", "stop_go"]

class Actor extends CharacterBody2D:
    var mind
    var action := "guard"
    var hp := 8.0
    var stamina := 5.0
    var cooldown := 0.0
    var attack_area: Area2D
    var learned := true
    var enabled := true
    var hits := 0
    var last_state := ""
    var last_action := ""
    var last_hp := 0.0
    var last_hits := 0
    var last_stamina := 5.0
    var diag_pending := {}

    func _ready() -> void:
        var shape := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = 12.0
        shape.shape = circle
        add_child(shape)
        attack_area = Area2D.new()
        attack_area.collision_layer = 0
        attack_area.collision_mask = 2 if collision_layer == 1 else 1
        attack_area.monitoring = true
        var reach := CollisionShape2D.new()
        var range_circle := CircleShape2D.new()
        range_circle.radius = 37.0
        reach.shape = range_circle
        attack_area.add_child(reach)
        add_child(attack_area)

var policy = Core.SharedPolicy.new()
var goblins: Array[Actor] = []
var player: Actor
var elapsed := 0.0
var decision_timer := 0.0
var attack_timer := 0.0
var last_frame_us := 0
var frame_intervals: Array[float] = []
var decision_ms: Array[float] = []
var full_decision_ms: Array[float] = []
var phases := ["dodge_right", "dodge_left", "rush", "kite"]
var novel := OS.get_environment("ARENA_NOVEL") == "1"
var reactive := OS.get_environment("ARENA_REACTIVE") == "1"
var v3_blind := OS.get_environment("ARENA_V3_BLIND") == "1"
var long_bout := OS.get_environment("ARENA_LONG_BOUT") == "1"
var blind_dry_run := OS.get_environment("ARENA_BLIND_DRY_RUN") == "1"
var blind_v2_baseline := OS.get_environment("ARENA_BLIND_V2_BASELINE") == "1"
var team_size := 10
var current_phase := -1
var phase_elapsed := 0.0
var current_mode := 0
var evaluation_modes: Array[String] = ["learned", "fixed"]
var duel := OS.get_environment("ARENA_DUEL") == "1"
var legal_violations := 0
var timeout_fallbacks := 0
var stale_fallbacks := 0
var budgeted_bursts := 0
var frame_budget_enabled := OS.has_environment("ARENA_FRAME_BUDGET_MS")
var frame_budget_ms: float = maxf(0.0, float(OS.get_environment("ARENA_FRAME_BUDGET_MS"))) if frame_budget_enabled else INF
var fake_slow_us := maxi(0, OS.get_environment("ARENA_FAKE_SLOW_US").to_int())
var fake_stale := OS.get_environment("ARENA_FORCE_STALE") == "1"
var injuries := {"learned": 0, "fixed": 0, "conservative": 0, "authored_fsm": 0, "player": 0}
var tactics := {}
var phase_tactics := {}
var phase_hits := {}
var noise_rng := RandomNumberGenerator.new()
var noise_timer := 0.0
var noisy_style := "dodge_right"
var episode_results := []
var final_recorded := false
var observed_styles := ""
var starting_slots_hash := ""
var collecting := OS.get_environment("ARENA_COLLECT") == "1"
var physics_policy := OS.get_environment("ARENA_USE_PHYSICS_POLICY") == "1"
var refined := OS.get_environment("ARENA_REFINED") == "1"
var v3 := OS.get_environment("ARENA_V3") == "1"
var diagnostic := OS.get_environment("ARENA_DIAGNOSTIC") == "1"
var diag_rows := []
var rollouts := []
var placement_rng := RandomNumberGenerator.new()
var training_seed := 222
var scenario_seed := 991

func percentile(values: Array[float], fraction: float) -> float:
    values.sort()
    return values[clampi(ceili(float(values.size()) * fraction) - 1, 0, values.size() - 1)]

func _ready() -> void:
    if v3_blind:
        if collecting or diagnostic or novel or reactive or not physics_policy or not refined or (OS.get_environment("ARENA_V3") != "1" and not blind_dry_run and not blind_v2_baseline) or (int(blind_dry_run) + int(blind_v2_baseline) + int(OS.get_environment("ARENA_V3") == "1")) != 1 or not OS.has_environment("ARENA_SINGLE_TEAM") or not long_bout or (blind_dry_run and (OS.has_environment("ARENA_HELDOUT_SEED") or OS.get_environment("ARENA_DEV_SEED") != "700")) or (not blind_dry_run and not OS.has_environment("ARENA_HELDOUT_SEED")):
            push_error("Blind v3 requires immutable v3 inference and a single long-bout team")
            get_tree().quit(1)
            return
        phases = V3_BLIND_STYLES.duplicate()
    if v3 and not refined:
        push_error("V3 requires the refined visible-motion observation base")
        get_tree().quit(1)
        return
    if diagnostic:
        var seed_text := OS.get_environment("ARENA_DEV_SEED")
        if not seed_text.is_valid_int() or not seed_text.to_int() in range(700, 708) or collecting or novel or reactive or not refined or not physics_policy or OS.get_environment("ARENA_SINGLE_TEAM") != "learned" or OS.has_environment("ARENA_HELDOUT_SEED") or OS.has_environment("ARENA_FINAL_SEED") or OS.has_environment("ARENA_EVAL_SEED"):
            push_error("Diagnostics require refined inference, one learned team and development seeds 700–707 only")
            get_tree().quit(1)
            return
        if OS.get_environment("ARENA_DEV_LUNGE") == "1":
            phases = ["dodge_right", "dodge_left", "post_attack_lunge", "kite"]
    if (novel and reactive) or (v3_blind and (novel or reactive)):
        push_error("Select only one evaluation opponent")
        get_tree().quit(1)
        return
    if reactive:
        phases = REACTIVE_STYLES.duplicate()
    elif novel:
        phases = NOVEL_STYLES.duplicate()
    if OS.has_environment("ARENA_AGENTS"):
        team_size = OS.get_environment("ARENA_AGENTS").to_int()
        if not team_size in [8, 10, 20]:
            push_error("ARENA_AGENTS must be 8, 10 or 20")
            get_tree().quit(1)
            return
    if (frame_budget_enabled or fake_slow_us > 0 or fake_stale) and (collecting or diagnostic or v3_blind or OS.get_environment("ARENA_SINGLE_TEAM") != "learned" or team_size != 20 or OS.has_environment("ARENA_HELDOUT_SEED")):
        push_error("Synthetic budget/revision injection is development-only and requires a 20-agent learned team")
        get_tree().quit(1)
        return
    if OS.get_environment("ARENA_EXTENDED") == "1" and not collecting:
        evaluation_modes.append_array(["conservative", "authored_fsm"])
    if OS.has_environment("ARENA_SINGLE_TEAM"):
        var team := OS.get_environment("ARENA_SINGLE_TEAM")
        if collecting or not team in ["learned", "fixed", "conservative", "authored_fsm"]:
            push_error("Invalid single-team evaluation mode")
            get_tree().quit(1)
            return
        evaluation_modes.clear()
        evaluation_modes.append(team)
    if collecting:
        if duel or novel or reactive or v3_blind or team_size != 10 or OS.get_environment("ARENA_EXTENDED") == "1":
            push_error("Rollouts require the original ten-goblin, two-team training contract")
            get_tree().quit(1)
            return
        training_seed = maxi(1, OS.get_environment("ARENA_TRAIN_SEED").to_int()) if OS.has_environment("ARENA_TRAIN_SEED") else 222
        if refined and not training_seed in (range(800, 832) if v3 else range(500, 532)):
            push_error("V3 uses training-only seeds 800–831; v2 uses 500–531")
            get_tree().quit(1)
            return
        if training_seed in [15137, 29011] or training_seed in HELDOUT_SEEDS or training_seed in NOVEL_SEEDS or training_seed in ISOLATED_SEEDS or training_seed in REACTIVE_SEEDS or training_seed in V3_BLIND_SEEDS or OS.has_environment("ARENA_HELDOUT_SEED") or OS.get_environment("ARENA_EVAL_SEED") == "15137" or OS.get_environment("ARENA_FINAL_SEED") == "29011":
            push_error("Held-out evaluation seed must not be used for training")
            get_tree().quit(1)
            return
        policy = Core.SharedPolicy.new(training_seed)
    var artifact := ("user://physics_policy_v3.json" if v3 and not blind_dry_run and not blind_v2_baseline else ("user://physics_policy_v2.json" if refined else "user://physics_policy_v1.json")) if physics_policy else "user://adaptive_policy_v1.json"
    if not (collecting and refined) and not policy.load_artifact(artifact) and not collecting:
        push_error("Policy unavailable; train first. Tried: " + artifact)
        get_tree().quit(1)
        return
    if v3 and not blind_dry_run and not blind_v2_baseline and not collecting:
        if policy.weights.is_empty():
            push_error("Refusing empty v3 blind policy")
            get_tree().quit(1)
            return
        for key in policy.weights:
            if not key is String or not key.begins_with("v3:"):
                push_error("Refusing artifact without the frozen v3 observation schema")
                get_tree().quit(1)
                return
    Engine.max_fps = 0 if collecting else 60
    var approved_seeds: Array = V3_BLIND_SEEDS if v3_blind else (REACTIVE_SEEDS if reactive else (NOVEL_SEEDS + ISOLATED_SEEDS if novel else HELDOUT_SEEDS))
    if OS.has_environment("ARENA_HELDOUT_SEED") and not int(OS.get_environment("ARENA_HELDOUT_SEED")) in approved_seeds:
        push_error("Evaluation seed is not in the predeclared held-out set")
        get_tree().quit(1)
        return
    scenario_seed = OS.get_environment("ARENA_DEV_SEED").to_int() if diagnostic or blind_dry_run else (training_seed if collecting else (int(OS.get_environment("ARENA_HELDOUT_SEED")) if OS.has_environment("ARENA_HELDOUT_SEED") else (29011 if OS.get_environment("ARENA_FINAL_SEED") == "29011" else (15137 if OS.get_environment("ARENA_EVAL_SEED") == "15137" else 991))))
    _wall(Vector2(480, 0), Vector2(960, 22))
    _wall(Vector2(480, 600), Vector2(960, 22))
    _wall(Vector2(0, 300), Vector2(22, 600))
    _wall(Vector2(960, 300), Vector2(22, 600))
    player = Actor.new()
    player.learned = false
    player.collision_layer = 1
    player.collision_mask = 6
    add_child(player)
    # The player uses an attack area that recognizes goblin layer 2.
    for i in range(team_size * 2):
        var goblin := Actor.new()
        goblin.learned = i < team_size
        goblin.collision_layer = 2
        goblin.collision_mask = 7
        goblin.mind = Core.Mind.new(0.2 if i % 2 == 0 else 0.8, 0.2 if i % 2 == 0 else 0.8)
        add_child(goblin)
        goblins.append(goblin)
    _reset_phase(0)

func _wall(center: Vector2, size: Vector2) -> void:
    var wall := StaticBody2D.new()
    wall.collision_layer = 4
    wall.collision_mask = 3
    wall.position = center
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collision.shape = shape
    wall.add_child(collision)
    add_child(wall)

func _record_phase() -> void:
    if current_phase < 0:
        return
    if collecting or diagnostic:
        for goblin in goblins:
            if goblin.enabled and goblin.learned:
                if collecting:
                    _finish_transition(goblin, goblin.last_state, [], true)
                if diagnostic:
                    _finish_diagnostic(goblin, true)
    var fallen := 0
    for goblin in goblins:
        if goblin.enabled and goblin.hp <= 0.0:
            fallen += 1
    var participants := 1 if duel else team_size
    var outcome := "goblins_win" if player.hp <= 0.0 else ("player_win" if fallen >= participants else "timeout")
    episode_results.append({"style": phases[current_phase], "team": evaluation_modes[current_mode],
        "player_hp": snappedf(player.hp, 0.1), "goblins_defeated": fallen, "outcome": outcome,
        "opponent_trace": observed_styles.sha256_text(), "starts": starting_slots_hash})

func _finish_transition(goblin: Actor, next_state: String, next_legal: Array, done: bool) -> void:
    if goblin.last_state.is_empty():
        return
    var dealt := maxi(0, goblin.hits - goblin.last_hits)
    var taken := maxf(0.0, goblin.last_hp - goblin.hp)
    # Authoritative hit/health deltas from physics, not the scripted opponent label.
    var reward: float = float(dealt) - taken * (0.6 + 0.6 * (1.0 - goblin.mind.courage)) - 0.015
    if done:
        reward += (0.2 * (1.0 - goblin.mind.courage)) if goblin.hp > 0.0 else -0.4
    var spent := maxf(0.0, goblin.last_stamina - goblin.stamina)
    if v3:
        reward = (1.0 + 0.2 * goblin.mind.ambition) * float(dealt) - (1.1 + 0.6 * (1.0 - goblin.mind.courage)) * taken - 0.04 * spent - 0.015
        if done:
            reward += (0.2 * (1.0 - goblin.mind.courage)) if goblin.hp > 0.0 else -0.8
        reward = clampf(reward, -10.0, 10.0)
    var row := {"state": goblin.last_state, "action": goblin.last_action,
        "reward": reward, "next_state": next_state, "next_legal": next_legal.duplicate(), "done": done}
    if v3:
        row["dealt"] = dealt
        row["taken"] = taken
        row["stamina_spent"] = spent
        row["courage"] = goblin.mind.courage
        row["ambition"] = goblin.mind.ambition
        row["alive"] = goblin.hp > 0.0
    rollouts.append(row)
    goblin.last_state = ""

func _finish_diagnostic(goblin: Actor, terminal: bool) -> void:
    if goblin.diag_pending.is_empty():
        return
    var row: Dictionary = goblin.diag_pending.duplicate()
    row["dealt"] = maxi(0, goblin.hits - row.hit_baseline)
    row["taken"] = maxf(0.0, row.hp_baseline - goblin.hp)
    row["terminal"] = terminal or goblin.hp <= 0.0
    row.erase("hit_baseline")
    row.erase("hp_baseline")
    if diag_rows.size() < 2000:
        diag_rows.append(row)
    goblin.diag_pending = {}

func _save_rollouts() -> bool:
    var all_transitions: Array = rollouts.duplicate()
    var seeds := [training_seed]
    var path := "user://physics_rollouts_v3.json" if v3 else ("user://physics_rollouts_v2.json" if refined else "user://physics_rollouts_v1.json")
    if OS.get_environment("ARENA_APPEND") == "1":
        if not FileAccess.file_exists(path):
            return false
        var existing = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not existing is Dictionary or existing.get("version") != (3 if v3 else 1) or (v3 and existing.get("schema") != "v3-observation-reward-v1") or not existing.get("transitions_json") is String or existing.transitions_json.sha256_text() != existing.get("sha256"):
            return false
        var earlier = JSON.parse_string(existing.transitions_json)
        if not earlier is Array or earlier.size() > 100000 or not existing.get("train_seeds") is Array or existing.train_seeds.has(training_seed):
            return false
        seeds = existing.train_seeds.duplicate()
        seeds.append(training_seed)
        all_transitions = earlier + rollouts
    if all_transitions.size() > 100000:
        return false
    var text := JSON.stringify(all_transitions)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"version": 3 if v3 else 1, "schema": "v3-observation-reward-v1" if v3 else "legacy",
        "train_seeds": seeds, "sha256": text.sha256_text(), "transitions_json": text}))
    file.close()
    return true

func _reset_phase(index: int, new_team: bool = false) -> void:
    current_phase = index
    phase_elapsed = 0.0
    # Rewind the opponent and placement streams at each paired phase. Both teams
    # see the SAME seeded style schedule and ten starting slots, not sequential RNG draws.
    noise_rng.seed = scenario_seed + index * 1013
    placement_rng.seed = scenario_seed + index * 1009
    player.position = Vector2(480, 300)
    player.velocity = Vector2.ZERO
    player.hp = 3.0 if duel else 100.0
    player.stamina = 5.0
    player.cooldown = 0.0
    attack_timer = 0.0
    var starts: Array[Vector2] = []
    var starts_text := ""
    observed_styles = ""
    if v3_blind:
        observed_styles = "v3-blind-v1:%s:%d" % [phases[index], scenario_seed]
    if reactive:
        # The opponent contract, NOT an identical trajectory: it reacts to each
        # team's visible actions and can legitimately follow a different path.
        observed_styles = "reactive-v1:%s:%d" % [phases[index], scenario_seed]
    if novel:
        # Hash the complete precommitted schedule: death cannot truncate the trace.
        for step_index in range(25):
            var t := float(step_index) * ACTION_PERIOD
            var step := ""
            match phases[index]:
                "feint": step = "right" if fmod(t, 0.8) < 0.4 else "left"
                "burst_kite": step = "rush" if fmod(t, 1.2) < 0.3 else "kite"
                "orbit_flip": step = "right" if int(t / 1.25) % 2 == 0 else "left"
                "stop_go": step = "still" if fmod(t, 0.8) < 0.25 else "rush"
            observed_styles += step + ","
    for slot in range(team_size):
        var position := Vector2(175 + (slot % 5) * 150, (160 + (slot / 5) * 110) if team_size == 20 else (220 + (slot / 5) * 140))
        if collecting or scenario_seed != 991:
            position += Vector2(placement_rng.randi_range(-28, 28), placement_rng.randi_range(-22, 22))
        starts.append(position)
        starts_text += "%.1f,%.1f|" % [position.x, position.y]
    starting_slots_hash = starts_text.sha256_text()
    for i in range(goblins.size()):
        var actor: Actor = goblins[i]
        var local_index := i % team_size
        actor.enabled = (actor.learned if evaluation_modes[current_mode] == "learned" else not actor.learned) and (not duel or local_index == 7)
        if new_team and not actor.learned:
            actor.mind.player_moves.clear()
        actor.collision_layer = 2 if actor.enabled else 0
        actor.collision_mask = 7 if actor.enabled else 0
        actor.attack_area.monitoring = actor.enabled
        actor.position = starts[local_index] if actor.enabled else Vector2(-2000, -2000)
        actor.hp = 4.0
        actor.last_state = ""
        actor.last_action = ""
        actor.last_hp = actor.hp
        actor.last_hits = actor.hits
        actor.diag_pending = {}
        actor.stamina = 5.0
        actor.last_stamina = actor.stamina
        actor.cooldown = 0.0
        actor.velocity = Vector2.ZERO
        actor.action = "guard"
    decision_timer = 0.0
    noise_timer = 1.0 # Force a new, seeded observable style at the phase boundary.

func _advance_blind_phase(index: int) -> void:
    # Continuing fight: preserve HP, stamina, position, per-agent beliefs and
    # original start hash. Only opponent rule and phase clock change.
    current_phase = index
    phase_elapsed = 0.0
    observed_styles = "v3-blind-v1:%s:%d" % [phases[index], scenario_seed]

func _baseline_action(goblin: Actor, legal: Array) -> String:
    var team: String = evaluation_modes[current_mode]
    if team == "conservative":
        return "retreat" if goblin.hp <= 3.0 and goblin.mind.courage < 0.5 else "guard"
    if team == "authored_fsm":
        if goblin.hp <= 2.0 and goblin.mind.courage < 0.5:
            return "retreat"
        # Uses previous *visible* moves, exactly like the shared policy, never the
        # current scripted style or next move. Hand-authored policy is a strong baseline.
        var belief: String = goblin.mind.player_belief()
        var tactic: String = {"rush": "guard", "kite": "pressure", "dodge_right": "flank_right", "dodge_left": "flank_left"}.get(belief, "guard")
        return tactic if legal.has(tactic) else "guard"
    return "pressure" if legal.has("pressure") else "guard"

func _physics_process(delta: float) -> void:
    if player == null:
        return
    elapsed += delta
    if elapsed >= float(evaluation_modes.size()) * 20.0:
        if not final_recorded:
            _record_phase()
            final_recorded = true
        return
    var desired_mode := mini(int(elapsed / 20.0), evaluation_modes.size() - 1)
    var desired_phase := mini(int(fmod(elapsed, 20.0) / 5.0), 3)
    if desired_mode != current_mode or desired_phase != current_phase:
        _record_phase()
        var new_team := desired_mode != current_mode
        current_mode = desired_mode
        if v3_blind and long_bout and not new_team:
            _advance_blind_phase(desired_phase)
        else:
            _reset_phase(desired_phase, new_team)
    var style: String = phases[current_phase]
    if not novel and not reactive and not v3_blind and OS.get_environment("ARENA_NOISY") == "1":
        noise_timer += delta
        if noise_timer >= 0.6:
            noise_timer = 0.0
            var alternative := "dodge_left" if style == "dodge_right" else ("dodge_right" if style == "dodge_left" else ("kite" if style == "rush" else "rush"))
            noisy_style = style if noise_rng.randf() < 0.8 else alternative
            observed_styles += noisy_style + ","
        style = noisy_style
    phase_elapsed += delta
    var nearest: Actor = null
    for goblin in goblins:
        if goblin.enabled and goblin.hp > 0.0 and (nearest == null or goblin.position.distance_squared_to(player.position) < nearest.position.distance_squared_to(player.position)):
            nearest = goblin
    if nearest == null or player.hp <= 0.0:
        player.velocity = Vector2.ZERO
        return # The phase clock continues; dead combatants take no more actions.
    var toward := (nearest.position - player.position).normalized()
    var tangent := Vector2(-toward.y, toward.x)
    var player_move := toward if style == "rush" else (-toward if style == "kite" else (tangent if style == "dodge_right" else -tangent))
    if v3_blind:
        # Frozen game-owned opponent rules, responsive to visible positions/actions.
        # Both teams face identical rules and starting slots, NOT identical paths.
        var distance := player.position.distance_to(nearest.position)
        match style:
            "wall_switch":
                var at_wall := player.position.x < 90.0 or player.position.x > 870.0 or player.position.y < 90.0 or player.position.y > 510.0
                player_move = toward if at_wall else (tangent if phase_elapsed < 2.5 else -tangent)
            "bait_hold":
                player_move = -toward if nearest.action == "guard" else (toward if fmod(phase_elapsed, 1.4) < 0.25 else -tangent)
            "reach_cycle":
                player_move = toward if distance > 150.0 else (tangent if distance < 65.0 else -toward)
            "cross_feint":
                var opening_hp := 3.0 if duel else 100.0
                player_move = tangent if player.hp > opening_hp * 0.7 else (-tangent if nearest.hp > 2.0 else toward)
    if reactive:
        # Reacts to the NPC's PREVIOUSLY visible action, stamina and health—not
        # hidden policy weights or future moves. Same opponent algorithm per team.
        var distance := nearest.position.distance_to(player.position)
        match style:
            "counter_tactic":
                match nearest.action:
                    "flank_right": player_move = -tangent
                    "flank_left", "pressure": player_move = tangent
                    "retreat": player_move = toward
                    _: player_move = -toward
            "hunt_injured": player_move = toward if nearest.hp <= 2.0 and nearest.action != "guard" else -toward
            "range_control": player_move = -toward if distance <= 90.0 else toward
            "tire_out": player_move = toward if nearest.stamina < 2.0 else tangent
    if collecting and v3 and current_phase == (2 if training_seed % 2 == 0 else 1):
        # Training-only adversaries differ from both the frozen blind opponent
        # and diagnostic cooldown probe; no held-out style label enters state.
        if training_seed % 2 == 0:
            player_move = toward if nearest.action in ["pressure", "flank_right", "flank_left"] else tangent
        else:
            player_move = -tangent if nearest.hp <= 2.0 else tangent
    if diagnostic and style == "post_attack_lunge":
        # Development-only perturbation: responds to a visible recent lunge,
        # not the frozen held-out stamina-threshold opponent or model weights.
        player_move = toward if nearest.cooldown > 0.35 and nearest.action in ["pressure", "flank_right", "flank_left"] else tangent
    if novel:
        # New test archetypes, never used to collect training rollouts. Time-dependent
        # motion is deterministic for each phase and paired team; NPCs see only velocity.
        var t := minf(phase_elapsed, 4.999)
        match style:
            "feint": player_move = tangent if fmod(t, 0.8) < 0.4 else -tangent
            "burst_kite": player_move = toward if fmod(t, 1.2) < 0.3 else -toward
            "orbit_flip": player_move = tangent if int(t / 1.25) % 2 == 0 else -tangent
            "stop_go": player_move = Vector2.ZERO if fmod(t, 0.8) < 0.25 else toward
    player.velocity = player_move * 92.0
    player.move_and_slide()
    decision_timer += delta
    if decision_timer >= ACTION_PERIOD:
        decision_timer = 0.0
        var start := Time.get_ticks_usec()
        var decision_agents := 0
        var revision_at_start := 0
        var game_revision := 0
        var injected_delay := false
        for goblin in goblins:
            if not goblin.enabled or goblin.hp <= 0.0:
                continue
            decision_agents += 1
            if fake_stale and decision_agents == 5:
                game_revision += 1 # Synthetic game-owned fact revision, after prior choices.
            if not injected_delay and fake_slow_us > 0:
                injected_delay = true
                var stall_until := Time.get_ticks_usec() + fake_slow_us
                while Time.get_ticks_usec() < stall_until:
                    pass # Test only: emulate a synchronous backend that cannot be cancelled.
            var relative := (goblin.position - player.position).normalized()
            var side := Vector2(-relative.y, relative.x)
            var cue := "rush" if player.velocity.dot(relative) > 35.0 else ("kite" if player.velocity.dot(relative) < -35.0 else ("dodge_right" if player.velocity.dot(side) > 0.0 else "dodge_left"))
            var legal := ["guard", "retreat"]
            if goblin.stamina >= 2.0:
                legal.append_array(["pressure", "flank_right", "flank_left"])
            var state: String = goblin.mind.observation(goblin.hp <= 3.0, false)
            if refined:
                # Authoritative CURRENT motion, relative to this NPC, never the
                # opponent's scripted name or next move.
                var distance := goblin.position.distance_to(player.position)
                var motion := "unknown" if v3 and player.velocity.length_squared() < 1225.0 else cue
                state += ":%s:%s" % [motion, "contact" if distance <= 55.0 else ("closing" if distance <= 145.0 else "far")]
                if v3:
                    var stamina_band := "spent" if goblin.stamina < 2.0 else ("fragile" if goblin.stamina < 3.5 else "ready")
                    var recovery := "recovering" if goblin.cooldown > 0.35 else "available"
                    var threat := "threat" if distance <= 65.0 and player.velocity.dot(relative) > 35.0 else "safe"
                    state = "v3:" + state + ":%s:%s:%s" % [stamina_band, recovery, threat]
            if v3_blind and not blind_dry_run and not blind_v2_baseline and not state.begins_with("v3:"):
                push_error("Refusing blind evaluation until the versioned v3 state is implemented")
                get_tree().quit(1)
                return
            if collecting and goblin.learned:
                _finish_transition(goblin, state, legal, goblin.hp <= 0.0)
            if diagnostic and goblin.learned:
                _finish_diagnostic(goblin, goblin.hp <= 0.0)
            goblin.action = policy.select(state, legal, (0.8 if refined else 0.55) if collecting else 0.0) if goblin.learned else _baseline_action(goblin, legal)
            if collecting and goblin.learned:
                goblin.last_state = state
                goblin.last_hp = goblin.hp
                goblin.last_hits = goblin.hits
                goblin.last_stamina = goblin.stamina
            if not legal.has(goblin.action):
                legal_violations += 1
                goblin.action = "guard"
            if collecting and goblin.learned:
                goblin.last_action = goblin.action
            if diagnostic and goblin.learned:
                goblin.diag_pending = {"seed": scenario_seed, "phase": phases[current_phase],
                    "state": state, "cue": "unknown" if v3 and player.velocity.length_squared() < 1225.0 else cue,
                    "legal": legal.duplicate(), "action": goblin.action,
                    "stamina": goblin.stamina, "stamina_band": "spent" if goblin.stamina < 2.0 else "attack_legal",
                    "recovery_seconds": goblin.cooldown, "hp": goblin.hp,
                    "distance": snappedf(goblin.position.distance_to(player.position), 0.1),
                    "courage": goblin.mind.courage, "ambition": goblin.mind.ambition,
                    "hit_baseline": goblin.hits, "hp_baseline": goblin.hp}
            if goblin.learned:
                tactics[goblin.action] = tactics.get(goblin.action, 0) + 1
                var by_phase: String = "%s_%s" % [phases[current_phase], goblin.action]
                phase_tactics[by_phase] = phase_tactics.get(by_phase, 0) + 1
            goblin.mind.observe_player("unknown" if v3 and player.velocity.length_squared() < 1225.0 else cue) # After choice; only visible velocity.
        var elapsed_decision := float(Time.get_ticks_usec() - start) / 1000.0
        if frame_budget_enabled or fake_stale:
            var stale := game_revision != revision_at_start
            var expired := frame_budget_enabled and elapsed_decision > frame_budget_ms
            budgeted_bursts += 1
            if stale or expired:
                for actor in goblins:
                    if actor.enabled and actor.hp > 0.0:
                        # Atomic rejection: NONE of this burst's old choices execute.
                        if actor.action != "guard" and actor.learned:
                            tactics[actor.action] -= 1
                            tactics["guard"] = tactics.get("guard", 0) + 1
                            var old_phase_key: String = "%s_%s" % [phases[current_phase], actor.action]
                            phase_tactics[old_phase_key] -= 1
                            var guard_key: String = "%s_guard" % phases[current_phase]
                            phase_tactics[guard_key] = phase_tactics.get(guard_key, 0) + 1
                        actor.action = "guard" # Always present in the game-owned mask.
                        if stale:
                            stale_fallbacks += 1
                        else:
                            timeout_fallbacks += 1
        elapsed_decision = float(Time.get_ticks_usec() - start) / 1000.0
        decision_ms.append(elapsed_decision)
        if decision_agents == (1 if duel else team_size):
            full_decision_ms.append(elapsed_decision)
    for goblin in goblins:
        if not goblin.enabled or goblin.hp <= 0.0:
            goblin.velocity = Vector2.ZERO
            continue
        goblin.stamina = minf(5.0, goblin.stamina + delta * 1.0)
        goblin.cooldown = maxf(0.0, goblin.cooldown - delta)
        var to_player := (player.position - goblin.position).normalized()
        var side := Vector2(-to_player.y, to_player.x)
        match goblin.action:
            "pressure": goblin.velocity = to_player * 108.0
            "flank_right": goblin.velocity = (to_player + side * 0.3).normalized() * 112.0
            "flank_left": goblin.velocity = (to_player - side * 0.3).normalized() * 112.0
            "retreat": goblin.velocity = -to_player * 115.0
            _: goblin.velocity = Vector2.ZERO
        goblin.move_and_slide()
        # The animation/physics velocity and overlap decide whether the attack connects,
        # not the NPC's claim about what the player intended to do.
        var lateral := player.velocity.dot(side)
        var advancing := player.velocity.dot(-to_player)
        var connects := (goblin.action == "pressure" and absf(lateral) < 35.0) or (
            goblin.action == "flank_right" and lateral < -25.0) or (
            goblin.action == "flank_left" and lateral > 25.0) or (
            goblin.action == "guard" and advancing > 35.0)
        if connects and goblin.cooldown == 0.0 and goblin.attack_area.get_overlapping_bodies().has(player) and (not v3_blind or player.hp > 0.0):
            if goblin.action == "guard" or goblin.stamina >= 2.0:
                goblin.stamina -= 0.0 if goblin.action == "guard" else 2.0
                goblin.cooldown = 0.7
                player.hp = maxf(0.0, player.hp - 1.0) if v3_blind else player.hp - 1.0
                goblin.hits += 1
                injuries[evaluation_modes[current_mode]] += 1
                var phase_key: String = "%s_%s" % [phases[current_phase], evaluation_modes[current_mode]]
                phase_hits[phase_key] = phase_hits.get(phase_key, 0) + 1
    attack_timer += delta
    if attack_timer >= 0.7:
        attack_timer = 0.0
        var overlaps: Array[Node2D] = player.attack_area.get_overlapping_bodies()
        # Stable priority independent of physics-server overlap iteration order.
        for target in goblins:
            if target.enabled and overlaps.has(target) and target.hp > 0.0 and target.action != "guard":
                target.hp = maxf(0.0, target.hp - 1.0)
                injuries.player += 1
                break
    queue_redraw()

func _process(_delta: float) -> void:
    var now := Time.get_ticks_usec()
    if last_frame_us != 0:
        frame_intervals.append(float(now - last_frame_us) / 1000.0)
    last_frame_us = now
    if elapsed >= float(evaluation_modes.size()) * 20.0 and final_recorded and (OS.get_environment("ARENA_AUTORUN") == "1" or collecting):
        var paired_inputs := episode_results.size() == evaluation_modes.size() * 4
        if paired_inputs:
            for mode in range(1, evaluation_modes.size()):
                for phase in range(4):
                    paired_inputs = paired_inputs and episode_results[phase].starts == episode_results[mode * 4 + phase].starts and episode_results[phase].opponent_trace == episode_results[mode * 4 + phase].opponent_trace
        if not paired_inputs:
            for row in episode_results:
                print("PAIR_INPUTS team=", row.team, " style=", row.style, " starts=", row.starts, " schedule=", row.opponent_trace)
            push_error("Paired fights used different starting positions or opponent style schedules")
            get_tree().quit(1)
            return
        if collecting and not _save_rollouts():
            push_error("Physics rollouts could not be saved")
            get_tree().quit(1)
            return
        if diagnostic:
            for i in range(goblins.size()):
                var expected: float = 0.2 if i % 2 == 0 else 0.8
                var mind = goblins[i].mind
                if not is_equal_approx(mind.courage, expected) or not is_equal_approx(mind.ambition, expected) or not mind.seen_events.is_empty():
                    push_error("Inference or diagnostics changed persistent identity/epiphany ledger")
                    get_tree().quit(1)
                    return
            print("V3_DIAGNOSTIC ", JSON.stringify({"version": 1, "seed": scenario_seed,
                "opponent": "post_attack_lunge" if OS.get_environment("ARENA_DEV_LUNGE") == "1" else "standard_noisy",
                "rows": diag_rows, "outcomes": episode_results}))
        print("PHYSICS_ARENA p95_frame_ms=", percentile(frame_intervals, 0.95),
            " p99_frame_ms=", percentile(frame_intervals, 0.99), " max_frame_ms=", frame_intervals.max(),
            " active_agents=", 1 if duel else team_size, " full_passes=", full_decision_ms.size(),
            " p50_full_observation_policy_ms=", percentile(full_decision_ms, 0.5) if not full_decision_ms.is_empty() else -1.0,
            " p95_full_observation_policy_ms=", percentile(full_decision_ms, 0.95) if not full_decision_ms.is_empty() else -1.0,
            " p99_full_observation_policy_ms=", percentile(full_decision_ms, 0.99) if not full_decision_ms.is_empty() else -1.0,
            " p50_observation_policy_ms=", percentile(decision_ms, 0.5),
            " p95_observation_policy_ms=", percentile(decision_ms, 0.95),
            " p99_observation_policy_ms=", percentile(decision_ms, 0.99), " legal_violations=", legal_violations,
            " budgeted_bursts=", budgeted_bursts, " timeout_fallbacks=", timeout_fallbacks,
            " stale_fallbacks=", stale_fallbacks,
            " godot_static_mem_mib=", snappedf(float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0, 0.1),
            " hits_by_policy=", injuries, " modes=", evaluation_modes, " duel=", duel,
            " learned_tactics=", tactics, " phase_tactics=", phase_tactics, " phase_hits=", phase_hits,
            " episode_outcomes=", episode_results,
            " noisy_variant=", OS.get_environment("ARENA_NOISY") == "1", " scenario=", "v3_blind" if v3_blind else ("reactive" if reactive else ("novel" if novel else "standard")), " paired_inputs=", paired_inputs,
            " source=", "physics" if physics_policy else "abstract", " policy_variant=", "v3_dry_run" if blind_dry_run else ("v2_blind_baseline" if blind_v2_baseline else ("v3" if v3 else ("refined" if refined else "original"))), " rollouts=", rollouts.size(),
            " persistent_courage=", goblins[0].mind.courage)
        # Zero hits is a valid (if poor) outcome, especially for defensive play.
        get_tree().quit(1 if legal_violations > 0 else 0)

func _draw() -> void:
    if player == null:
        return
    draw_circle(player.position, RADIUS, Color(0.2, 0.5, 1.0))
    for goblin in goblins:
        if goblin.enabled:
            draw_circle(goblin.position, RADIUS, Color(0.8, 0.4, 0.15) if goblin.learned else Color(0.4, 0.4, 0.4))
    draw_string(ThemeDB.fallback_font, Vector2(20, 34), "Physical hitboxes | blue: player | " + evaluation_modes[current_mode] + " | phase: " + phases[current_phase], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
    draw_string(ThemeDB.fallback_font, Vector2(20, 570), "Paired " + ("duels" if duel else str(team_size) + "-goblin bouts") + "; policy trained offline on physics. Prototype only.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
