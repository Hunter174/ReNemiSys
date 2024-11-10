#include "rlnode2d.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <cmath>
#include <random>
#include <limits>
#include <tuple>

using namespace godot;
using namespace std;
using Eigen::MatrixXd;
using Eigen::VectorXd;

// Set desired frame intervals for training and experience storage
const int UPDATE_INTERVAL_FRAMES = 10; // Update every 30 frames (adjust as needed)

const double MAX_REWARD = 1000.0;
const double MIN_REWARD = -1000.0;
const double MAX_GRADIENT = 1.0;  // Gradient clipping value

void RLNode2D::_bind_methods() {
    // Bind standard properties and methods
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
    ClassDB::bind_method(D_METHOD("get_reward"), &RLNode2D::get_reward);
    ClassDB::bind_method(D_METHOD("set_reward", "reward"), &RLNode2D::set_reward);

    // Bind Q-value getter methods
    ClassDB::bind_method(D_METHOD("get_q_value_0"), &RLNode2D::get_q_value_0);
    ClassDB::bind_method(D_METHOD("get_q_value_1"), &RLNode2D::get_q_value_1);
    ClassDB::bind_method(D_METHOD("get_q_value_2"), &RLNode2D::get_q_value_2);
    ClassDB::bind_method(D_METHOD("get_q_value_3"), &RLNode2D::get_q_value_3);
    ClassDB::bind_method(D_METHOD("get_q_value_4"), &RLNode2D::get_q_value_4);
    ClassDB::bind_method(D_METHOD("get_q_value_5"), &RLNode2D::get_q_value_5);
    ClassDB::bind_method(D_METHOD("get_q_value_6"), &RLNode2D::get_q_value_6);
    ClassDB::bind_method(D_METHOD("get_q_value_7"), &RLNode2D::get_q_value_7);

    // Add Q-values as properties
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_0"), "", "get_q_value_0");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_1"), "", "get_q_value_1");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_2"), "", "get_q_value_2");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_3"), "", "get_q_value_3");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_4"), "", "get_q_value_4");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_5"), "", "get_q_value_5");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_6"), "", "get_q_value_6");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "q_value_7"), "", "get_q_value_7");

    // Other property bindings
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed", PROPERTY_HINT_RANGE, "0,20,0.01"), "set_speed", "get_speed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "health", PROPERTY_HINT_RANGE, "0,100,0.1"), "set_health", "get_health");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_attacking"), "set_is_attacking", "get_is_attacking");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "target_position"), "set_target_position", "get_target_position");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "linear_velocity"), "set_linear_velocity", "get_linear_velocity");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "reward"), "set_reward", "get_reward");
}

RLNode2D::RLNode2D()
    : q_values(VectorXd::Zero(8))  // Initialize q_values to a zero vector with 8 elements
{
    speed = 100.0;
    epsilon = 10.0; // Initial exploration rate
    epsilon_decay = 0.999;
    min_epsilon = 0.1;
    q_network = new NeuralNetwork({4, 64, 64, 8});
    target_network = new NeuralNetwork({4, 64, 64, 8});
    update_target_network();
}

RLNode2D::~RLNode2D() {
    delete q_network;
    delete target_network;
}

void RLNode2D::_physics_process(double delta) {
    frame_count++;

    // Prepare state vector with position, health, and attack status
    VectorXd state_vector = vector2_to_eigen(Vector2(get_position().x, get_position().y));
    state_vector.conservativeResize(4);
    state_vector(2) = health;
    state_vector(3) = is_attacking ? 1.0 : 0.0;

    // Check if the update interval has been reached
    if (frame_count % UPDATE_INTERVAL_FRAMES == 0) {
        Vector2 previous_position = get_position();

        // Choose the action based on the current exploration rate
        auto [chosen_action, action_index] = choose_action(state_vector);

        Vector2 new_position = previous_position + chosen_action * speed * delta;
        double movement_reward = calculate_movement_reward(previous_position, new_position);

        // Check if reward has improved or plateaued
        if (movement_reward > 0) {
            reward += movement_reward;
            plateau_counter = 0;  // Reset plateau counter if reward improves
        } else {
            plateau_counter++;  // Increment plateau counter if reward stagnates
        }

        // Temporarily boost exploration if plateau persists
        if (plateau_counter >= PLATEAU_THRESHOLD) {
            epsilon = max(epsilon, 0.5);  // Increase epsilon for exploration
        } else {
            epsilon = max(min_epsilon, epsilon * epsilon_decay); // Normal decay of epsilon
        }

        reward = clamp(reward, MIN_REWARD, MAX_REWARD);
        set_linear_velocity(chosen_action * speed);

        // Update the state and store experience
        VectorXd next_state = state_vector;
        next_state(0) = new_position.x;
        next_state(1) = new_position.y;
        store_experience(state_vector, action_index, reward, next_state);

        train_network();
    }

    // Reset frame counter if it reaches its max value
    if (frame_count >= numeric_limits<int>::max() - 1) {
        frame_count = 0;
    }
}

void RLNode2D::update_q_values(const VectorXd& current_state) {
    q_values = q_network->forward(current_state);
}

tuple<Vector2, int> RLNode2D::choose_action(const VectorXd& current_state) {
    update_q_values(current_state);
    int best_action_index = distance(q_values.data(), max_element(q_values.data(), q_values.data() + q_values.size()));
    vector<Vector2> action_map = {
        Vector2(1, 0),               // Right
        Vector2(-1, 0),              // Left
        Vector2(0, 1),               // Up
        Vector2(0, -1),              // Down
        Vector2(1, 1).normalized(),  // Diagonal up-right
        Vector2(-1, 1).normalized(), // Diagonal up-left
        Vector2(1, -1).normalized(), // Diagonal down-right
        Vector2(-1, -1).normalized() // Diagonal down-left
    };
    return {action_map[best_action_index], best_action_index};
}

double RLNode2D::calculate_movement_reward(Vector2 previous_position, Vector2 new_position) {
    double prev_distance = previous_position.distance_to(target_position);
    double new_distance = new_position.distance_to(target_position);

    double distance_change = prev_distance - new_distance;
    if (distance_change > 0) {
        return distance_change;  // Reward for getting closer
    } else {
        return -0.1;  // Small penalty for idling or moving away
    }
}


void RLNode2D::store_experience(const VectorXd& state, int action, double reward, const VectorXd& next_state) {
    NeuralNetwork::Experience experience = { state, next_state, reward, action };

    if (replay_buffer.size() >= buffer_size) {
        replay_buffer.pop_front();
    }

    replay_buffer.push_back(experience);
}

void RLNode2D::train_network() {
    if (replay_buffer.size() < batch_size) return;

    vector<NeuralNetwork::Experience> mini_batch;
    uniform_int_distribution<size_t> distribution(0, replay_buffer.size() - 1);

    for (size_t i = 0; i < batch_size; ++i) {
        size_t random_index = distribution(generator);
        mini_batch.push_back(replay_buffer[random_index]);
    }

    q_network->train(mini_batch, 0.1, 0.99);
}

void RLNode2D::update_target_network() {
    target_network->copy_weights_from(*q_network);
}

VectorXd RLNode2D::vector2_to_eigen(const Vector2& vec) {
    VectorXd result(2);
    result(0) = vec.x;
    result(1) = vec.y;
    return result;
}

Vector2 RLNode2D::eigen_to_vector2(const VectorXd& vec) {
    return (vec.size() >= 2) ? Vector2(vec(0), vec(1)) : Vector2();
}

void RLNode2D::set_linear_velocity(const Vector2 velocity) {
    RigidBody2D::set_linear_velocity(velocity);
}

Vector2 RLNode2D::get_linear_velocity() const {
    return RigidBody2D::get_linear_velocity();
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

void RLNode2D::set_reward(double p_reward) {
    reward = clamp(p_reward, MIN_REWARD, MAX_REWARD);  // Clamp reward for safety
}