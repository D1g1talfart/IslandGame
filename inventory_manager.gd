class_name InventoryManager
extends Node

# Inventory setup
const TOTAL_SLOTS = 40
const HOTBAR_SLOTS = 10
var items: Array[InventoryItem] = []
var selected_hotbar_slot: int = 0

# Item data structure
class InventoryItem:
	var name: String
	var type: String  # "resource", "tool", "seed", etc.
	var stack_size: int
	var icon: Texture2D
	var metadata: Dictionary = {}  # For tool durability, etc.
	
	func _init(item_name: String, item_type: String, max_stack: int = 99):
		name = item_name
		type = item_type
		stack_size = max_stack

signal inventory_changed
signal hotbar_changed(slot: int)

func _ready():
	# Initialize empty inventory
	items.resize(TOTAL_SLOTS)
	
	# Debug: Add some starting items
	add_item("Wood", "resource", 99)
	add_item("Stone", "resource", 5)
	add_item("Axe", "tool", 1)
	
func add_item(item_name: String, item_type: String, amount: int = 1) -> bool:
	print("Adding ", amount, " ", item_name)
	
	# Try to stack with existing items first
	for i in range(TOTAL_SLOTS):
		if items[i] != null and items[i].name == item_name:
			var space_left = items[i].stack_size - items[i].metadata.get("count", 1)
			if space_left > 0:
				var add_amount = min(amount, space_left)
				items[i].metadata["count"] = items[i].metadata.get("count", 1) + add_amount
				amount -= add_amount
				inventory_changed.emit()
				
				if amount <= 0:
					return true
	
	# Create new stacks for remaining items
	while amount > 0:
		var empty_slot = find_empty_slot()
		if empty_slot == -1:
			print("Inventory full!")
			return false
		
		var new_item = InventoryItem.new(item_name, item_type)
		var stack_amount = min(amount, 99)  # Max stack size
		new_item.metadata["count"] = stack_amount
		items[empty_slot] = new_item
		amount -= stack_amount
		
	inventory_changed.emit()
	return true

func remove_item(item_name: String, amount: int = 1) -> bool:
	var removed = 0
	
	for i in range(TOTAL_SLOTS):
		if items[i] != null and items[i].name == item_name:
			var current_count = items[i].metadata.get("count", 1)
			var remove_amount = min(amount - removed, current_count)
			
			items[i].metadata["count"] = current_count - remove_amount
			removed += remove_amount
			
			if items[i].metadata["count"] <= 0:
				items[i] = null
			
			if removed >= amount:
				break
	
	if removed > 0:
		inventory_changed.emit()
	
	return removed >= amount

func get_item_count(item_name: String) -> int:
	var total = 0
	for item in items:
		if item != null and item.name == item_name:
			total += item.metadata.get("count", 1)
	return total

func find_empty_slot() -> int:
	for i in range(TOTAL_SLOTS):
		if items[i] == null:
			return i
	return -1

func get_hotbar_item(slot: int) -> InventoryItem:
	if slot >= 0 and slot < HOTBAR_SLOTS:
		return items[slot]
	return null

func get_selected_item() -> InventoryItem:
	return get_hotbar_item(selected_hotbar_slot)

func select_hotbar_slot(slot: int):
	if slot >= 0 and slot < HOTBAR_SLOTS:
		selected_hotbar_slot = slot
		hotbar_changed.emit(slot)
		print("Selected hotbar slot: ", slot)

# Handle number key inputs for hotbar
func _input(event):
	if event is InputEventKey and event.pressed:
		# Number keys 1-9, 0 for slots 0-8, 9
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			select_hotbar_slot(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			select_hotbar_slot(9)
