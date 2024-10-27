extends Node

var faction_name = "Base Faction"
var color = Color.WHITE

var spawn_point = Vector2(0, 0)
var spawn_area_size = Vector2(200, 200)  # Width and height of the spawn area
var min_distance = 50  # Minimum distance between spawned goblins

var members = []
var allies = []
var enemies = []
var spawned_positions = []
	
func remove_member(goblin):
	members.erase(goblin)
	print(faction_name, "lost", goblin.name)

func add_ally(faction):
	if faction not in allies:
		allies.append(faction)
		faction.allies.append(self)
		print(faction_name, "and", faction.faction_name, "are now allies")
		
func add_enemy(faction):
	if faction not in enemies:
		enemies.append(faction)
		faction.enemies.append(self)
		print(faction_name, "and", faction.faction_name, "are now enemies")
		
func declare_enemy(enemy_faction):
	self.add_enemy(enemy_faction)
	print(self.faction_name, "now considers", enemy_faction.faction_name, "as an enemy")
		
func is_ally(faction):
	if faction in self.allies:
		return true
	return false
	
func is_enemy(faction):
	if faction in self.enemies:
		return true
	return false
	
func promote_goblin(goblin):
	if goblin.can_be_promoted(goblin):
		goblin.promote()
		print(goblin.name, "has been promoted in", faction_name)
	else:
		print(goblin.name, "Can not be promoted yet")
		
func find_nemisis(goblin):
	for enemy_faction in enemies:
		for enemy in enemy_faction.members:
			if goblin.remembers_defeat_by(enemy):
				print(goblin.name, "found a nemisis in", enemy.name)
				return enemy
	print("No nemsisi found for", goblin.name)
	return null
	
func initiate_revenge(goblin):
	var nemisis = find_nemisis(goblin)
	if nemisis.target_nemisis(nemisis):
		goblin.target_nemesis(nemisis)
		print(goblin.name, "is seeking revenge on", nemisis.name)
	else:
		print(goblin.name, "has no enemies to target")
		
func assist_ally(ally_faction):
	if self.is_ally(ally_faction):
		print(self.faction_name, "is assisting ally", ally_faction.faction_name)
		for goblin in self.members:
			if goblin.has_nemesis():
				goblin.track_nemesis()
	
func update_nemeses():
	for goblin in self.members:
		if goblin.has_nemesis():
			goblin.track_nemesis()
			print(goblin.name, "is tracking nemesis in", self.faction_name)
		else:
			print(goblin.name, "has no nemesis to track")
			
func initiate_patrol():
	for goblin in self.members:
		if not goblin.player_in_range:
			goblin.move_with_collision(get_process_delta_time())
			print(goblin.name, "is patrolling in", self.faction_name)
			
func get_non_overlapping_position():
	var position = Vector2()
	var max_attempts = 10
	var attempts = 0
	
	while attempts < max_attempts:
		position = spawn_point + Vector2(
			randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2),
			randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
		)
		
		if is_position_valid(position):
			return position

		attempts += 1

	print("Warning: Could not find a non-overlapping position after max attempts.")
	return position

func is_position_valid(new_position: Vector2) -> bool:
	for pos in spawned_positions:
		if pos.distance_to(new_position) < min_distance:
			return false
	return true
