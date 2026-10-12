extends Node2D
# Visual synthetic decision demonstration; NOT ReNemiSys's existing combat/physics.
const Core = preload("res://combat_core.gd")
var policy = Core.SharedPolicy.new()
var minds := []
var actions: Array[String] = []
var phase := 0.0
var ticks := 0.0
var frames: Array[float] = []
var decisions: Array[float] = []
var last_frame_us := 0

func _ready() -> void:
    if not policy.load_artifact("user://adaptive_policy_v1.json"):
        push_error("First run: Godot --headless --path demos/adaptive_arena --script res://arena_check.gd")
        get_tree().quit(1)
        return
    Engine.max_fps = 60
    for i in range(20):
        var mind = Core.Mind.new(0.2 if i % 2 == 0 else 0.8, 0.2 if i % 2 == 0 else 0.8)
        minds.append(mind)
        actions.append("guard")

func _process(delta: float) -> void:
    var now := Time.get_ticks_usec()
    if last_frame_us != 0:
        frames.append(float(now - last_frame_us) / 1000.0)
    last_frame_us = now
    phase += delta
    var style := "dodge_right" if phase < 5.0 else ("dodge_left" if phase < 10.0 else ("rush" if phase < 15.0 else "kite"))
    ticks += delta
    if ticks >= 0.16:
        ticks = 0.0
        var start := Time.get_ticks_usec()
        for i in range(minds.size()):
            minds[i].observe_player(style)
            # This prototype's damage and action legality are still abstract.
            actions[i] = policy.select(minds[i].observation(i % 3 == 0, true), Core.ACTIONS)
        decisions.append(float(Time.get_ticks_usec() - start) / 1000.0)
    queue_redraw()
    if phase >= 20.0 and OS.get_environment("ARENA_AUTORUN") == "1":
        frames.sort()
        decisions.sort()
        print("ARENA_RENDER frames=", frames.size(), " frame_p95_ms=", frames[clampi(ceili(frames.size() * 0.95) - 1, 0, frames.size() - 1)],
            " frame_max_ms=", frames.max(), " 20_agent_policy_p95_ms=", decisions[clampi(ceili(decisions.size() * 0.95) - 1, 0, decisions.size() - 1)])
        get_tree().quit()

func _draw() -> void:
    var font := ThemeDB.fallback_font
    var style := "dodge right" if phase < 5.0 else ("dodge left" if phase < 10.0 else ("rush" if phase < 15.0 else "kite"))
    draw_string(font, Vector2(18, 36), "Player style: " + style + " (scripted switches at 5s, 10s, 15s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
    draw_string(font, Vector2(18, 66), "Shared learned Q-table, 20 goblins, personality inputs. No LLM or online training.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
    for i in range(minds.size()):
        var x := 36.0 + float(i % 5) * 183.0
        var y := 119.0 + float(i / 5) * 110.0
        draw_circle(Vector2(x, y), 14.0, Color(0.8, 0.35, 0.3) if i % 2 == 0 else Color(0.2, 0.7, 0.5))
        draw_string(font, Vector2(x + 18.0, y), "coward" if i % 2 == 0 else "bold", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
        draw_string(font, Vector2(x + 18.0, y + 21.0), actions[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
    draw_string(font, Vector2(18, 572), "Illustrative arena only; no hitboxes, RL training, or live game integration here.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
