extends Node

# Your master item dictionary with all items including the missing ones
var items = {
	1: {  # Wood
		"id": 1,
		"name": "Wood",
		"type": "resource", 
		"description": "Basic building material from trees",
		"icon_path": "res://Icons/Wood.png",
		"stack_size": 99,
		"sell_price": 5,
		"rarity": "common"
	},
	2: {  # Stone  
		"id": 2,
		"name": "Stone",
		"type": "resource",
		"description": "Hard mineral for construction", 
		"icon_path": "res://Icons/Stone.png",
		"stack_size": 99,
		"sell_price": 3,
		"rarity": "common"
	},
	3: {  # Iron
		"id": 3,
		"name": "Iron",
		"type": "resource",
		"description": "Valuable metal ore",
		"icon_path": "res://Icons/Iron.png",
		"stack_size": 99,
		"sell_price": 15,
		"rarity": "uncommon"
	},
	4: {  # Berries
		"id": 4,
		"name": "Berries",
		"type": "consumable",
		"description": "Sweet wild berries",
		"icon_path": "res://Icons/Berries.png",
		"stack_size": 50,
		"sell_price": 2,
		"rarity": "common",
		"heal_amount": 5
	},
	5: {  # Crystal
		"id": 5,
		"name": "Crystal",
		"type": "resource", 
		"description": "Magical crystalline formation",
		"icon_path": "res://Icons/Crystal.png",
		"stack_size": 20,
		"sell_price": 50,
		"rarity": "rare"
	},
	6: {  # Rare Seed - NEW!
		"id": 6,
		"name": "Rare Seed",
		"type": "seed",
		"description": "A mysterious seed from ancient trees",
		"icon_path": "res://Icons/Rare_Seed.png",
		"stack_size": 10,
		"sell_price": 100,
		"rarity": "rare"
	},
	7: {  # Shell - NEW!
		"id": 7,
		"name": "Shell",
		"type": "resource",
		"description": "Beautiful seashell from the beach",
		"icon_path": "res://Icons/Shell.png",
		"stack_size": 50,
		"sell_price": 8,
		"rarity": "common"
	},
	8: {  # Lily Pad - NEW!
		"id": 8,
		"name": "Lily Pad",
		"type": "resource",
		"description": "Floating leaf from water lilies",
		"icon_path": "res://Icons/Lily_Pad.png",
		"stack_size": 30,
		"sell_price": 4,
		"rarity": "common"
	},
	9: {  # Reed - NEW!
		"id": 9,
		"name": "Reed",
		"type": "resource",
		"description": "Flexible plant stem from waterside",
		"icon_path": "res://Icons/Reed.png",
		"stack_size": 64,
		"sell_price": 3,
		"rarity": "common"
	},
	10: {  # Axe
		"id": 10,
		"name": "Axe",
		"type": "tool",
		"tool_type": "axe",
		"description": "For chopping wood",
		"icon_path": "res://Icons/Axe.png",
		"stack_size": 1,
		"sell_price": 75,
		"rarity": "common",
		"durability": 100,
		"tool_power": 2
	},
	11: {  # Big Axe
		"id": 11,
		"name": "Big Axe",
		"type": "tool",
		"tool_type": "axe",
		"description": "Heavy axe for cutting large trees",
		"icon_path": "res://Icons/Axe.png",  # You'll need this icon
		"stack_size": 1,
		"sell_price": 200,
		"rarity": "uncommon",
		"durability": 150,  # More durable than regular axe
		"tool_power": 3
	},
	12: {  # Wood
		"id": 12,
		"name": "Hard Wood",
		"type": "resource", 
		"description": "Better building material from Anceint trees",
		"icon_path": "res://Icons/Wood.png",
		"stack_size": 99,
		"sell_price": 5,
		"rarity": "common"
	},
	13: {  # Pickaxe
	"id": 13,
	"name": "Pickaxe",
	"type": "tool",
	"tool_type": "pickaxe",
	"description": "For mining stone and ore",
	"icon_path": "res://Icons/Pickaxe.png",
	"stack_size": 1,
	"sell_price": 100,
	"rarity": "common",
	"durability": 80,
	"tool_power": 2
},

14: {  # Mining Hammer
	"id": 14,
	"name": "Mining Hammer",
	"type": "tool", 
	"tool_type": "pickaxe",
	"description": "Heavy tool for mining crystals and hard stone",
	"icon_path": "res://Icons/MiningHammer.png",
	"stack_size": 1,
	"sell_price": 250,
	"rarity": "rare",
	"durability": 120,
	"tool_power": 3
},
}

# Rest of your ItemDatabase code stays the same...
var name_to_id = {}
var id_to_name = {}

func _ready():
	build_lookup_tables()

func build_lookup_tables():
	name_to_id.clear()
	id_to_name.clear()
	
	for item_id in items:
		var item_data = items[item_id] 
		name_to_id[item_data.name] = item_id
		id_to_name[item_id] = item_data.name

# All your existing functions stay the same...
func get_item_by_id(item_id: int) -> Dictionary:
	return items.get(item_id, {})

func get_item_by_name(item_name: String) -> Dictionary:
	var item_id = name_to_id.get(item_name, -1)
	if item_id != -1:
		return items[item_id]
	return {}

func get_item_id_by_name(item_name: String) -> int:
	return name_to_id.get(item_name, -1)

func get_item_name_by_id(item_id: int) -> String:
	return id_to_name.get(item_id, "")

func has_item_id(item_id: int) -> bool:
	return item_id in items

func has_item_name(item_name: String) -> bool:
	return item_name in name_to_id

func get_item_icon(item_id: int) -> Texture2D:
	var item_data = get_item_by_id(item_id)
	var icon_path = item_data.get("icon_path", "")
	
	if icon_path != "" and ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	else:
		print("Icon not found for item ", item_id, " at path: ", icon_path)
		return null

func register_item(item_id: int, item_data: Dictionary):
	items[item_id] = item_data
	if item_data.has("name"):
		name_to_id[item_data.name] = item_id
		id_to_name[item_id] = item_data.name
