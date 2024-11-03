#include <vector>
#include <tuple>
#include <iostream>
#include "neural_network.h"

int main() {
    // Initialize the neural network
    NeuralNetwork network({4, 64, 64, 8});

    // Create a simple test input and next state
    Eigen::VectorXd input(4);
    input << 1.0, 0.5, -0.5, 0.3;
    Eigen::VectorXd next_state(4);
    next_state << 0.2, -0.1, 0.4, 0.5;

    // Create a mini-batch with one training example
    std::vector<std::tuple<Eigen::VectorXd, int, double, Eigen::VectorXd>> mini_batch;
    mini_batch.push_back(std::make_tuple(input, 0, 1.0, next_state));

    // Train the network
    network.train(mini_batch, 0.01, 0.99);

    // Print weights after training
    std::cout << "Weights after training:\n";
    for (const auto& weight_matrix : network.get_weights()) {
        std::cout << weight_matrix << "\n";
    }

    return 0;
}
