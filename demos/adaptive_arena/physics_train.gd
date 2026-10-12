extends SceneTree
# Offline-only Q-learning on *recorded Godot physics* transitions. No in-fight weight updates.
const Core = preload("res://combat_core.gd")

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var v3 := OS.get_environment("ARENA_V3_TRAIN") == "1"
    var refined := OS.get_environment("ARENA_REFINED_TRAIN") == "1" or v3
    var path := "user://physics_rollouts_v3.json" if v3 else ("user://physics_rollouts_v2.json" if refined else "user://physics_rollouts_v1.json")
    if not FileAccess.file_exists(path):
        push_error("Collect physics data first with ARENA_COLLECT=1")
        quit(1)
        return
    var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not envelope is Dictionary or envelope.get("version") != (3 if v3 else 1) or not envelope.get("transitions_json") is String or envelope.transitions_json.sha256_text() != envelope.get("sha256") or (v3 and envelope.get("schema") != "v3-observation-reward-v1"):
        push_error("Physics rollout envelope is invalid or corrupted")
        quit(1)
        return
    if refined:
        var seeds = envelope.get("train_seeds")
        var start_seed := 800 if v3 else 500
        if not seeds is Array or seeds.size() != 32:
            push_error("Training requires the full predeclared 32-seed set")
            quit(1)
            return
        for i in range(32):
            if not (seeds[i] is int or seeds[i] is float) or float(seeds[i]) != float(start_seed + i):
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
        if not record is Dictionary or not record.get("state") is String or record.state.is_empty() or record.state.length() > (160 if v3 else 120) or not record.get("next_state") is String or record.next_state.length() > (160 if v3 else 120) or not record.get("action") is String or not record.action in Core.ACTIONS or not record.get("next_legal") is Array or record.next_legal.size() > Core.ACTIONS.size() or not record.get("done") is bool:
            push_error("Malformed physics transition")
            quit(1)
            return
        if v3:
            if not record.state.begins_with("v3:") or not record.next_state.begins_with("v3:") or record.state.length() > 160 or record.next_state.length() > 160:
                push_error("Transition has incompatible v3 observation key")
                quit(1)
                return
            for component in ["dealt", "taken", "stamina_spent", "courage", "ambition"]:
                var value = record.get(component)
                if not (value is float or value is int) or not is_finite(float(value)):
                    push_error("Missing or nonfinite authoritative v3 reward component")
                    quit(1)
                    return
            if not record.get("alive") is bool or float(record.dealt) < 0.0 or float(record.dealt) > 4.0 or float(record.taken) < 0.0 or float(record.taken) > 4.0 or float(record.stamina_spent) < 0.0 or float(record.stamina_spent) > 5.0 or float(record.courage) < 0.0 or float(record.courage) > 1.0 or float(record.ambition) < 0.0 or float(record.ambition) > 1.0 or (record.done and record.alive and float(record.taken) >= 4.0) or (not record.done and not record.alive):
                push_error("V3 reward components outside authoritative bounds")
                quit(1)
                return
            var expected: float = (1.0 + 0.2 * float(record.ambition)) * float(record.dealt) - (1.1 + 0.6 * (1.0 - float(record.courage))) * float(record.taken) - 0.04 * float(record.stamina_spent) - 0.015
            if record.done:
                expected += 0.2 * (1.0 - float(record.courage)) if record.alive else -0.8
            if not record.get("reward") is float and not record.get("reward") is int or absf(float(record.reward) - clampf(expected, -10.0, 10.0)) > 0.0001:
                push_error("V3 reward does not reconstruct from authoritative deltas")
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
    # Twelve and sixteen were development-only trials; twenty is the frozen v3
    # replay count meeting quality budgets without opening the blind suite.
    var epochs := 20 if v3 else 12
    if v3 and OS.has_environment("ARENA_V3_EPOCHS"):
        epochs = OS.get_environment("ARENA_V3_EPOCHS").to_int()
        if not epochs in [12, 16, 20]:
            push_error("V3 development epochs must be 12, 16 or 20")
            quit(1)
            return
    var rng := RandomNumberGenerator.new()
    rng.seed = 93
    var model = Core.SharedPolicy.new(93)
    var began := Time.get_ticks_usec()
    for epoch in range(epochs):
        # Deterministic shuffled replay, never on a rendered _physics_process tick.
        for i in range(valid.size() - 1, 0, -1):
            var other: int = rng.randi_range(0, i)
            var tmp: Dictionary = valid[i]
            valid[i] = valid[other]
            valid[other] = tmp
        for row in valid:
            model.learn(row.state, row.action, float(row.reward), row.next_state, row.done, row.next_legal)
    var train_ms := float(Time.get_ticks_usec() - began) / 1000.0
    var artifact := "user://physics_policy_v3.json" if v3 else ("user://physics_policy_v2.json" if refined else "user://physics_policy_v1.json")
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
        " q_states=", model.weights.size(), " epochs=", epochs, " training_ms=", snappedf(train_ms, 0.1),
        " artifact=", artifact, " (local-only)")
    quit()
