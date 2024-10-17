extends Node2D

var cpp_ai  # C++ AI instance

func _ready():
	

func _process(delta):
	if cpp_ai:
		cpp_ai._process(delta)
