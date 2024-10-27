#include "rlnode2d.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <cmath>
#include <cstdlib>
#include <ctime>

using namespace godot;

void RLNode2D::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_speed"), &RLNode2D::get_speed);
    ClassDB::bind_method(D_METHOD("set_speed", "p_speed"), &RLNode2D::set_speed);

    ClassDB::bind_method(D_METHOD("get_health"), &RLNode2D::get_health);
    ClassDB::bind_method(D_METHOD("set_health", "_health"), &RLNode2D::set_health);

    ClassDB::bind_method(D_METHOD("get_target_position"), &RLNode2D::get_target_position);
    ClassDB::bind_method(D_METHOD("set_target_position", "p_target_position"), &RLNode2D::set_target_position);

    ClassDB::bind_method(D_METHOD("get_is_attacking"), &RLNode2D::get_is_attacking);
    ClassDB::bind_method(D_METHOD("set_is_attacking", "attacking"), &RLNode2D::set_is_attacking);

    ClassDB::bind_method(D_METHOD("get_linear_velocity"), &RLNode2D::get_linear_velocity);
    ClassDB::bind_method(D_METHOD("set_linear_velocity", "velocity"), &RLNode2D::set_linear_velocity);

    ClassDB::bind_method(D_METHOD("get_reward"), &RLNode2D::get_reward); // Bind reward getter

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed", PROPERTY_HINT_RANGE, "0,20,0.01"), "set_speed", "get_speed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "health", PROPERTY_HINT_RANGE, "0,100,0.1"), "set_health", "get_health");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_attacking"), "set_is_attacking", "get_is_attacking");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "target_position"), "set_target_position", "get_target_position");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "linear_velocity"), "set_linear_velocity", "get_linear_velocity");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "reward"), "", "get_reward"); // Expose reward as a read-only property
}



RLNode2D::RLNode2D() {
    time_passed = 0.0;
    speed = 100.0;
    epsilon = 1.0; // Initial exploration rate
    epsilon_decay = 0.99; // Decay factor for exploration
    min_epsilon = 0.1; // Minimum exploration rate
    srand(static_cast<unsigned int>(time(0)));
}

RLNode2D::~RLNode2D() {}

void RLNode2D::_physics_process(double delta) {
    // Define possible actions as directional vectors
    Vector2 actions[] = {Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
                         Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
                         Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()};

    Vector2 best_action = Vector2(0, 0);
    double max_reward = -INFINITY;

    // Epsilon-greedy exploration
    bool should_explore = (rand() / double(RAND_MAX)) < epsilon;
    epsilon = fmax(min_epsilon, epsilon * epsilon_decay); // Decay epsilon over time

    if (should_explore) {
        // Select a random action for exploration
        best_action = actions[randomInt(0, sizeof(actions) / sizeof(actions[0]) - 1)];
    } else {
        // Evaluate each action based on expected reward for exploitation
        for (Vector2 action : actions) {
            double reward = calculate_movement_reward(get_position() + action * speed * delta);
            if (reward > max_reward) {
                max_reward = reward;
                best_action = action;
            }
        }
    }

    // Diversity reward: penalize repeated actions with no improvement
    if (best_action == last_action && max_reward <= last_reward) {
        max_reward -= 1.0; // Penalize lack of improvement
    }

    last_action = best_action;
    last_reward = max_reward;

    // Set linear velocity to move in the direction of the highest reward
    set_linear_velocity(best_action * speed);
}

// Reward calculations
double RLNode2D::calculate_movement_reward(Vector2 new_position) {
    double reward = 0.0;

    // Reward for moving closer to target
    Vector2 to_target = target_position - new_position;
    reward += 10.0 / (to_target.length() + 1);  // Higher reward for closer distances

    if(is_attacking){
        reward += 5.0;
    }

    // Reward for keeping distance if health is low
    if (health < 2) {
        Vector2 to_target = new_position - target_position;
        reward += 5.0 * (1.0 / (to_target.length() + 1));
    }

    return reward;
}

// Health and attack setters
void RLNode2D::set_health(double p_health) { health = p_health; }
double RLNode2D::get_health() const { return health; }
void RLNode2D::set_is_attacking(bool attacking) { is_attacking = attacking; }
bool RLNode2D::get_is_attacking() const { return is_attacking; }

int RLNode2D::randomInt(int a, int b) {
    return a + (rand() % (b - a + 1));
}

void RLNode2D::set_speed(const double p_speed) {
    speed = p_speed;
}

double RLNode2D::get_speed() const {
    return speed;
}

void RLNode2D::set_target_position(const Vector2 p_target_position) {
    target_position = p_target_position;
}

Vector2 RLNode2D::get_target_position() const {
    return target_position;
}

void RLNode2D::set_linear_velocity(const Vector2 velocity) {
    RigidBody2D::set_linear_velocity(velocity);
}

Vector2 RLNode2D::get_linear_velocity() const {
    return RigidBody2D::get_linear_velocity();
}

double RLNode2D::get_reward() const {
    return reward;
}