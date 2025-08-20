extends CharacterBody3D

@export var speed: float = 20.0
@export var use_terrain_effects: bool = true
@export var show_terrain_debug: bool = true
@export var respect_terrain_movement: bool = true
@export var max_passable_cost: float = 20.0  # Can't move through anything higher

# Terrain integration
var terrain_manager: TerrainManager
var base_speed: float
var current_terrain_effects: Dictionary = {}
var last_terrain_type: int = -1

func _ready():
	print("Player spawned at:", global_position)
	base_speed = speed  # Store original speed
	
	# Find the TerrainManager
	terrain_manager = get_node_or_null("../TerrainManager")
	if not terrain_manager:
		terrain_manager = get_tree().get_first_node_in_group("terrain_manager")
	
	if terrain_manager:
		print("Player: Connected to TerrainManager")
		# Connect to terrain updates if needed
		if terrain_manager.has_signal("terrain_updated"):
			terrain_manager.terrain_updated.connect(_on_terrain_updated)
	else:
		print("Player: No TerrainManager found - terrain effects disabled")
		use_terrain_effects = false
		
	var inventory_manager = $InventoryManager
	if inventory_manager:
		print("Inventory system ready!")
		
	# Create visual collection range indicator
	create_collection_range_indicator()

func create_collection_range_indicator():
	var indicator = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 2.0  # Collection range
	cylinder.bottom_radius = 2.0
	cylinder.height = 0.1
	indicator.mesh = cylinder
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.3
	indicator.material_override = material
	
	indicator.position.y = -0.9  # At ground level
	add_child(indicator)

func _physics_process(delta):
	# Update terrain effects first
	if use_terrain_effects and terrain_manager:
		update_terrain_effects()
	
	# Add gravity first
	if not is_on_floor():
		velocity.y -= 150 * delta
	
	var input_vector = Vector2()
	
	# Get camera for relative movement
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	# WASD movement relative to camera direction
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W):
		input_vector.y += 1
	if Input.is_action_pressed("move_backward") or Input.is_key_pressed(KEY_S):
		input_vector.y -= 1
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		input_vector.x += 1
	
	# JUMP - Multiple input options
	if (Input.is_key_pressed(KEY_SPACE) or 
		Input.is_action_just_pressed("ui_accept")) and is_on_floor():
		
		# Check if we can jump from current terrain
		if respect_terrain_movement and terrain_manager:
			var current_cost = terrain_manager.get_movement_cost_at_world_pos(global_position)
			if current_cost >= 999:
				print("Can't jump - you're drowning in deep water!")
				# Don't jump, maybe apply damage
			else:
				velocity.y = 40
				print("JUMP! Player at:", global_position)
		else:
			velocity.y = 40
			print("JUMP! Player at:", global_position)
	
	# Convert to 3D movement relative to camera
	var horizontal_movement = Vector3()
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		
		# Get camera's horizontal direction
		var cam_forward = -camera.global_transform.basis.z
		var cam_right = camera.global_transform.basis.x
		
		# Flatten to horizontal plane
		cam_forward.y = 0
		cam_right.y = 0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()
		
		horizontal_movement = cam_right * input_vector.x + cam_forward * input_vector.y
		
		# Check if we can move to the target position
		if respect_terrain_movement and terrain_manager:
			var target_position = global_position + horizontal_movement.normalized() * 0.5
			var target_cost = terrain_manager.get_movement_cost_at_world_pos(target_position)
			
			if target_cost >= max_passable_cost:
				print("Can't move there - terrain too difficult!")
				horizontal_movement = Vector3.ZERO  # Block movement
			else:
				# Apply terrain-modified speed
				var final_speed = get_terrain_modified_speed()
				# Apply movement cost as speed reduction
				var cost_modifier = 1.0 / max(1.0, target_cost * 0.5)  # Higher cost = slower
				horizontal_movement *= final_speed * cost_modifier
		else:
			# Apply terrain-modified speed normally
			var final_speed = get_terrain_modified_speed()
			horizontal_movement *= final_speed
	
	# Apply horizontal movement but KEEP existing Y velocity (gravity)
	velocity.x = horizontal_movement.x
	velocity.z = horizontal_movement.z
	
	move_and_slide()

func update_terrain_effects():
	"""Update terrain effects based on current position - FIXED VERSION"""
	if not terrain_manager:
		return
	
	# Only check terrain occasionally, not every frame
	if Engine.get_process_frames() % 10 != 0:  # Only check every 10 frames
		return
	
	# Get current biome info WITHOUT debug spam
	var old_debug_state = terrain_manager.show_terrain_debug
	terrain_manager.show_terrain_debug = false  # Temporarily disable debug
	
	var biome_info = terrain_manager.get_biome_info_at_position(global_position)
	
	terrain_manager.show_terrain_debug = old_debug_state  # Restore debug state
	
	current_terrain_effects = biome_info.environmental_effects
	
	# Debug info when terrain type changes (not every frame!)
	if show_terrain_debug and biome_info.terrain_type != last_terrain_type:
		last_terrain_type = biome_info.terrain_type
		print_terrain_change(biome_info)

func get_terrain_modified_speed() -> float:
	"""Get movement speed modified by terrain effects"""
	if not use_terrain_effects or current_terrain_effects.is_empty():
		return base_speed
	
	var speed_modifier = current_terrain_effects.get("movement_speed", 1.0)
	return base_speed * speed_modifier

func print_terrain_change(biome_info: Dictionary):
	"""Debug print when entering new terrain"""
	var terrain_names = {
		0: "Deep Ocean", 1: "Shallow Saltwater", 2: "Shallow Freshwater", 
		3: "Deep Pond", 4: "River", 5: "River L1", 6: "River L2", 
		7: "River L3", 8: "River Mouth", 9: "Beach",
		10: "Level 0 Grass", 11: "Level 0 Dirt", 12: "Level 1 Grass", 
		13: "Level 1 Dirt", 14: "Level 2 Grass", 15: "Level 2 Dirt",
		16: "Level 3 Grass", 17: "Level 3 Dirt"
	}
	
	var terrain_name = terrain_names.get(biome_info.terrain_type, "Unknown")
	print("=== TERRAIN CHANGE ===")
	print("Now on: ", terrain_name)
	print("Movement cost: ", biome_info.movement_cost)
	print("Passable: ", biome_info.is_passable)
	
	if not biome_info.environmental_effects.is_empty():
		print("Environmental effects:")
		for effect in biome_info.environmental_effects:
			print("  - ", effect, ": ", biome_info.environmental_effects[effect])
	
	if biome_info.nearby_resources.size() > 0:
		print("Nearby resources: ", biome_info.nearby_resources.size())
		for resource in biome_info.nearby_resources:
			print("  - ", resource.type, " at ", resource.world_pos)

func _on_terrain_updated():
	"""Called when terrain manager updates"""
	print("Player: Terrain updated - refreshing effects")

# Debug input
func _input(event):
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_I):
		toggle_terrain_debug()
	
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_O):
		toggle_terrain_effects()
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		debug_terrain_manager_connection()
		
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		try_gather_resource()
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		debug_resource_collection()
	
	# Press T to see what resources the terrain manager thinks are nearby
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		debug_terrain_resources()
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_Y:
		if terrain_manager:
			terrain_manager.sync_with_visual_spawner()
	
	# Press U to force full resync (nuclear option)
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		if terrain_manager:
			terrain_manager.force_full_resync()

func debug_resource_collection():
	"""Debug what resources are nearby and why collection might fail"""
	print("\n=== RESOURCE COLLECTION DEBUG ===")
	print("Player position: ", global_position)
	
	if not terrain_manager:
		print("ERROR: No terrain manager!")
		return
	
	# Check resources in increasing ranges
	var ranges = [1.0, 2.0, 3.0, 5.0, 10.0]
	for range_val in ranges:
		var nearby = terrain_manager.get_resources_near_position(global_position, range_val)
		print("Range ", range_val, "m: ", nearby.size(), " resources")
		
		for resource in nearby:
			var distance = global_position.distance_to(resource.world_pos)
			print("  - ", resource.type, " at ", resource.world_pos, " (", "%.2f" % distance, "m away)")
	
	# Check what the visual spawner thinks
	var resource_spawner = get_node_or_null("../ResourceSpawner")
	if resource_spawner:
		var visual_nearby = resource_spawner.get_resources_near_position(global_position, 5.0)
		print("Visual resources in 5m: ", visual_nearby.size())
		for visual in visual_nearby:
			var distance = global_position.distance_to(visual.world_pos)
			print("  - Visual ", visual.type, " at ", visual.world_pos, " (", "%.2f" % distance, "m away)")

func debug_terrain_resources():
	"""Debug terrain manager resource data"""
	if not terrain_manager:
		return
	
	print("\n=== TERRAIN MANAGER RESOURCE DATA ===")
	print("Total spawned resources: ", terrain_manager.spawned_resources.size())
	
	# Show first few resources
	for i in range(min(5, terrain_manager.spawned_resources.size())):
		var res = terrain_manager.spawned_resources[i]
		var distance = global_position.distance_to(res.world_pos)
		print(i, ": ", res.type, " at ", res.world_pos, " (", "%.2f" % distance, "m away)")

func toggle_terrain_debug():
	"""Toggle terrain debug info"""
	show_terrain_debug = !show_terrain_debug
	print("Terrain debug: ", "ON" if show_terrain_debug else "OFF")

func toggle_terrain_effects():
	"""Toggle terrain effects on/off"""
	use_terrain_effects = !use_terrain_effects
	print("Terrain effects: ", "ON" if use_terrain_effects else "OFF")
	
	# Reset speed when disabling
	if not use_terrain_effects:
		speed = base_speed

# ============================================================================
# TERRAIN QUERY FUNCTIONS (for other systems to use)
# ============================================================================

func get_current_terrain_type() -> int:
	"""Get terrain type at player's current position"""
	if not terrain_manager:
		return -1
	return terrain_manager.get_terrain_type_at_position(global_position)

func get_current_biome_info() -> Dictionary:
	"""Get complete biome info at player's current position"""
	if not terrain_manager:
		return {}
	return terrain_manager.get_biome_info_at_position(global_position)

func can_move_to_position(target_pos: Vector3) -> bool:
	"""Check if player can move to a specific position"""
	if not terrain_manager:
		return true  # Allow movement if no terrain manager
	
	var movement_cost = terrain_manager.get_movement_cost_at_world_pos(target_pos)
	return movement_cost < 999  # 999 = impassable

func get_movement_cost_to_position(target_pos: Vector3) -> float:
	"""Get movement cost to a specific position"""
	if not terrain_manager:
		return 1.0
	return terrain_manager.get_movement_cost_at_world_pos(target_pos)

# ============================================================================
# ADVANCED TERRAIN INTERACTIONS (optional for later)
# ============================================================================

func try_interact_with_resources():
	"""Try to interact with nearby resources"""
	if not terrain_manager:
		return
	
	var nearby_resources = terrain_manager.get_resources_near_position(global_position, 2.0)
	
	if nearby_resources.size() > 0:
		print("Resources in interaction range:")
		for resource in nearby_resources:
			var distance = global_position.distance_to(resource.world_pos)
			print("  - ", resource.type, " (", distance, "m away)")
	else:
		print("No resources nearby")
		
func try_gather_resource():
	"""Gather resources when pressing E - FIXED VERSION"""
	if not terrain_manager:
		print("No terrain manager - can't collect resources")
		return
	
	print("\n--- Attempting to collect resource ---")
	print("Player at: ", global_position)
	
	# Use a more generous search range first
	var search_range = 5.0
	var collect_range = 2.5  # Actual collection range
	
	var nearby_resources = terrain_manager.get_resources_near_position(global_position, search_range)
	print("Found ", nearby_resources.size(), " resources within ", search_range, "m")
	
	if nearby_resources.size() == 0:
		print("No resources found nearby")
		return
	
	# Find closest collectible resource
	var collectible_resources = []
	
	for resource in nearby_resources:
		var distance = global_position.distance_to(resource.world_pos)
		print("Resource ", resource.type, " at distance ", "%.2f" % distance, "m")
		
		if distance <= collect_range:
			collectible_resources.append({
				"resource": resource,
				"distance": distance
			})
	
	if collectible_resources.size() == 0:
		print("No resources within collection range (", collect_range, "m)")
		print("Closest resource is ", "%.2f" % nearby_resources.map(func(r): return global_position.distance_to(r.world_pos)).min(), "m away")
		return
	
	# Sort by distance and take closest
	collectible_resources.sort_custom(func(a, b): return a.distance < b.distance)
	var closest = collectible_resources[0].resource
	
	print("Collecting closest resource: ", closest.type, " at ", "%.2f" % collectible_resources[0].distance, "m")
	
	# Collect it
	var drops = terrain_manager.collect_resource(closest)
	
	# Add to inventory
	var total_items_added = 0
	var items_collected = []
	
	for drop in drops:
		if $InventoryManager.add_item(drop.item, "resource", drop.amount):
			total_items_added += drop.amount
			items_collected.append(str(drop.amount) + " " + drop.item)
		else:
			print("Inventory full - couldn't collect ", drop.item)
	
	if total_items_added > 0:
		print("✓ Successfully collected: ", ", ".join(items_collected))
	else:
		print("✗ Failed to collect anything")

func apply_environmental_damage():
	"""Apply environmental effects like drowning, cold, etc."""
	if not use_terrain_effects or not terrain_manager:
		return
	
	var terrain_type = get_current_terrain_type()
	
	# Example: Drowning in deep water
	if terrain_type == 0 or terrain_type == 3:  # Deep ocean or deep pond
		print("Player is drowning! Need to get to shallow water or land!")
		# Could apply damage here
	
	# Example: Cold at high altitudes
	if terrain_type in [16, 17]:  # Level 3 terrain
		var effects = current_terrain_effects
		if effects.has("cold_resistance") and effects.cold_resistance < 1.0:
			print("It's getting cold up here...")

# Call this from _input if you want resource interaction
func _unhandled_input(event):
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		try_interact_with_resources()
		
func debug_terrain_manager_connection():
	"""Debug the terrain manager connection"""
	print("\n=== PLAYER TERRAIN DEBUG ===")
	
	if not terrain_manager:
		print("ERROR: No terrain_manager reference!")
		print("Trying to find terrain manager...")
		terrain_manager = get_node_or_null("../TerrainManager")
		if terrain_manager:
			print("Found terrain manager at: ", terrain_manager.get_path())
		else:
			print("Still no terrain manager found!")
		return
	
	print("Terrain manager: ", terrain_manager.name)
	print("Current position: ", global_position)
	
	# Toggle terrain manager debug
	terrain_manager.toggle_debug()
	
	# Test movement cost
	var cost = terrain_manager.get_movement_cost_at_world_pos(global_position)
	print("Movement cost at current position: ", cost)
