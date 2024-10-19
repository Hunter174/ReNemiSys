extends Node2D

var blue_goblin_scene = preload("res://scenes/blue_goblin.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	create_member(Vector2(100, 200))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func get_members():
	var members = []
	for member in get_children():
		members.append(member)
		
	return members
	
func create_member(pos):
	var blue_goblin = blue_goblin_scene.instantiate()

	add_child(blue_goblin)
	blue_goblin.position = pos
	
