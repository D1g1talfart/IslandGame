# IslandDataStore.gd - Simple storage for island data
extends Node

var current_island_data = null

func set_island_data(data):
	current_island_data = data
	print("Island data stored globally")

func get_island_data():
	return current_island_data

func has_island_data() -> bool:
	return current_island_data != null

func clear_island_data():
	current_island_data = null
	print("Island data cleared")
