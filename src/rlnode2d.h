#ifndef RLNODE2D_H
#define RLNODE2D_H

#include <godot_cpp/classes/rigid_body2d.hpp>
#include <godot_cpp/variant/vector2.hpp>  // Include for Vector2
#include "neural_network.h"  // Include for NeuralNetwork header
#include <vector>
#include <random>

namespace godot {

    class RLNode2D : public RigidBody2D  {
        GDCLASS(RLNode2D, RigidBody2D)

    private:
        double speed = 100.0;              // Default speed in pixels per second
        double time_passed = 0.0;
        double health = 5;                 // Initial health value
        bool is_attacking = false;
        Vector2 target_position;           // Position of the target for reward calculation
        double reward = 0.0;               // Reward variable to track in-game

        // Exploration and diversity variables
        double epsilon = 1.0;              // Exploration rate
        double epsilon_decay = 0.99;       // Rate at which epsilon decays
        double min_epsilon = 0.1;          // Minimum value for epsilon
        Vector2 last_action = Vector2(0, 0); // Last chosen action for diversity reward
        double last_reward = 0.0;          // Last calculated reward for diversity tracking

        NeuralNetwork* q_network;          // Q-network for action selection
        NeuralNetwork* target_network;     // Target network for stable Q-learning

        std::default_random_engine generator;

        // Helper methods
        Vector2 choose_action(const Eigen::VectorXd& current_state);
        void train_network();
        double calculate_movement_reward(Vector2 new_position);
        void update_target_network();

        // Conversion helpers
        Eigen::VectorXd vector2_to_eigen(const Vector2& vec);
        Vector2 eigen_to_vector2(const Eigen::VectorXd& vec);

    protected:
        static void _bind_methods();       // Used to bind methods and properties for Godot

    public:
        RLNode2D();
        ~RLNode2D();

        void _physics_process(double delta) override; // Use _physics_process for physics-based nodes

        // Health and attack state accessors
        void set_health(double p_health);
        double get_health() const;
        void set_is_attacking(bool attacking);
        bool get_is_attacking() const;
        void set_target_position(Vector2 p_target_position);
        Vector2 get_target_position() const;
        void set_linear_velocity(const Vector2 velocity);
        Vector2 get_linear_velocity() const;
        double get_reward() const;

        // Speed accessors
        void set_speed(const double p_speed);
        double get_speed() const;

        // Random number generation function
        int randomInt(int a, int b);
    };

}

#endif // RLNODE2D_H
