extends Node

func _ready():
	get_factions()


func get_factions():
	for faction in get_children():
		pass
		get_faction_members(faction)
		
func get_faction_members(faction):
	for member in faction.get_members():
		pass
