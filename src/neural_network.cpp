#include "neural_network.h"
#include <cmath>
#include <random>
#include <iostream>


NeuralNetwork::NeuralNetwork(const std::vector<int>& layer_sizes) {
    for (size_t i = 0; i < layer_sizes.size() - 1; ++i) {
        weights.push_back(random_init(layer_sizes[i + 1], layer_sizes[i]));
        biases.push_back(Eigen::VectorXd::Zero(layer_sizes[i + 1]));
    }
}

Eigen::MatrixXd NeuralNetwork::random_init(int rows, int cols) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<> dis(-0.1, 0.1);

    Eigen::MatrixXd mat(rows, cols);
    for (int i = 0; i < rows; ++i)
        for (int j = 0; j < cols; ++j)
            mat(i, j) = dis(gen);

    return mat;
}

Eigen::VectorXd NeuralNetwork::relu(const Eigen::VectorXd& x) {
    return x.cwiseMax(0);
}

Eigen::VectorXd NeuralNetwork::softmax(const Eigen::VectorXd& x) {
    Eigen::VectorXd exp_x = x.array().exp();
    return exp_x / exp_x.sum();
}

Eigen::VectorXd NeuralNetwork::forward(const Eigen::VectorXd& input) {
    Eigen::VectorXd activation = input;
    for (size_t i = 0; i < weights.size() - 1; ++i) {
        std::cout << "Layer " << i << ": weights size = " << weights[i].rows() << "x" << weights[i].cols()
                  << ", activation size = " << activation.size() << std::endl;

        activation = relu(weights[i] * activation + biases[i]);
    }
    std::cout << "Final layer: weights size = " << weights.back().rows() << "x" << weights.back().cols()
              << ", activation size = " << activation.size() << std::endl;

    activation = weights.back() * activation + biases.back(); // No activation on the final layer
    return activation;
}

void NeuralNetwork::backpropagate(const Eigen::VectorXd& input, const Eigen::VectorXd& target, double learning_rate) {
    // Forward pass
    std::vector<Eigen::VectorXd> activations;
    std::vector<Eigen::VectorXd> zs;
    activations.push_back(input);
    Eigen::VectorXd activation = input;

    for (size_t i = 0; i < weights.size(); ++i) {
        Eigen::VectorXd z = weights[i] * activation + biases[i];
        zs.push_back(z);
        activation = relu(z);
        activations.push_back(activation);
    }

    // Backward pass
    Eigen::VectorXd delta = activations.back() - target; // Output error

    for (int i = weights.size() - 1; i >= 0; --i) {
        Eigen::MatrixXd grad_w = delta * activations[i].transpose();
        Eigen::VectorXd grad_b = delta;

        // Update weights and biases
        weights[i] -= learning_rate * grad_w;
        biases[i] -= learning_rate * grad_b;

        if (i > 0) {
            delta = (weights[i].transpose() * delta).cwiseProduct(zs[i - 1].unaryExpr([](double elem) { return elem > 0 ? 1.0 : 0.0; }));
        }
    }
}

void NeuralNetwork::train(std::vector<std::tuple<Eigen::VectorXd, int, double, Eigen::VectorXd>>& mini_batch, double learning_rate, double gamma) {
    for (const auto& experience : mini_batch) {
        Eigen::VectorXd state, next_state;
        int action;
        double reward;
        std::tie(state, action, reward, next_state) = experience;

        std::cout << "State size: " << state.size() << ", Next state size: " << next_state.size() << std::endl;
        std::cout << "Action index: " << action << std::endl;

        Eigen::VectorXd target = forward(state);
        std::cout << "Target size before update: " << target.size() << std::endl;

        double max_next_q = forward(next_state).maxCoeff();
        target[action] = reward + gamma * max_next_q;

        backpropagate(state, target, learning_rate);
    }
}

void NeuralNetwork::copy_weights_from(const NeuralNetwork& other) {
    for (size_t i = 0; i < weights.size(); ++i) {
        weights[i] = other.weights[i];
        biases[i] = other.biases[i];
    }
}

// Define get_weights() method
const std::vector<Eigen::MatrixXd>& NeuralNetwork::get_weights() const {
    return weights;
}
