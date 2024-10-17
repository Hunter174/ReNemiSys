#ifndef RANDOM_MOVEMENT_H
#define RANDOM_MOVEMENT_H

#include <Godot.hpp>
#include <Node2D.hpp>
#include <random_number_generator.hpp>

class RandomMovement : public godot::Node2D {
    GDCLASS(RandomMovement, godot::Node2D)  // Use GDCLASS instead of GODOT_CLASS

private:
    godot::RandomNumberGenerator* rng;

public:
    // Constructor
    RandomMovement();

    // Destructor
    ~RandomMovement();

    // Initialize random number generator
    void _init();

    // Function to move in a random direction
    godot::String move_random(float delta);

    // Process function (called every frame)
    void _process(float delta);

    // Method binding (required for Godot to recognize functions)
    static void _bind_methods();
};

#endif  // RANDOM_MOVEMENT_H
