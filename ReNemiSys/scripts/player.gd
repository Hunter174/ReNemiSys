extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@export var speed = 400
@onready var attack_timer = $Timer
@onready var attack_zone = $AttackZone


var input_direction = Vector2(0,0)
var attacking = false
var enemy_in_range = false

func _get_input():
	#if attacking != true:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	
	if Input.is_action_just_pressed('left_click'):
		attacking = true
		attack_timer.start()
		velocity = Vector2(0,0)
	
func _on_attack_timeout():
	attacking = false
	
func _get_attack_state():
	if input_direction.x != 0:
		if sign(input_direction.x) == -1:
			animated_sprite_2d.flip_h = true
			
		if sign(input_direction.x) == 1:
			animated_sprite_2d.flip_h = false	
		animated_sprite_2d.play('attack')
		
	elif sign(input_direction.y) == -1:
		animated_sprite_2d.play('attack_up')	
	
	elif sign(input_direction.y) == 1:
		animated_sprite_2d.play('attack_down')	
	else:
		animated_sprite_2d.play('attack')
	
	
func update_state():
	if attacking == true:
		_get_attack_state()
		
	elif velocity != Vector2(0,0):
		if sign(input_direction.x) == -1:
			animated_sprite_2d.flip_h = true
			
		if sign(input_direction.x) == 1:
			animated_sprite_2d.flip_h = false	
			
		animated_sprite_2d.play('walking')
	else:
		animated_sprite_2d.play('idle')	
	
func _physics_process(delta):
	_get_input()
	move_and_slide()
	update_state()
	

# Triggers for positional attacks ======================================= #

# Enemy is right
func _detection_body_entered_right(body):
	if body.is_in_group("enemy") and attacking == true:
		body.take_damage()
		enemy_in_range = true

func _detection_body_exited_right(body):
	if body.is_in_group("enemy"):
		enemy_in_range = false
		
# Enemy is left
func _detection_body_entered_left(body):
	if body.is_in_group("enemy") and attacking == true:
		body.take_damage()
		enemy_in_range = true
		
func _detection_body_exited_left(body):
	if body.is_in_group("enemy"):
		enemy_in_range = false
		
# Enemy is up		
func _detection_body_entered_up(body):
	if body.is_in_group("enemy") and attacking == true:
		body.take_damage()
		enemy_in_range = true

func _detection_body_exited_up(body):
	if body.is_in_group("enemy"):
		enemy_in_range = false

# Enemy is down
func _detection_body_entered_down(body):
	if body.is_in_group("enemy") and attacking == true:
		body.take_damage()
		enemy_in_range = true
		
func _detection_body_exited_down(body):
	if body.is_in_group("enemy"):
		enemy_in_range = false
