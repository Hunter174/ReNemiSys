# goblin_base.gd
extends RigidBody2D

# Basic attributes
var health = 3
var patrol_speed = 200
var direction = Vector2(1, 0) # initial direction
var prev_direction = Vector2(1, 0)
var timer = 0.0
var change_dir = 2.0 # change the direction after 2 sec
var reverse_collision = true
var player_in_range = false  # Tracks if the player is within the detection range
var dead = false
var is_attacking = false  # Track if the goblin is currently attacking

# Faction and promotion attributes
var faction_name = ""
var level = 1  # Goblin level for promotion tracking
var experience = 0  # Experience points for promotion criteria
var nemesis = null  # Reference to this goblin’s nemesis

# Node references
@onready var detection_area = $GoblinArea
@onready var animated_sprite = $AnimatedSprite2D
@onready var die_timer = $Timer
@onready var rl_node_2d = $RLNode2D

	
func take_damage():
	if dead:
		return false
		
	health -= 1
	if health <= 0:
		remove_from_group('enemy')
		die()
	return true 
		
func die():
	dead = true
	linear_velocity = Vector2.ZERO
	die_timer.start()
	animated_sprite.play("die")

func _on_timer_timeout():
	queue_free()
	
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

func gain_exp(points):
	experience += points
	if can_be_promoted():
		experience = 0 # reset their exp on promotion
		promote()
		
func can_be_promoted():
	return experience >= 100
	
func promote():
	level += 1
	health += 2
	print("Goblin promoted to level", level, "in faction", faction_name)
	
func set_nemiesis(enemy):
	nemesis = enemy
	
func track_nemesis():
	if nemesis and not dead:
		direction = (nemesis.global_position - global_position).normalized()
		patrol_speed = 300
		print(name, "is tracking nemesis", nemesis.name)
		move_with_collision(get_process_delta_time())
		
func has_nemesis():
	return nemesis != null
