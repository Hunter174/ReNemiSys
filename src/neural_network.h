#ifndef NEURAL_NETWORK_H
#define NEURAL_NETWORK_H

#include <vector>
#include <Eigen/Dense>

using namespace std;
using Eigen::MatrixXd;
using Eigen::VectorXd;

class NeuralNetwork {
private:
    vector<MatrixXd> weights;
    vector<MatrixXd> biases;
    const double clip_value = 1.0;

    // Activation functions
    VectorXd relu(const VectorXd& x);
    VectorXd softmax(const VectorXd& x);

    MatrixXd init_weights(int rows, int cols);

public:
    NeuralNetwork(const vector<int>& layer_sizes);

    // Struct to represent a single experience in the environment
    struct Experience {
        VectorXd current_state;
        VectorXd next_state;
        double reward;
        int action;
    };

    VectorXd forward(const VectorXd& x);

    // Train function based on Bellman's equation
    void train(vector<Experience>& mini_batch, double learning_rate, double gamma);

    void backpropagate(const VectorXd& input, const VectorXd& target, double learning_rate);

    // Get the weights
    const vector<MatrixXd>& get_weights() const;
    void copy_weights_from(const NeuralNetwork& other);
};

#endif // NEURAL_NETWORK_H
