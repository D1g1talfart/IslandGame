extends CanvasLayer

var inventory_manager
var hotbar_container
var hotbar_slots: Array[Button] = []

var inventory_panel: Panel
var inventory_grid: GridContainer
var inventory_slots: Array[Button] = []
var delete_slot: Button
var is_inventory_open: bool = false

var dragging_item: InventoryManager.InventoryItem = null
var dragging_from_slot: int = -1
var drag_preview: Control = null

class InventorySlot extends Button:
	var slot_index: int
	var inventory_ui: Node
	
	func _init(index: int, ui: Node):
		slot_index = index
		inventory_ui = ui
	
	# Handle mouse input to start drags immediately
	func _gui_input(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				# Start single item drag immediately
				start_right_click_drag()
				get_viewport().set_input_as_handled()
	
	func start_right_click_drag():
		"""Start dragging a single item immediately on right-click"""
		var item = inventory_ui.inventory_manager.items[slot_index]
		if item == null:
			return
			
		var count = item.metadata.get("count", 1)
		if count <= 0:
			return
		
		print("Right-click dragging single item: ", item.name)
		
		# Create single item for dragging
		var drag_item = InventoryManager.InventoryItem.new(item.name, item.type)
		drag_item.metadata["count"] = 1
		drag_item.stack_size = item.stack_size
		
		# Create preview
		var preview = Button.new()
		preview.text = item.name + "\n1"
		preview.custom_minimum_size = Vector2(75, 65)
		preview.size = Vector2(75, 65)
		preview.modulate = Color(1, 1, 1, 0.8)
		
		# Create drag data
		var drag_data = {
			"item": drag_item,
			"from_slot": slot_index,
			"is_single_grab": true
		}
		
		# Force start the drag with proper parameters
		force_drag(drag_data, preview)
	
	# Enable drag detection
	func _can_drop_data(position, data):
		return data.has("item") and data.has("from_slot")
	
	# Handle drop
	func _drop_data(position, data):
		inventory_ui.handle_item_drop(slot_index, data)
	
	# Start drag - handles left-click drags
	func _get_drag_data(position):
		var item = inventory_ui.inventory_manager.items[slot_index]
		if item == null:
			return null
		
		# Left-click drag - full stack
		var count = item.metadata.get("count", 1)
		var preview_text = item.name + "\n" + str(count)
		
		# Create drag preview
		var preview = Button.new()
		preview.text = preview_text
		preview.custom_minimum_size = Vector2(75, 65)
		preview.size = Vector2(75, 65)
		preview.modulate = Color(1, 1, 1, 0.8)
		
		set_drag_preview(preview)
		
		return {
			"item": item,
			"from_slot": slot_index,
			"is_single_grab": false
		}

class TrashSlot extends Button:
	var inventory_ui: Node
	
	func _init(ui: Node):
		inventory_ui = ui
	
	func _can_drop_data(position, data):
		return data.has("item") and data.has("from_slot")
	
	func _drop_data(position, data):
		inventory_ui.handle_item_trash(data)
		
	# Visual feedback when hovering with item
	func _can_drop_data_changed():
		if _can_drop_data(Vector2.ZERO, {}):
			modulate = Color.RED * 1.2  # Brighter red
		else:
			modulate = Color.RED

func _ready():
	# Hide UI initially
	visible = false
	layer = 10
	
	# Wait a frame to ensure parent is ready
	await get_tree().process_frame
	
	inventory_manager = get_parent().get_node("InventoryManager")
	if not inventory_manager:
		print("ERROR: Can't find InventoryManager!")
		return
		
	create_hotbar_ui()
	create_full_inventory()  # NEW: Create full inventory
	inventory_manager.inventory_changed.connect(update_all_displays)  # CHANGED
	inventory_manager.hotbar_changed.connect(highlight_selected_slot)

func show_inventory_ui():
	"""Call this when the game is actually ready to show inventory"""
	if not inventory_manager:
		print("No inventory manager found!")
		return
	visible = true
	update_all_displays()  # Update everything when showing
	print("Inventory UI now visible!")

func create_hotbar_ui():
	print("Creating hotbar UI...")
	
	# Create hotbar container
	var hotbar = HBoxContainer.new()
	hotbar.name = "HotbarContainer"
	add_child(hotbar)
	
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_top = -100    # Move up from bottom
	hotbar.offset_left = -250   # Center it (half of width)
	hotbar.offset_right = 250   # Other half of width
	hotbar.offset_bottom = -20  # Some margin from bottom
	
	# Add a background so we can see it
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(500, 80)
	hotbar.add_child(bg)
	
	print("Hotbar size: ", hotbar.size)
	print("Hotbar position: ", hotbar.position)
	print("Hotbar global position: ", hotbar.global_position)
	
	# Create 10 hotbar slots
	for i in range(10):
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(45, 60)
		slot_button.text = str(i + 1) if i < 9 else "0"
		slot_button.flat = false
		
		# Make buttons very visible
		slot_button.modulate = Color.HONEYDEW
		
		hotbar.add_child(slot_button)
		hotbar_slots.append(slot_button)
		
		# Connect click events
		var slot_index = i
		slot_button.pressed.connect(func(): inventory_manager.select_hotbar_slot(slot_index))
		
		print("Created button ", i, " at position: ", slot_button.position)
	
	hotbar_container = hotbar
	print("Hotbar UI created with ", hotbar_slots.size(), " buttons!")
	
	# Force update the display
	await get_tree().process_frame
	update_hotbar_display()
	
func create_full_inventory():
	# Main inventory panel - MUCH WIDER
	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	
	# BIGGER: Much wider panel
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_panel.offset_left = -400   # Much wider (was -275)
	inventory_panel.offset_right = 400   
	inventory_panel.offset_top = -225    
	inventory_panel.offset_bottom = 225  
	
	# Make it look nice
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	inventory_panel.add_theme_stylebox_override("panel", style)
	
	# Title label
	var title = Label.new()
	title.text = "Inventory"
	title.position = Vector2(15, 15)
	title.add_theme_font_size_override("font_size", 20)
	inventory_panel.add_child(title)
	
	# 4x10 Grid container - MUCH WIDER
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 10
	inventory_grid.position = Vector2(15, 50)
	inventory_grid.size = Vector2(770, 280)    # Much wider (was 520)
	inventory_grid.add_theme_constant_override("h_separation", 3)  # Bit more space
	inventory_grid.add_theme_constant_override("v_separation", 3)
	inventory_panel.add_child(inventory_grid)
	
	# Create 40 inventory slots (4 rows × 10 columns) - BIGGER SLOTS
	for i in range(40):
		var slot_button = InventorySlot.new(i, self)
		slot_button.custom_minimum_size = Vector2(75, 65)  # Much wider (was 50)
		slot_button.size = Vector2(75, 65)
		slot_button.clip_contents = true
		slot_button.text = ""
	
		# Better text handling
		slot_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
		# Make hotbar row look different (first 10 slots)
		if i < 10:
			slot_button.modulate = Color.YELLOW
			slot_button.tooltip_text = "Hotbar Slot " + str(i + 1)
		else:
			slot_button.modulate = Color.WHITE
	
		inventory_grid.add_child(slot_button)
		inventory_slots.append(slot_button)
	
		# Keep click events for hotbar selection
		if i < 10:
			var slot_index = i
			slot_button.pressed.connect(func(): inventory_manager.select_hotbar_slot(slot_index))

# UPDATED: Reposition trash and close buttons for wider panel
	delete_slot = TrashSlot.new(self)
	delete_slot.text = "🗑️\nTRASH"
	delete_slot.custom_minimum_size = Vector2(80, 50)
	delete_slot.position = Vector2(700, 390)  # Moved right for wider panel
	delete_slot.modulate = Color.RED
	delete_slot.tooltip_text = "Drag items here to delete them"
	inventory_panel.add_child(delete_slot)

# Close button
	var close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.position = Vector2(760, 10)  # Moved right for wider panel
	close_button.pressed.connect(toggle_inventory)
	inventory_panel.add_child(close_button)
	
	# Start hidden
	inventory_panel.visible = false
	
	print("Full inventory UI created!")

func on_inventory_slot_clicked(slot_index: int):
	print("Clicked inventory slot: ", slot_index)
	# For now, just select hotbar items if it's in the hotbar row
	if slot_index < 10:
		inventory_manager.select_hotbar_slot(slot_index)

func update_all_displays():
	update_hotbar_display()
	update_inventory_display()

func update_hotbar_display():
	for i in range(10):
		var item = inventory_manager.get_hotbar_item(i)
		var button = hotbar_slots[i]
		
		if item != null:
			var count = item.metadata.get("count", 1)
			button.text = item.name + "\n" + str(count)
		else:
			button.text = str(i + 1) if i < 9 else "0"

func update_inventory_display():
	if not inventory_slots:
		return
		
	for i in range(40):
		if i < inventory_slots.size():
			var item = inventory_manager.items[i] if i < inventory_manager.items.size() else null
			var button = inventory_slots[i]
			
			if item != null:
				var count = item.metadata.get("count", 1)
				
				# More space for names now!
				var display_name = item.name
				if display_name.length() > 12:  # More characters fit now
					display_name = display_name.substr(0, 10) + ".."
				
				button.text = display_name + "\n" + str(count)
				button.tooltip_text = item.name + " (x" + str(count) + ")\nLeft-click: drag all\nRight-click: drag one"
				button.disabled = false
				
				# Color coding by item type
				match item.type:
					"resource":
						button.modulate = Color.YELLOW if i < 10 else Color.WHITE
					"tool":
						button.modulate = Color.CYAN if i < 10 else Color.LIGHT_BLUE
					_:
						button.modulate = Color.YELLOW if i < 10 else Color.WHITE
			else:
				button.text = ""
				button.tooltip_text = ""
				button.disabled = false
				button.modulate = Color.YELLOW if i < 10 else Color.GRAY

func highlight_selected_slot(slot: int):
	# Reset all buttons
	for button in hotbar_slots:
		button.modulate = Color.WHITE
	
	# Highlight selected
	if slot < hotbar_slots.size():
		hotbar_slots[slot].modulate = Color.YELLOW
		
func _input(event):
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			toggle_inventory()
			get_viewport().set_input_as_handled()

func toggle_inventory():
	is_inventory_open = !is_inventory_open
	inventory_panel.visible = is_inventory_open
	
	if is_inventory_open:
		print("Inventory opened!")
		update_all_displays()
	else:
		print("Inventory closed!")

func handle_item_drop(to_slot: int, drag_data: Dictionary):
	var from_slot = drag_data["from_slot"]
	var item = drag_data["item"]
	var is_single = drag_data.get("is_single_grab", false)
	
	print("Moving item from slot ", from_slot, " to slot ", to_slot)
	
	# Don't drop on same slot
	if from_slot == to_slot:
		return
	
	if is_single:
		# Handle single item grab
		handle_single_item_move(from_slot, to_slot, item)
	else:
		# Handle full stack move (existing logic)
		var target_item = inventory_manager.items[to_slot] if to_slot < inventory_manager.items.size() else null
		
		if target_item == null:
			move_item(from_slot, to_slot)
		elif target_item.name == item.name:
			stack_items(from_slot, to_slot)
		else:
			swap_items(from_slot, to_slot)

func handle_item_trash(drag_data: Dictionary):
	var from_slot = drag_data["from_slot"]
	var item = drag_data["item"]
	
	print("Trashing item: ", item.name, " from slot ", from_slot)
	
	# Remove item from inventory
	if from_slot < inventory_manager.items.size():
		inventory_manager.items[from_slot] = null
		inventory_manager.inventory_changed.emit()

func move_item(from_slot: int, to_slot: int):
	"""Move item from one slot to another"""
	var item = inventory_manager.items[from_slot]
	inventory_manager.items[from_slot] = null
	
	# Ensure inventory array is big enough
	while inventory_manager.items.size() <= to_slot:
		inventory_manager.items.append(null)
	
	inventory_manager.items[to_slot] = item
	inventory_manager.inventory_changed.emit()

func swap_items(from_slot: int, to_slot: int):
	"""Swap items between two slots"""
	var from_item = inventory_manager.items[from_slot]
	var to_item = inventory_manager.items[to_slot]
	
	inventory_manager.items[from_slot] = to_item
	inventory_manager.items[to_slot] = from_item
	inventory_manager.inventory_changed.emit()

func stack_items(from_slot: int, to_slot: int):
	"""Try to stack items of the same type"""
	var from_item = inventory_manager.items[from_slot]
	var to_item = inventory_manager.items[to_slot]
	
	if from_item.name != to_item.name:
		return  # Can't stack different items
	
	var from_count = from_item.metadata.get("count", 1)
	var to_count = to_item.metadata.get("count", 1)
	var max_stack = 99  # Could make this per-item later
	
	var total = from_count + to_count
	
	if total <= max_stack:
		# All items fit in target stack
		to_item.metadata["count"] = total
		inventory_manager.items[from_slot] = null
	else:
		# Partial stack
		to_item.metadata["count"] = max_stack
		from_item.metadata["count"] = total - max_stack
	
	inventory_manager.inventory_changed.emit()
	
func handle_single_item_move(from_slot: int, to_slot: int, single_item: InventoryManager.InventoryItem):
	"""Handle moving a single item from a stack - FIXED VERSION"""
	var from_item = inventory_manager.items[from_slot]
	if not from_item:
		print("ERROR: No item in source slot!")
		return
		
	var from_count = from_item.metadata.get("count", 1)
	print("Moving 1 ", single_item.name, " from slot ", from_slot, " (has ", from_count, ") to slot ", to_slot)
	
	# Prepare target slot
	while inventory_manager.items.size() <= to_slot:
		inventory_manager.items.append(null)
	
	var target_item = inventory_manager.items[to_slot]
	
	if target_item == null:
		# Empty slot - place single item
		print("Placing in empty slot")
		inventory_manager.items[to_slot] = single_item
		
		# Remove one from source
		from_item.metadata["count"] = from_count - 1
		if from_item.metadata["count"] <= 0:
			inventory_manager.items[from_slot] = null
			
	elif target_item.name == single_item.name:
		# Same item - add to stack
		print("Adding to existing stack")
		target_item.metadata["count"] = target_item.metadata.get("count", 1) + 1
		
		# Remove one from source
		from_item.metadata["count"] = from_count - 1
		if from_item.metadata["count"] <= 0:
			inventory_manager.items[from_slot] = null
			
	else:
		# Different item - can't place
		print("Can't place ", single_item.name, " on ", target_item.name)
		return
	
	inventory_manager.inventory_changed.emit()
	print("Single item move complete!")
