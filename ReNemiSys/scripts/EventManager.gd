extends Node

# Event log
var event_log: Array

# Initialize the event log
func _ready():
	event_log = []

# Create and broadcast a new event
func create_event(event_name: String, involved_factions: Array):
	var event_entry = {
		"name": event_name,
		"factions": involved_factions
	}
	event_log.append(event_entry)
	print("Event created:", event_name, "between factions:", involved_factions)
	notify_factions(event_name, involved_factions)

# Notify the factions involved in the event
func notify_factions(event_name: String, involved_factions: Array):
	for faction in involved_factions:
		faction.trigger_event(event_name)

# Get recent events
func get_recent_events():
	return event_log
