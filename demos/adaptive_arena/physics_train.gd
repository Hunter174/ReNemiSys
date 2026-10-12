extends SceneTree
# Offline-only Q-learning on *recorded Godot physics* transitions. No in-fight weight updates.
const Core = preload("res://combat_core.gd")

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var refined := OS.get_environment("ARENA_REFINED_TRAIN") == "1"
    var path := "user://physics_rollouts_v2.json" if refined else "user://physics_rollouts_v1.json"
    if not FileAccess.file_exists(path):
        push_error("Collect physics data first with ARENA_COLLECT=1")
        quit(1)
        return
    var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not envelope is Dictionary or envelope.get("version") != 1 or not envelope.get("transitions_json") is String or envelope.transitions_json.sha256_text() != envelope.get("sha256"):
        push_error("Physics rollout envelope is invalid or corrupted")
        quit(1)
        return
    if refined:
        var seeds = envelope.get("train_seeds")
        if not seeds is Array or seeds.size() != 32:
            push_error("Refined training requires the full predeclared 500–531 seed set")
            quit(1)
            return
        for i in range(32):
            if not (seeds[i] is int or seeds[i] is float) or float(seeds[i]) != float(500 + i):
                push_error("Refined rollout contains an unapproved training seed")
                quit(1)
                return
    var observations = JSON.parse_string(envelope.transitions_json)
    if not observations is Array or observations.is_empty() or observations.size() > 100000:
        push_error("Physics rollout payload is empty or too large")
        quit(1)
        return
    var unique_pairs := {}
    var valid: Array[Dictionary] = []
    for record in observations:
        if not record is Dictionary or not record.get("state") is String or record.state.is_empty() or record.state.length() > 120 or not record.get("next_state") is String or record.next_state.length() > 120 or not record.get("action") is String or not record.action in Core.ACTIONS or not record.get("next_legal") is Array or record.next_legal.size() > Core.ACTIONS.size() or not record.get("done") is bool:
            push_error("Malformed physics transition")
            quit(1)
            return
        var reward = record.get("reward")
        if not (reward is float or reward is int) or not is_finite(float(reward)) or absf(float(reward)) > 10.0:
            push_error("Untrusted physics reward")
            quit(1)
            return
        var ids := {}
        for action in record.next_legal:
            if not action is String or not action in Core.ACTIONS or ids.has(action):
                push_error("Invalid next-action mask")
                quit(1)
                return
            ids[action] = true
        unique_pairs[record.state + "/" + record.action] = true
        valid.append(record)
    var rng := RandomNumberGenerator.new()
    rng.seed = 93
    var model = Core.SharedPolicy.new(93)
    var began := Time.get_ticks_usec()
    for epoch in range(12):
        # Deterministic shuffled replay, never on a rendered _physics_process tick.
        for i in range(valid.size() - 1, 0, -1):
            var other: int = rng.randi_range(0, i)
            var tmp: Dictionary = valid[i]
            valid[i] = valid[other]
            valid[other] = tmp
        for row in valid:
            model.learn(row.state, row.action, float(row.reward), row.next_state, row.done, row.next_legal)
    var train_ms := float(Time.get_ticks_usec() - began) / 1000.0
    var artifact := "user://physics_policy_v2.json" if refined else "user://physics_policy_v1.json"
    if not model.save_artifact(artifact):
        push_error("Physics policy artifact could not be saved")
        quit(1)
        return
    var reloaded = Core.SharedPolicy.new(93)
    if not reloaded.load_artifact(artifact) or not reloaded.approximately_equals(model):
        push_error("Physics policy failed the artifact roundtrip")
        quit(1)
        return
    print("PHYSICS_TRAIN transitions=", valid.size(), " distinct_state_actions=", unique_pairs.size(),
        " q_states=", model.weights.size(), " epochs=12 training_ms=", snappedf(train_ms, 0.1),
        " artifact=", artifact, " (local-only)")
    quit()
