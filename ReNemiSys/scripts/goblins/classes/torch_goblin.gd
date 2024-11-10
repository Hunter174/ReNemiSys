# torch_goblin.gd
extends "res://scripts/goblins/goblin_base.gd"

@onready var goblin_area = $GoblinArea
@onready var attack_timer = $AttackTimer 
@onready var cool_down_timer = $CoolDownTimer
@onready var line_of_sight = $LineOfSight
@onready var los_visualization = $LineOfSightVisualization

# Additional attributes
var promoted = false  
var attack_cooldown = 2.0  
var can_attack = true  
var los_distance = 150

var last_target_position = null

func _ready():
	
	add_to_group('enemy')
	update_rl_enviornment()
	rl_node_2d.reward = 0
	rl_node_2d.target_position =Vector2(-700,-5600)
	
	# Initialize the debug line for the line of sight
	los_visualization.show()
	los_visualization.clear_points()
	los_visualization.add_point(line_of_sight.position)
	if last_target_position:
		los_visualization.add_point(last_target_position)

func _physics_process(delta):
	print(rl_node_2d.reward)
	if not dead:
		if not is_attacking:
			if rl_node_2d != null:
				update_rl_enviornment()
				animated_sprite.play("walking")
				
				# Flip sprite based on movement direction
				if linear_velocity.x > 0:
					animated_sprite.flip_h = false
				elif linear_velocity.x < 0:
					animated_sprite.flip_h = true

				# Update direction and line of sight
				update_direction()
				check_line_of_sight(delta)
		else:
			linear_velocity = Vector2.ZERO

func update_rl_enviornment():
	linear_velocity = rl_node_2d.linear_velocity
	rl_node_2d.health = float(self.health)
	rl_node_2d.is_attacking = is_attacking
	# Assign last known player location as target position for RL node
	if last_target_position and last_target_position != Vector2.ZERO:
		rl_node_2d.target_position = last_target_position
		#praaaaint("Current Target Position:", rl_node_2d.target_position)

func update_direction():
	# Update Line2D visualization to point to last known player location
	los_visualization.clear_points()
	los_visualization.add_point(line_of_sight.position)
	if last_target_position:
		los_visualization.add_point(last_target_position)

# Handle interactions with a player entering and exiting GoblinArea
func _on_goblin_area_body_entered(body):
	if body.is_in_group("player") and can_attack:
		player_in_range = body
		attack_player()

func _on_goblin_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = null
		is_attacking = false

# Attack player logic
func attack_player():
	if player_in_range and can_attack:
		is_attacking = true  
		can_attack = false

		# Calculate attack direction based on player’s relative position
		var direction = (player_in_range.global_position - global_position).normalized()
		if abs(direction.x) > abs(direction.y):
			animated_sprite.flip_h = direction.x < 0
			animated_sprite.play("attack")
		else:
			animated_sprite.play("attack_up" if direction.y < 0 else "attack_down")

		# Start timers
		attack_timer.start()
		cool_down_timer.start()

# Function called when the attack animation finishes
func _on_attack_timer_timeout():
	if player_in_range:
		var player_defeated = player_in_range.take_damage()
		if player_defeated:
			self.gain_exp(50)
			if nemesis:
				self.promote()
				nemesis = null
	is_attacking = false

# Function called when the cooldown timer finishes
func _on_cool_down_timer_timeout():
	can_attack = true

# Adjust the line of sight ray to follow the player if within range
func check_line_of_sight(delta):
	if line_of_sight.is_colliding():
		var collider = line_of_sight.get_collider()
		if collider.is_in_group("player"):
			# Update last known player position to track them even if they go out of sight
			last_target_position = (collider.global_position - global_position).normalized() * los_distance

	# Update Line2D visualization with last known position
	los_visualization.clear_points()
	los_visualization.add_point(line_of_sight.position)
	if last_target_position:
		los_visualization.add_point(last_target_position)
