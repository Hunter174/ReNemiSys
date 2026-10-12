extends RefCounted
# Isolated *abstract* combat environment. No SaLMon or MLGodotKit dependency.
# This tabular shared-weight policy is a baseline, not a neural-network or game combat system.
const ACTIONS := ["pressure", "flank_right", "flank_left", "guard", "retreat"]
const STYLES := ["rush", "dodge_right", "dodge_left", "kite"]
const ARTIFACT_VERSION := 2

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

    # Game-owned save snapshot. An untrusted LLM must never call restore() or edit the ledger.
    func snapshot() -> Dictionary:
        return {"version": 1, "courage": courage, "ambition": ambition,
            "player_moves": player_moves.duplicate(), "seen_epiphanies": seen_events.keys()}

    func restore(record: Dictionary) -> bool:
        if record.get("version") != 1 or not (record.get("courage") is float or record.get("courage") is int) or not (record.get("ambition") is float or record.get("ambition") is int):
            return false
        var c := float(record.courage)
        var a := float(record.ambition)
        if not is_finite(c) or not is_finite(a) or c < 0.0 or c > 1.0 or a < 0.0 or a > 1.0:
            return false
        var moves = record.get("player_moves")
        var events = record.get("seen_epiphanies")
        if not moves is Array or moves.size() > 5 or not events is Array or events.size() > 128:
            return false
        var validated_moves: Array[String] = []
        var validated_events := {}
        for move in moves:
            if not move is String or not move in ["rush", "dodge_right", "dodge_left", "kite"]:
                return false
            validated_moves.append(move)
        for id in events:
            if not id is String or id.is_empty() or id.length() > 128 or validated_events.has(id):
                return false
            validated_events[id] = true
        courage = c
        ambition = a
        player_moves = validated_moves
        seen_events = validated_events
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

    func learn(key: String, action: String, reward: float, next_key: String, done: bool, next_legal: Array = ["pressure", "flank_right", "flank_left", "guard", "retreat"]) -> void:
        var index := ["pressure", "flank_right", "flank_left", "guard", "retreat"].find(action)
        if index < 0:
            return
        var q: Array = values(key)
        var next_best := 0.0
        if not done:
            var available := []
            for next_action in next_legal:
                var next_index := ["pressure", "flank_right", "flank_left", "guard", "retreat"].find(next_action)
                if next_index >= 0:
                    available.append(float(values(next_key)[next_index]))
            if not available.is_empty():
                next_best = available.max()
        var target := reward + (0.0 if done else 0.85 * next_best)
        q[index] = clampf(float(q[index]) + 0.18 * (target - float(q[index])), -100.0, 100.0)

    func save_artifact(path: String) -> bool:
        var payload := JSON.stringify(weights)
        if payload.length() > 262144:
            return false
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file == null:
            return false
        # Hash exact bytes, not re-stringified JSON numbers (which can round on parse).
        file.store_string(JSON.stringify({"version": 2, "actions": ["pressure", "flank_right", "flank_left", "guard", "retreat"],
            "sha256": payload.sha256_text(), "weights_json": payload}))
        file.close()
        return true

    func load_artifact(path: String) -> bool:
        if not FileAccess.file_exists(path):
            return false
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null or file.get_length() > 280000:
            return false
        var parsed = JSON.parse_string(file.get_as_text())
        if not parsed is Dictionary or parsed.get("actions") != ["pressure", "flank_right", "flank_left", "guard", "retreat"]:
            return false
        var candidate: Dictionary
        if parsed.get("version") == 2:
            if not parsed.get("weights_json") is String or parsed.weights_json.length() > 262144 or parsed.weights_json.sha256_text() != parsed.get("sha256"):
                return false
            var data = JSON.parse_string(parsed.weights_json)
            if not data is Dictionary:
                return false
            candidate = data
        elif parsed.get("version") == 1: # Existing local development artifacts only.
            if not parsed.get("weights") is Dictionary or JSON.stringify(parsed.weights).sha256_text() != parsed.get("sha256"):
                return false
            candidate = parsed.weights
        else:
            return false
        if candidate.size() > 512:
            return false
        for key in candidate:
            if not key is String or not candidate[key] is Array or candidate[key].size() != 5:
                return false
            for value in candidate[key]:
                if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value)) > 100.0:
                    return false
        weights = candidate
        return true

    func approximately_equals(other: SharedPolicy, tolerance: float = 0.00001) -> bool:
        if weights.size() != other.weights.size():
            return false
        for key in weights:
            if not other.weights.has(key):
                return false
            for i in range(5):
                if absf(float(weights[key][i]) - float(other.weights[key][i])) > tolerance:
                    return false
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
