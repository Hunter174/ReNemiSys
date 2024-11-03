#include "rlnode2d.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <cmath>
#include <random>

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
    q_network = new NeuralNetwork({4, 64, 64, 8}); // Example network with input, hidden, and output layers
    target_network = new NeuralNetwork({4, 64, 64, 8});
    update_target_network(); // Initialize target network weights
    srand(static_cast<unsigned int>(time(0)));
}

RLNode2D::~RLNode2D() {
    delete q_network;
    delete target_network;
}

void RLNode2D::_physics_process(double delta) {
    // Convert current state to Eigen vector for input
    Eigen::VectorXd state_vector = vector2_to_eigen(Vector2(get_position().x, get_position().y));
    state_vector.conservativeResize(4);
    state_vector(2) = health;
    state_vector(3) = is_attacking ? 1.0 : 0.0;

    Vector2 chosen_action = choose_action(state_vector);

    // Decay epsilon over time
    epsilon = std::max(min_epsilon, epsilon * epsilon_decay);

    // Apply chosen action as linear velocity
    set_linear_velocity(chosen_action * speed);
}

Vector2 RLNode2D::choose_action(const Eigen::VectorXd& current_state) {
    std::uniform_real_distribution<double> distribution(0.0, 1.0);
    if (distribution(generator) < epsilon) {
        // Exploration: choose a random action
        std::vector<Vector2> possible_actions = {Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
                                                  Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
                                                  Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()};
        return possible_actions[randomInt(0, possible_actions.size() - 1)];
    } else {
        // Exploitation: choose action based on Q-network output
        Eigen::VectorXd q_values = q_network->forward(current_state);
        int best_action_index = std::distance(q_values.data(), std::max_element(q_values.data(), q_values.data() + q_values.size()));
        std::vector<Vector2> action_map = {Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
                                           Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
                                           Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()};
        return action_map[best_action_index];
    }
}

int RLNode2D::randomInt(int a, int b) {
    return a + (rand() % (b - a + 1));
}

void RLNode2D::update_target_network() {
    target_network->copy_weights_from(*q_network);
}

// Helper to convert Vector2 to Eigen::VectorXd
Eigen::VectorXd RLNode2D::vector2_to_eigen(const Vector2& vec) {
    Eigen::VectorXd result(2);
    result(0) = vec.x;
    result(1) = vec.y;
    return result;
}

// Helper to convert Eigen::VectorXd to Vector2
Vector2 RLNode2D::eigen_to_vector2(const Eigen::VectorXd& vec) {
    if (vec.size() >= 2) {
        return Vector2(vec(0), vec(1));
    }
    return Vector2();
}

void RLNode2D::set_linear_velocity(const Vector2 velocity) {
    RigidBody2D::set_linear_velocity(velocity); // Call base class method
}

Vector2 RLNode2D::get_linear_velocity() const {
    return RigidBody2D::get_linear_velocity(); // Call base class method
}

void RLNode2D::set_is_attacking(bool attacking) {
    is_attacking = attacking;
}

bool RLNode2D::get_is_attacking() const {
    return is_attacking;
}

void RLNode2D::set_target_position(Vector2 p_target_position) {
    target_position = p_target_position;
}

Vector2 RLNode2D::get_target_position() const {
    return target_position;
}

void RLNode2D::set_health(double p_health) {
    health = p_health;
}

double RLNode2D::get_health() const {
    return health;
}

void RLNode2D::set_speed(const double p_speed) {
    speed = p_speed;
}

double RLNode2D::get_speed() const {
    return speed;
}

double RLNode2D::get_reward() const {
    return reward;
}
