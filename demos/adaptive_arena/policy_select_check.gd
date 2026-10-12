extends SceneTree
# Regression: optimized hot-path selection must keep the original legal-order
# tie break and never mutate a loaded shared policy during live inference.
const Core = preload("res://combat_core.gd")

func _initialize() -> void:
    call_deferred("run")

func reference_select(weights: Dictionary, key: String, legal: Array) -> String:
    var choices: Array[String] = []
    for action in legal:
        if action in ["pressure", "flank_right", "flank_left", "guard", "retreat"] and not choices.has(action):
            choices.append(action)
    if choices.is_empty():
        return ""
    if not weights.has(key):
        return "guard" if choices.has("guard") else choices[0]
    var q: Array = weights[key]
    var best: String = choices[0]
    for action in choices:
        if q[["pressure", "flank_right", "flank_left", "guard", "retreat"].find(action)] > q[["pressure", "flank_right", "flank_left", "guard", "retreat"].find(best)]:
            best = action
    return best

func run() -> void:
    var checks := 0
    for path in ["user://physics_policy_v1.json", "user://physics_policy_v2.json"]:
        var policy = Core.SharedPolicy.new()
        if not policy.load_artifact(path):
            push_error("Train both physics artifacts before testing select")
            quit(1)
            return
        var before := JSON.stringify(policy.weights)
        var keys: Array = policy.weights.keys()
        keys.append("never_seen_state")
        # Include ties and every nonempty action mask in both legal orders.
        policy.weights["test_equal"] = [1.0, 1.0, 1.0, 1.0, 1.0]
        keys.append("test_equal")
        for key in keys:
            for mask in range(1, 32):
                var legal := []
                for i in range(5):
                    if mask & (1 << i):
                        legal.append(Core.ACTIONS[i])
                for reverse in [false, true]:
                    var ordered := legal.duplicate()
                    if reverse:
                        ordered.reverse()
                    ordered.append("illegal")
                    ordered.append(ordered[0])
                    if policy.select(key, ordered, 0.0) != reference_select(policy.weights, key, ordered):
                        push_error("Shared selection changed: %s mask=%d" % [key, mask])
                        quit(1)
                        return
                    checks += 1
        policy.weights.erase("test_equal")
        if JSON.stringify(policy.weights) != before:
            push_error("Inference modified pretrained weights")
            quit(1)
            return
    print("POLICY_SELECT_CHECK checks=", checks, " failures=0")
    quit()
