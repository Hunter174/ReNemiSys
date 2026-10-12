extends Node2D
# Isolated combat integration: real Godot physics bodies + overlap-based hits.
# It does NOT alter the existing ReNemiSys main game. The shared policy never trains here.
const Core = preload("res://combat_core.gd")
const RADIUS := 12.0
const ACTION_PERIOD := 0.2

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
var phases := ["dodge_right", "dodge_left", "rush", "kite"]
var current_phase := -1
var current_mode := 0
var legal_violations := 0
var injuries := {"learned": 0, "fixed": 0, "player": 0}
var tactics := {}
var phase_hits := {}
var noise_rng := RandomNumberGenerator.new()
var noise_timer := 0.0
var noisy_style := "dodge_right"
var episode_results := []
var final_recorded := false

func percentile(values: Array[float], fraction: float) -> float:
    values.sort()
    return values[clampi(ceili(float(values.size()) * fraction) - 1, 0, values.size() - 1)]

func _ready() -> void:
    if not policy.load_artifact("user://adaptive_policy_v1.json"):
        push_error("Train first with --headless --script res://arena_check.gd")
        get_tree().quit(1)
        return
    Engine.max_fps = 60
    noise_rng.seed = 991
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
    for i in range(20):
        var goblin := Actor.new()
        goblin.learned = i < 10
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
    var fallen := 0
    for goblin in goblins:
        if goblin.enabled and goblin.hp <= 0.0:
            fallen += 1
    episode_results.append({"style": phases[current_phase], "team": "learned" if current_mode == 0 else "fixed",
        "player_hp": snappedf(player.hp, 0.1), "goblins_defeated": fallen})

func _reset_phase(index: int) -> void:
    current_phase = index
    player.position = Vector2(480, 300)
    player.hp = 100.0
    player.stamina = 5.0
    player.cooldown = 0.0
    for i in range(goblins.size()):
        var actor: Actor = goblins[i]
        var local_index := i % 10
        actor.enabled = actor.learned if current_mode == 0 else not actor.learned
        actor.collision_layer = 2 if actor.enabled else 0
        actor.collision_mask = 7 if actor.enabled else 0
        actor.attack_area.monitoring = actor.enabled
        actor.position = Vector2(175 + (local_index % 5) * 150, 220 + (local_index / 5) * 140) if actor.enabled else Vector2(-2000, -2000)
        actor.hp = 4.0
        actor.stamina = 5.0
        actor.cooldown = 0.0
        actor.action = "guard"
    decision_timer = 0.0
    noise_timer = 1.0 # Force a new, seeded observable style at the phase boundary.

func _physics_process(delta: float) -> void:
    if player == null:
        return
    elapsed += delta
    if elapsed >= 40.0:
        if not final_recorded:
            _record_phase()
            final_recorded = true
        return
    var desired_mode := mini(int(elapsed / 20.0), 1)
    var desired_phase := mini(int(fmod(elapsed, 20.0) / 5.0), 3)
    if desired_mode != current_mode or desired_phase != current_phase:
        _record_phase()
        current_mode = desired_mode
        _reset_phase(desired_phase)
    var style: String = phases[current_phase]
    if OS.get_environment("ARENA_NOISY") == "1":
        noise_timer += delta
        if noise_timer >= 0.6:
            noise_timer = 0.0
            var alternative := "dodge_left" if style == "dodge_right" else ("dodge_right" if style == "dodge_left" else ("kite" if style == "rush" else "rush"))
            noisy_style = style if noise_rng.randf() < 0.8 else alternative
        style = noisy_style
    var nearest: Actor = goblins[0] if current_mode == 0 else goblins[10]
    for goblin in goblins:
        if goblin.enabled and goblin.hp > 0.0 and goblin.position.distance_squared_to(player.position) < nearest.position.distance_squared_to(player.position):
            nearest = goblin
    var toward := (nearest.position - player.position).normalized()
    var tangent := Vector2(-toward.y, toward.x)
    var player_move := toward if style == "rush" else (-toward if style == "kite" else (tangent if style == "dodge_right" else -tangent))
    player.velocity = player_move * 92.0
    player.move_and_slide()
    decision_timer += delta
    if decision_timer >= ACTION_PERIOD:
        decision_timer = 0.0
        var start := Time.get_ticks_usec()
        for goblin in goblins:
            if not goblin.enabled or goblin.hp <= 0.0:
                continue
            var relative := (goblin.position - player.position).normalized()
            var side := Vector2(-relative.y, relative.x)
            var cue := "rush" if player.velocity.dot(relative) > 35.0 else ("kite" if player.velocity.dot(relative) < -35.0 else ("dodge_right" if player.velocity.dot(side) > 0.0 else "dodge_left"))
            var legal := ["guard", "retreat"]
            if goblin.stamina >= 2.0:
                legal.append_array(["pressure", "flank_right", "flank_left"])
            goblin.action = policy.select(goblin.mind.observation(goblin.hp <= 3.0, false), legal) if goblin.learned else ("pressure" if legal.has("pressure") else "guard")
            if not legal.has(goblin.action):
                legal_violations += 1
                goblin.action = "guard"
            if goblin.learned:
                tactics[goblin.action] = tactics.get(goblin.action, 0) + 1
            goblin.mind.observe_player(cue) # After choice; only visible velocity, not the scripted intent.
        decision_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
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
        if connects and goblin.cooldown == 0.0 and goblin.attack_area.get_overlapping_bodies().has(player):
            if goblin.action == "guard" or goblin.stamina >= 2.0:
                goblin.stamina -= 0.0 if goblin.action == "guard" else 2.0
                goblin.cooldown = 0.7
                player.hp -= 1.0
                goblin.hits += 1
                injuries["learned" if goblin.learned else "fixed"] += 1
                var phase_key: String = "%s_%s" % [phases[current_phase], "learned" if goblin.learned else "fixed"]
                phase_hits[phase_key] = phase_hits.get(phase_key, 0) + 1
    attack_timer += delta
    if attack_timer >= 0.7:
        attack_timer = 0.0
        for target in player.attack_area.get_overlapping_bodies():
            if target is Actor and target.hp > 0.0 and target.action != "guard":
                target.hp = maxf(0.0, target.hp - 1.0)
                injuries.player += 1
                break
    queue_redraw()

func _process(_delta: float) -> void:
    var now := Time.get_ticks_usec()
    if last_frame_us != 0:
        frame_intervals.append(float(now - last_frame_us) / 1000.0)
    last_frame_us = now
    if elapsed >= 40.0 and final_recorded and OS.get_environment("ARENA_AUTORUN") == "1":
        print("PHYSICS_ARENA p95_frame_ms=", percentile(frame_intervals, 0.95), " max_frame_ms=", frame_intervals.max(),
            " p50_10_active_decision_ms=", percentile(decision_ms, 0.5),
            " p95_10_active_decision_ms=", percentile(decision_ms, 0.95),
            " p99_10_active_decision_ms=", percentile(decision_ms, 0.99), " legal_violations=", legal_violations,
            " learned_hits=", injuries.learned, " fixed_hits=", injuries.fixed, " player_hits=", injuries.player,
            " learned_tactics=", tactics, " phase_hits=", phase_hits,
            " episode_outcomes=", episode_results,
            " noisy_variant=", OS.get_environment("ARENA_NOISY") == "1",
            " persistent_courage=", goblins[0].mind.courage)
        get_tree().quit(1 if legal_violations > 0 or injuries.learned + injuries.fixed == 0 else 0)

func _draw() -> void:
    if player == null:
        return
    draw_circle(player.position, RADIUS, Color(0.2, 0.5, 1.0))
    for goblin in goblins:
        if goblin.enabled:
            draw_circle(goblin.position, RADIUS, Color(0.8, 0.4, 0.15) if goblin.learned else Color(0.4, 0.4, 0.4))
    draw_string(ThemeDB.fallback_font, Vector2(20, 34), "Physical hitboxes | blue: player | " + ("orange: learned" if current_mode == 0 else "gray: fixed") + " | phase: " + phases[current_phase], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
    draw_string(ThemeDB.fallback_font, Vector2(20, 570), "10 active per run; paired learned/fixed episodes. Physics combat still simplified; training is abstract.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
