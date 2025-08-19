extends Control

# Reference to the island generator (will auto-find parent if not set)
@export var island_generator: TileMapLayer

# GUI elements
var main_container: VBoxContainer
var scroll_container: ScrollContainer
var tabs_container: TabContainer

# Preset management
var preset_data: Dictionary = {}
var preset_file_path: String = "user://island_presets.json"

# Control groups for organization
var controls: Dictionary = {}

# Preset controls
var preset_name_input: LineEdit
var preset_list: ItemList
var save_preset_btn: Button
var load_preset_btn: Button
var delete_preset_btn: Button

# Generation controls
var generate_btn: Button
var auto_generate_checkbox: CheckBox

func _ready():
	# Auto-find island generator if not manually assigned
	if not island_generator:
		# Check if parent's parent is TileMapLayer (CanvasLayer -> TileMapLayer)
		var canvas_layer = get_parent()
		if canvas_layer and canvas_layer.get_parent() is TileMapLayer:
			island_generator = canvas_layer.get_parent()
			print("Auto-found island generator: ", island_generator.name)
		else:
			print("Warning: Could not auto-find island generator!")
			return
	
	if not island_generator:
		print("Warning: Island generator not assigned!")
		return
	
	setup_gui()
	load_presets()
	populate_controls()
	connect_signals()

func setup_gui():
	# Main container
	main_container = VBoxContainer.new()
	add_child(main_container)
	
	# Title
	var title = Label.new()
	title.text = "Island Generator Control Panel"
	title.add_theme_font_size_override("font_size", 20)
	main_container.add_child(title)
	
	# Preset management section
	create_preset_section()
	
	# Generation controls
	create_generation_controls()
	
	# Scroll container for parameters
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(500, 700)
	main_container.add_child(scroll_container)
	
	# Tab container for organized controls
	tabs_container = TabContainer.new()
	scroll_container.add_child(tabs_container)
	
	# Create tabs for different parameter groups
	create_parameter_tabs()

func create_preset_section():
	var preset_container = VBoxContainer.new()
	main_container.add_child(preset_container)
	
	var preset_label = Label.new()
	preset_label.text = "Preset Management"
	preset_label.add_theme_font_size_override("font_size", 16)
	preset_container.add_child(preset_label)
	
	# Preset name input
	var name_container = HBoxContainer.new()
	preset_container.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Preset Name:"
	name_container.add_child(name_label)
	
	preset_name_input = LineEdit.new()
	preset_name_input.placeholder_text = "Enter preset name..."
	name_container.add_child(preset_name_input)
	
	# Preset buttons
	var button_container = HBoxContainer.new()
	preset_container.add_child(button_container)
	
	save_preset_btn = Button.new()
	save_preset_btn.text = "Save Preset"
	button_container.add_child(save_preset_btn)
	
	load_preset_btn = Button.new()
	load_preset_btn.text = "Load Preset"
	button_container.add_child(load_preset_btn)
	
	delete_preset_btn = Button.new()
	delete_preset_btn.text = "Delete Preset"
	button_container.add_child(delete_preset_btn)
	
	# Preset list
	preset_list = ItemList.new()
	preset_list.custom_minimum_size = Vector2(0, 100)
	preset_container.add_child(preset_list)

func create_generation_controls():
	var gen_container = HBoxContainer.new()
	main_container.add_child(gen_container)
	
	generate_btn = Button.new()
	generate_btn.text = "Generate Island"
	generate_btn.add_theme_font_size_override("font_size", 16)
	gen_container.add_child(generate_btn)
	
	auto_generate_checkbox = CheckBox.new()
	auto_generate_checkbox.text = "Auto-generate on change"
	gen_container.add_child(auto_generate_checkbox)

func create_parameter_tabs():
	# Island Shape & Size Tab
	create_shape_tab()
	
	# Elevation Settings Tab
	create_elevation_tab()
	
	# Terrain Distribution Tab
	create_terrain_tab()
	
	# Pond Generation Tab
	create_pond_tab()
	
	# River Generation Tab
	create_river_tab()
	
	# Beach & Coast Tab  
	create_beach_tab()
	
	# Tile IDs Tab
	create_tile_ids_tab()
	
	# Advanced Controls Tab
	create_advanced_tab()

func create_shape_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Shape & Size")
	
	controls["shape"] = {}
	
	# Island dimensions
	add_group_header(tab, "Island Dimensions")
	controls["shape"]["island_width"] = add_int_control(tab, "Island Width", "island_width", 50, 500, 200)
	controls["shape"]["island_height"] = add_int_control(tab, "Island Height", "island_height", 50, 300, 120)
	
	# Highland distribution
	add_group_header(tab, "Highland/Lowland Distribution")
	controls["shape"]["highland_transition"] = add_float_control(tab, "Highland Transition", "highland_transition", 0.1, 0.9, 0.65, 0.05)
	
	# Base noise
	add_group_header(tab, "Base Noise")
	controls["shape"]["noise_scale"] = add_float_control(tab, "Main Noise Scale", "noise_scale", 0.01, 0.1, 0.03, 0.001)
	controls["shape"]["cliff_noise_scale"] = add_float_control(tab, "Cliff Noise Scale", "cliff_noise_scale", 0.005, 0.05, 0.01, 0.001)

func create_elevation_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Elevation")
	
	controls["elevation"] = {}
	
	add_group_header(tab, "Height Thresholds")
	controls["elevation"]["water_threshold"] = add_float_control(tab, "Water Threshold", "water_threshold", 0.05, 0.3, 0.1, 0.01)
	controls["elevation"]["beach_threshold"] = add_float_control(tab, "Beach Threshold", "beach_threshold", 0.1, 0.4, 0.20, 0.01)
	controls["elevation"]["lowland_threshold"] = add_float_control(tab, "Lowland Threshold", "lowland_threshold", 0.2, 0.5, 0.35, 0.01)
	controls["elevation"]["highland_threshold"] = add_float_control(tab, "Highland Threshold", "highland_threshold", 0.3, 0.7, 0.5, 0.01)
	controls["elevation"]["cliff_level_2"] = add_float_control(tab, "Cliff Level 2", "cliff_level_2", 0.4, 0.8, 0.6, 0.01)
	controls["elevation"]["cliff_level_3"] = add_float_control(tab, "Cliff Level 3", "cliff_level_3", 0.6, 1.0, 0.85, 0.01)

func create_terrain_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Terrain")
	
	controls["terrain"] = {}
	
	add_group_header(tab, "Dirt/Grass Distribution")
	controls["terrain"]["level0_dirt_percentage"] = add_float_control(tab, "Level 0 Dirt %", "level0_dirt_percentage", 0.0, 0.5, 0.05, 0.01)
	controls["terrain"]["level1_dirt_percentage"] = add_float_control(tab, "Level 1 Dirt %", "level1_dirt_percentage", 0.0, 0.7, 0.15, 0.01)
	controls["terrain"]["level2_dirt_percentage"] = add_float_control(tab, "Level 2 Dirt %", "level2_dirt_percentage", 0.0, 0.8, 0.30, 0.01)
	controls["terrain"]["level3_dirt_percentage"] = add_float_control(tab, "Level 3 Dirt %", "level3_dirt_percentage", 0.0, 1.0, 0.45, 0.01)
	controls["terrain"]["dirt_grass_noise_scale"] = add_float_control(tab, "Dirt/Grass Noise Scale", "dirt_grass_noise_scale", 0.01, 0.1, 0.02, 0.001)

func create_pond_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Ponds")
	
	controls["pond"] = {}
	
	# Pond counts
	add_group_header(tab, "Pond Counts")
	controls["pond"]["deep_pond_count"] = add_int_control(tab, "Deep Pond Count", "deep_pond_count", 0, 15, 5)
	controls["pond"]["small_pond_count"] = add_int_control(tab, "Small Pond Count", "small_pond_count", 0, 20, 8)
	controls["pond"]["pond_min_size"] = add_int_control(tab, "Small Pond Min Size", "pond_min_size", 1, 5, 2)
	controls["pond"]["pond_max_size"] = add_int_control(tab, "Small Pond Max Size", "pond_max_size", 2, 8, 4)
	
	# Deep pond sizing  
	add_group_header(tab, "Deep Pond Sizing")
	controls["pond"]["pond_size_variation"] = add_vector2i_control(tab, "Deep Pond Size Range", "pond_size_variation", Vector2i(2, 2), Vector2i(10, 10), Vector2i(3, 7))
	
	# Elevation preferences
	add_group_header(tab, "Elevation Placement Weights")
	controls["pond"]["pond_level3_weight"] = add_float_control(tab, "Level 3 Weight", "pond_level3_weight", 0.0, 10.0, 5.0, 0.5)
	controls["pond"]["pond_level2_weight"] = add_float_control(tab, "Level 2 Weight", "pond_level2_weight", 0.0, 10.0, 3.0, 0.5)
	controls["pond"]["pond_level1_weight"] = add_float_control(tab, "Level 1 Weight", "pond_level1_weight", 0.0, 10.0, 1.0, 0.5)
	controls["pond"]["pond_level0_weight"] = add_float_control(tab, "Level 0 Weight", "pond_level0_weight", 0.0, 5.0, 0.3, 0.1)

func create_river_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Rivers")
	
	controls["river"] = {}
	
	add_group_header(tab, "River Behavior")
	controls["river"]["river_meandering"] = add_float_control(tab, "River Meandering", "river_meandering", 0.0, 1.0, 0.4, 0.05)
	controls["river"]["river_momentum_strength"] = add_float_control(tab, "Momentum Strength", "river_momentum_strength", 0.0, 20.0, 6.0, 0.5)
	controls["river"]["side_flow_chance"] = add_float_control(tab, "Side Flow Chance", "side_flow_chance", 0.0, 1.0, 0.2, 0.05)

func create_beach_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Beaches")
	
	controls["beach"] = {}
	
	add_group_header(tab, "Beach Extensions")
	controls["beach"]["south_beach_min"] = add_int_control(tab, "South Beach Min", "south_beach_min", 1, 10, 5)
	controls["beach"]["south_beach_max"] = add_int_control(tab, "South Beach Max", "south_beach_max", 3, 15, 7)
	controls["beach"]["side_beach_min"] = add_int_control(tab, "Side Beach Min", "side_beach_min", 1, 8, 2)
	controls["beach"]["side_beach_max"] = add_int_control(tab, "Side Beach Max", "side_beach_max", 2, 10, 3)
	
	add_group_header(tab, "Shallow Water")
	controls["beach"]["shallow_saltwater_depth"] = add_int_control(tab, "Shallow Saltwater Depth", "shallow_saltwater_depth", 1, 8, 3)
	
	add_group_header(tab, "Coast Generation")
	controls["beach"]["northern_shore_exclusion"] = add_float_control(tab, "Northern Shore Exclusion", "northern_shore_exclusion", 0.0, 0.5, 0.15, 0.05)

func create_tile_ids_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Tile IDs")
	
	controls["tile_ids"] = {}
	
	# Water tiles
	add_group_header(tab, "Water Tile IDs")
	controls["tile_ids"]["deep_ocean_id"] = add_int_control(tab, "Deep Ocean ID", "deep_ocean_id", 0, 200, 0)
	controls["tile_ids"]["shallow_saltwater_id"] = add_int_control(tab, "Shallow Saltwater ID", "shallow_saltwater_id", 0, 200, 1)
	controls["tile_ids"]["shallow_freshwater_id"] = add_int_control(tab, "Shallow Freshwater ID", "shallow_freshwater_id", 0, 200, 2)
	controls["tile_ids"]["deep_freshwater_id"] = add_int_control(tab, "Deep Freshwater ID", "deep_freshwater_id", 0, 200, 3)
	controls["tile_ids"]["river_id"] = add_int_control(tab, "River ID", "river_id", 0, 200, 4)
	controls["tile_ids"]["river_mouth_id"] = add_int_control(tab, "River Mouth ID", "river_mouth_id", 0, 200, 5)
	
	# Land tiles
	add_group_header(tab, "Land Tile IDs")
	controls["tile_ids"]["beach_id"] = add_int_control(tab, "Beach ID", "beach_id", 0, 200, 12)
	controls["tile_ids"]["level0_grass_id"] = add_int_control(tab, "Level 0 Grass ID", "level0_grass_id", 0, 200, 10)
	controls["tile_ids"]["level0_dirt_id"] = add_int_control(tab, "Level 0 Dirt ID", "level0_dirt_id", 0, 200, 11)
	controls["tile_ids"]["level1_grass_id"] = add_int_control(tab, "Level 1 Grass ID", "level1_grass_id", 0, 200, 20)
	controls["tile_ids"]["level1_dirt_id"] = add_int_control(tab, "Level 1 Dirt ID", "level1_dirt_id", 0, 200, 21)
	controls["tile_ids"]["level2_grass_id"] = add_int_control(tab, "Level 2 Grass ID", "level2_grass_id", 0, 200, 30)
	controls["tile_ids"]["level2_dirt_id"] = add_int_control(tab, "Level 2 Dirt ID", "level2_dirt_id", 0, 200, 31)
	controls["tile_ids"]["level3_grass_id"] = add_int_control(tab, "Level 3 Grass ID", "level3_grass_id", 0, 200, 40)
	controls["tile_ids"]["level3_dirt_id"] = add_int_control(tab, "Level 3 Dirt ID", "level3_dirt_id", 0, 200, 41)

func create_advanced_tab():
	var tab = VBoxContainer.new()
	tabs_container.add_child(tab)
	tabs_container.set_tab_title(tabs_container.get_tab_count() - 1, "Advanced")
	
	controls["advanced"] = {}
	
	add_group_header(tab, "Pond Shape Controls")
	controls["advanced"]["pond_detail_scale_large"] = add_float_control(tab, "Large Scale Features", "pond_detail_scale_large", 0.05, 0.5, 0.15, 0.01)
	controls["advanced"]["pond_detail_scale_medium"] = add_float_control(tab, "Medium Scale Features", "pond_detail_scale_medium", 0.1, 1.0, 0.4, 0.01)
	controls["advanced"]["pond_detail_scale_fine"] = add_float_control(tab, "Fine Detail Features", "pond_detail_scale_fine", 0.2, 2.0, 0.8, 0.01)
	controls["advanced"]["pond_erosion_threshold"] = add_float_control(tab, "Pond Erosion Threshold", "pond_erosion_threshold", 0.0, 1.0, 0.3, 0.05)

func add_group_header(parent: Node, text: String):
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = Color(0.8, 0.9, 1.0)  # Light blue tint
	parent.add_child(header)
	
	var separator = HSeparator.new()
	parent.add_child(separator)

func add_int_control(parent: Node, label_text: String, property_name: String, min_val: int, max_val: int, default_val: int) -> SpinBox:
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 200
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.value = default_val
	spinbox.step = 1
	container.add_child(spinbox)
	
	# Store property name for later use
	spinbox.set_meta("property_name", property_name)
	
	return spinbox

func add_float_control(parent: Node, label_text: String, property_name: String, min_val: float, max_val: float, default_val: float, step_val: float = 0.01) -> SpinBox:
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 200
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.value = default_val
	spinbox.step = step_val
	container.add_child(spinbox)
	
	# Store property name for later use
	spinbox.set_meta("property_name", property_name)
	
	return spinbox

func add_vector2i_control(parent: Node, label_text: String, property_name: String, min_val: Vector2i, max_val: Vector2i, default_val: Vector2i) -> Dictionary:
	var container = VBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	# X component
	var x_container = HBoxContainer.new()
	container.add_child(x_container)
	
	var x_label = Label.new()
	x_label.text = "  Min:"
	x_label.custom_minimum_size.x = 100
	x_container.add_child(x_label)
	
	var x_spinbox = SpinBox.new()
	x_spinbox.min_value = min_val.x
	x_spinbox.max_value = max_val.x
	x_spinbox.value = default_val.x
	x_spinbox.step = 1
	x_container.add_child(x_spinbox)
	
	# Y component  
	var y_container = HBoxContainer.new()
	container.add_child(y_container)
	
	var y_label = Label.new()
	y_label.text = "  Max:"
	y_label.custom_minimum_size.x = 100
	y_container.add_child(y_label)
	
	var y_spinbox = SpinBox.new()
	y_spinbox.min_value = min_val.y
	y_spinbox.max_value = max_val.y
	y_spinbox.value = default_val.y
	y_spinbox.step = 1
	y_container.add_child(y_spinbox)
	
	# Store property name and return both spinboxes
	var result = {
		"x": x_spinbox,
		"y": y_spinbox,
		"property_name": property_name
	}
	
	x_spinbox.set_meta("property_name", property_name + "_x")
	y_spinbox.set_meta("property_name", property_name + "_y")
	x_spinbox.set_meta("vector2i_control", result)
	y_spinbox.set_meta("vector2i_control", result)
	
	return result

func connect_signals():
	if not island_generator:
		return
		
	# Generation controls
	generate_btn.pressed.connect(_on_generate_pressed)
	
	# Preset controls
	save_preset_btn.pressed.connect(_on_save_preset_pressed)
	load_preset_btn.pressed.connect(_on_load_preset_pressed)
	delete_preset_btn.pressed.connect(_on_delete_preset_pressed)
	preset_list.item_selected.connect(_on_preset_selected)
	
	# Connect all parameter controls
	for category in controls.values():
		for control_name in category:
			var control = category[control_name]
			if control is SpinBox:
				control.value_changed.connect(_on_parameter_changed)
			elif control is Dictionary and "x" in control and "y" in control:
				# Vector2i control
				control["x"].value_changed.connect(_on_vector2i_parameter_changed)
				control["y"].value_changed.connect(_on_vector2i_parameter_changed)

func populate_controls():
	if not island_generator:
		return
		
	# Update all controls with current values from the generator
	for category in controls.values():
		for control_name in category:
			var control = category[control_name]
			if control is SpinBox:
				var property_name = control.get_meta("property_name")
				if property_name in island_generator:
					control.value = island_generator.get(property_name)
			elif control is Dictionary and "property_name" in control:
				# Vector2i control
				var property_name = control["property_name"]
				if property_name in island_generator:
					var vec_value = island_generator.get(property_name)
					control["x"].value = vec_value.x
					control["y"].value = vec_value.y

func _on_parameter_changed(value):
	if not island_generator:
		return
	
	# Find which spinbox changed and update the generator
	for category in controls.values():
		for control_name in category:
			var control = category[control_name]
			if control is SpinBox:
				var property_name = control.get_meta("property_name")
				if property_name in island_generator:
					island_generator.set(property_name, control.value)
	
	# Auto-generate if enabled
	if auto_generate_checkbox.button_pressed:
		_on_generate_pressed()

func _on_vector2i_parameter_changed(value):
	if not island_generator:
		return
	
	# Find which Vector2i control changed
	for category in controls.values():
		for control_name in category:
			var control = category[control_name]
			if control is Dictionary and "property_name" in control:
				var property_name = control["property_name"]
				if property_name in island_generator:
					var new_value = Vector2i(control["x"].value, control["y"].value)
					island_generator.set(property_name, new_value)
	
	# Auto-generate if enabled
	if auto_generate_checkbox.button_pressed:
		_on_generate_pressed()

func _on_generate_pressed():
	if island_generator and island_generator.has_method("regenerate"):
		island_generator.regenerate()

func _on_save_preset_pressed():
	var preset_name = preset_name_input.text.strip_edges()
	if preset_name.is_empty():
		print("Please enter a preset name!")
		return
	
	# Collect current values
	var preset = {}
	for category in controls.values():
		for control_name in category:
			var control = category[control_name]
			if control is SpinBox:
				var property_name = control.get_meta("property_name")
				preset[property_name] = control.value
			elif control is Dictionary and "property_name" in control:
				# Vector2i control
				var property_name = control["property_name"]
				preset[property_name] = {"x": control["x"].value, "y": control["y"].value}
	
	preset_data[preset_name] = preset
	save_presets()
	refresh_preset_list()
	print("Preset '", preset_name, "' saved!")

func _on_load_preset_pressed():
	var selected = preset_list.get_selected_items()
	if selected.is_empty():
		print("Please select a preset to load!")
		return
	
	var preset_name = preset_list.get_item_text(selected[0])
	if preset_name in preset_data:
		load_preset_values(preset_data[preset_name])
		print("Preset '", preset_name, "' loaded!")

func _on_delete_preset_pressed():
	var selected = preset_list.get_selected_items()
	if selected.is_empty():
		print("Please select a preset to delete!")
		return
	
	var preset_name = preset_list.get_item_text(selected[0])
	if preset_name in preset_data:
		preset_data.erase(preset_name)
		save_presets()
		refresh_preset_list()
		print("Preset '", preset_name, "' deleted!")

func _on_preset_selected(index: int):
	var preset_name = preset_list.get_item_text(index)
	preset_name_input.text = preset_name

func load_preset_values(preset: Dictionary):
	# Apply preset values to controls and generator
	for category in controls.values():
		for control_name in category:
			var control = category[control_name]
			if control is SpinBox:
				var property_name = control.get_meta("property_name")
				if property_name in preset:
					control.value = preset[property_name]
					if property_name in island_generator:
						island_generator.set(property_name, preset[property_name])
			elif control is Dictionary and "property_name" in control:
				# Vector2i control
				var property_name = control["property_name"]
				if property_name in preset:
					var preset_value = preset[property_name]
					if typeof(preset_value) == TYPE_DICTIONARY and "x" in preset_value and "y" in preset_value:
						control["x"].value = preset_value["x"]
						control["y"].value = preset_value["y"]
						if property_name in island_generator:
							island_generator.set(property_name, Vector2i(preset_value["x"], preset_value["y"]))

func save_presets():
	var file = FileAccess.open(preset_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(preset_data))
		file.close()

func load_presets():
	if FileAccess.file_exists(preset_file_path):
		var file = FileAccess.open(preset_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				preset_data = json.data
			else:
				print("Failed to parse presets file!")
	
	refresh_preset_list()

func refresh_preset_list():
	preset_list.clear()
	for preset_name in preset_data.keys():
		preset_list.add_item(preset_name)

# Updated default presets to match new variables
func create_default_presets():
	# Archipelago preset
	preset_data["Archipelago"] = {
		"island_width": 300,
		"island_height": 200,
		"small_pond_count": 15,
		"deep_pond_count": 8,
		"highland_transition": 0.3,
		"water_threshold": 0.15,
		"noise_scale": 0.025,
		"pond_size_variation": {"x": 4, "y": 8},
		"river_meandering": 0.6
	}
	
	# Mountain Island preset  
	preset_data["Mountain Island"] = {
		"island_width": 150,
		"island_height": 100,
		"highland_transition": 0.8,
		"cliff_level_3": 0.9,
		"level3_dirt_percentage": 0.8,
		"deep_pond_count": 3,
		"pond_level3_weight": 8.0,
		"river_meandering": 0.2
	}
	
	# Tropical Paradise preset
	preset_data["Tropical Paradise"] = {
		"island_width": 250,
		"island_height": 150,
		"south_beach_max": 10,
		"side_beach_max": 6,
		"shallow_saltwater_depth": 5,
		"highland_transition": 0.4,
		"level0_dirt_percentage": 0.02,
		"northern_shore_exclusion": 0.1
	}
	
	save_presets()
	refresh_preset_list()

# Add keyboard shortcuts
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space
		_on_generate_pressed()
	elif event.is_action_pressed("ui_cancel"):  # Escape
		visible = not visible
