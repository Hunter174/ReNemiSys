extends "res://physics_arena.gd"
# Interactive, DEV-ONLY view of the existing authoritative arena. No new AI,
# movement rule, weight or LLM dependency. Never used for evaluation/training.
const CASE_KEYS := {
    KEY_1: "approve", KEY_2: "deny", KEY_3: "counter", KEY_4: "relay",
    KEY_5: "edge_open", KEY_6: "contested", KEY_7: "natural",
    KEY_8: "multiple", KEY_9: "edge", KEY_0: "unload",
}
var live_paused := false
var live_slow := false
var live_round := 1
var smoke_done := false
var recent_events: Array[String] = []

func _ready() -> void:
    if OS.get_environment("ARENA_CROWD_LIVE") != "1":
        push_error("Use live_retreat_demo.py to start the development-only viewer")
        get_tree().quit(1)
        return
    super._ready() # Enforces the 900–907 seed, policy and arena-only contract.
    if player != null:
        print("RETREAT_LIVE_READY case=", crowd_case, " consent=", consent_enabled,
            " recovery=", crowd_separation_trial, " seed=", scenario_seed)

func _exit_tree() -> void:
    Engine.time_scale = 1.0

func _restart() -> void:
    if player == null:
        return
    # New fight, not an epiphany/save: reset observed tactical cues, but never
    # change courage, ambition, shared weights or the authoritative legal mask.
    for actor in goblins:
        actor.mind.player_moves.clear()
        actor.hits = 0
    for key in injuries:
        injuries[key] = 0
    for key in request_counts:
        request_counts[key] = 0
    last_crowd_replies.clear()
    recent_events.clear()
    tactics.clear()
    phase_tactics.clear()
    phase_hits.clear()
    episode_results.clear()
    decision_ms.clear()
    full_decision_ms.clear()
    crowd_policy_ms.clear()
    crowd_request_ms.clear()
    frame_intervals.clear()
    last_frame_us = 0
    overlap_examples.clear()
    overlap_violations = 0
    max_pair_penetration_px = 0.0
    contact_correction_attempts = 0
    max_contact_correction_px = 0.0
    request_revision += 1 # Revoke any in-flight consent before resetting bodies.
    request_tick = 0
    elapsed = 0.0
    decision_timer = 0.0
    attack_timer = 0.0
    current_mode = 0
    current_phase = -1
    final_recorded = false
    player.hits = 0
    _reset_phase(0)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo or player == null:
        return
    var key: int = event.keycode
    if CASE_KEYS.has(key):
        crowd_case = CASE_KEYS[key]
        live_round = 1
        _restart()
    else:
        match key:
            KEY_N:
                consent_enabled = not consent_enabled
                _restart()
            KEY_R:
                _restart()
            KEY_TAB:
                scenario_seed = 900 + (scenario_seed - 899) % 8
                _restart()
            KEY_SPACE:
                live_paused = not live_paused
                queue_redraw()
            KEY_S:
                live_slow = not live_slow
                Engine.time_scale = 0.35 if live_slow else 1.0
                queue_redraw()
            KEY_ESCAPE:
                get_tree().quit()
            _:
                return
    get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
    if player == null or live_paused:
        return
    if elapsed >= 20.0:
        live_round += 1
        _restart()
        if OS.get_environment("ARENA_CROWD_LIVE_ROUND_SMOKE") == "1":
            print("RETREAT_LIVE_ROUND_SMOKE restarted_round=", live_round, " seed=", scenario_seed)
            get_tree().quit()
            return
    var tick_before := request_tick
    var conflicts_before: int = request_counts.conflicts
    super._physics_process(delta)
    if consent_enabled and request_tick != tick_before:
        for requester_id in last_crowd_replies:
            var reply: Dictionary = last_crowd_replies[requester_id]
            if reply.at >= elapsed - delta - 0.001 and reply.status in ["yield", "deny", "counter"]:
                var hop_label := " (%d HOPS)" % reply.get("hops", 1) if reply.status == "yield" and reply.get("hops", 0) > 1 else ""
                recent_events.push_front("#%d -> #%d %s%s" % [requester_id, reply.recipient, reply.status.to_upper(), hop_label])
                if recent_events.size() > 3:
                    recent_events.pop_back()
        if request_counts.conflicts > conflicts_before:
            recent_events.push_front("Game rejected contested slot; requester retains legal options")
            if recent_events.size() > 3:
                recent_events.pop_back()
    if OS.get_environment("ARENA_CROWD_LIVE_SMOKE") == "1" and elapsed >= 2.0 and not smoke_done:
        smoke_done = true
        if OS.get_environment("ARENA_CROWD_LIVE_SCREENSHOT") == "1":
            _finish_rendered_smoke()
        else:
            print("RETREAT_LIVE_SMOKE case=", crowd_case, " consent=", consent_enabled,
                " replies=", request_counts, " elapsed=", snappedf(elapsed, 0.01))
            get_tree().quit()

func _finish_rendered_smoke() -> void:
    live_paused = true
    queue_redraw()
    await RenderingServer.frame_post_draw
    var path := "user://retreat_live_preview.png"
    var error := get_viewport().get_texture().get_image().save_png(path)
    print("RETREAT_LIVE_SMOKE screenshot=", ProjectSettings.globalize_path(path),
        " save_error=", error, " replies=", request_counts)
    get_tree().quit(0 if error == OK else 1)

func _draw_link(from: Vector2, to: Vector2, tint: Color) -> void:
    draw_line(from, to, tint, 2.0)
    var arrow := (to - from).normalized()
    if not arrow.is_zero_approx():
        var side := Vector2(-arrow.y, arrow.x)
        draw_line(to, to - arrow * 7.0 + side * 4.0, tint, 2.0)
        draw_line(to, to - arrow * 7.0 - side * 4.0, tint, 2.0)

func _draw() -> void:
    if player == null:
        return
    super._draw()
    var font := ThemeDB.fallback_font
    for actor in goblins:
        if not actor.enabled or actor.hp <= 0.0:
            continue
        var tint := Color(0.35, 0.95, 0.55) if actor.yield_until > elapsed else (Color(1.0, 0.65, 0.2) if actor.action == "retreat" else Color.WHITE)
        draw_string(font, actor.position + Vector2(14, -12), "#%d %s" % [actor.actor_id, actor.action], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
        if actor.yield_until > elapsed:
            _draw_link(actor.position, actor.position + actor.yield_direction * 24.0, tint)
    for requester_id in last_crowd_replies:
        var reply: Dictionary = last_crowd_replies[requester_id]
        var recipient_id: int = reply.recipient
        if elapsed - reply.at > 0.42 or recipient_id < 0 or recipient_id >= team_size:
            continue
        var color := Color(0.3, 1.0, 0.5) if reply.status == "yield" else (Color(1.0, 0.35, 0.35) if reply.status == "deny" else Color(1.0, 0.9, 0.25))
        _draw_link(goblins[requester_id].position, goblins[recipient_id].position, color)
    draw_rect(Rect2(8, 6, 944, 145), Color(0.025, 0.045, 0.08, 0.91), true)
    var status := "ON" if consent_enabled else "OFF"
    var title := "RETREAT REQUEST DEMO | %s | consent %s | seed %d | %d agents | round %d%s%s" % [crowd_case, status, scenario_seed, team_size, live_round, " | PAUSED" if live_paused else "", " | SLOW" if live_slow else ""]
    draw_string(font, Vector2(18, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
    var counts := "YIELD %d   REFUSE %d   COUNTER %d   REJECT %d   HP %.0f   HITS %d" % [request_counts.yield, request_counts.deny, request_counts.counter, request_counts.conflicts, player.hp, injuries.learned]
    draw_string(font, Vector2(18, 49), counts, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.94, 1.0))
    var progress := ""
    if crowd_case != "natural":
        progress = "EGRESS %.0f px | first 30px %.2fs" % [crowd_max_progress, crowd_escape_time]
    else:
        progress = "NATURAL FIGHT: AI picks tactics; no scripted egress or survival claim"
    draw_string(font, Vector2(18, 70), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.87, 0.55))
    draw_string(font, Vector2(18, 92), "1 blocked + consent  2 injured ally refuses  3 independent route  4 two-hop  5 open wall  6 contested  7 natural", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))
    draw_string(font, Vector2(18, 110), "8 two requesters  9 blocked wall  0 unload | N consent  R reset  Tab next seed  S slow  Space pause  Esc quit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))
    var latest := "Recent decisions: " + (" | ".join(PackedStringArray(recent_events)) if consent_enabled else "requests disabled; compare physical egress")
    draw_string(font, Vector2(18, 135), latest, HORIZONTAL_ALIGNMENT_LEFT, 930, 12, Color(0.45, 1.0, 0.7))
    draw_rect(Rect2(8, 552, 944, 36), Color(0.025, 0.045, 0.08, 0.91), true)
    draw_string(font, Vector2(18, 575), "Orange=retreat  Green=consenting ally  Red=refusal  Yellow=counter  |  900-907 DEVELOPMENT ONLY; #15 pending", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
