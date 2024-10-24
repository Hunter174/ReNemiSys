#ifndef RLNODE2D_H
#define RLNODE2D_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/variant/vector2.hpp>  // Include for Vector2

namespace godot {

    class RLNode2D : public Node2D {
        GDCLASS(RLNode2D, Node2D)

    private:
        double speed = 0.0;
        double time_passed = 0.0;
        Vector2 target_position;  // Declaration of the target position

    protected:
        static void _bind_methods();  // Used to bind methods and properties for Godot

    public:
        RLNode2D();
        ~RLNode2D();

        void _process(double delta) override;

        // Getter and setter for speed
        void set_speed(const double p_speed);
        double get_speed() const;

        // Random number generation functions
        int randomInt(int a, int b);    // Generates a random integer between a and b (inclusive)
    };

}

#endif // RLNODE2D_H
