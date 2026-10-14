extends RefCounted
# Game-owned SHORT-HORIZON geometry and consent. Neither an LLM nor a combat
# weight table may move an ally or turn its refusal into permission.
const MAX_HOPS := 2
const SEPARATION := 25.0
const LANE_STEP := 36.0
const SEARCH_DISTANCE := 53.0

# Authored utility knobs; issue #14 may tune ONLY offline on new training seeds.
const URGENCY_LOW_HP := 1.1
const COST_THREATENED := 0.6
const COST_COMMITTED := 0.5
const COST_LOW_HP := 1.6
const YIELD_THRESHOLD := 0.45

func negotiate(requester: Dictionary, peers: Array, player: Vector2, bounds: Rect2, revision: int, tick: int) -> Dictionary:
    if not _valid_actor(requester) or revision < 0 or tick < 0:
        return {"status": "invalid", "revision": revision, "expires_tick": tick}
    var away: Vector2 = (requester.position - player).normalized()
    if away.is_zero_approx():
        return {"status": "invalid", "revision": revision, "expires_tick": tick}
    var blocker := _first_blocker(requester.position, away, peers, [requester.id])
    var answer := {"status": "clear", "requester": requester.id, "recipient": -1,
        "revision": revision, "expires_tick": tick + 1, "route": away, "plans": [], "hops": 0}
    if not _within_bounds(requester.position + away * LANE_STEP, bounds):
        # A wall blocks this outward lane, not every independently legal exit.
        return _counter_or_deny(answer, requester, away, peers, bounds, player)
    if blocker.is_empty():
        return answer
    answer.recipient = blocker.id
    if not _willing(requester, blocker, player):
        return _counter_or_deny(answer, requester, away, peers, bounds, player)
    var plans: Array = []
    var visited := {requester.id: true}
    if _plan_yield(requester, blocker, away, peers, player, bounds, 1, visited, plans):
        answer.status = "yield"
        answer.plans = plans
        answer.hops = plans.size()
        return answer
    return _counter_or_deny(answer, requester, away, peers, bounds, player)

func valid_response(response: Dictionary, revision: int, tick: int, requester_id: int) -> bool:
    return response.get("revision") == revision and response.get("expires_tick") == tick + 1 and response.get("requester") == requester_id and response.get("status") in ["clear", "yield", "counter", "deny"]

func _valid_actor(actor: Dictionary) -> bool:
    return actor.get("id") is int and actor.get("position") is Vector2 and actor.get("hp") is float and actor.get("stamina") is float and actor.get("courage") is float and actor.get("action") is String

func _willing(requester: Dictionary, recipient: Dictionary, player: Vector2) -> bool:
    # Nearby injured or committed attackers may rationally refuse assistance.
    var urgency: float = 0.8 + (URGENCY_LOW_HP if requester.hp <= 2.0 else 0.0)
    var danger: float = COST_THREATENED if recipient.position.distance_to(player) < 62.0 else 0.0
    var commitment: float = COST_COMMITTED if recipient.action in ["pressure", "flank_right", "flank_left"] else 0.0
    var injury: float = COST_LOW_HP if recipient.hp <= 2.0 else 0.0
    var personality: float = 0.2 * recipient.courage
    return urgency - danger - commitment - injury - personality >= YIELD_THRESHOLD

func _first_blocker(start: Vector2, direction: Vector2, peers: Array, excluded: Array) -> Dictionary:
    var closest := SEARCH_DISTANCE
    var result := {}
    for peer in peers:
        if not _valid_actor(peer) or excluded.has(peer.id) or peer.hp <= 0.0:
            continue
        var displacement: Vector2 = peer.position - start
        var forward: float = displacement.dot(direction)
        if forward > 0.0 and forward < closest and absf(displacement.cross(direction)) < SEPARATION:
            closest = forward
            result = peer
    return result

func _within_bounds(position: Vector2, bounds: Rect2) -> bool:
    return bounds.grow(-24.0).has_point(position)

func _path_free(origin: Vector2, target: Vector2, peers: Array, ignored: Array, bounds: Rect2, player: Vector2) -> bool:
    if not _within_bounds(target, bounds):
        return false
    var segment := target - origin
    # A free destination is not enough: the motion can sweep through the player.
    var player_fraction := clampf((player - origin).dot(segment) / maxf(1.0, segment.length_squared()), 0.0, 1.0)
    if player.distance_to(origin + segment * player_fraction) < SEPARATION:
        return false
    for peer in peers:
        if not _valid_actor(peer) or ignored.has(peer.id) or peer.hp <= 0.0:
            continue
        var fraction := clampf((peer.position - origin).dot(segment) / maxf(1.0, segment.length_squared()), 0.0, 1.0)
        if peer.position.distance_to(origin + segment * fraction) < SEPARATION:
            return false
    return true

func _plan_yield(requester: Dictionary, recipient: Dictionary, direction: Vector2,
        peers: Array, player: Vector2, bounds: Rect2, depth: int, visited: Dictionary, plans: Array) -> bool:
    if depth > MAX_HOPS or visited.has(recipient.id) or not _willing(requester, recipient, player):
        return false
    visited[recipient.id] = true
    var side := Vector2(-direction.y, direction.x)
    # The first recipient sidesteps. A second-hop recipient must continue that
    # SAME outward lane rather than sidestepping back into the requester.
    var candidates := [direction] if depth > 1 else [side, -side]
    for candidate in candidates:
        var desired: Vector2 = recipient.position + candidate * LANE_STEP
        if _path_free(recipient.position, desired, peers, [recipient.id], bounds, player):
            plans.append({"id": recipient.id, "direction": candidate, "target": desired})
            return true
        if depth < MAX_HOPS:
            var occupant := _first_blocker(recipient.position, candidate, peers, [requester.id, recipient.id])
            if not occupant.is_empty() and not visited.has(occupant.id):
                var subplans: Array = []
                if _plan_yield(requester, occupant, candidate, peers, player, bounds, depth + 1, visited.duplicate(), subplans):
                    var ignored := [recipient.id]
                    for plan in subplans:
                        ignored.append(plan.id)
                    if _path_free(recipient.position, desired, peers, ignored, bounds, player):
                        plans.append_array(subplans)
                        plans.append({"id": recipient.id, "direction": candidate, "target": desired})
                        return true
    return false

func _counter_or_deny(answer: Dictionary, requester: Dictionary, away: Vector2, peers: Array, bounds: Rect2, player: Vector2) -> Dictionary:
    var side := Vector2(-away.y, away.x)
    for sign_value in [1.0, -1.0]:
        var route: Vector2 = side * sign_value
        if _path_free(requester.position, requester.position + route * LANE_STEP, peers, [requester.id], bounds, player):
            answer.status = "counter"
            answer.route = route
            return answer
    answer.status = "deny"
    answer.route = Vector2.ZERO
    return answer
