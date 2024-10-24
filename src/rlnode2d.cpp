#include "rlnode2d.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <cmath>
#include <cstdlib>
#include <ctime>

using namespace godot;

void RLNode2D::_bind_methods() {
    // Binding the getter and setter methods for speed
    ClassDB::bind_method(D_METHOD("get_speed"), &RLNode2D::get_speed);
    ClassDB::bind_method(D_METHOD("set_speed", "p_speed"), &RLNode2D::set_speed);

    // Registering speed as a property in Godot's inspector
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed", PROPERTY_HINT_RANGE, "0,20,0.01"), "set_speed", "get_speed");
}

RLNode2D::RLNode2D() {
    // Initialize variables
    time_passed = 0.0;
    speed = 100.0; // Speed in pixels per second

    // Seed the random number generator once, in the constructor
    srand(static_cast<unsigned int>(time(0)));

    // Set an initial random target position using integer randomness
    target_position = Vector2(randomInt(-200, 200), randomInt(-200, 200));
}

RLNode2D::~RLNode2D() {
    // Add any cleanup code here if necessary
}

void RLNode2D::_process(double delta) {
    // Calculate the direction towards the target
    Vector2 current_position = get_position();
    Vector2 direction = target_position - current_position;

    // If we're close to the target, generate a new target position
    if (direction.length() < 5) {  // Threshold of 10 pixels
        target_position = Vector2(randomInt(-200, 200), randomInt(-200, 200));
    } else {
        // Normalize the direction and move towards the target
        direction = direction.normalized();
        Vector2 velocity = direction * speed * delta;

        // Move the node by the calculated velocity
        set_position(current_position + velocity);
    }
}

// Function to generate a random integer between two values (inclusive)
int RLNode2D::randomInt(int a, int b) {
    return a + (rand() % (b - a + 1));
}

// Setter for speed
void RLNode2D::set_speed(const double p_speed) {
    speed = p_speed;
}

// Getter for speed
double RLNode2D::get_speed() const {
    return speed;
}
