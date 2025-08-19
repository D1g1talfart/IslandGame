extends CanvasLayer

var inventory_manager
var hotbar_container
var hotbar_slots: Array[Button] = []
var is_game_active = false

func _ready():
	# Make sure this CanvasLayer is visible
	layer = 10
	visible = false  # Start hidden!
	
	# Wait a frame to ensure parent is ready
	await get_tree().process_frame
	
	inventory_manager = get_parent().get_node("InventoryManager")
	if not inventory_manager:
		print("ERROR: Can't find InventoryManager!")
		return
		
	create_hotbar_ui()
	inventory_manager.inventory_changed.connect(update_hotbar_display)
	inventory_manager.hotbar_changed.connect(highlight_selected_slot)
	
	# Check if we should be visible
	check_if_should_show()

func check_if_should_show():
	var current_scene = get_tree().current_scene
	print("Current scene name: '", current_scene.name, "'")
	print("Current scene type: ", current_scene.get_class())
	
	# Let's also check if GameWorld exists as a child
	var gameworld = current_scene.get_node_or_null("GameWorld")
	print("GameWorld found: ", gameworld != null)
	
	# Based on your logs, it looks like your scene is called "Node"
	if current_scene.name == "Node":  # Changed from "GameWorld"
		show_inventory()
	else:
		print("InventoryUI: Waiting for game scene... (looking for 'Node')")
		get_tree().create_timer(1.0).timeout.connect(check_if_should_show)

func show_inventory():
	visible = true
	is_game_active = true
	print("InventoryUI: Now visible in game scene!")

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

func update_hotbar_display():
	for i in range(10):
		var item = inventory_manager.get_hotbar_item(i)
		var button = hotbar_slots[i]
		
		if item != null:
			var count = item.metadata.get("count", 1)
			button.text = item.name + "\n" + str(count)
		else:
			button.text = str(i + 1) if i < 9 else "0"

func highlight_selected_slot(slot: int):
	# Reset all buttons
	for button in hotbar_slots:
		button.modulate = Color.WHITE
	
	# Highlight selected
	if slot < hotbar_slots.size():
		hotbar_slots[slot].modulate = Color.YELLOW
