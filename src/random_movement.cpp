#include "random_movement.h"

using namespace godot;

RandomMovement::RandomMovement() {}

RandomMovement::~RandomMovement() {
    if (rng) {
        memdelete(rng);  // Free Godot objects with memdelete
    }
}

void RandomMovement::_init() {
    rng = memnew(RandomNumberGenerator);  // Initialize the RNG
    rng->randomize();  // Randomize the seed
}

String RandomMovement::move_random(float delta) {
    // Generate random movement direction (-1 to 1)
    float random_x = rng->randf_range(-1, 1);
    float random_y = rng->randf_range(-1, 1);

    // Create a random direction vector and normalize it
    Vector2 random_direction = Vector2(random_x, random_y).normalized();

    // Apply movement to the node's position
    set_position(get_position() + random_direction * delta * 100.0);  // 100 is the movement speed

    // Return a simple string indicating movement (for demo purposes)
    if (random_x > 0) {
        return "move_right";
    } else if (random_x < 0) {
        return "move_left";
    } else if (random_y < 0) {
        return "move_up";
    } else {
        return "move_down";
    }
}

void RandomMovement::_process(float delta) {
    // Automatically move randomly every frame
    move_random(delta);
}

// The _bind_methods function to register methods
void RandomMovement::_bind_methods() {
    ClassDB::bind_method(D_METHOD("_process"), &RandomMovement::_process);
    ClassDB::bind_method(D_METHOD("move_random"), &RandomMovement::move_random);
}

// GDExtension initialization function
extern "C" void GDE_EXPORT gdextension_random_movement_library_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization* initialization) {

    godot::GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);

    // Use ClassDB to register the RandomMovement class
    ClassDB::register_class<RandomMovement>();

    init_obj.register_terminator(nullptr);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
}
