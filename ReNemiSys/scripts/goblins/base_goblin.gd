extends RigidBody2D

var health = 3
var patrol_speed = 200
var direction = Vector2(1,0) #initial direction
var prev_direction = Vector2(1,0)
var timer = 0.0
var change_dir = 2.0 # change the direction after 2 sec
var reverse_collision = true
var player_in_range = false  # Tracks if the player is within the detection range
var line_of_sight = 150
var dead = false
var is_attacking = false  # Track if the goblin is currently attacking

@onready var detection_area = $GoblinArea
@onready var raycast = $RayCast2D
@onready var line2d = $Line2D  # Reference to Line2D for visualizing the ray
@onready var animated_sprite = $AnimatedSprite2D  # Reference to the sprite for animations
@onready var die_timer = $Timer
@onready var rl_node_2d = $RLNode2D
	
func take_damage():
	if dead:  # If the enemy is dead, return false
		return false
	
	print('ow')
	health -= 1
	if health <= 0:
		remove_from_group('enemy')
		die()
	
	return true  # Return true if the enemy is still alive
		
func die():
	dead = true
	linear_velocity = Vector2.ZERO
	die_timer.start()
	animated_sprite.play("die")

func _on_timer_timeout():
	queue_free()

func _physics_process(delta):
	if dead == false:
		if is_attacking == false:
			if rl_node_2d != null:
				linear_velocity  = rl_node_2d.position
				animated_sprite.play("walking")
				
				if linear_velocity.x > 0:
					animated_sprite.flip_h = false  # Moving right, no flip
				elif linear_velocity.x < 0:
					animated_sprite.flip_h = true   # Moving left, flip sprite

				# Update ray target position if the enemy changes direction
				update_direction()
		else:		
			linear_velocity  = Vector2.ZERO
		
func update_direction():
	# Check if the direction has changed
	if direction != prev_direction:
		prev_direction = direction 

		# Update the RayCast2D's target_position to match the new direction
		raycast.target_position = direction.normalized() * line_of_sight 

		# Update Line2D to reflect the new ray target
		line2d.clear_points()
		line2d.add_point(raycast.position)
		line2d.add_point(raycast.target_position)

# Function to handle movement and detect collisions
func move_with_collision(delta):
	var collision = move_and_collide(direction * patrol_speed * delta)
	
	if collision:
		if reverse_collision:
			direction = -direction
		else:
			direction = Vector2.ZERO

	# Play walking animation when moving
	if direction != Vector2.ZERO:
		animated_sprite.play("walking")
	else:
		animated_sprite.play("idle")

	# Flip the sprite if moving left
	if direction.x < 0:
		animated_sprite.flip_h = true  # Flip the sprite when moving left
	elif direction.x > 0:
		animated_sprite.flip_h = false  # Reset flip when moving right

func check_line_of_sight(delta):
	# Ensure direction is not zero to avoid invalid raycast direction
	if direction == Vector2.ZERO:
		direction = Vector2(1, 0)  # Default direction if none is set

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider.is_in_group("players"):
			print("Player detected in line of sight!")
			#chase_player(collider, delta)
		else:
			# If no player is detected, continue patrolling
			#patrol(delta)
			pass
	else:
		# If no collision is detected, continue patrolling
		pass

# Example function to chase the player
func chase_player(player, delta):
	# Move towards the player directly
	direction = (player.position - position).normalized()
	move_with_collision(delta)

