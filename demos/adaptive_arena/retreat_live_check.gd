extends SceneTree
# Headless UI-contract check; the real rendered screenshot is a separate smoke.

func _initialize() -> void:
    call_deferred("run")

func key(scene: Node, code: int) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = true
    scene._input(event)

func check(condition: bool, label: String) -> bool:
    if not condition:
        push_error("Live retreat UI check failed: " + label)
    return condition

func run() -> void:
    if OS.get_environment("ARENA_CROWD_LIVE") != "1" or OS.get_environment("ARENA_DEV_SEED") != "900":
        push_error("Live checks require an isolated development seed")
        quit(1)
        return
    var scene = load("res://retreat_live_demo.tscn").instantiate()
    root.add_child(scene)
    await physics_frame
    if not check(scene.player != null and scene.crowd_case == "approve" and scene.consent_enabled, "launch/approve"):
        quit(1)
        return
    var identity: float = scene.goblins[0].mind.courage
    key(scene, KEY_2)
    if not check(scene.crowd_case == "deny" and scene.goblins[1].hp == 1.0, "rational refusal fixture"):
        quit(1)
        return
    key(scene, KEY_N)
    if not check(not scene.consent_enabled and scene.request_counts.yield == 0 and scene.goblins[0].mind.courage == identity, "toggle does not mutate identity"):
        quit(1)
        return
    key(scene, KEY_5)
    if not check(scene.crowd_case == "edge_open" and scene.player.position.x == 850.0, "independent wall route"):
        quit(1)
        return
    key(scene, KEY_TAB)
    if not check(scene.scenario_seed == 901, "only the next development seed"):
        quit(1)
        return
    key(scene, KEY_6)
    if not check(scene.crowd_case == "contested" and scene.goblins[2].position.y == 313.0, "contested helper"):
        quit(1)
        return
    key(scene, KEY_7)
    if not check(scene.crowd_case == "natural" and scene.player.position.x == 480.0, "natural mode"):
        quit(1)
        return
    key(scene, KEY_SPACE)
    if not check(scene.live_paused, "pause"):
        quit(1)
        return
    key(scene, KEY_S)
    if not check(scene.live_slow and is_equal_approx(Engine.time_scale, 0.35), "visible slow-motion toggle"):
        quit(1)
        return
    key(scene, KEY_S)
    if not check(not scene.live_slow and is_equal_approx(Engine.time_scale, 1.0), "restore ordinary time"):
        quit(1)
        return
    key(scene, KEY_R)
    if not check(scene.goblins[0].mind.courage == identity and scene.last_crowd_replies.is_empty(), "reset has no epiphany"):
        quit(1)
        return
    print("RETREAT_LIVE_CHECK cases=11 failures=0")
    quit()
