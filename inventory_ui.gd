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

var message_label: Label
var message_timer: Timer

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
	
		if item.count <= 0:
			return

		print("Right-click dragging single item: ", item.get_name())

		# FIXED: Create single item preserving metadata
		var drag_item = item.duplicate_with_count(1)

		# Create preview with icon
		var preview = create_drag_preview(item, 1)

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
		var count = item.count
	
		# Create drag preview with icon
		var preview = create_drag_preview(item, count)
		set_drag_preview(preview)
	
		return {
			"item": item,
			"from_slot": slot_index,
			"is_single_grab": false
		}
	
	func create_drag_preview(item: InventoryManager.InventoryItem, count: int) -> Control:
		var preview = Button.new()
		preview.custom_minimum_size = Vector2(85, 85)
		preview.size = Vector2(85, 85)
		preview.modulate = Color(1, 1, 1, 0.8)

		# Set icon if available
		var icon = item.get_icon()
		if icon:
			preview.icon = icon
			preview.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			preview.expand_icon = true
		
			# Handle tool vs normal item display
			if item.is_tool():
				preview.text = item.get_name()
				# Add durability bar to preview too
				inventory_ui.add_durability_bar_to_button(preview, item)
			else:
				preview.text = str(count)
		
			preview.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		else:
			# Fallback to text
			if item.is_tool():
				preview.text = item.get_name()
			else:
				preview.text = item.get_name() + "\n" + str(count)

		return preview

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
	create_full_inventory()
	create_message_system()
	inventory_manager.inventory_changed.connect(update_all_displays)
	inventory_manager.hotbar_changed.connect(highlight_selected_slot)
	
	# ADD THIS: Ensure initial selection after everything is connected
	await get_tree().process_frame
	highlight_selected_slot(inventory_manager.selected_hotbar_slot)

func show_inventory_ui():
	"""Call this when the game is actually ready to show inventory"""
	if not inventory_manager:
		print("No inventory manager found!")
		return
	visible = true
	update_all_displays()
	print("Inventory UI now visible!")

func create_hotbar_ui():
	print("Creating hotbar UI...")
	
	# Create hotbar container
	var hotbar = HBoxContainer.new()
	hotbar.name = "HotbarContainer"
	add_child(hotbar)
	
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_top = -120    # Move up more for bigger buttons
	hotbar.offset_left = -300   # Wider for bigger buttons
	hotbar.offset_right = 300   
	hotbar.offset_bottom = -20  
	
	# Add a background so we can see it
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(600, 100)  # Bigger background
	hotbar.add_child(bg)
	
	# Create 10 hotbar slots - BIGGER
	for i in range(10):
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(55, 80)  # Bigger (was 45x60)
		slot_button.text = str(i + 1) if i < 9 else "0"
		slot_button.flat = false
		slot_button.modulate = Color.HONEYDEW
		
		hotbar.add_child(slot_button)
		hotbar_slots.append(slot_button)
		
		# Connect click events
		var slot_index = i
		slot_button.pressed.connect(func(): inventory_manager.select_hotbar_slot(slot_index))
	
	hotbar_container = hotbar
	print("Hotbar UI created with ", hotbar_slots.size(), " buttons!")
	
	# Force update the display
	await get_tree().process_frame
	update_hotbar_display()
	
func create_full_inventory():
	# Main inventory panel - EVEN BIGGER for larger icons
	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	
	# BIGGER: Even wider panel for larger icons
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_panel.offset_left = -470   # Even wider (was -400)
	inventory_panel.offset_right = 470   
	inventory_panel.offset_top = -275    # Taller (was -225)
	inventory_panel.offset_bottom = 275  
	
	# Style the panel (same as before)
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
	
	# 4x10 Grid container - BIGGER for larger icons
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 10
	inventory_grid.position = Vector2(15, 50)
	inventory_grid.size = Vector2(870, 360)    # Much bigger (was 770x280)
	inventory_grid.add_theme_constant_override("h_separation", 5)  # More space
	inventory_grid.add_theme_constant_override("v_separation", 5)
	inventory_panel.add_child(inventory_grid)
	
	# Create 40 inventory slots - MUCH BIGGER
	for i in range(40):
		var slot_button = InventorySlot.new(i, self)
		slot_button.custom_minimum_size = Vector2(85, 85)  # Much bigger (was 75x65)
		slot_button.size = Vector2(85, 85)
		slot_button.clip_contents = true
		slot_button.text = ""
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

	# UPDATED: Reposition trash and close buttons for bigger panel
	delete_slot = TrashSlot.new(self)
	delete_slot.text = "🗑️\nTRASH"
	delete_slot.custom_minimum_size = Vector2(80, 50)
	delete_slot.position = Vector2(780, 470)  # Moved for bigger panel
	delete_slot.modulate = Color.RED
	delete_slot.tooltip_text = "Drag items here to delete them"
	inventory_panel.add_child(delete_slot)

	# Close button
	var close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.position = Vector2(860, 10)  # Moved for bigger panel
	close_button.pressed.connect(toggle_inventory)
	inventory_panel.add_child(close_button)
	
	# Start hidden
	inventory_panel.visible = false
	print("Full inventory UI created!")

func update_all_displays():
	update_hotbar_display()
	update_inventory_display()

func update_hotbar_display():
	for i in range(10):
		var button = hotbar_slots[i]
		var item = inventory_manager.get_hotbar_item(i)
		
		# ALWAYS clean up first, regardless of item state
		remove_durability_bar_from_button(button)
		
		if item != null:
			# Set icon
			var icon = item.get_icon()
			if icon:
				button.icon = icon
				button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				button.expand_icon = true
				
				# Show name and handle tool durability vs normal count
				var name = item.get_name()
				if name.length() > 8:
					name = name.substr(0, 6) + ".."
				
				if item.is_tool():
					# Tools show name only, durability bar will be added
					button.text = name
					# Use call_deferred to avoid timing issues
					call_deferred("add_durability_bar_to_button", button, item)
				else:
					# Normal items show name + count
					button.text = name + "\n" + str(item.count)
				
				button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			else:
				# Fallback to text if no icon
				button.icon = null
				if item.is_tool():
					button.text = item.get_name()
					call_deferred("add_durability_bar_to_button", button, item)
				else:
					button.text = item.get_name() + "\n" + str(item.count)
		else:
			button.icon = null
			button.text = str(i + 1) if i < 9 else "0"

func update_inventory_display():
	if not inventory_slots:
		return
	
	for i in range(40):
		if i < inventory_slots.size():
			var button = inventory_slots[i]
			var item = inventory_manager.items[i] if i < inventory_manager.items.size() else null
			
			# ALWAYS clean up first
			remove_durability_bar_from_button(button)
			
			if item != null:
				# Set icon
				var icon = item.get_icon()
				if icon:
					button.icon = icon
					button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
					button.expand_icon = true
					
					if item.is_tool():
						# Tools show no count text, just durability bar
						button.text = ""
						call_deferred("add_durability_bar_to_button", button, item)
						
						# Enhanced tooltip for tools with durability
						var dur = item.get_durability()
						var max_dur = item.get_max_durability()
						button.tooltip_text = item.get_name() + "\nDurability: " + str(dur) + "/" + str(max_dur) + "\n" + ItemDatabase.get_item_by_id(item.item_id).get("description", "")
					else:
						# Normal items show count
						button.text = str(item.count)
						button.tooltip_text = item.get_name() + " (x" + str(item.count) + ")\n" + ItemDatabase.get_item_by_id(item.item_id).get("description", "") + "\n\nLeft-click: drag all\nRight-click: drag one"
					
					button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				else:
					# Fallback to text if no icon
					button.icon = null
					if item.is_tool():
						var display_name = item.get_name()
						if display_name.length() > 10:
							display_name = display_name.substr(0, 8) + ".."
						button.text = display_name
						call_deferred("add_durability_bar_to_button", button, item)
						
						var dur = item.get_durability()
						var max_dur = item.get_max_durability()
						button.tooltip_text = item.get_name() + "\nDurability: " + str(dur) + "/" + str(max_dur)
					else:
						var display_name = item.get_name()
						if display_name.length() > 10:
							display_name = display_name.substr(0, 8) + ".."
						button.text = display_name + "\n" + str(item.count)
						button.tooltip_text = item.get_name() + " (x" + str(item.count) + ")\nLeft-click: drag all\nRight-click: drag one"
				
				button.disabled = false
				
				# Color coding by item type
				match item.get_type():
					"resource":
						button.modulate = Color.YELLOW if i < 10 else Color.WHITE
					"tool":
						button.modulate = Color.CYAN if i < 10 else Color.LIGHT_BLUE
					"consumable":
						button.modulate = Color.GREEN if i < 10 else Color.LIGHT_GREEN
					"seed":
						button.modulate = Color.MAGENTA if i < 10 else Color.PINK
					_:
						button.modulate = Color.YELLOW if i < 10 else Color.WHITE
			else:
				button.icon = null
				button.text = ""
				button.tooltip_text = ""
				button.disabled = false
				button.modulate = Color.YELLOW if i < 10 else Color.GRAY

func remove_durability_bar_from_button(button: Button):
	"""Remove ALL durability bar elements from a button"""
	# Remove by name - more reliable
	var children_to_remove = []
	
	for child in button.get_children():
		if child.name.begins_with("Durability"):
			children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()
	
	# Also remove any ColorRect children (fallback cleanup)
	var color_rects = []
	for child in button.get_children():
		if child is ColorRect:
			color_rects.append(child)
	
	for rect in color_rects:
		rect.queue_free()

func add_durability_bar_to_button(button: Button, item: InventoryManager.InventoryItem):
	"""Add a durability bar to a button"""
	# ALWAYS remove existing bars first
	remove_durability_bar_from_button(button)
	
	# Wait a frame to ensure cleanup is complete
	await get_tree().process_frame
	
	var current_dur = item.get_durability()
	var max_dur = item.get_max_durability()
	
	if max_dur <= 0:
		return  # No durability system
	
	# Calculate durability percentage
	var durability_percent = float(current_dur) / float(max_dur)
	
	# Create background bar
	var bg_bar = ColorRect.new()
	bg_bar.name = "DurabilityBG_" + str(item.item_id)  # Unique name
	bg_bar.color = Color.BLACK
	bg_bar.size = Vector2(button.size.x - 10, 6)
	bg_bar.position = Vector2(5, button.size.y - 10)
	button.add_child(bg_bar)
	
	# Create durability bar
	var dur_bar = ColorRect.new()
	dur_bar.name = "DurabilityBar_" + str(item.item_id)  # Unique name
	dur_bar.size = Vector2((button.size.x - 10) * durability_percent, 6)
	dur_bar.position = Vector2(5, button.size.y - 10)
	
	# Color based on durability percentage
	if durability_percent > 0.5:
		dur_bar.color = Color.GREEN
	elif durability_percent > 0.1:
		dur_bar.color = Color.YELLOW
	else:
		dur_bar.color = Color.RED
	
	button.add_child(dur_bar)

func highlight_selected_slot(slot: int):
	# Reset all buttons to their default color (not white!)
	for button in hotbar_slots:
		button.modulate = Color.HONEYDEW  # Use the original color, not WHITE
	
	# Highlight selected
	if slot < hotbar_slots.size():
		hotbar_slots[slot].modulate = Color.YELLOW
		print("UI: Highlighted hotbar slot ", slot)  # Debug to confirm it's working
		
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
		handle_single_item_move(from_slot, to_slot, item)
	else:
		# Handle full stack move
		var target_item = inventory_manager.items[to_slot] if to_slot < inventory_manager.items.size() else null
		
		if target_item == null:
			move_item(from_slot, to_slot)
		elif target_item.item_id == item.item_id:  # UPDATED: Compare by ID
			stack_items(from_slot, to_slot)
		else:
			swap_items(from_slot, to_slot)

func handle_item_trash(drag_data: Dictionary):
	var from_slot = drag_data["from_slot"]
	var item = drag_data["item"]
	
	print("Trashing item: ", item.get_name(), " from slot ", from_slot)
	
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
	
	if from_item.item_id != to_item.item_id:  # UPDATED: Compare by ID
		return
	
	var from_count = from_item.count
	var to_count = to_item.count
	var max_stack = from_item.get_max_stack_size()  # UPDATED: Use database value
	
	var total = from_count + to_count
	
	if total <= max_stack:
		# All items fit in target stack
		to_item.count = total
		inventory_manager.items[from_slot] = null
	else:
		# Partial stack
		to_item.count = max_stack
		from_item.count = total - max_stack
	
	inventory_manager.inventory_changed.emit()
	
func handle_single_item_move(from_slot: int, to_slot: int, single_item: InventoryManager.InventoryItem):
	"""Handle moving a single item from a stack"""
	var from_item = inventory_manager.items[from_slot]
	if not from_item:
		print("ERROR: No item in source slot!")
		return
		
	var from_count = from_item.count
	print("Moving 1 ", single_item.get_name(), " from slot ", from_slot, " (has ", from_count, ") to slot ", to_slot)
	
	# Prepare target slot
	while inventory_manager.items.size() <= to_slot:
		inventory_manager.items.append(null)
	
	var target_item = inventory_manager.items[to_slot]
	
	if target_item == null:
		# Empty slot - place single item
		print("Placing in empty slot")
		inventory_manager.items[to_slot] = single_item
		
		# Remove one from source
		from_item.count = from_count - 1
		if from_item.count <= 0:
			inventory_manager.items[from_slot] = null
			
	elif target_item.item_id == single_item.item_id:  # UPDATED: Compare by ID
		# Same item - add to stack
		print("Adding to existing stack")
		target_item.count = target_item.count + 1
		
		# Remove one from source
		from_item.count = from_count - 1
		if from_item.count <= 0:
			inventory_manager.items[from_slot] = null
			
	else:
		# Different item - can't place
		print("Can't place ", single_item.get_name(), " on ", target_item.get_name())
		return
	
	inventory_manager.inventory_changed.emit()
	print("Single item move complete!")

func create_message_system():
	"""Create floating message system for tool feedback"""
	# Create label for messages
	message_label = Label.new()
	message_label.name = "ToolMessage"
	add_child(message_label)
	
	# Position in center-top of screen
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_top = 100
	message_label.offset_left = -200
	message_label.offset_right = 200
	message_label.offset_bottom = 150
	
	# Style the message
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.visible = false
	
	# Add background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	message_label.add_theme_stylebox_override("normal", style)
	
	# Create timer for hiding messages
	message_timer = Timer.new()
	message_timer.name = "MessageTimer"
	message_timer.wait_time = 1.0
	message_timer.one_shot = true
	message_timer.timeout.connect(hide_tool_message)
	add_child(message_timer)
	
	print("UI Message system created!")

func show_tool_message(message: String, color: Color = Color.WHITE):
	"""Show a message at the top of the screen"""
	if not message_label:
		print("No message label!")
		return
		
	message_label.text = message
	message_label.add_theme_color_override("font_color", color)
	message_label.visible = true
	
	# Reset timer
	message_timer.stop()
	message_timer.start()
	
	print("UI: Showing message: ", message)

func hide_tool_message():
	"""Hide the message"""
	if message_label:
		message_label.visible = false
		print("UI: Hidden message")
