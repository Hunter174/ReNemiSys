# torch_goblin.gd
extends "res://scripts/goblins/goblin_base.gd"

@onready var goblin_area = $GoblinArea
@onready var attack_timer = $AttackTimer 
@onready var cool_down_timer = $CoolDownTimer
@onready var line_of_sight = $LineOfSight
@onready var los_visualization = $LineOfSightVisualization


# Additional attributes
var promoted = false  # Track if this goblin has been promoted
var attack_cooldown = 2.0  # Cooldown time in seconds
var can_attack = true  # Lock for attack readiness
var los_distance = 150
var chasing_player = false

func _ready():
	add_to_group('enemy')
	
	update_rl_enviornment()
	
	# initialize the debug line
	los_visualization.show()
	los_visualization.clear_points()
	los_visualization.add_point(line_of_sight.position)
	los_visualization.add_point(line_of_sight.target_position)
	
	
func _physics_process(delta):
	if dead == false:
		if is_attacking == false:
			if rl_node_2d != null:
				
				update_rl_enviornment()
				animated_sprite.play("walking")
				
				if linear_velocity.x > 0:
					animated_sprite.flip_h = false  # Moving right, no flip
				elif linear_velocity.x < 0:
					animated_sprite.flip_h = true   # Moving left, flip sprite

				# Update ray target position if the enemy changes direction
				update_direction()
				check_line_of_sight(delta)
		else:		
			linear_velocity  = Vector2.ZERO
	
func update_rl_enviornment():
	#print(rl_node_2d.linear_velocity)
	
	# update RL settings every tick
	linear_velocity = rl_node_2d.linear_velocity
	rl_node_2d.health = float(self.health)
	rl_node_2d.is_attacking = is_attacking
	rl_node_2d.target_position = line_of_sight.target_position

func update_direction():
	
	# Update the RayCast2D's target_position to match the new direction
	line_of_sight.target_position = direction.normalized() * los_distance 

	# Update Line2D to reflect the new ray target
	los_visualization.clear_points()
	los_visualization.add_point(line_of_sight.position)
	los_visualization.add_point(line_of_sight.target_position)

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

		# Calculate direction relative to the goblin
		var direction = (player_in_range.global_position - global_position).normalized()
		if abs(direction.x) > abs(direction.y):
			animated_sprite.flip_h = direction.x < 0
			animated_sprite.play("attack")  # Attack up
		else:
			# Vertical attack (up or down)
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

# Detects player in line of sight and initiates chase if in range
func check_line_of_sight(delta):
	if line_of_sight.is_colliding():
		var collider = line_of_sight.get_collider()
		if collider.is_in_group("player"):
			chase_player(collider, delta)

func chase_player(player, delta):
	direction = (player.position - position).normalized()
	chasing_player = true
	move_with_collision(delta)
