class_name InventoryManager
extends Node

# Inventory setup - unchanged
const TOTAL_SLOTS = 40
const HOTBAR_SLOTS = 10
var items: Array[InventoryItem] = []
var selected_hotbar_slot: int = 0

# UPDATED: Enhanced InventoryItem class that uses the database
class InventoryItem:
	var item_id: int
	var count: int
	var metadata: Dictionary = {}  # For tool durability, etc.
	
	# Cache frequently accessed data
	var _cached_data: Dictionary = {}
	
	func _init(id: int, amount: int = 1):
		item_id = id
		count = amount
		_cached_data = ItemDatabase.get_item_by_id(item_id)
	
	# Convenient property accessors
	func get_name() -> String:
		return _cached_data.get("name", "Unknown")
	
	func get_type() -> String:
		return _cached_data.get("type", "misc")
	
	func get_max_stack_size() -> int:
		return _cached_data.get("stack_size", 1)
	
	func get_icon_path() -> String:
		return _cached_data.get("icon_path", "")
	
	func can_stack_with(other_id: int) -> bool:
		return item_id == other_id and count < get_max_stack_size()
	
	func add_to_stack(amount: int) -> int:
		var max_stack = get_max_stack_size()
		var can_add = min(amount, max_stack - count)
		count += can_add
		return amount - can_add  # Return leftover
	
	# Add this to your InventoryItem class in inventory_manager.gd
	func get_icon() -> Texture2D:
		return ItemDatabase.get_item_icon(item_id)
		
	# Add these methods to your InventoryItem class in inventory_manager.gd

	func get_durability() -> int:
		return metadata.get("durability", get_max_durability())

	func get_max_durability() -> int:
		return _cached_data.get("durability", 0)

	func has_durability() -> bool:
		return get_max_durability() > 0

	func use_durability(amount: int = 1) -> bool:
		"""Use durability and return true if item should be destroyed"""
		if not has_durability():
			return false
	
		var current_dur = get_durability()
		var new_dur = max(0, current_dur - amount)
		metadata["durability"] = new_dur
	
		print("Tool durability: ", new_dur, "/", get_max_durability())
	
		return new_dur <= 0  # Return true if broken

	func get_tool_power() -> int:
		return _cached_data.get("tool_power", 0)

	func is_tool() -> bool:
		return get_type() == "tool"
		
	# Add this method to your InventoryItem class in inventory_manager.gd

	func duplicate_with_count(new_count: int) -> InventoryItem:
		"""Create a duplicate of this item with a different count, preserving metadata"""
		var new_item = InventoryItem.new(item_id, new_count)
		new_item.metadata = metadata.duplicate()  # Copy durability and other metadata
		return new_item

signal inventory_changed
signal hotbar_changed(slot: int)

func _ready():
	add_to_group("inventory_manager")  # ADD THIS LINE
	# Initialize empty inventory
	items.resize(TOTAL_SLOTS)
	
	# Debug: Add some starting items using IDs
	add_item_by_id(1, 15)  # 15 Wood
	add_item_by_id(2, 5)   # 5 Stone  
	add_item_by_id(10, 1)  # 1 Axe
	add_item_by_id(11,1)
	
	select_hotbar_slot(0)
	
# UPDATED: Add item by ID (primary method)
func add_item_by_id(item_id: int, amount: int = 1) -> bool:
	if not ItemDatabase.has_item_id(item_id):
		print("ERROR: Unknown item ID: ", item_id)
		return false
	
	var item_name = ItemDatabase.get_item_name_by_id(item_id)
	print("Adding ", amount, " ", item_name, " (ID: ", item_id, ")")
	
	# Try to stack with existing items first
	for i in range(TOTAL_SLOTS):
		if items[i] != null and items[i].item_id == item_id:
			var leftover = items[i].add_to_stack(amount)
			amount = leftover
			if amount <= 0:
				inventory_changed.emit()
				return true
	
	# Create new stacks for remaining items
	while amount > 0:
		var empty_slot = find_empty_slot()
		if empty_slot == -1:
			print("Inventory full!")
			return false
		
		var item_data = ItemDatabase.get_item_by_id(item_id)
		var max_stack = item_data.get("stack_size", 1)
		var stack_amount = min(amount, max_stack)
		
		items[empty_slot] = InventoryItem.new(item_id, stack_amount)
		amount -= stack_amount
		
	inventory_changed.emit()
	return true

# UPDATED: Add item by name (convenience method)  
func add_item_by_name(item_name: String, amount: int = 1) -> bool:
	var item_id = ItemDatabase.get_item_id_by_name(item_name)
	if item_id == -1:
		print("ERROR: Unknown item name: ", item_name)
		return false
	return add_item_by_id(item_id, amount)

# LEGACY: Keep your old add_item method for backward compatibility
func add_item(item_name: String, item_type: String, amount: int = 1) -> bool:
	return add_item_by_name(item_name, amount)

# UPDATED: Remove item methods
func remove_item_by_id(item_id: int, amount: int = 1) -> bool:
	var removed = 0
	
	for i in range(TOTAL_SLOTS):
		if items[i] != null and items[i].item_id == item_id:
			var remove_amount = min(amount - removed, items[i].count)
			items[i].count -= remove_amount
			removed += remove_amount
			
			if items[i].count <= 0:
				items[i] = null
			
			if removed >= amount:
				break
	
	if removed > 0:
		inventory_changed.emit()
	
	return removed >= amount

func remove_item_by_name(item_name: String, amount: int = 1) -> bool:
	var item_id = ItemDatabase.get_item_id_by_name(item_name)
	if item_id == -1:
		return false
	return remove_item_by_id(item_id, amount)

# LEGACY: Keep old remove_item method
func remove_item(item_name: String, amount: int = 1) -> bool:
	return remove_item_by_name(item_name, amount)

# UPDATED: Get item count methods
func get_item_count_by_id(item_id: int) -> int:
	var total = 0
	for item in items:
		if item != null and item.item_id == item_id:
			total += item.count
	return total

func get_item_count_by_name(item_name: String) -> int:
	var item_id = ItemDatabase.get_item_id_by_name(item_name)
	if item_id == -1:
		return 0
	return get_item_count_by_id(item_id)

# LEGACY: Keep old get_item_count method
func get_item_count(item_name: String) -> int:
	return get_item_count_by_name(item_name)

# Rest of your methods stay the same!
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
		
	# Add these methods to your main InventoryManager class

func get_equipped_tool() -> InventoryItem:
	"""Get the currently equipped tool (selected hotbar item)"""
	return get_selected_item()

func has_tool_equipped(tool_type: String = "") -> bool:
	"""Check if player has a tool equipped"""
	var equipped = get_equipped_tool()
	if not equipped or not equipped.is_tool():
		return false
	
	# If specific tool type requested, check it
	if tool_type != "":
		return equipped.get_name().to_lower().contains(tool_type.to_lower())
	
	return true

func use_equipped_tool(durability_cost: int = 1) -> bool:
	"""Use the equipped tool and handle breaking. Returns false if tool breaks."""
	var equipped = get_equipped_tool()
	if not equipped or not equipped.is_tool():
		return false
	
	var should_break = equipped.use_durability(durability_cost)
	
	if should_break:
		print("💥 ", equipped.get_name(), " broke!")
		# Remove the broken tool
		items[selected_hotbar_slot] = null
		inventory_changed.emit()
		hotbar_changed.emit(selected_hotbar_slot)
		return false
	
	# Tool still works
	inventory_changed.emit()
	return true

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			select_hotbar_slot(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			select_hotbar_slot(9)
