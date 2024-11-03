#ifndef NEURAL_NETWORK_H
#define NEURAL_NETWORK_H

#include <vector>
#include <Eigen/Dense>

class NeuralNetwork {
private:
    std::vector<Eigen::MatrixXd> weights; // Vector of weight matrices
    std::vector<Eigen::VectorXd> biases;  // Vector of bias vectors

    // Activation functions
    Eigen::VectorXd relu(const Eigen::VectorXd& x);
    Eigen::VectorXd softmax(const Eigen::VectorXd& x);

    // Random initialization helper
    Eigen::MatrixXd random_init(int rows, int cols);

public:
    NeuralNetwork(const std::vector<int>& layer_sizes);

    // Forward pass
    Eigen::VectorXd forward(const Eigen::VectorXd& input);

    // Based on the Q Learning update rule
    void train(std::vector<std::tuple<Eigen::VectorXd, int, double, Eigen::VectorXd>>& mini_batch, double learning_rate, double gamma);

    // Backpropagation method for training
    void backpropagate(const Eigen::VectorXd& input, const Eigen::VectorXd& target, double learning_rate);

    // Utility to copy weights from another network
    void copy_weights_from(const NeuralNetwork& other);

    // Method to access weights
    const std::vector<Eigen::MatrixXd>& get_weights() const; // Declare get_weights() here
};

#endif // NEURAL_NETWORK_H
