# FactionManager.gd
extends Node

@onready var blue_faction = $BlueFaction
@onready var purple_faction = $PurpleFaction
@onready var red_faction = $RedFaction
@onready var yellow_faction = $YellowFaction


var factions = {}
var load_state = null

var initial_members = {
	"Blue": ["BlueGoblin1", "BlueGoblin2", "BlueGoblin3"],
	"Purple": ["PurpleGoblin1", "PurpleGoblin2"],
	"Red": ["RedGoblin1", "RedGoblin2", "RedGoblin3"],
	"Yellow": ["YellowGoblin1"]
}

func _ready():
	factions["Blue"] = blue_faction
	factions["Purple"] = purple_faction
	factions["Red"] = red_faction
	factions["Yellow"] = yellow_faction
	for faction in factions:
		print(factions[faction])
	
	setup_faction_relationships()
	spawn_members()

func setup_faction_relationships():
	factions["Blue"].add_ally(factions["Red"])
	factions["Blue"].declare_enemy(factions["Purple"])
	
	factions["Purple"].add_ally(factions["Yellow"])
	factions["Purple"].declare_enemy(factions["Blue"])
	
func spawn_members():
	# initialize the world on new game
	if load_state == null:
		for faction_name in initial_members.keys():
			var faction = factions[faction_name]
			for member_name in initial_members[faction_name]:
				faction.add_member(member_name)  # Pass the name to add_member()
				print("Spawned", member_name, "in", faction_name, "faction")
			
	# initialize the world from memory		
	else:
		pass
