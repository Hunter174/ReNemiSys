extends SceneTree
const Core = preload("res://combat_core.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func percentile(samples: Array[float], p: float) -> float:
    samples.sort()
    return samples[clampi(ceili(float(samples.size()) * p) - 1, 0, samples.size() - 1)]

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var policy = Core.SharedPolicy.new(43)
    var training_started_us := Time.get_ticks_usec()
    # OFFLINE TRAINING ONLY. Fixed payoff mechanics, observed player moves, epsilon exploration;
    # agents do not optimize neural weights during _physics_process.
    for courage in [0.2, 0.8]:
        for ambition in [0.2, 0.8]:
            for low in [false, true]:
                for tough in [false, true]:
                    for style in Core.STYLES:
                        var mind = Core.Mind.new(courage, ambition)
                        mind.observe_player(style)
                        mind.observe_player(style)
                        for episode in range(550):
                            var state: String = mind.observation(low, tough)
                            var action: String = policy.select(state, Core.ACTIONS, 0.35)
                            var reward: float = Core.encounter_reward(style, action, mind, low, tough)
                            policy.learn(state, action, reward, state, true)
    var training_ms := float(Time.get_ticks_usec() - training_started_us) / 1000.0
    var artifact := "user://adaptive_policy_v1.json"
    check(policy.save_artifact(artifact), "Training artifact must save")
    var loaded = Core.SharedPolicy.new(99)
    check(loaded.load_artifact(artifact), "Artifact must reload")
    check(JSON.stringify(policy.weights) == JSON.stringify(loaded.weights), "Loaded weights must reproduce learned policy")
    var corrupt := FileAccess.open("user://corrupt_policy.json", FileAccess.WRITE)
    corrupt.store_string('{"version":1,"actions":[],"sha256":"bogus","weights":{}}')
    corrupt.close()
    check(not loaded.load_artifact("user://corrupt_policy.json"), "Invalid weights must fail closed")

    var bold = Core.Mind.new(0.8, 0.8)
    var coward = Core.Mind.new(0.2, 0.2)
    for n in range(5):
        bold.observe_player("rush")
        coward.observe_player("rush")
    var brave_action: String = loaded.select(bold.observation(true, false), Core.ACTIONS)
    var timid_action: String = loaded.select(coward.observation(true, false), Core.ACTIONS)
    check(brave_action == "guard" and timid_action == "retreat", "Personality should change learned low-health tactic")
    var original_courage: float = coward.courage
    for n in range(10):
        coward.observe_player("dodge_right")
        loaded.select(coward.observation(false, false), Core.ACTIONS)
    check(coward.courage == original_courage, "Combat observations must not rewrite permanent traits")
    check(not coward.apply_epiphany({"kind": "epiphany", "id": "offer", "courage_delta": 0.2}, false, false), "Untrusted event must not mutate traits")
    check(not coward.apply_epiphany({"kind": "epiphany", "id": "offer", "courage_delta": 0.2}, true, true), "Ordinary fight may not change traits")
    check(coward.apply_epiphany({"kind": "epiphany", "id": "offer", "courage_delta": 0.2}, true, true, true), "Authorized mid-fight epiphany must apply")
    check(not coward.apply_epiphany({"kind": "epiphany", "id": "offer", "courage_delta": 0.2}, true, true, true), "Duplicate epiphany must not repeat")
    check(coward.courage > original_courage, "Epiphany must change the lasting trait")
    var save_path := "user://goblin_personality_v1.json"
    var save_file := FileAccess.open(save_path, FileAccess.WRITE)
    check(save_file != null, "Goblin save file must open")
    if save_file != null:
        save_file.store_string(JSON.stringify(coward.snapshot()))
        save_file.close()
    var restored = Core.Mind.new(0.8, 0.8)
    var save_data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    check(save_data is Dictionary and restored.restore(save_data), "Goblin trait and memory must reload")
    check(restored.courage == coward.courage and restored.ambition == coward.ambition and
        restored.player_belief() == coward.player_belief(), "Traits and encounter memory must survive reload")
    check(not restored.apply_epiphany({"kind": "epiphany", "id": "offer", "courage_delta": 0.2}, true, false),
        "Already-applied epiphany must stay idempotent after reload")
    var old_courage: float = restored.courage
    check(not restored.restore({"version": 1, "courage": -1, "ambition": 0.5, "player_moves": [], "seen_epiphanies": []}) and restored.courage == old_courage,
        "Malformed trait snapshot must fail without mutating the agent")

    var scout = Core.Mind.new(0.8, 0.8)
    for n in range(5):
        scout.observe_player("dodge_right")
    var right_action: String = loaded.select(scout.observation(false, false), Core.ACTIONS)
    for n in range(5):
        scout.observe_player("dodge_left")
    var left_action: String = loaded.select(scout.observation(false, false), Core.ACTIONS)
    check(right_action == "flank_right" and left_action == "flank_left", "Agent must exploit and then adapt to a changed player pattern")
    var adaptive_score := 0.0
    var fixed_score := 0.0
    for style in Core.STYLES:
        var observer = Core.Mind.new(0.8, 0.8)
        for n in range(5):
            observer.observe_player(style)
        var learned: String = loaded.select(observer.observation(false, false), Core.ACTIONS)
        adaptive_score += Core.encounter_reward(style, learned, observer, false, false)
        fixed_score += Core.encounter_reward(style, "pressure", observer, false, false)
    check(adaptive_score > fixed_score + 2.0, "Policy must outperform fixed pressure on trained archetypes")
    # Evaluation strategy was NOT used for training: a noisy opponent changes its bias mid-fight.
    var opponent_rng := RandomNumberGenerator.new()
    opponent_rng.seed = 877
    var changing = Core.Mind.new(0.8, 0.8)
    var mixed_adaptive := 0.0
    var mixed_fixed := 0.0
    var early_right := 0
    var late_left := 0
    for turn in range(100):
        var action: String = loaded.select(changing.observation(false, false), Core.ACTIONS)
        if turn >= 10 and turn < 40 and action == "flank_right":
            early_right += 1
        if turn >= 70 and action == "flank_left":
            late_left += 1
        var favored := "dodge_right" if turn < 50 else "dodge_left"
        var style: String = favored if opponent_rng.randf() < 0.8 else ("dodge_left" if favored == "dodge_right" else "dodge_right")
        mixed_adaptive += Core.encounter_reward(style, action, changing, false, false)
        mixed_fixed += Core.encounter_reward(style, "pressure", changing, false, false)
        changing.observe_player(style) # only after action; cannot peek at the next move
    check(mixed_adaptive > mixed_fixed and early_right >= 20 and late_left >= 20,
        "Policy must exploit then adapt to a held-out stochastic player")
    check(loaded.select(scout.observation(false, false), ["guard"]) == "guard", "Mask must constrain learned choice")
    check(loaded.select(scout.observation(false, false), ["invalid"]) == "", "No legal action must remain no action")
    var size_before: int = loaded.weights.size()
    check(loaded.select("unseen:state", Core.ACTIONS) == "guard" and loaded.weights.size() == size_before,
        "Inference must not create new weights for unseen states")
    var independent: Array[float] = []
    var agents := []
    for i in range(20):
        var agent = Core.Mind.new(0.8, 0.8)
        agent.observe_player("dodge_right")
        agent.observe_player("dodge_right")
        agents.append(agent)
    for n in range(400):
        var start := Time.get_ticks_usec()
        for agent in agents:
            loaded.select(agent.observation(false, false), Core.ACTIONS)
        independent.append(float(Time.get_ticks_usec() - start) / 1000.0)
    print("ARENA_CHECK training_ms=", snappedf(training_ms, 0.1),
        " shared_q_states=", loaded.weights.size(), " brave=", brave_action,
        " coward=", timid_action, " adapt=", right_action, "->", left_action,
        " scripted_adaptive_reward=", adaptive_score, " fixed_pressure_reward=", fixed_score,
        " noisy_style_reward=", snappedf(mixed_adaptive, 0.1), " noisy_fixed_reward=", snappedf(mixed_fixed, 0.1),
        " right_before_switch=", early_right, "/30 left_after_switch=", late_left, "/30",
        " 20_agents_p50_ms=", percentile(independent, 0.5),
        " 20_agents_p95_ms=", percentile(independent, 0.95),
        " 20_agents_p99_ms=", percentile(independent, 0.99), " failures=", failures)
    quit(1 if failures else 0)
