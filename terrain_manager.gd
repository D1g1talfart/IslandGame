extends Node
class_name TerrainManager

# ============================================================================
# TERRAIN MANAGER - Game Logic Hub for All Terrain Interactions
# ============================================================================

signal terrain_updated
signal resource_spawned(resource_type: String, world_pos: Vector3)
signal environmental_effect_triggered(effect_type: String, area: Array)
signal resource_collected(resource_data: Dictionary, drops: Array)

@export_group("Movement Settings")
@export var enable_movement_costs: bool = true
@export var height_cost_multiplier: float = 1.0

@export_group("Resource Settings") 
@export var enable_resource_spawning: bool = true
@export var resource_spawn_density: float = 0.3
@export var auto_spawn_on_terrain_load: bool = true

@export_group("Environmental Settings")
@export var enable_environmental_effects: bool = true
@export var weather_intensity: float = 1.0

# ============================================================================
# CORE DATA
# ============================================================================

var island_renderer: Island3DRenderer
var current_island_data
var spawned_resources: Array = []
var active_environmental_effects: Dictionary = {}

# Import terrain types from renderer
enum TerrainType {
	DEEP_OCEAN, SHALLOW_SALTWATER, SHALLOW_FRESHWATER, DEEP_FRESHWATER_POND,
	RIVER, RIVER_1, RIVER_2, RIVER_3, RIVER_MOUTH, BEACH,
	LEVEL0_GRASS, LEVEL0_DIRT, LEVEL1_GRASS, LEVEL1_DIRT,
	LEVEL2_GRASS, LEVEL2_DIRT, LEVEL3_GRASS, LEVEL3_DIRT
}

# ============================================================================
# MOVEMENT COST SYSTEM
# ============================================================================

var movement_costs: Dictionary = {
	# Water terrain
	TerrainType.DEEP_OCEAN: 999,  # Impassable
	TerrainType.SHALLOW_SALTWATER: 8,
	TerrainType.SHALLOW_FRESHWATER: 6,
	TerrainType.DEEP_FRESHWATER_POND: 999,  # Impassable
	TerrainType.RIVER: 4,
	TerrainType.RIVER_1: 4,
	TerrainType.RIVER_2: 4,
	TerrainType.RIVER_3: 4,
	TerrainType.RIVER_MOUTH: 6,
	
	# Land terrain - optimized for gameplay
	TerrainType.BEACH: 3,
	TerrainType.LEVEL0_GRASS: 1,  
	TerrainType.LEVEL0_DIRT: 2,
	TerrainType.LEVEL1_GRASS: 1,
	TerrainType.LEVEL1_DIRT: 2,
	TerrainType.LEVEL2_GRASS: 1,  
	TerrainType.LEVEL2_DIRT: 2,
	TerrainType.LEVEL3_GRASS: 1,  
	TerrainType.LEVEL3_DIRT: 2    
}

# ============================================================================
# RESOURCE SPAWN SYSTEM
# ============================================================================

var resource_spawn_rules: Dictionary = {
	TerrainType.LEVEL0_GRASS: [
		{"type": "small_tree", "chance": 0.2, "max_per_tile": 1},
		{"type": "berry_bush", "chance": 0.1, "max_per_tile": 1}
	],
	TerrainType.LEVEL1_GRASS: [
		{"type": "oak_tree", "chance": 0.3, "max_per_tile": 1}, 
		{"type": "stone_small", "chance": 0.15, "max_per_tile": 1}
	],
	TerrainType.LEVEL2_GRASS: [
		{"type": "pine_tree", "chance": 0.4, "max_per_tile": 1},
		{"type": "stone_medium", "chance": 0.2, "max_per_tile": 1}
	],
	TerrainType.LEVEL3_GRASS: [
		{"type": "ancient_tree", "chance": 0.1, "max_per_tile": 1},
		{"type": "crystal_node", "chance": 0.05, "max_per_tile": 1}
	],
	TerrainType.LEVEL3_DIRT: [
		{"type": "crystal_node", "chance": 0.1, "max_per_tile": 1}
	],
	TerrainType.BEACH: [
		{"type": "driftwood", "chance": 0.3, "max_per_tile": 2},
		{"type": "seashell", "chance": 0.4, "max_per_tile": 3}
	],
	TerrainType.SHALLOW_FRESHWATER: [
		{"type": "water_lily", "chance": 0.25, "max_per_tile": 1},
		{"type": "reed", "chance": 1, "max_per_tile": 2}
	]
}

# ============================================================================
# ENVIRONMENTAL EFFECTS SYSTEM
# ============================================================================

var environmental_effects: Dictionary = {
	"ocean_breeze": {
		"terrain_types": [TerrainType.BEACH, TerrainType.SHALLOW_SALTWATER],
		"radius": 3,
		"effects": {"movement_speed": 1.1, "stamina_regen": 1.2}
	},
	"mountain_air": {
		"terrain_types": [TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT],
		"radius": 2, 
		"effects": {"visibility_range": 1.5, "cold_resistance": 0.8}
	},
	"forest_canopy": {
		"terrain_types": [TerrainType.LEVEL1_GRASS, TerrainType.LEVEL2_GRASS],
		"radius": 1,
		"effects": {"shade_bonus": 1.0, "stealth": 1.3}
	},
	"river_sounds": {
		"terrain_types": [TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2],
		"radius": 2,
		"effects": {"stress_reduction": 1.2, "hearing_range": 0.7}
	}
}

# ============================================================================
# INITIALIZATION (FIXED with better debugging)
# ============================================================================

func _ready():
	add_to_group("terrain_manager")
	print("TerrainManager: Starting initialization...")
	
	# Find the island renderer - try multiple ways
	island_renderer = get_node_or_null("../Island3DRenderer") 
	if not island_renderer:
		island_renderer = get_node_or_null("/root/Main/Island3DRenderer")
	if not island_renderer:
		island_renderer = get_tree().get_first_node_in_group("island_3d_renderer")
	
	if island_renderer:
		print("TerrainManager: Found Island3DRenderer at: ", island_renderer.get_path())
		
		# Connect to renderer signals
		if not island_renderer.island_rendered.is_connected(_on_island_rendered):
			island_renderer.island_rendered.connect(_on_island_rendered)
			print("TerrainManager: Connected to island_rendered signal")
		
		# Check if island is already rendered
		if island_renderer.has_island_rendered():
			print("TerrainManager: Island already rendered, initializing immediately")
			call_deferred("initialize_from_island_data")
		else:
			print("TerrainManager: Waiting for island to be rendered...")
	else:
		print("TerrainManager: ERROR - No Island3DRenderer found!")
		print("Available nodes in scene:")
		_debug_print_scene_tree(get_tree().current_scene, 0)

func _debug_print_scene_tree(node: Node, depth: int):
	"""Debug helper to see scene structure"""
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent, "- ", node.name, " (", node.get_script().get_path() if node.get_script() else "no script", ")")
	
	for child in node.get_children():
		_debug_print_scene_tree(child, depth + 1)

func initialize_from_island_data():
	"""Call this after island is rendered - ENHANCED DEBUG VERSION"""
	print("\n=== TERRAIN MANAGER INITIALIZATION ===")
	
	if not island_renderer:
		print("ERROR: No island_renderer reference!")
		return
	
	print("Island renderer found: ", island_renderer.name)
	print("Island renderer has_island_rendered(): ", island_renderer.has_island_rendered())
	
	if not island_renderer.has_island_rendered():
		print("ERROR: Island not rendered yet!")
		return
	
	current_island_data = island_renderer.current_island_data
	
	if not current_island_data:
		print("ERROR: current_island_data is null!")
		print("Trying to access island_renderer.current_island_data...")
		return
	
	print("SUCCESS: Got island data!")
	print("- Island width: ", current_island_data.island_width)
	print("- Island height: ", current_island_data.island_height) 
	print("- Terrain data size: ", current_island_data.terrain_data.size())
	
	# Test a few terrain lookups
	print("- Testing terrain lookups:")
	for test_y in range(min(3, current_island_data.terrain_data.size())):
		for test_x in range(min(3, current_island_data.terrain_data[test_y].size())):
			var terrain_type = current_island_data.terrain_data[test_y][test_x]
			var cost = movement_costs.get(terrain_type, -1)
			print("  Tile[", test_x, ",", test_y, "]: terrain=", terrain_type, " cost=", cost)
	
	if auto_spawn_on_terrain_load:
		spawn_all_resources()
		# NEW: Clean up any issues
		call_deferred("cleanup_invalid_resources")
	
	if enable_environmental_effects:
		initialize_environmental_effects()
	
	print("=== TERRAIN MANAGER READY ===\n")
	terrain_updated.emit()

func _on_island_rendered():
	"""Called when renderer finishes creating the island"""
	print("TerrainManager: Received island_rendered signal!")
	call_deferred("initialize_from_island_data")

# ============================================================================
# MOVEMENT COST API (ENHANCED DEBUG VERSION)
# ============================================================================

func get_movement_cost_at_tile(tile_pos: Vector2i) -> float:
	"""Get movement cost for a specific tile - ENHANCED DEBUG"""
	if not enable_movement_costs:
		if show_terrain_debug:
			print("TerrainManager: Movement costs disabled")
		return 1.0
	
	if not current_island_data:
		if show_terrain_debug:
			print("TerrainManager: No island data - cost = 1.0")
		return 1.0
	
	# Check bounds
	if tile_pos.y < 0 or tile_pos.y >= current_island_data.terrain_data.size() or \
	   tile_pos.x < 0 or tile_pos.x >= current_island_data.terrain_data[tile_pos.y].size():
		if show_terrain_debug:
			print("TerrainManager: Tile out of bounds: ", tile_pos, " - cost = 999")
		return 999
	
	var terrain_type = current_island_data.terrain_data[tile_pos.y][tile_pos.x]
	var cost = movement_costs.get(terrain_type, 1.0)
	
	if show_terrain_debug:
		print("TerrainManager: Tile ", tile_pos, " terrain=", terrain_type, " cost=", cost)
	
	return cost

# Add this debug flag
var show_terrain_debug: bool = false

func toggle_debug():
	"""Toggle terrain manager debug output"""
	show_terrain_debug = !show_terrain_debug
	print("TerrainManager debug: ", "ON" if show_terrain_debug else "OFF")

func get_movement_cost_at_world_pos(world_pos: Vector3) -> float:
	"""Get movement cost for a world position"""
	if not island_renderer:
		return 1.0
	
	var tile_x = int(world_pos.x / island_renderer.tile_size + 0.5)
	var tile_z = int(world_pos.z / island_renderer.tile_size + 0.5)
	return get_movement_cost_at_tile(Vector2i(tile_x, tile_z))

func get_height_cost_modifier(from_tile: Vector2i, to_tile: Vector2i) -> float:
	"""Additional cost for height differences"""
	if not current_island_data or not island_renderer:
		return 0.0
	
	var from_terrain = current_island_data.terrain_data[from_tile.y][from_tile.x]
	var to_terrain = current_island_data.terrain_data[to_tile.y][to_tile.x]
	
	var from_height = island_renderer.get_terrain_level_height(from_terrain, from_tile)
	var to_height = island_renderer.get_terrain_level_height(to_terrain, to_tile)
	
	var height_diff = to_height - from_height
	
	# Going uphill costs extra
	if height_diff > 0:
		return (height_diff / island_renderer.height_scale) * height_cost_multiplier
	else:
		return 0.0  # Downhill is free

func get_total_movement_cost(from_tile: Vector2i, to_tile: Vector2i) -> float:
	"""Get total cost including terrain + height + environmental modifiers"""
	var base_cost = get_movement_cost_at_tile(to_tile)
	var height_cost = get_height_cost_modifier(from_tile, to_tile)
	var env_modifier = get_environmental_movement_modifier(to_tile)
	
	return (base_cost + height_cost) * env_modifier

func can_move_to_tile(tile_pos: Vector2i, max_cost: float = 10.0) -> bool:
	"""Check if a tile is passable"""
	return get_movement_cost_at_tile(tile_pos) <= max_cost

func is_tile_passable(tile_pos: Vector2i) -> bool:
	"""Simple passable check"""
	return get_movement_cost_at_tile(tile_pos) < 999

# ============================================================================
# RESOURCE SPAWNING SYSTEM
# ============================================================================

func spawn_all_resources():
	"""Spawn resources across the entire island"""
	if not current_island_data or not enable_resource_spawning:
		return
	
	print("TerrainManager: Starting resource spawning...")
	clear_all_resources()
	
	var resources_spawned = 0
	
	for y in range(current_island_data.island_height):
		for x in range(current_island_data.island_width):
			if y < current_island_data.terrain_data.size() and x < current_island_data.terrain_data[y].size():
				var terrain_type = current_island_data.terrain_data[y][x]
				var tile_pos = Vector2i(x, y)
				
				resources_spawned += spawn_resources_for_tile(tile_pos, terrain_type)
	
	print("TerrainManager: Spawned ", resources_spawned, " resources")

func spawn_resources_for_tile(tile_pos: Vector2i, terrain_type: int) -> int:
	"""Spawn resources for a single tile"""
	if terrain_type not in resource_spawn_rules:
		return 0
	
	var spawned_count = 0
	var spawn_rules = resource_spawn_rules[terrain_type]
	
	for rule in spawn_rules:
		if randf() < rule.chance * resource_spawn_density:
			var spawn_count = randi_range(1, rule.max_per_tile)
			
			for i in range(spawn_count):
				var resource_pos = tile_to_world_pos_with_offset(tile_pos)
				spawn_resource(rule.type, resource_pos, tile_pos)
				spawned_count += 1
	
	return spawned_count

func spawn_resource(resource_type: String, world_pos: Vector3, tile_pos: Vector2i):
	"""Spawn a single resource at position"""
	var resource_data = {
		"type": resource_type,
		"world_pos": world_pos,
		"tile_pos": tile_pos,
		"spawn_time": Time.get_ticks_msec()
	}
	
	spawned_resources.append(resource_data)
	resource_spawned.emit(resource_type, world_pos)

func tile_to_world_pos_with_offset(tile_pos: Vector2i) -> Vector3:
	"""Convert tile to world position with random offset and proper height"""
	if not island_renderer:
		return Vector3.ZERO
	
	var base_world_pos = Vector3(
		tile_pos.x * island_renderer.tile_size,
		0,
		tile_pos.y * island_renderer.tile_size
	)
	
	# Add random offset within tile
	var offset = Vector3(
		randf_range(-island_renderer.tile_size * 0.3, island_renderer.tile_size * 0.3),
		0,
		randf_range(-island_renderer.tile_size * 0.3, island_renderer.tile_size * 0.3)
	)
	
	base_world_pos += offset
	
	# Get proper terrain height
	var terrain_info = island_renderer.get_terrain_info_at_position(base_world_pos)
	if terrain_info.has("height"):
		base_world_pos.y = terrain_info.height
	
	return base_world_pos

func clear_all_resources():
	"""Clear all spawned resources"""
	spawned_resources.clear()

func get_resources_near_position(world_pos: Vector3, radius: float) -> Array:
	"""Get all resources within radius of position"""
	var nearby_resources = []
	
	for resource in spawned_resources:
		var distance = world_pos.distance_to(resource.world_pos)
		if distance <= radius:
			nearby_resources.append(resource)
	
	return nearby_resources

func get_resources_of_type(resource_type: String) -> Array:
	"""Get all resources of a specific type"""
	var matching_resources = []
	
	for resource in spawned_resources:
		if resource.type == resource_type:
			matching_resources.append(resource)
	
	return matching_resources
	
# ============================================================================
# RESOURCE DROP SYSTEM (NEW)
# ============================================================================

# Define what each resource type drops when collected
var resource_drop_tables: Dictionary = {
	"small_tree": [
		{"item_id": 1, "min": 1, "max": 2, "chance": 1.0}  # Wood
	],
	"oak_tree": [
		{"item_id": 1, "min": 2, "max": 4, "chance": 1.0}  # Wood
	],
	"pine_tree": [
		{"item_id": 1, "min": 3, "max": 5, "chance": 1.0}  # Wood
	],
	"ancient_tree": [
		{"item_id": 1, "min": 4, "max": 8, "chance": 1.0},  # Wood
		{"item_id": 6, "min": 1, "max": 1, "chance": 0.1}   # Rare Seed (add to database)
	],
	"stone_small": [
		{"item_id": 2, "min": 1, "max": 2, "chance": 1.0},  # Stone
		{"item_id": 3, "min": 1, "max": 1, "chance": 0.2}  # Iron
	],
	"stone_medium": [
		{"item_id": 2, "min": 2, "max": 4, "chance": 1.0},  # Stone  
		{"item_id": 3, "min": 1, "max": 1, "chance": 0.5}   # Iron
	],
	"driftwood": [
		{"item_id": 1, "min": 1, "max": 2, "chance": 1.0}   # Wood
	],
	"berry_bush": [
		{"item_id": 4, "min": 2, "max": 5, "chance": 1.0}   # Berries
	],
	"crystal_node": [
		{"item_id": 5, "min": 1, "max": 3, "chance": 1.0},  # Crystal
		{"item_id": 3, "min": 1, "max": 1, "chance": 0.2}   # Iron
	],
	"seashell": [
		{"item_id": 7, "min": 1, "max": 1, "chance": 1.0}   # Shell (add to database)
	],
	"water_lily": [
		{"item_id": 8, "min": 1, "max": 1, "chance": 1.0}   # Lily Pad (add to database)
	],
	"reed": [
		{"item_id": 9, "min": 1, "max": 2, "chance": 1.0}   # Reed (add to database)
	]
}

# UPDATED: Get drops method using IDs
func get_resource_drops(resource_type: String) -> Array:
	var drops = []
	
	if not resource_drop_tables.has(resource_type):
		print("WARNING: No drop table for resource type: ", resource_type)
		return []
	
	var drop_table = resource_drop_tables[resource_type]
	
	for drop_rule in drop_table:
		if randf() <= drop_rule.chance:
			var amount = randi_range(drop_rule.min, drop_rule.max)
			drops.append({
				"item_id": drop_rule.item_id,
				"amount": amount
			})
	
	return drops

func collect_resource(resource_data: Dictionary) -> Array:
	"""Collect a resource and remove it from the world"""
	var drops = get_resource_drops(resource_data.type)
	
	# Remove from spawned resources
	var index = spawned_resources.find(resource_data)
	if index >= 0:
		spawned_resources.remove_at(index)
		print("TerrainManager: Collected ", resource_data.type, " - got ", drops.size(), " drops")
		
		# AUTO-ADD TO INVENTORY (if inventory manager exists)
		var inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
		if not inventory_manager:
			inventory_manager = get_node_or_null("/root/Main/InventoryManager")
		
		if inventory_manager:
			for drop in drops:
				if drop.has("item_id"):
					# Using new ID system
					inventory_manager.add_item_by_id(drop.item_id, drop.amount)
				elif drop.has("item"):
					# Fallback for old system
					inventory_manager.add_item_by_name(drop.item, drop.amount)
		else:
			print("WARNING: No inventory manager found to add drops to")
		
		# Emit signal so visual can be removed
		resource_collected.emit(resource_data, drops)
	else:
		print("WARNING: Tried to collect resource that wasn't found in spawned_resources")
	
	return drops
	
func cleanup_invalid_resources():
	"""Remove any invalid or duplicate resources from the spawned list"""
	var original_count = spawned_resources.size()
	var cleaned_resources = []
	var seen_positions = {}
	
	for resource in spawned_resources:
		# Check if resource data is valid
		if not resource.has("type") or not resource.has("world_pos"):
			print("TerrainManager: Removing invalid resource data")
			continue
		
		# Check for duplicates at same position
		var pos_key = str(resource.world_pos.round())  # Round to avoid floating point issues
		if seen_positions.has(pos_key):
			print("TerrainManager: Removing duplicate resource at ", resource.world_pos)
			continue
		
		seen_positions[pos_key] = true
		cleaned_resources.append(resource)
	
	spawned_resources = cleaned_resources
	var removed_count = original_count - cleaned_resources.size()
	
	if removed_count > 0:
		print("TerrainManager: Cleaned up ", removed_count, " invalid/duplicate resources")

# ============================================================================
# RESOURCE SYNCHRONIZATION (NEW)
# ============================================================================

func sync_with_visual_spawner():
	"""Sync resource data with visual spawner to fix mismatches"""
	var resource_spawner = get_node_or_null("../ResourceSpawner") 
	if not resource_spawner:
		resource_spawner = get_tree().get_first_node_in_group("resource_spawner")
	
	if not resource_spawner:
		print("TerrainManager: No ResourceSpawner found for sync")
		return
	
	print("\n=== SYNCING RESOURCES ===")
	print("Before sync:")
	print("- TerrainManager has ", spawned_resources.size(), " data resources")
	print("- ResourceSpawner has ", resource_spawner.spawned_visual_resources.size(), " visual resources")
	
	# Create data for visual resources that don't have data
	for visual_resource in resource_spawner.spawned_visual_resources:
		var data_exists = false
		
		# Check if we already have data for this visual
		for data_resource in spawned_resources:
			var distance = visual_resource.world_pos.distance_to(data_resource.world_pos)
			if distance < 0.5 and visual_resource.type == data_resource.type:
				data_exists = true
				break
		
		# If no data exists, create it
		if not data_exists:
			print("Creating missing data for visual ", visual_resource.type, " at ", visual_resource.world_pos)
			var tile_pos = world_pos_to_tile_pos(visual_resource.world_pos)
			var resource_data = {
				"type": visual_resource.type,
				"world_pos": visual_resource.world_pos,
				"tile_pos": tile_pos,
				"spawn_time": Time.get_ticks_msec()
			}
			spawned_resources.append(resource_data)
	
	# Remove visuals that don't have data (optional - or we could create data for them)
	var visuals_to_remove = []
	for i in range(resource_spawner.spawned_visual_resources.size() - 1, -1, -1):
		var visual_resource = resource_spawner.spawned_visual_resources[i]
		var has_data = false
		
		for data_resource in spawned_resources:
			var distance = visual_resource.world_pos.distance_to(data_resource.world_pos)
			if distance < 0.5 and visual_resource.type == data_resource.type:
				has_data = true
				break
		
		# Comment out this section if you want to keep visuals and create data instead
		if not has_data:
			visuals_to_remove.append(i)
	
	# Remove orphaned visuals (if wanted)
	for i in visuals_to_remove:
		var visual = resource_spawner.spawned_visual_resources[i]
		if is_instance_valid(visual.visual_node):
			visual.visual_node.queue_free()
		resource_spawner.spawned_visual_resources.remove_at(i)
	
	print("After sync:")
	print("- TerrainManager has ", spawned_resources.size(), " data resources")
	print("- ResourceSpawner has ", resource_spawner.spawned_visual_resources.size(), " visual resources")
	print("=== SYNC COMPLETE ===\n")

func force_full_resync():
	"""Nuclear option - completely rebuild resource system"""
	print("TerrainManager: FULL RESYNC - clearing and rebuilding everything")
	
	# Clear all data
	spawned_resources.clear()
	
	# Clear all visuals
	var resource_spawner = get_node_or_null("../ResourceSpawner") 
	if not resource_spawner:
		resource_spawner = get_tree().get_first_node_in_group("resource_spawner")
	
	if resource_spawner:
		resource_spawner.clear_all_visuals()
	
	# Respawn everything fresh
	spawn_all_resources()
	
	print("TerrainManager: Full resync complete - ", spawned_resources.size(), " resources spawned")
	
# ============================================================================
# ENVIRONMENTAL EFFECTS SYSTEM
# ============================================================================

func initialize_environmental_effects():
	"""Set up environmental effects for the island"""
	if not enable_environmental_effects:
		return
	
	active_environmental_effects.clear()
	print("TerrainManager: Initializing environmental effects...")

func get_environmental_effects_at_position(world_pos: Vector3) -> Dictionary:
	"""Get all environmental effects active at a world position"""
	var tile_pos = world_pos_to_tile_pos(world_pos)
	var effects = {}
	
	if not current_island_data:
		return effects
	
	# Check each environmental effect
	for effect_name in environmental_effects.keys():
		var effect_data = environmental_effects[effect_name]
		
		if is_position_affected_by_environment(tile_pos, effect_data):
			# Merge effects
			for effect_key in effect_data.effects.keys():
				effects[effect_key] = effect_data.effects[effect_key]
	
	return effects

func get_environmental_movement_modifier(tile_pos: Vector2i) -> float:
	"""Get movement speed modifier from environmental effects"""
	if not current_island_data:
		return 1.0
	
	var world_pos = tile_to_world_pos_with_offset(tile_pos)
	var effects = get_environmental_effects_at_position(world_pos)
	
	return effects.get("movement_speed", 1.0)

func is_position_affected_by_environment(tile_pos: Vector2i, effect_data: Dictionary) -> bool:
	"""Check if a position is affected by an environmental effect"""
	var radius = effect_data.radius
	var target_terrain_types = effect_data.terrain_types
	
	# Check in radius around position
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var check_pos = tile_pos + Vector2i(dx, dy)
			
			# Check bounds
			if check_pos.y < 0 or check_pos.y >= current_island_data.terrain_data.size() or \
			   check_pos.x < 0 or check_pos.x >= current_island_data.terrain_data[check_pos.y].size():
				continue
			
			var terrain_type = current_island_data.terrain_data[check_pos.y][check_pos.x]
			
			if terrain_type in target_terrain_types:
				return true
	
	return false

func world_pos_to_tile_pos(world_pos: Vector3) -> Vector2i:
	"""Convert world position to tile position"""
	if not island_renderer:
		return Vector2i.ZERO
	
	var tile_x = int(world_pos.x / island_renderer.tile_size + 0.5)
	var tile_z = int(world_pos.z / island_renderer.tile_size + 0.5)
	return Vector2i(tile_x, tile_z)

# ============================================================================
# PUBLIC QUERY API
# ============================================================================

func get_terrain_type_at_position(world_pos: Vector3) -> int:
	"""Get terrain type at world position"""
	if not island_renderer:
		return -1
	
	var terrain_info = island_renderer.get_terrain_info_at_position(world_pos)
	return terrain_info.get("terrain_type", -1)

func get_biome_info_at_position(world_pos: Vector3) -> Dictionary:
	"""Get complete biome information at position"""
	var tile_pos = world_pos_to_tile_pos(world_pos)
	var terrain_type = get_terrain_type_at_position(world_pos)
	var movement_cost = get_movement_cost_at_world_pos(world_pos)
	var env_effects = get_environmental_effects_at_position(world_pos)
	var nearby_resources = get_resources_near_position(world_pos, island_renderer.tile_size if island_renderer else 1.0)
	
	return {
		"terrain_type": terrain_type,
		"tile_position": tile_pos,
		"world_position": world_pos,
		"movement_cost": movement_cost,
		"environmental_effects": env_effects,
		"nearby_resources": nearby_resources,
		"is_passable": is_tile_passable(tile_pos)
	}

# ============================================================================
# DEBUG AND UTILITIES
# ============================================================================

func print_terrain_stats():
	"""Debug function to print terrain statistics"""
	if not current_island_data:
		print("No terrain data loaded")
		return
	
	print("=== TERRAIN MANAGER STATS ===")
	print("Island size: ", current_island_data.island_width, "x", current_island_data.island_height)
	print("Resources spawned: ", spawned_resources.size())
	print("Environmental effects active: ", environmental_effects.size())
	print("Movement costs enabled: ", enable_movement_costs)

func refresh_all_systems():
	"""Refresh all terrain-based systems"""
	if island_renderer and island_renderer.has_island_rendered():
		initialize_from_island_data()
