extends "res://scripts/goblins/base_goblin.gd"
@onready var goblin_area = $GoblinArea
@onready var attack_timer = $AttackTimer 
@onready var cool_down_timer = $CoolDownTimer  # Cooldown timer for managing attack cooldowns

var promoted = false  # Track if this goblin has been promoted
var attack_cooldown = 2.0  # Cooldown time in seconds
var can_attack = true  # Lock for attack readiness

func _ready():
	add_to_group('enemy')

	print("Goblin scout ready with health: ", health)
	
	# initialize the debug line
	line2d.show()
	line2d.add_point(raycast.position)
	line2d.add_point(raycast.target_position)

func promote():
	if not promoted:
		# Add specific promotion behavior for this subclass
		health += 10  # Further increase health for scout goblins
		promoted = true  # Mark this goblin as promoted
		print("Scout goblin promoted: Health: ", health)

# Function to handle player entering the GoblinArea
func _on_goblin_area_body_entered(body):
	if body.is_in_group("player") and can_attack:
		player_in_range = body  # Store the player reference
		attack_player()  # Initiate attack if the player is in range

# Function to handle player exiting the GoblinArea
func _on_goblin_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = null  # Reset player reference
		is_attacking = false  # Stop attacking if player leaves the range

# Function to attack the player
func attack_player():
	if player_in_range and can_attack:
		print('Attacking')
		is_attacking = true  # Mark as attacking to avoid multiple triggers
		can_attack = false  # Lock further attacks until cooldown

		# Calculate direction relative to the goblin
		var direction = (player_in_range.global_position - global_position).normalized()
		print("Direction to player: ", direction)

		# Attack direction checka
		if abs(direction.x) > abs(direction.y):
			# Horizontal attack (left or right)
			if direction.x < 0:
				animated_sprite.flip_h = true  # Attack left
			else:
				animated_sprite.flip_h = false  # Attack right
			animated_sprite.play("attack")  # Attack up
		else:
			# Vertical attack (up or down)
			if direction.y < 0:
				animated_sprite.play("attack_up")  # Attack up
			else:
				animated_sprite.play("attack_down")  # Attack down

		# Start attack timer
		attack_timer.start()
		player_in_range.take_damage()

		# Start cooldown after attack completes
		cool_down_timer.start()

# Function called when the attack animation finishes
func _on_attack_timer_timeout():
	is_attacking = false  # End attack state

# Function called when the cooldown timer finishes
func _on_cool_down_timer_timeout():
	can_attack = true  # Unlock attack after cooldown ends
	print("Cooldown finished, goblin can attack again.")
