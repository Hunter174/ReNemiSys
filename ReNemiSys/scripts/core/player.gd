extends CharacterBody2D

@onready var attack_timer = $Timer
@onready var attack_zone = $AttackZone
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var attack_zone_visual = $AttackZone/ColorRect  
@onready var attack_zone_collision = $AttackZone/CollisionShape2D
@onready var health_bar = $HealthBar

@export var speed = 400

var health = 5
var dead = false

var attacking = false
var player_in_range = false 
var enemy_in_range = null 
var attack_offset = Vector2.ZERO
var input_direction = Vector2.ZERO

func _ready():
	add_to_group('player')
	attack_zone_visual.visible = true
	health_bar.max_value = health

func _get_input():
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	
	if Input.is_action_just_pressed('left_click'):
		attacking = true
		attack_timer.start()
		velocity = Vector2(0, 0)
		_set_attack_zone_position()

		# Check if the player is in range and attacking
		if enemy_in_range != null:
			perform_attack()

func _on_attack_timeout():
	attacking = false

func _set_attack_zone_position():
	# Calculate the offset for the attack zone based on the input direction
	attack_offset = input_direction * Vector2(75, 75)
	
	# Ensure the offset is applied only when moving, i.e., direction isn't zero
	if attack_offset != Vector2.ZERO:
		# Update the attack zone position based on the player's position and the offset
		attack_zone_collision.global_position = global_position + attack_offset
		
		# Manual adjustments to match sprite direction
		attack_zone_collision.global_position.x -= 45
		attack_zone_collision.global_position.y -= 30
		
	# Sync the visual and collision shape positions
	attack_zone_visual.global_position = attack_zone_collision.global_position

func update_state():
	health_bar.value = health
	
	if attacking:
		animated_sprite_2d.play('attack')
	elif velocity != Vector2.ZERO:
		animated_sprite_2d.play('walking')
		animated_sprite_2d.flip_h = (input_direction.x < 0)
	else:
		animated_sprite_2d.play('idle')

func _physics_process(delta):
	_get_input()
	move_and_slide()
	update_state()

func perform_attack():
	if enemy_in_range:
		var attack_success = enemy_in_range.take_damage()

		if not attack_success:
			enemy_in_range = null
			
func take_damage():
	health -= 1
	if health <= 0:
		die()
	
	if dead:
		return true
	
func die():
	dead = true
	velocity = Vector2.ZERO
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

# Area2D detection signals
func _on_AttackZone_body_entered(body):
	if body.is_in_group("enemy"):
		player_in_range = true  
		enemy_in_range = body

func _on_AttackZone_body_exited(body):
	if body.is_in_group("enemy"):
		player_in_range = false
		enemy_in_range = null
