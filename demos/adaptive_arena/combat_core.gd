extends RefCounted
# Isolated *abstract* combat environment. No SaLMon or MLGodotKit dependency.
# This tabular shared-weight policy is a baseline, not a neural-network or game combat system.
const ACTIONS := ["pressure", "flank_right", "flank_left", "guard", "retreat"]
const STYLES := ["rush", "dodge_right", "dodge_left", "kite"]
const ARTIFACT_VERSION := 1

class Mind:
    var courage: float
    var ambition: float
    var player_moves: Array[String] = []
    var seen_events := {}

    func _init(p_courage: float, p_ambition: float) -> void:
        courage = clampf(p_courage, 0.0, 1.0)
        ambition = clampf(p_ambition, 0.0, 1.0)

    func observe_player(move: String) -> void:
        if not move in ["rush", "dodge_right", "dodge_left", "kite"]:
            return
        player_moves.append(move)
        if player_moves.size() > 5:
            player_moves.pop_front()

    func player_belief() -> String:
        if player_moves.size() < 2:
            return "unknown"
        var tally := {"rush": 0, "dodge_right": 0, "dodge_left": 0, "kite": 0}
        for move in player_moves:
            tally[move] += 1
        var best := "unknown"
        var count := 0
        for style in ["rush", "dodge_right", "dodge_left", "kite"]:
            if tally[style] > count:
                best = style
                count = tally[style]
        return best

    # Authorization is supplied by the trusted game event ledger, not by LLM text.
    # An epiphany may happen during combat ONLY when the game explicitly authorizes it.
    func apply_epiphany(event: Dictionary, authorized: bool, in_combat: bool, allow_mid_fight: bool = false) -> bool:
        if not authorized or (in_combat and not allow_mid_fight) or event.get("kind") != "epiphany":
            return false
        var id = event.get("id")
        var delta = event.get("courage_delta")
        if not id is String or id.is_empty() or seen_events.has(id) or not delta is float or not is_finite(delta) or absf(delta) > 0.2:
            return false
        seen_events[id] = true
        courage = clampf(courage + delta, 0.0, 1.0)
        return true

    func observation(low_health: bool, tough_enemy: bool) -> String:
        return "%s:%d:%d:%d:%d" % [player_belief(), int(low_health), int(tough_enemy), int(courage >= 0.5), int(ambition >= 0.5)]

class SharedPolicy:
    var weights := {}
    var random := RandomNumberGenerator.new()

    func _init(seed_value: int = 2203) -> void:
        random.seed = seed_value

    func values(key: String) -> Array:
        if not weights.has(key):
            weights[key] = [0.0, 0.0, 0.0, 0.0, 0.0]
        return weights[key]

    func select(key: String, legal: Array, epsilon: float = 0.0) -> String:
        var choices: Array[String] = []
        for action in legal:
            if action in ["pressure", "flank_right", "flank_left", "guard", "retreat"] and not choices.has(action):
                choices.append(action)
        if choices.is_empty():
            return "" # the game must not invent an action
        if epsilon > 0.0 and random.randf() < epsilon:
            return choices[random.randi_range(0, choices.size() - 1)]
        if not weights.has(key):
            return "guard" if choices.has("guard") else choices[0]
        var q: Array = weights[key]
        var best: String = choices[0]
        for action in choices:
            if q[["pressure", "flank_right", "flank_left", "guard", "retreat"].find(action)] > q[["pressure", "flank_right", "flank_left", "guard", "retreat"].find(best)]:
                best = action
        return best

    func learn(key: String, action: String, reward: float, next_key: String, done: bool) -> void:
        var index := ["pressure", "flank_right", "flank_left", "guard", "retreat"].find(action)
        if index < 0:
            return
        var q: Array = values(key)
        var target := reward + (0.0 if done else 0.85 * float(values(next_key).max()))
        q[index] = clampf(float(q[index]) + 0.18 * (target - float(q[index])), -100.0, 100.0)

    func save_artifact(path: String) -> bool:
        var payload := JSON.stringify(weights)
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file == null:
            return false
        file.store_string(JSON.stringify({"version": 1, "actions": ["pressure", "flank_right", "flank_left", "guard", "retreat"],
            "sha256": payload.sha256_text(), "weights": weights}))
        file.close()
        return true

    func load_artifact(path: String) -> bool:
        if not FileAccess.file_exists(path):
            return false
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not parsed is Dictionary or parsed.get("version") != 1 or parsed.get("actions") != ["pressure", "flank_right", "flank_left", "guard", "retreat"] or not parsed.get("weights") is Dictionary:
            return false
        var candidate: Dictionary = parsed.weights
        if candidate.size() > 128 or JSON.stringify(candidate).sha256_text() != parsed.get("sha256"):
            return false
        for key in candidate:
            if not key is String or not candidate[key] is Array or candidate[key].size() != 5:
                return false
            for value in candidate[key]:
                if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value)) > 100.0:
                    return false
        weights = candidate
        return true

# This toy arena computes consequences; neither the agent nor an LLM declares hits.
static func encounter_reward(style: String, action: String, mind: Mind, low_health: bool, tough_enemy: bool) -> float:
    var hit := (style == "rush" and action == "guard") or (style == "dodge_right" and action == "flank_right") or (style == "dodge_left" and action == "flank_left") or (style == "kite" and action == "pressure")
    var outcome := 1.0 if hit else -0.7
    if action == "retreat":
        outcome = 0.45 if low_health else -0.4
        outcome += (1.0 - mind.courage) * 0.75 if low_health else 0.0
    elif action == "guard" and style != "rush":
        outcome = -0.25
    elif not hit and action == "pressure" and style == "rush":
        outcome = -1.1
    if hit and tough_enemy:
        outcome += mind.ambition * 0.3
    return outcome
