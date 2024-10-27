# purple_faction
extends "res://scripts/goblins/faction_base.gd"

const PURPLE_GOBLIN = preload("res://scenes/goblins/classes/torch/purple_goblin.tscn")

# Initialize faction properties
func _ready():
	self.faction_name = "Purple Faction"
	self.color = Color.PURPLE
	self.spawn_point = Vector2(-3500, -3000)

# Override method to add blue goblins
func add_member(goblin_name):
	var goblin_instance = PURPLE_GOBLIN.instantiate()
	print('HERE')
	print(goblin_instance)
	add_child(goblin_instance)

	goblin_instance.name = goblin_name
	goblin_instance.faction_name = self.faction_name
	goblin_instance.add_to_group("purple_faction")

	# Find a position that doesn’t overlap with existing goblins
	var spawn_pos = self.get_non_overlapping_position()
	goblin_instance.position = spawn_pos  # Set initial position

	# Store the position to avoid future overlaps
	self.spawned_positions.append(spawn_pos)

	add_child(goblin_instance)  # Add goblin to the scene tree
	members.append(goblin_instance)
	print(self.faction_name, "added a new goblin:", goblin_instance.name, "at", spawn_pos)
	return goblin_instance

func promote_goblin(goblin):
	if goblin.can_be_promoted():
		goblin.promote()
		goblin.health += 5
		print(goblin.name, "promote in", self.faction_name, "to level", goblin.level)
	else:
		print(goblin.name, "Can't be promoted yet")
