#ifndef RL_NODE_2D_H
#define RL_NODE_2D_H

#include <godot_cpp/classes/rigid_body2d.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include "neural_network.h"
#include <vector>
#include <random>
#include <deque>
#include <tuple> // Required for std::tuple

using namespace std;
using Eigen::MatrixXd;
using Eigen::VectorXd;

namespace godot {

    class RLNode2D : public RigidBody2D {
        GDCLASS(RLNode2D, RigidBody2D)

    private:
        double speed;
        double health;
        double reward;
        bool is_attacking;
        int frame_count;

        Vector2 target_position; // Target position for the node
        Vector2 position;        // The position of the enemy node
        Vector2 rl_velocity;     // Stores the target direction for velocity
        VectorXd q_values;       // Q-values for each action

        double epsilon;
        double epsilon_decay;
        double min_epsilon;

        // Neural Network and Replay Buffer
        NeuralNetwork* q_network;
        NeuralNetwork* target_network;
        deque<NeuralNetwork::Experience> replay_buffer;

        size_t buffer_size = 10000; // Default buffer size
        size_t batch_size = 32;     // Default batch size

        default_random_engine generator{random_device{}()}; // Seed the generator

        // Plateau detection variables
        int plateau_counter = 0;           // Tracks consecutive frames with no reward improvement
        const int PLATEAU_THRESHOLD = 10;  // Frames before boosting exploration

        // Helper methods
        tuple<Vector2, int> choose_action(const VectorXd& current_state);
        void train_network();
        void store_experience(const VectorXd& state, int action, double reward, const VectorXd& next_state);
        double calculate_movement_reward(Vector2 previous_position, Vector2 new_position);
        void update_target_network();
        void update_q_values(const VectorXd& current_state);

        // Conversion helpers
        VectorXd vector2_to_eigen(const Vector2& vec);
        Vector2 eigen_to_vector2(const VectorXd& vec);

    protected:
        static void _bind_methods();

    public:
        RLNode2D();
        ~RLNode2D();

        void _physics_process(double delta) override;

        // Accessor and Mutator methods
        void set_health(double p_health);
        double get_health() const;

        void set_is_attacking(bool attacking);
        bool get_is_attacking() const;

        void set_position(Vector2 p_position);
        Vector2 get_position() const;

        void set_target_position(Vector2 p_target_position);
        Vector2 get_target_position() const;

        void set_rl_velocity(const Vector2 velocity);
        Vector2 get_rl_velocity() const;

        void set_reward(double p_reward);
        double get_reward() const;

        void set_speed(const double p_speed);
        double get_speed() const;

        // Getter methods for each Q-value
        double get_q_value_0() const { return q_values[0]; }
        double get_q_value_1() const { return q_values[1]; }
        double get_q_value_2() const { return q_values[2]; }
        double get_q_value_3() const { return q_values[3]; }
        double get_q_value_4() const { return q_values[4]; }
        double get_q_value_5() const { return q_values[5]; }
        double get_q_value_6() const { return q_values[6]; }
        double get_q_value_7() const { return q_values[7]; }
    };

}

#endif // RL_NODE_2D_H
