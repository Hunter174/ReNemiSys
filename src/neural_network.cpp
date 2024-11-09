#include "neural_network.h"
#include <cmath>
#include <random>
#include <iostream>
#include <algorithm>

using namespace std;
using Eigen::MatrixXd;
using Eigen::VectorXd;

// Clipping constants to prevent values from exploding
const double GRADIENT_CLIP_VALUE = 1.0;
const double TARGET_CLIP_MIN = -10.0;
const double TARGET_CLIP_MAX = 10.0;

NeuralNetwork::NeuralNetwork(const vector<int>& layer_sizes) {
    for (size_t i = 0; i < layer_sizes.size() - 1; ++i) {
        weights.push_back(init_weights(layer_sizes[i + 1], layer_sizes[i]));
        biases.push_back(VectorXd::Zero(layer_sizes[i + 1]));
    }
}

// Helper function to initialize weights with random values
MatrixXd NeuralNetwork::init_weights(int rows, int cols) {
    random_device rd;
    mt19937 gen(rd());
    uniform_real_distribution<> dis(-0.1, 0.1);  // Small range to prevent large initial values

    MatrixXd mat(rows, cols);
    for (int i = 0; i < rows; ++i)
        for (int j = 0; j < cols; ++j)
            mat(i, j) = dis(gen);

    return mat;
}

// Activation functions
VectorXd NeuralNetwork::relu(const VectorXd& x) {
    return x.cwiseMax(0);
}

VectorXd NeuralNetwork::softmax(const VectorXd& x) {
    VectorXd exp_x = (x.array() - x.maxCoeff()).exp();
    return exp_x / exp_x.sum();
}

// Forward pass through the network
VectorXd NeuralNetwork::forward(const VectorXd& x) {
    VectorXd activation = x;
    for (size_t i = 0; i < weights.size() - 1; ++i) {
        activation = relu(weights[i] * activation + biases[i]).cwiseMin(10.0).cwiseMax(-10.0);  // Clipping activations
    }

    activation = weights.back() * activation + biases.back();
    return softmax(activation);
}

// Backpropagation for a single sample
void NeuralNetwork::backpropagate(const VectorXd& input, const VectorXd& target, double learning_rate) {
    vector<VectorXd> activations;
    vector<VectorXd> zs;

    activations.push_back(input);
    VectorXd activation = input;

    // Forward pass to store activations and pre-activation (z) values
    for (size_t i = 0; i < weights.size(); ++i) {
        VectorXd z = weights[i] * activation + biases[i];
        zs.push_back(z);
        activation = (i < weights.size() - 1) ? relu(z) : softmax(z);
        activation = activation.cwiseMin(10.0).cwiseMax(-10.0);  // Clipping activations
        activations.push_back(activation);
    }

    VectorXd delta = (activations.back() - target).cwiseMin(1.0).cwiseMax(-1.0);  // Cap delta between -1 and 1

    // Backpropagation through layers
    for (int i = weights.size() - 1; i >= 0; --i) {
        MatrixXd grad_w = delta * activations[i].transpose();
        VectorXd grad_b = delta;

        // Gradient clipping
        grad_w = grad_w.unaryExpr([](double v) { return std::clamp(v, -GRADIENT_CLIP_VALUE, GRADIENT_CLIP_VALUE); });
        grad_b = grad_b.unaryExpr([](double v) { return std::clamp(v, -GRADIENT_CLIP_VALUE, GRADIENT_CLIP_VALUE); });

        // Update weights and biases with clipped gradients
        weights[i] -= learning_rate * grad_w;
        biases[i] -= learning_rate * grad_b;

        // Calculate delta for the next layer if not the first layer
        if (i > 0) {
            delta = (weights[i].transpose() * delta).cwiseProduct(zs[i - 1].unaryExpr([](double elem) { return elem > 0 ? 1.0 : 0.0; }));
        }
    }
}

// Train the network with a mini-batch of experiences based on Bellman's equation
void NeuralNetwork::train(vector<Experience>& mini_batch, double learning_rate, double gamma) {
    for (const auto& experience : mini_batch) {
        VectorXd state = experience.current_state;
        VectorXd next_state = experience.next_state;
        int action = experience.action;
        double reward = experience.reward;

        VectorXd target = forward(state);

        double max_next_q = forward(next_state).maxCoeff();
        double target_value = std::clamp(reward + gamma * max_next_q, TARGET_CLIP_MIN, TARGET_CLIP_MAX);  // Target clipping
        target[action] = target_value;

        backpropagate(state, target, learning_rate);
    }
}

void NeuralNetwork::copy_weights_from(const NeuralNetwork& other) {
    if (weights.size() != other.weights.size() || biases.size() != other.biases.size()) {
        cerr << "Error: Network structures do not match. Cannot copy weights." << endl;
        return;
    }
    for (size_t i = 0; i < weights.size(); ++i) {
        weights[i] = other.weights[i];
        biases[i] = other.biases[i];
    }
}

// Get the weights of the network
const vector<MatrixXd>& NeuralNetwork::get_weights() const {
    return weights;
}
