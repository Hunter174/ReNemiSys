extends SceneTree
# Pure contract tests; real CharacterBody2D egress is checked in the arena.
const Planner = preload("res://retreat_coordination.gd")

func _initialize() -> void:
    call_deferred("run")

func assert_case(ok: bool, label: String) -> bool:
    if not ok:
        push_error("Retreat request failed: " + label)
    return ok

func actor(id: int, position: Vector2, hp: float = 4.0, action: String = "guard", courage: float = 0.8) -> Dictionary:
    return {"id": id, "position": position, "hp": hp, "stamina": 5.0, "courage": courage, "action": action}

func run() -> void:
    var planner = Planner.new()
    var bounds := Rect2(0.0, 0.0, 960.0, 600.0)
    var player := Vector2(480.0, 300.0)
    var requester := actor(0, Vector2(530.0, 300.0), 2.0, "retreat", 0.2)
    var recipient := actor(1, Vector2(555.0, 300.0))
    var checks := 0
    var agreed: Dictionary = planner.negotiate(requester, [recipient], player, bounds, 11, 4)
    if not assert_case(agreed.status == "yield" and agreed.plans.size() == 1 and agreed.hops == 1, "independent ally consents"):
        quit(1)
        return
    checks += 1
    if not assert_case(planner.valid_response(agreed, 11, 4, 0) and not planner.valid_response(agreed, 12, 4, 0) and not planner.valid_response(agreed, 11, 5, 0), "revision/expiry reject stale reply"):
        quit(1)
        return
    checks += 1
    var relay: Dictionary = planner.negotiate(requester, [recipient, actor(2, Vector2(555, 332))], player, bounds, 11, 4)
    if not assert_case(relay.status == "yield" and relay.plans.size() == 2 and relay.hops == 2, "bounded outward relay"):
        quit(1)
        return
    checks += 1
    var injured := actor(1, Vector2(555, 300), 1.0)
    var counter: Dictionary = planner.negotiate(requester, [injured], player, bounds, 11, 4)
    if not assert_case(counter.status == "counter" and counter.plans.is_empty() and counter.route != Vector2.ZERO, "recipient refuses yield, proposes independent path"):
        quit(1)
        return
    checks += 1
    var denied: Dictionary = planner.negotiate(requester, [injured, actor(3, Vector2(530, 332)), actor(4, Vector2(530, 268))], player, bounds, 11, 4)
    if not assert_case(denied.status == "deny" and denied.route == Vector2.ZERO, "recipient refuses; no route forces movement"):
        quit(1)
        return
    checks += 1
    var boundary: Dictionary = planner.negotiate(actor(0, Vector2(920, 300), 1.0, "retreat", 0.2),
        [actor(1, Vector2(935, 300)), actor(2, Vector2(920, 332)), actor(3, Vector2(920, 268))], Vector2(850, 300), bounds, 11, 4)
    if not assert_case(boundary.status == "deny" and boundary.plans.is_empty(), "wall does not create an illegal corridor"):
        quit(1)
        return
    checks += 1
    var open_wall: Dictionary = planner.negotiate(actor(0, Vector2(920, 300), 1.0, "retreat", 0.2),
        [], Vector2(850, 300), bounds, 11, 4)
    if not assert_case(open_wall.status == "counter" and open_wall.route == Vector2.DOWN and open_wall.plans.is_empty(), "wall does not forbid an independently legal sideways exit"):
        quit(1)
        return
    checks += 1
    # The destination lies >25px from this player, but the 36px movement
    # segment passes only 18px away. A target-only check would admit it.
    var crossing_player := Vector2(548, 318)
    if not assert_case(not planner._path_free(Vector2(530, 300), Vector2(530, 336), [], [0], bounds, crossing_player), "swept movement cannot cross player"):
        quit(1)
        return
    checks += 1
    var alternate: Dictionary = planner._counter_or_deny({"status": "deny", "plans": []}, requester,
        Vector2.RIGHT, [injured], bounds, crossing_player)
    if not assert_case(alternate.status == "counter" and alternate.route == Vector2.UP, "refusal cannot offer a counter-route through player"):
        quit(1)
        return
    checks += 1
    print("RETREAT_REQUEST_CHECK checks=", checks, " failures=0")
    quit()
