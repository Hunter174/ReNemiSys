extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready():
	print(get_tree().get_nodes_in_group('enemy'))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_retry_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed():
	get_tree().quit()
