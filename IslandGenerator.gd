extends Node
class_name IslandDataGenerator

# ============================================================================
# EXPORT VARIABLES - Copy all your @export variables here
# ============================================================================

@export_group("Island Shape & Size")
@export var island_width: int = 200
@export var island_height: int = 120
@export var noise_scale: float = 0.03
@export var cliff_noise_scale: float = 0.01
@export var highland_transition: float = 0.5

@export_group("Elevation Thresholds")
@export var water_threshold: float = 0.1
@export var beach_threshold: float = 0.20
@export var lowland_threshold: float = 0.45
@export var highland_threshold: float = 0.6
@export var cliff_level_2: float = 0.7
@export var cliff_level_3: float = 0.75

@export_group("Terrain Smoothing")
@export var enable_terrain_smoothing: bool = true
@export var fill_interior_water_holes: bool = true
@export var smooth_elevation_spikes: bool = true
@export var smooth_cliff_lines: bool = true
@export var min_patch_size_to_keep: int = 50
@export var smoothing_iterations: int = 2
@export var interior_water_fill_size: int = 100
@export var cliff_smoothing_threshold: int = 5

@export_group("Terrain Distribution")
@export var level0_dirt_percentage: float = 0.05
@export var level1_dirt_percentage: float = 0.15
@export var level2_dirt_percentage: float = 0.30
@export var level3_dirt_percentage: float = 0.45
@export var dirt_grass_noise_scale: float = 0.02

@export_group("Deep Pond Generation")
@export var deep_pond_count: int = 5
@export var pond_size_variation: Vector2i = Vector2i(3, 7)
@export var pond_level3_weight: float = 5.0
@export var pond_level2_weight: float = 3.0
@export var pond_level1_weight: float = 1.0
@export var pond_level0_weight: float = 0.3
@export var pond_detail_scale_large: float = 0.3
@export var pond_detail_scale_medium: float = 0.4
@export var pond_detail_scale_fine: float = 0.8

@export_group("Shallow Pond Generation")
@export var shallow_pond_count: int = 6
@export var shallow_pond_level0_weight: float = 5.0
@export var shallow_pond_level1_weight: float = 3.0
@export var shallow_pond_level2_weight: float = 1.0
@export var shallow_pond_level3_weight: float = 0.2
@export var shallow_pond_size_variation: Vector2i = Vector2i(2, 5)

@export_group("River Generation")
@export var river_meandering: float = 0.4
@export var side_flow_chance: float = 0.3

@export_group("Beach & Coast Generation")
@export var south_beach_min: int = 5
@export var south_beach_max: int = 7
@export var side_beach_min: int = 2
@export var side_beach_max: int = 3
@export var shallow_saltwater_depth: int = 3
@export var northern_shore_exclusion: float = 0.15

# ============================================================================
# SIGNALS AND DATA STRUCTURES
# ============================================================================

signal generation_started
signal generation_progress(step_name: String, progress: float)
signal generation_complete(island_data)
signal island_cleared

enum TerrainType {
	DEEP_OCEAN,
	SHALLOW_SALTWATER, 
	SHALLOW_FRESHWATER,
	DEEP_FRESHWATER_POND,
	RIVER,
	RIVER_1,
	RIVER_2,
	RIVER_3,
	RIVER_MOUTH,
	BEACH,
	LEVEL0_GRASS,
	LEVEL0_DIRT,
	LEVEL1_GRASS,
	LEVEL1_DIRT,
	LEVEL2_GRASS,
	LEVEL2_DIRT,
	LEVEL3_GRASS,
	LEVEL3_DIRT
}

enum WaterType {
	NONE,
	FRESH,
	SALT
}

class IslandData:
	var terrain_data: Array = []
	var height_data: Array = []
	var water_types: Array = []
	var beach_zones: Array = []
	var river_mouths: Array = []
	var deep_ponds: Array = []
	var island_width: int
	var island_height: int
	
	func _init(w: int, h: int):
		island_width = w
		island_height = h
	
	func is_valid() -> bool:
		return terrain_data.size() > 0 and height_data.size() > 0

# ============================================================================
# CORE VARIABLES
# ============================================================================

var noise: FastNoiseLite
var cliff_noise: FastNoiseLite
var dirt_grass_noise: FastNoiseLite
var current_island_data: IslandData
var is_generating: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("island_data_generator")
	setup_noise()
	print("Island Data Generator ready")

func setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = noise_scale
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	cliff_noise = FastNoiseLite.new()
	cliff_noise.seed = randi() + 1000
	cliff_noise.frequency = cliff_noise_scale
	cliff_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	dirt_grass_noise = FastNoiseLite.new()
	dirt_grass_noise.seed = randi() + 2000
	dirt_grass_noise.frequency = dirt_grass_noise_scale
	dirt_grass_noise.noise_type = FastNoiseLite.TYPE_PERLIN

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

func generate_new_island() -> bool:
	if is_generating:
		print("Generation already in progress...")
		return false
	
	is_generating = true
	generation_started.emit()
	
	current_island_data = IslandData.new(island_width, island_height)
	
	await generate_island_data()
	
	is_generating = false
	generation_complete.emit(current_island_data)
	
	print("Island data generation complete!")
	return true

func get_current_island_data() -> IslandData:
	return current_island_data

func has_island_data() -> bool:
	return current_island_data != null and current_island_data.is_valid()

func clear_island_data():
	if current_island_data:
		current_island_data = null
	island_cleared.emit()
	print("Island data cleared")

# ============================================================================
# MAIN GENERATION PIPELINE
# ============================================================================

func generate_island_data():
	print("Starting island data generation...")
	setup_noise()
	initialize_data_arrays()
	
	generation_progress.emit("Generating elevation...", 0.1)
	generate_elevation_with_gradient()
	await get_tree().process_frame
	
	generation_progress.emit("Smoothing terrain...", 0.2)
	smooth_terrain_post_generation()
	await get_tree().process_frame
	
	generation_progress.emit("Setting initial ocean...", 0.3)
	set_initial_ocean_data()
	await get_tree().process_frame
	
	generation_progress.emit("Placing terrain tiles...", 0.4)
	place_all_terrain_data()
	await get_tree().process_frame
	
	generation_progress.emit("Placing deep ponds...", 0.5)
	place_deep_ponds()
	await get_tree().process_frame
	
	generation_progress.emit("Generating rivers...", 0.6)
	generate_rivers_from_ponds()
	await get_tree().process_frame
	
	generation_progress.emit("Creating river mouths...", 0.7)
	create_river_mouths()
	await get_tree().process_frame
	
	generation_progress.emit("Creating beaches...", 0.8)
	create_beaches()
	await get_tree().process_frame
	
	generation_progress.emit("Adding shallow water zones...", 0.9)
	create_shallow_water_zones()
	await get_tree().process_frame
	
	generation_progress.emit("Adding small ponds...", 0.95)
	add_small_freshwater_ponds()
	await get_tree().process_frame
	
	generation_progress.emit("Finalizing island...", 1.0)
	await get_tree().process_frame

func initialize_data_arrays():
	current_island_data.terrain_data.clear()
	current_island_data.height_data.clear()
	current_island_data.water_types.clear()
	current_island_data.beach_zones.clear()
	current_island_data.river_mouths.clear()
	current_island_data.deep_ponds.clear()
	
	for y in range(island_height):
		current_island_data.terrain_data.append([])
		current_island_data.height_data.append([])
		current_island_data.water_types.append([])
		current_island_data.beach_zones.append([])
		
		for x in range(island_width):
			current_island_data.terrain_data[y].append(TerrainType.DEEP_OCEAN)
			current_island_data.height_data[y].append(0.0)
			current_island_data.water_types[y].append(WaterType.NONE)
			current_island_data.beach_zones[y].append(false)

# ============================================================================
# ELEVATION GENERATION
# ============================================================================

func generate_elevation_with_gradient():
	if highland_transition < 0.5:
		highland_transition = 0.65
	
	for y in range(island_height):
		for x in range(island_width):
			var height = calculate_height_with_gradient(x, y)
			current_island_data.height_data[y][x] = height

func calculate_height_with_gradient(x: int, y: int) -> float:
	var noise_value = noise.get_noise_2d(x, y)
	var cliff_noise_value = cliff_noise.get_noise_2d(x, y) * 0.3
	
	var edge_dist_x = min(x, island_width - x) / float(island_width * 0.25)
	var edge_dist_y = min(y, island_height - y) / float(island_height * 0.25)
	var edge_distance = min(edge_dist_x, edge_dist_y)
	
	var island_mask = smoothstep(0.0, 1.0, clamp(edge_distance, 0.0, 1.0))
	
	var combined_noise = (noise_value + cliff_noise_value + 1.0) * 0.4
	var base_height = combined_noise * island_mask
	
	if base_height > water_threshold:
		var north_south_progress = float(y) / float(island_height)
		var elevation_boost = 0.0
		
		if north_south_progress < highland_transition:
			var highland_strength = (highland_transition - north_south_progress) / highland_transition
			elevation_boost = highland_strength * 0.7
			
			if north_south_progress < 0.3:
				elevation_boost += highland_strength * 0.1
		else:
			var lowland_strength = (north_south_progress - highland_transition) / (1.0 - highland_transition)
			elevation_boost = -lowland_strength * 0.3
		
		base_height += elevation_boost
	
	if y < 5:
		var edge_factor = (5.0 - y) / 5.0
		if base_height > water_threshold:
			base_height += edge_factor * 0.3
		else:
			base_height *= (1.0 - edge_factor * 0.5)
	
	return clamp(base_height, 0.0, 1.0)

# ============================================================================
# TERRAIN SMOOTHING
# ============================================================================

func smooth_terrain_post_generation():
	if not enable_terrain_smoothing:
		return
	
	print("Starting terrain smoothing with ", smoothing_iterations, " iterations...")
	
	for iteration in range(smoothing_iterations):
		print("Smoothing iteration ", iteration + 1)
		
		if fill_interior_water_holes:
			fill_interior_water_patches()
		
		if smooth_elevation_spikes:
			smooth_elevation_anomalies()
		
		if smooth_cliff_lines:
			smooth_cliff_transitions()
	
	print("Terrain smoothing complete!")

func fill_interior_water_patches():
	print("Filling interior water holes...")
	
	var ocean_connected = find_ocean_connected_water()
	var interior_patches = find_interior_water_patches_improved(ocean_connected)
	
	var patches_filled = 0
	
	for patch in interior_patches:
		if patch.size() <= interior_water_fill_size:
			fill_water_patch_with_terrain(patch)
			patches_filled += 1
			print("Filled interior water patch of size ", patch.size())
	
	print("Filled ", patches_filled, " interior water patches")

func find_ocean_connected_water() -> Dictionary:
	var ocean_connected = {}
	var to_check = []
	
	for y in range(island_height):
		for x in range(island_width):
			if x == 0 or x == island_width - 1 or y == 0 or y == island_height - 1:
				var height = current_island_data.height_data[y][x]
				if height <= water_threshold:
					var pos_key = str(x) + "," + str(y)
					if pos_key not in ocean_connected:
						ocean_connected[pos_key] = true
						to_check.append(Vector2i(x, y))
	
	while to_check.size() > 0:
		var current_pos = to_check.pop_front()
		
		var neighbors = [
			Vector2i(current_pos.x + 1, current_pos.y),
			Vector2i(current_pos.x - 1, current_pos.y),
			Vector2i(current_pos.x, current_pos.y + 1),
			Vector2i(current_pos.x, current_pos.y - 1)
		]
		
		for neighbor in neighbors:
			if is_valid_position(neighbor):
				var neighbor_key = str(neighbor.x) + "," + str(neighbor.y)
				
				if neighbor_key not in ocean_connected:
					var neighbor_height = current_island_data.height_data[neighbor.y][neighbor.x]
					
					if neighbor_height <= water_threshold or current_island_data.terrain_data[neighbor.y][neighbor.x] == TerrainType.DEEP_OCEAN:
						ocean_connected[neighbor_key] = true
						to_check.append(neighbor)
	
	return ocean_connected

func find_interior_water_patches_improved(ocean_connected: Dictionary) -> Array:
	var interior_patches: Array = []
	var visited = {}
	
	for y in range(island_height):
		for x in range(island_width):
			var pos_key = str(x) + "," + str(y)
			
			if pos_key in visited or pos_key in ocean_connected:
				continue
			
			var height = current_island_data.height_data[y][x]
			
			if height > water_threshold:
				continue
			
			var patch = flood_fill_interior_water_patch(Vector2i(x, y), visited, ocean_connected)
			
			if patch.size() > 0:
				print("Found interior water patch of size ", patch.size(), " at ", Vector2i(x, y))
				interior_patches.append(patch)
	
	return interior_patches

func flood_fill_interior_water_patch(start_pos: Vector2i, visited: Dictionary, ocean_connected: Dictionary) -> Array[Vector2i]:
	var patch: Array[Vector2i] = []
	var to_check = [start_pos]
	
	while to_check.size() > 0:
		var current_pos = to_check.pop_front()
		var pos_key = str(current_pos.x) + "," + str(current_pos.y)
		
		if pos_key in visited or not is_valid_position(current_pos):
			continue
		
		if pos_key in ocean_connected:
			continue
		
		var height = current_island_data.height_data[current_pos.y][current_pos.x]
		
		if height > water_threshold:
			continue
		
		visited[pos_key] = true
		patch.append(current_pos)
		
		var neighbors = [
			Vector2i(current_pos.x + 1, current_pos.y),
			Vector2i(current_pos.x - 1, current_pos.y),
			Vector2i(current_pos.x, current_pos.y + 1),
			Vector2i(current_pos.x, current_pos.y - 1)
		]
		
		for neighbor in neighbors:
			var neighbor_key = str(neighbor.x) + "," + str(neighbor.y)
			if neighbor_key not in visited:
				to_check.append(neighbor)
	
	return patch

func fill_water_patch_with_terrain(patch: Array[Vector2i]):
	var surrounding_levels = {}
	var total_surrounding_height = 0.0
	var surrounding_count = 0
	
	for pos in patch:
		var neighbors = [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1)
		]
		
		for neighbor in neighbors:
			if is_valid_position(neighbor):
				var neighbor_height = current_island_data.height_data[neighbor.y][neighbor.x]
				
				if neighbor_height > water_threshold:
					var level = get_elevation_level(neighbor_height)
					if level in surrounding_levels:
						surrounding_levels[level] += 1
					else:
						surrounding_levels[level] = 1
					
					total_surrounding_height += neighbor_height
					surrounding_count += 1
	
	var target_level = 0
	var max_count = 0
	
	for level in surrounding_levels.keys():
		if surrounding_levels[level] > max_count:
			max_count = surrounding_levels[level]
			target_level = level
	
	var fill_height = calculate_height_for_level(target_level)
	
	for pos in patch:
		current_island_data.height_data[pos.y][pos.x] = fill_height + randf_range(-0.02, 0.02)

func smooth_elevation_anomalies():
	print("Smoothing elevation anomalies...")
	
	var changes_made = 0
	var elevation_patches = find_small_elevation_patches()
	
	for patch_data in elevation_patches:
		var patch = patch_data.positions
		var target_level = patch_data.target_level
		
		if patch.size() < min_patch_size_to_keep:
			smooth_elevation_patch_to_level(patch, target_level)
			changes_made += 1
	
	print("Smoothed ", changes_made, " small elevation patches")

func find_small_elevation_patches() -> Array[Dictionary]:
	var elevation_patches: Array[Dictionary] = []
	var visited = {}
	
	for y in range(1, island_height - 1):
		for x in range(1, island_width - 1):
			var pos_key = str(x) + "," + str(y)
			
			if pos_key in visited:
				continue
			
			var current_height = current_island_data.height_data[y][x]
			
			if current_height <= water_threshold:
				continue
			
			var current_level = get_elevation_level(current_height)
			
			var patch = flood_fill_elevation_patch(Vector2i(x, y), current_level, visited)
			
			if patch.size() > 0 and patch.size() < min_patch_size_to_keep:
				var target_level = determine_smoothing_target_level(patch, current_level)
				
				elevation_patches.append({
					"positions": patch,
					"current_level": current_level,
					"target_level": target_level
				})
	
	return elevation_patches

func flood_fill_elevation_patch(start_pos: Vector2i, target_level: int, visited: Dictionary) -> Array[Vector2i]:
	var patch: Array[Vector2i] = []
	var to_check = [start_pos]
	
	while to_check.size() > 0:
		var current_pos = to_check.pop_front()
		var pos_key = str(current_pos.x) + "," + str(current_pos.y)
		
		if pos_key in visited or not is_valid_position(current_pos):
			continue
		
		var height = current_island_data.height_data[current_pos.y][current_pos.x]
		var level = get_elevation_level(height)
		
		if level != target_level or height <= water_threshold:
			continue
		
		visited[pos_key] = true
		patch.append(current_pos)
		
		var neighbors = [
			Vector2i(current_pos.x + 1, current_pos.y),
			Vector2i(current_pos.x - 1, current_pos.y),
			Vector2i(current_pos.x, current_pos.y + 1),
			Vector2i(current_pos.x, current_pos.y - 1)
		]
		
		for neighbor in neighbors:
			var neighbor_key = str(neighbor.x) + "," + str(neighbor.y)
			if neighbor_key not in visited:
				to_check.append(neighbor)
	
	return patch

func determine_smoothing_target_level(patch: Array[Vector2i], current_level: int) -> int:
	var surrounding_levels = {}
	
	for pos in patch:
		var neighbors = [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1),
			Vector2i(pos.x + 1, pos.y + 1),
			Vector2i(pos.x - 1, pos.y + 1),
			Vector2i(pos.x + 1, pos.y - 1),
			Vector2i(pos.x - 1, pos.y - 1)
		]
		
		for neighbor in neighbors:
			if is_valid_position(neighbor):
				var neighbor_height = current_island_data.height_data[neighbor.y][neighbor.x]
				
				if neighbor_height > water_threshold:
					var level = get_elevation_level(neighbor_height)
					
					var is_part_of_patch = false
					for patch_pos in patch:
						if neighbor == patch_pos:
							is_part_of_patch = true
							break
					
					if not is_part_of_patch:
						if level in surrounding_levels:
							surrounding_levels[level] += 1
						else:
							surrounding_levels[level] = 1
	
	var target_level = current_level
	var max_count = 0
	
	for level in surrounding_levels.keys():
		if surrounding_levels[level] > max_count:
			max_count = surrounding_levels[level]
			target_level = level
	
	return target_level

func smooth_elevation_patch_to_level(patch: Array[Vector2i], target_level: int):
	var target_height = calculate_height_for_level(target_level)
	
	for pos in patch:
		var height_variation = randf_range(-0.03, 0.03)
		current_island_data.height_data[pos.y][pos.x] = target_height + height_variation

func smooth_cliff_transitions():
	print("Smoothing cliff transitions...")
	
	var changes_made = 0
	var tiles_to_adjust: Array[Dictionary] = []
	
	for y in range(1, island_height - 1):
		for x in range(1, island_width - 1):
			var current_height = current_island_data.height_data[y][x]
			
			if current_height <= water_threshold:
				continue
			
			var current_level = get_elevation_level(current_height)
			var adjustment_data = should_adjust_for_cliff_smoothing(Vector2i(x, y), current_level)
			
			if adjustment_data.should_adjust:
				tiles_to_adjust.append({
					"position": Vector2i(x, y),
					"current_level": current_level,
					"target_level": adjustment_data.target_level,
					"surrounding_count": adjustment_data.surrounding_count
				})
	
	for adjustment in tiles_to_adjust:
		var pos = adjustment.position
		var target_level = adjustment.target_level
		var new_height = calculate_height_for_level(target_level)
		
		var height_variation = randf_range(-0.02, 0.02)
		current_island_data.height_data[pos.y][pos.x] = new_height + height_variation
		
		changes_made += 1
	
	print("Smoothed ", changes_made, " cliff transition tiles")

func should_adjust_for_cliff_smoothing(pos: Vector2i, current_level: int) -> Dictionary:
	var neighbors = [
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1),
		Vector2i(pos.x + 1, pos.y + 1),
		Vector2i(pos.x - 1, pos.y + 1),
		Vector2i(pos.x + 1, pos.y - 1),
		Vector2i(pos.x - 1, pos.y - 1)
	]
	
	var level_counts = {}
	var valid_neighbors = 0
	
	for neighbor in neighbors:
		if is_valid_position(neighbor):
			var neighbor_height = current_island_data.height_data[neighbor.y][neighbor.x]
			
			if neighbor_height > water_threshold:
				var neighbor_level = get_elevation_level(neighbor_height)
				
				if neighbor_level in level_counts:
					level_counts[neighbor_level] += 1
				else:
					level_counts[neighbor_level] = 1
				
				valid_neighbors += 1
	
	var dominant_level = current_level
	var max_count = 0
	
	for level in level_counts.keys():
		if level_counts[level] > max_count:
			max_count = level_counts[level]
			dominant_level = level
	
	var should_adjust = false
	
	if dominant_level != current_level and max_count >= cliff_smoothing_threshold:
		should_adjust = true
	
	var current_level_count = 0
	if current_level in level_counts:
		current_level_count = level_counts[current_level]
	
	if current_level_count <= 1 and max_count >= 2:
		should_adjust = true
	
	return {
		"should_adjust": should_adjust,
		"target_level": dominant_level,
		"surrounding_count": max_count,
		"current_level_count": current_level_count
	}

# ============================================================================
# TERRAIN PLACEMENT
# ============================================================================

func set_initial_ocean_data():
	for y in range(island_height):
		for x in range(island_width):
			var height = current_island_data.height_data[y][x]
			if height <= water_threshold:
				current_island_data.terrain_data[y][x] = TerrainType.DEEP_OCEAN
				current_island_data.water_types[y][x] = WaterType.SALT

func place_all_terrain_data():
	for y in range(island_height):
		for x in range(island_width):
			var height = current_island_data.height_data[y][x]
			var current_terrain = current_island_data.terrain_data[y][x]

			if current_terrain == TerrainType.DEEP_OCEAN and height > water_threshold:
				var new_terrain = determine_land_terrain_type(x, y, height)
				current_island_data.terrain_data[y][x] = new_terrain

func determine_land_terrain_type(x: int, y: int, height: float) -> TerrainType:
	var elevation_level = get_elevation_level(height)
	
	var dirt_noise = dirt_grass_noise.get_noise_2d(x, y)
	var normalized_noise = (dirt_noise + 1.0) / 2.0
	
	var dirt_percentage: float
	match elevation_level:
		0: dirt_percentage = level0_dirt_percentage
		1: dirt_percentage = level1_dirt_percentage
		2: dirt_percentage = level2_dirt_percentage
		3: dirt_percentage = level3_dirt_percentage
		_: dirt_percentage = level0_dirt_percentage
	
	var should_be_dirt = normalized_noise > (1.0 - dirt_percentage)
	
	match elevation_level:
		0:
			return TerrainType.LEVEL0_DIRT if should_be_dirt else TerrainType.LEVEL0_GRASS
		1:
			return TerrainType.LEVEL1_DIRT if should_be_dirt else TerrainType.LEVEL1_GRASS
		2:
			return TerrainType.LEVEL2_DIRT if should_be_dirt else TerrainType.LEVEL2_GRASS
		3:
			return TerrainType.LEVEL3_DIRT if should_be_dirt else TerrainType.LEVEL3_GRASS
		_:
			return TerrainType.LEVEL0_GRASS

# ============================================================================
# POND GENERATION
# ============================================================================

func place_deep_ponds():
	print("Placing deep ponds on elevated terrain...")
	
	var elevation_weights = {
		3: pond_level3_weight,
		2: pond_level2_weight,
		1: pond_level1_weight,
		0: pond_level0_weight
	}
	
	for i in range(deep_pond_count):
		var pond_placed = false
		var attempts = 0
		
		while not pond_placed and attempts < 100:
			var target_level = select_weighted_elevation_level(elevation_weights)
			var pond_pos = find_suitable_pond_location(target_level, i)
			
			if pond_pos != Vector2i(-1, -1):
				create_deep_pond_at_terrain_level(pond_pos.x, pond_pos.y)
				current_island_data.deep_ponds.append(pond_pos)
				pond_placed = true
				print("Placed pond at level ", target_level, " position: ", pond_pos)
			
			attempts += 1
		
		if not pond_placed:
			print("Failed to place pond ", i)

func select_weighted_elevation_level(weights: Dictionary) -> int:
	if randf() < 0.0:
		return randi_range(0, 3)
	
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for level in [3, 2, 1, 0]:
		current_weight += weights[level]
		if random_value <= current_weight:
			return level
	
	return 2

func find_suitable_pond_location(target_level: int, pond_index: int = -1) -> Vector2i:
	var num_zones = 5
	var zone_width = island_width / num_zones
	
	var preferred_zones = []
	if pond_index >= 0:
		var preferred_zone = pond_index % num_zones
		preferred_zones = [preferred_zone]
		
		for i in range(num_zones):
			if i != preferred_zone:
				preferred_zones.append(i)
	else:
		preferred_zones = [0, 1, 2, 3, 4]
		preferred_zones.shuffle()
	
	for zone in preferred_zones:
		var zone_start_x = int(zone * zone_width) + 8
		var zone_end_x = int((zone + 1) * zone_width) - 8
		zone_end_x = min(zone_end_x, island_width - 8)
		
		var attempts = 0
		while attempts < 20:
			var pond_x = randi_range(zone_start_x, zone_end_x)
			var pond_y = randi_range(8, island_height - 8)
			
			if can_place_deep_pond_at_level(pond_x, pond_y, target_level):
				print("Placed pond in zone ", zone, " at ", Vector2i(pond_x, pond_y))
				return Vector2i(pond_x, pond_y)
			
			attempts += 1
	
	return Vector2i(-1, -1)

func can_place_deep_pond_at_level(center_x: int, center_y: int, target_level: int) -> bool:
	var pond_radius = randi_range(3, 6)
	var buffer_zone = 3
	
	var check_radius = pond_radius + buffer_zone
	
	for dy in range(-check_radius, check_radius + 1):
		for dx in range(-check_radius, check_radius + 1):
			var x = center_x + dx
			var y = center_y + dy
			
			if not is_valid_position(Vector2i(x, y)):
				return false
			
			var height = current_island_data.height_data[y][x]
			var elevation_level = get_elevation_level(height)
			
			if elevation_level != target_level:
				return false
			
			if height <= water_threshold:
				return false
			
			var terrain = current_island_data.terrain_data[y][x]
			if terrain in [
				TerrainType.DEEP_FRESHWATER_POND,
				TerrainType.RIVER,
				TerrainType.RIVER_1,
				TerrainType.RIVER_2,
				TerrainType.RIVER_3,
				TerrainType.SHALLOW_FRESHWATER
			]:
				return false
	
	for existing_pond in current_island_data.deep_ponds:
		var distance = sqrt((center_x - existing_pond.x) ** 2 + (center_y - existing_pond.y) ** 2)
		if distance < (pond_radius + buffer_zone + 5):
			return false
	
	return true

func create_deep_pond_at_terrain_level(center_x: int, center_y: int):
	var base_height = current_island_data.height_data[center_y][center_x]
	var terrain_level = get_elevation_level(base_height)
	
	var pond_height = calculate_pond_height_for_level(terrain_level)
	
	var base_radius = randi_range(pond_size_variation.x, pond_size_variation.y)
	var pond_shape = generate_organic_pond_shape(center_x, center_y, base_radius)
	
	for pos in pond_shape:
		if is_valid_position(pos):
			var tile_level = get_elevation_level(current_island_data.height_data[pos.y][pos.x])
			if tile_level == terrain_level:
				current_island_data.terrain_data[pos.y][pos.x] = TerrainType.DEEP_FRESHWATER_POND
				current_island_data.water_types[pos.y][pos.x] = WaterType.FRESH
				current_island_data.height_data[pos.y][pos.x] = pond_height

func generate_organic_pond_shape(center_x: int, center_y: int, base_radius: int) -> Array[Vector2i]:
	var pond_tiles: Array[Vector2i] = []
	var max_radius = base_radius + 3
	
	var detail_scale1 = pond_detail_scale_large
	var detail_scale2 = pond_detail_scale_medium
	var detail_scale3 = pond_detail_scale_fine
	
	var pond_seed_offset = randi_range(0, 10000)
	
	for dy in range(-max_radius, max_radius + 1):
		for dx in range(-max_radius, max_radius + 1):
			var x = center_x + dx
			var y = center_y + dy
			
			if not is_valid_position(Vector2i(x, y)):
				continue
			
			var distance = sqrt(dx * dx + dy * dy)
			
			if distance > max_radius:
				continue
			
			var noise_x = (x + pond_seed_offset) 
			var noise_y = (y + pond_seed_offset)
			
			var noise1 = dirt_grass_noise.get_noise_2d(noise_x * detail_scale1, noise_y * detail_scale1)
			var noise2 = cliff_noise.get_noise_2d(noise_x * detail_scale2, noise_y * detail_scale2)
			var noise3 = noise.get_noise_2d(noise_x * detail_scale3, noise_y * detail_scale3)
			
			var combined_noise = (noise1 * 0.6) + (noise2 * 0.3) + (noise3 * 0.1)
			
			var normalized_distance = distance / float(base_radius)
			
			var shape_threshold = 1.0 - normalized_distance + (combined_noise * 0.7)
			
			var erosion_noise = dirt_grass_noise.get_noise_2d(noise_x * 0.6, noise_y * 0.6)
			if erosion_noise > 0.3:
				shape_threshold += 0.3
			elif erosion_noise < -0.4:
				shape_threshold -= 0.4
			
			var final_threshold = 0.2 + (randf() * 0.1)
			
			if shape_threshold > final_threshold:
				if distance < base_radius * 0.3 and randf() < 0.05:
					continue
				
				pond_tiles.append(Vector2i(x, y))
	
	if pond_tiles.size() < 6:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var pos = Vector2i(center_x + dx, center_y + dy)
				if is_valid_position(pos) and pos not in pond_tiles:
					pond_tiles.append(pos)
	
	return pond_tiles

func add_small_freshwater_ponds():
	print("Placing shallow freshwater ponds on lower terrain...")
	
	var elevation_weights = {
		0: shallow_pond_level0_weight,
		1: shallow_pond_level1_weight,
		2: shallow_pond_level2_weight,
		3: shallow_pond_level3_weight
	}
	
	var shallow_ponds_placed = 0
	
	for i in range(shallow_pond_count):
		var pond_placed = false
		var attempts = 0
		
		while not pond_placed and attempts < 100:
			var target_level = select_weighted_elevation_level_for_shallow(elevation_weights)
			var pond_pos = find_suitable_shallow_pond_location(target_level)
			
			if pond_pos != Vector2i(-1, -1):
				create_shallow_pond_at_terrain_level(pond_pos.x, pond_pos.y)
				pond_placed = true
				shallow_ponds_placed += 1
				print("Placed shallow pond at level ", target_level, " position: ", pond_pos)
			
			attempts += 1
		
		if not pond_placed:
			print("Failed to place shallow pond ", i)
	
	print("Successfully placed ", shallow_ponds_placed, " shallow ponds")

func select_weighted_elevation_level_for_shallow(weights: Dictionary) -> int:
	if randf() < 0.1:
		return randi_range(0, 2)
	
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for level in [0, 1, 2, 3]:
		current_weight += weights[level]
		if random_value <= current_weight:
			return level
	
	return 0

func find_suitable_shallow_pond_location(target_level: int) -> Vector2i:
	var attempts = 0
	
	while attempts < 50:
		var pond_x = randi_range(6, island_width - 6)
		var pond_y = randi_range(6, island_height - 6)
		
		if can_place_shallow_pond_at_level(pond_x, pond_y, target_level):
			return Vector2i(pond_x, pond_y)
		
		attempts += 1
	
	return Vector2i(-1, -1)

func can_place_shallow_pond_at_level(center_x: int, center_y: int, target_level: int) -> bool:
	var pond_radius = randi_range(2, 4)
	var buffer_zone = 2
	
	var check_radius = pond_radius + buffer_zone
	
	for dy in range(-check_radius, check_radius + 1):
		for dx in range(-check_radius, check_radius + 1):
			var x = center_x + dx
			var y = center_y + dy
			
			if not is_valid_position(Vector2i(x, y)):
				return false
			
			var height = current_island_data.height_data[y][x]
			var elevation_level = get_elevation_level(height)
			
			if elevation_level != target_level:
				return false
			
			if height <= water_threshold:
				return false
			
			var terrain = current_island_data.terrain_data[y][x]
			if terrain in [
				TerrainType.DEEP_FRESHWATER_POND,
				TerrainType.SHALLOW_FRESHWATER,
				TerrainType.RIVER,
				TerrainType.RIVER_1,
				TerrainType.RIVER_2,
				TerrainType.RIVER_3,
				TerrainType.RIVER_MOUTH,
				TerrainType.DEEP_OCEAN,
				TerrainType.SHALLOW_SALTWATER
			]:
				return false
	
	for existing_pond in current_island_data.deep_ponds:
		var distance = sqrt((center_x - existing_pond.x) ** 2 + (center_y - existing_pond.y) ** 2)
		if distance < 8:
			return false
	
	return true

func create_shallow_pond_at_terrain_level(center_x: int, center_y: int):
	var base_height = current_island_data.height_data[center_y][center_x]
	var terrain_level = get_elevation_level(base_height)
	
	var pond_height = water_threshold + 0.01
	
	var base_radius = randi_range(shallow_pond_size_variation.x, shallow_pond_size_variation.y)
	var pond_shape = generate_organic_shallow_pond_shape(center_x, center_y, base_radius)
	
	for pos in pond_shape:
		if is_valid_position(pos):
			var tile_level = get_elevation_level(current_island_data.height_data[pos.y][pos.x])
			var current_terrain = current_island_data.terrain_data[pos.y][pos.x]
			
			if tile_level == terrain_level and current_terrain in [
				TerrainType.LEVEL0_GRASS, TerrainType.LEVEL0_DIRT,
				TerrainType.LEVEL1_GRASS, TerrainType.LEVEL1_DIRT,
				TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT,
				TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT
			]:
				current_island_data.terrain_data[pos.y][pos.x] = TerrainType.SHALLOW_FRESHWATER
				current_island_data.water_types[pos.y][pos.x] = WaterType.FRESH
				current_island_data.height_data[pos.y][pos.x] = pond_height

func generate_organic_shallow_pond_shape(center_x: int, center_y: int, base_radius: int) -> Array[Vector2i]:
	var pond_tiles: Array[Vector2i] = []
	var max_radius = base_radius + 2
	
	var detail_scale1 = pond_detail_scale_large * 1.5
	var detail_scale2 = pond_detail_scale_medium * 1.5
	var detail_scale3 = pond_detail_scale_fine * 1.5
	
	var pond_seed_offset = randi_range(0, 10000)
	
	for dy in range(-max_radius, max_radius + 1):
		for dx in range(-max_radius, max_radius + 1):
			var x = center_x + dx
			var y = center_y + dy
			
			if not is_valid_position(Vector2i(x, y)):
				continue
			
			var distance = sqrt(dx * dx + dy * dy)
			
			if distance > max_radius:
				continue
			
			var noise_x = (x + pond_seed_offset) 
			var noise_y = (y + pond_seed_offset)
			
			var noise1 = dirt_grass_noise.get_noise_2d(noise_x * detail_scale1, noise_y * detail_scale1)
			var noise2 = cliff_noise.get_noise_2d(noise_x * detail_scale2, noise_y * detail_scale2)
			var noise3 = noise.get_noise_2d(noise_x * detail_scale3, noise_y * detail_scale3)
			
			var combined_noise = (noise1 * 0.5) + (noise2 * 0.3) + (noise3 * 0.2)
			
			var normalized_distance = distance / float(base_radius)
			
			var shape_threshold = 1.0 - normalized_distance + (combined_noise * 0.5)
			
			var erosion_noise = dirt_grass_noise.get_noise_2d(noise_x * 0.8, noise_y * 0.8)
			if erosion_noise > 0.4:
				shape_threshold += 0.2
			elif erosion_noise < -0.5:
				shape_threshold -= 0.3
			
			var final_threshold = 0.3 + (randf() * 0.1)
			
			if shape_threshold > final_threshold:
				pond_tiles.append(Vector2i(x, y))
	
	if pond_tiles.size() < 4:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var pos = Vector2i(center_x + dx, center_y + dy)
				if is_valid_position(pos) and pos not in pond_tiles:
					pond_tiles.append(pos)
	
	return pond_tiles

# ============================================================================
# RIVER GENERATION
# ============================================================================

func generate_rivers_from_ponds():
	print("Generating rivers from highland ponds...")
	print("Found ", current_island_data.deep_ponds.size(), " deep ponds")
	
	var rivers_created = 0
	
	for i in range(current_island_data.deep_ponds.size()):
		var pond_pos = current_island_data.deep_ponds[i]
		var pond_level = get_elevation_level(current_island_data.height_data[pond_pos.y][pond_pos.x])
		
		print("Pond ", i, " at ", pond_pos, " is level ", pond_level)
		
		if pond_level >= -1:
			if generate_simple_river(pond_pos):
				rivers_created += 1
				print("Successfully created river from pond at ", pond_pos)
			else:
				print("Failed to create river from pond at ", pond_pos)
	
	print("Created ", rivers_created, " rivers from ", current_island_data.deep_ponds.size(), " ponds")

func generate_simple_river(pond_pos: Vector2i) -> bool:
	print("Creating river from pond at ", pond_pos)
	
	var river_start = find_pond_exit(pond_pos)
	if river_start == Vector2i(-1, -1):
		print("Could not find pond exit")
		return false
	
	print("Starting river at: ", river_start)
	
	var path: Array[Vector2i] = [river_start]
	var current_pos = river_start
	var current_level = get_elevation_level(current_island_data.height_data[current_pos.y][current_pos.x])
	
	for step in range(200):
		var next_pos = find_next_river_step(current_pos, current_level, path)
		
		if next_pos == Vector2i(-1, -1):
			print("River stuck at ", current_pos, " - looking for connection...")
			var connection = find_nearest_connection(current_pos, path)
			if connection != Vector2i(-1, -1):
				path.append(connection)
				place_river_path(path)
				print("River connected via emergency connection")
				return true
			else:
				print("No valid connection found - abandoning river")
				return false
		
		path.append(next_pos)
		
		if is_valid_river_endpoint(next_pos):
			place_river_path(path)
			print("River completed with ", path.size(), " tiles")
			return true
		
		current_pos = next_pos
		var next_level = get_elevation_level(current_island_data.height_data[next_pos.y][next_pos.x])
		current_level = min(current_level, next_level)
	
	print("River too long - abandoning")
	return false

func find_pond_exit(pond_center: Vector2i) -> Vector2i:
	print("Finding pond exit for center at: ", pond_center)
	
	var actual_pond_tiles = find_connected_pond_tiles(pond_center)
	
	if actual_pond_tiles.size() == 0:
		print("No pond tiles found near center ", pond_center)
		return Vector2i(-1, -1)
	
	print("Found ", actual_pond_tiles.size(), " connected pond tiles")
	
	var perimeter_positions = find_pond_perimeter_positions(actual_pond_tiles)
	
	if perimeter_positions.size() == 0:
		print("No perimeter positions found")
		return Vector2i(-1, -1)
	
	print("Found ", perimeter_positions.size(), " perimeter positions")
	
	var valid_starts = filter_valid_river_starts(perimeter_positions, pond_center)
	
	if valid_starts.size() == 0:
		print("No valid river start positions found")
		return Vector2i(-1, -1)
	
	print("Found ", valid_starts.size(), " valid river start positions")
	
	return select_best_river_start(valid_starts, pond_center)

func find_connected_pond_tiles(start_pos: Vector2i) -> Array[Vector2i]:
	var pond_tiles: Array[Vector2i] = []
	var visited = {}
	var to_check = []
	
	var search_positions = [
		start_pos,
		start_pos + Vector2i(1, 0), start_pos + Vector2i(-1, 0),
		start_pos + Vector2i(0, 1), start_pos + Vector2i(0, -1),
		start_pos + Vector2i(1, 1), start_pos + Vector2i(-1, -1),
		start_pos + Vector2i(1, -1), start_pos + Vector2i(-1, 1)
	]
	
	var first_pond_tile = Vector2i(-1, -1)
	for search_pos in search_positions:
		if is_valid_position(search_pos):
			if current_island_data.terrain_data[search_pos.y][search_pos.x] == TerrainType.DEEP_FRESHWATER_POND:
				first_pond_tile = search_pos
				break
	
	if first_pond_tile == Vector2i(-1, -1):
		return pond_tiles
	
	to_check.append(first_pond_tile)
	
	while to_check.size() > 0:
		var current_pos = to_check.pop_front()
		var pos_key = str(current_pos.x) + "," + str(current_pos.y)
		
		if pos_key in visited or not is_valid_position(current_pos):
			continue
		
		if current_island_data.terrain_data[current_pos.y][current_pos.x] != TerrainType.DEEP_FRESHWATER_POND:
			continue
		
		visited[pos_key] = true
		pond_tiles.append(current_pos)
		
		var neighbors = [
			Vector2i(current_pos.x + 1, current_pos.y),
			Vector2i(current_pos.x - 1, current_pos.y),
			Vector2i(current_pos.x, current_pos.y + 1),
			Vector2i(current_pos.x, current_pos.y - 1)
		]
		
		for neighbor in neighbors:
			var neighbor_key = str(neighbor.x) + "," + str(neighbor.y)
			if neighbor_key not in visited:
				to_check.append(neighbor)
	
	return pond_tiles

func find_pond_perimeter_positions(pond_tiles: Array[Vector2i]) -> Array[Vector2i]:
	var perimeter_positions: Array[Vector2i] = []
	var checked_positions = {}
	
	for pond_tile in pond_tiles:
		var directions = [
			Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
		]
		
		for direction in directions:
			var adjacent_pos = pond_tile + direction
			var pos_key = str(adjacent_pos.x) + "," + str(adjacent_pos.y)
			
			if pos_key in checked_positions or not is_valid_position(adjacent_pos):
				continue
			
			checked_positions[pos_key] = true
			
			var terrain = current_island_data.terrain_data[adjacent_pos.y][adjacent_pos.x]
			
			if terrain in [
				TerrainType.LEVEL0_GRASS, TerrainType.LEVEL0_DIRT,
				TerrainType.LEVEL1_GRASS, TerrainType.LEVEL1_DIRT,
				TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT,
				TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT
			]:
				perimeter_positions.append(adjacent_pos)
	
	return perimeter_positions

func filter_valid_river_starts(perimeter_positions: Array[Vector2i], pond_center: Vector2i) -> Array[Vector2i]:
	var valid_starts: Array[Vector2i] = []
	
	for pos in perimeter_positions:
		if is_good_river_start_position(pos, pond_center):
			valid_starts.append(pos)
	
	return valid_starts

func is_good_river_start_position(pos: Vector2i, pond_center: Vector2i) -> bool:
	if not is_connected_to_substantial_landmass(pos):
		return false
	
	if not has_downhill_flow_potential(pos):
		return false
	
	if is_northern_flow_risk(pos, pond_center):
		return false
	
	if not has_clear_path_potential(pos):
		return false
	
	return true

func is_connected_to_substantial_landmass(start_pos: Vector2i, min_landmass_size: int = 20) -> bool:
	var visited = {}
	var to_check = [start_pos]
	var landmass_size = 0
	var max_check = min_landmass_size + 10
	
	while to_check.size() > 0 and landmass_size < max_check:
		var current_pos = to_check.pop_front()
		var pos_key = str(current_pos.x) + "," + str(current_pos.y)
		
		if pos_key in visited or not is_valid_position(current_pos):
			continue
		
		var terrain = current_island_data.terrain_data[current_pos.y][current_pos.x]
		
		if terrain not in [
			TerrainType.LEVEL0_GRASS, TerrainType.LEVEL0_DIRT,
			TerrainType.LEVEL1_GRASS, TerrainType.LEVEL1_DIRT,
			TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT,
			TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT
		]:
			continue
		
		visited[pos_key] = true
		landmass_size += 1
		
		if landmass_size >= min_landmass_size:
			return true
		
		var neighbors = [
			Vector2i(current_pos.x + 1, current_pos.y),
			Vector2i(current_pos.x - 1, current_pos.y),
			Vector2i(current_pos.x, current_pos.y + 1),
			Vector2i(current_pos.x, current_pos.y - 1)
		]
		
		for neighbor in neighbors:
			var neighbor_key = str(neighbor.x) + "," + str(neighbor.y)
			if neighbor_key not in visited:
				to_check.append(neighbor)
	
	return landmass_size >= min_landmass_size

func has_downhill_flow_potential(pos: Vector2i) -> bool:
	var start_height = current_island_data.height_data[pos.y][pos.x]
	
	for radius in range(1, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) + abs(dy) != radius:
					continue
				
				var check_pos = Vector2i(pos.x + dx, pos.y + dy)
				
				if not is_valid_position(check_pos):
					continue
				
				var check_height = current_island_data.height_data[check_pos.y][check_pos.x]
				
				if check_height < start_height - 0.02:
					return true
	
	return false

func is_northern_flow_risk(pos: Vector2i, pond_center: Vector2i) -> bool:
	var northern_third_boundary = island_height * 0.33
	
	if pond_center.y < northern_third_boundary:
		var pond_to_start = pos - pond_center
		
		if pond_to_start.y < 0:
			return true
	
	var north_clear_distance = 0
	for check_y in range(pos.y - 1, -1, -1):
		var check_pos = Vector2i(pos.x, check_y)
		
		if not is_valid_position(check_pos):
			break
		
		var terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
		
		if terrain == TerrainType.DEEP_OCEAN:
			return true
		
		if terrain in [
			TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT,
			TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT
		]:
			north_clear_distance = 0
			break
		
		north_clear_distance += 1
		
		if north_clear_distance > 8:
			return true
	
	return false

func has_clear_path_potential(pos: Vector2i) -> bool:
	var current_height = current_island_data.height_data[pos.y][pos.x]
	
	var preferred_directions = [
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, 0),
		Vector2i(-1, 0)
	]
	
	for direction in preferred_directions:
		var clear_path_length = 0
		var height_drops = 0
		
		for step in range(1, 8):
			var check_pos = pos + direction * step
			
			if not is_valid_position(check_pos):
				break
			
			var terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
			var check_height = current_island_data.height_data[check_pos.y][check_pos.x]
			
			if terrain == TerrainType.DEEP_OCEAN:
				return true
			
			if terrain in [TerrainType.DEEP_FRESHWATER_POND, TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2, TerrainType.RIVER_3]:
				break
			
			clear_path_length += 1
			
			if check_height < current_height - 0.01:
				height_drops += 1
				current_height = check_height
		
		if clear_path_length >= 4 and height_drops >= 1:
			return true
	
	return false

func select_best_river_start(valid_starts: Array[Vector2i], pond_center: Vector2i) -> Vector2i:
	if valid_starts.size() == 0:
		return Vector2i(-1, -1)
	
	if valid_starts.size() == 1:
		return valid_starts[0]
	
	var best_pos = valid_starts[0]
	var best_score = score_river_start_position(best_pos, pond_center)
	
	for i in range(1, valid_starts.size()):
		var pos = valid_starts[i]
		var score = score_river_start_position(pos, pond_center)
		
		if score > best_score:
			best_score = score
			best_pos = pos
	
	print("Selected river start at ", best_pos, " with score ", best_score)
	return best_pos

func score_river_start_position(pos: Vector2i, pond_center: Vector2i) -> float:
	var score = 0.0
	
	var relative_pos = pos - pond_center
	if relative_pos.y > 0:
		score += 10.0 * relative_pos.y
	else:
		score -= 5.0 * abs(relative_pos.y)
	
	var start_height = current_island_data.height_data[pos.y][pos.x]
	var max_drop = 0.0
	
	var flow_directions = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]
	
	for direction in flow_directions:
		for distance in range(1, 6):
			var check_pos = pos + direction * distance
			if is_valid_position(check_pos):
				var check_height = current_island_data.height_data[check_pos.y][check_pos.x]
				var drop = start_height - check_height
				max_drop = max(max_drop, drop)
	
	score += max_drop * 50.0
	
	var edge_distance = min(
		min(pos.x, island_width - pos.x),
		min(pos.y, island_height - pos.y)
	)
	score += (30 - edge_distance) * 2.0
	
	score += randf_range(-2.0, 2.0)
	
	return score

func find_next_river_step(pos: Vector2i, max_level: int, visited: Array[Vector2i]) -> Vector2i:
	var candidates = []
	
	for direction in get_flow_directions():
		var check_pos = pos + direction
		if not is_valid_position(check_pos) or check_pos in visited:
			continue
		
		var terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
		var terrain_level = get_elevation_level(current_island_data.height_data[check_pos.y][check_pos.x])
		
		if terrain_level > max_level:
			continue
		
		if is_valid_river_endpoint(check_pos):
			print("Found river endpoint at ", check_pos)
			return check_pos
		
		if terrain not in [
			TerrainType.LEVEL0_GRASS, TerrainType.LEVEL0_DIRT,
			TerrainType.LEVEL1_GRASS, TerrainType.LEVEL1_DIRT,
			TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT,
			TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT,
			TerrainType.BEACH
		]:
			continue
		
		var score = calculate_simple_score(pos, check_pos, direction)
		candidates.append({"pos": check_pos, "score": score})
	
	if candidates.is_empty():
		return Vector2i(-1, -1)
	
	candidates.sort_custom(func(a, b): return a.score > b.score)
	return candidates[0].pos

func get_flow_directions() -> Array[Vector2i]:
	return [
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, 0),
		Vector2i(-1, 0)
	]

func calculate_simple_score(from_pos: Vector2i, to_pos: Vector2i, direction: Vector2i) -> float:
	var score = 0.0
	
	if direction.y > 0:
		score += 10.0
	
	var height_diff = current_island_data.height_data[from_pos.y][from_pos.x] - current_island_data.height_data[to_pos.y][to_pos.x]
	score += height_diff * 25.0
	
	var distance_to_south_edge = island_height - to_pos.y
	score += (50.0 - distance_to_south_edge) * 0.3
	
	score += randf_range(-1.0, 1.0)
	
	return score

func is_valid_river_endpoint(pos: Vector2i) -> bool:
	var terrain = current_island_data.terrain_data[pos.y][pos.x]
	
	if terrain == TerrainType.DEEP_OCEAN and pos.y > island_height * 0.4:
		return true
	
	if terrain == TerrainType.SHALLOW_SALTWATER and pos.y > island_height * 0.4:
		return true
	
	if terrain in [TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2, TerrainType.RIVER_3, TerrainType.RIVER_MOUTH]:
		return true
	
	return false

func find_nearest_connection(pos: Vector2i, visited: Array[Vector2i]) -> Vector2i:
	for radius in range(1, 8):
		for direction in get_flow_directions():
			var check_pos = pos + direction * radius
			if is_valid_position(check_pos) and check_pos not in visited:
				if is_valid_river_endpoint(check_pos):
					return check_pos
	
	return Vector2i(-1, -1)

func place_river_path(path: Array[Vector2i]):
	if path.size() == 0:
		return
	
	widen_river_path(path)

func widen_river_path(river_path: Array[Vector2i]):
	if river_path.size() == 0:
		return
	
	print("Widening river path with ", river_path.size(), " centerline tiles")
	
	var river_levels: Array[int] = []
	
	for i in range(river_path.size()):
		var pos = river_path[i]
		
		var current_terrain = current_island_data.terrain_data[pos.y][pos.x]
		if current_terrain in [TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2, TerrainType.RIVER_3, TerrainType.RIVER_MOUTH]:
			print("Skipping river widening at ", pos, " - already has river terrain")
			river_levels.append(get_elevation_level(current_island_data.height_data[pos.y][pos.x]))
			continue
		
		var river_level = place_river_tile_with_level(pos)
		river_levels.append(river_level)
	
	for i in range(river_path.size()):
		var pos = river_path[i]
		var center_river_level = river_levels[i]
		var progress = float(i) / float(river_path.size() - 1)
		
		var width = int(lerp(3.0, 4.0, progress))
		
		var flow_direction = get_flow_direction(river_path, i)
		add_river_width_at_level(pos, flow_direction, width, center_river_level)

func place_river_tile_with_level(pos: Vector2i) -> int:
	if not is_valid_position(pos):
		return 0
	
	var current_terrain = current_island_data.terrain_data[pos.y][pos.x]
	if current_terrain in [TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2, TerrainType.RIVER_3, TerrainType.RIVER_MOUTH, TerrainType.DEEP_OCEAN, TerrainType.SHALLOW_SALTWATER]:
		return get_elevation_level(current_island_data.height_data[pos.y][pos.x])
	
	var surrounding_height = get_average_surrounding_terrain_height(pos)
	var terrain_level = get_elevation_level(surrounding_height)
	
	var river_terrain: TerrainType
	
	match terrain_level:
		1:
			river_terrain = TerrainType.RIVER_1
		2:
			river_terrain = TerrainType.RIVER_2
		3:
			river_terrain = TerrainType.RIVER_3
		_:
			river_terrain = TerrainType.RIVER
	
	current_island_data.terrain_data[pos.y][pos.x] = river_terrain
	current_island_data.water_types[pos.y][pos.x] = WaterType.FRESH
	
	var river_height = calculate_river_height_for_level(terrain_level)
	current_island_data.height_data[pos.y][pos.x] = river_height
	
	return terrain_level

func add_river_width_at_level(center_pos: Vector2i, flow_direction: Vector2i, width: int, required_level: int):
	var perpendicular_dirs: Array[Vector2i] = []
	
	if flow_direction.x == 0:
		perpendicular_dirs = [Vector2i(1, 0), Vector2i(-1, 0)]
	elif flow_direction.y == 0:
		perpendicular_dirs = [Vector2i(0, 1), Vector2i(0, -1)]
	else:
		perpendicular_dirs = [Vector2i(flow_direction.y, flow_direction.x), Vector2i(-flow_direction.y, -flow_direction.x)]
	
	var tiles_per_side = (width - 1) / 2
	
	for direction in perpendicular_dirs:
		for distance in range(1, tiles_per_side + 1):
			var side_pos = center_pos + direction * distance
			if not is_valid_position(side_pos):
				continue
			
			var terrain = current_island_data.terrain_data[side_pos.y][side_pos.x]
			
			if terrain in [
				TerrainType.DEEP_OCEAN, 
				TerrainType.SHALLOW_SALTWATER, 
				TerrainType.DEEP_FRESHWATER_POND,
				TerrainType.RIVER,
				TerrainType.RIVER_1,
				TerrainType.RIVER_2, 
				TerrainType.RIVER_3,
				TerrainType.RIVER_MOUTH
			]:
				continue
			
			var side_terrain_level = get_elevation_level(current_island_data.height_data[side_pos.y][side_pos.x])
			
			if side_terrain_level <= required_level:
				place_river_tile_at_specific_level(side_pos, required_level)
			else:
				break

func place_river_tile_at_specific_level(pos: Vector2i, forced_level: int):
	if not is_valid_position(pos):
		return
	
	var current_terrain = current_island_data.terrain_data[pos.y][pos.x]
	if current_terrain in [TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2, TerrainType.RIVER_3, TerrainType.RIVER_MOUTH, TerrainType.DEEP_OCEAN, TerrainType.SHALLOW_SALTWATER]:
		return
	
	var terrain_level = forced_level
	
	var river_terrain: TerrainType
	
	match terrain_level:
		1:
			river_terrain = TerrainType.RIVER_1
		2:
			river_terrain = TerrainType.RIVER_2
		3:
			river_terrain = TerrainType.RIVER_3
		_:
			river_terrain = TerrainType.RIVER
	
	current_island_data.terrain_data[pos.y][pos.x] = river_terrain
	current_island_data.water_types[pos.y][pos.x] = WaterType.FRESH
	
	var river_height = calculate_river_height_for_level(terrain_level)
	current_island_data.height_data[pos.y][pos.x] = river_height

func get_flow_direction(path: Array[Vector2i], index: int) -> Vector2i:
	if index == 0:
		if path.size() > 1:
			return path[1] - path[0]
		else:
			return Vector2i(0, 1)
	elif index == path.size() - 1:
		return path[index] - path[index - 1]
	else:
		var incoming = path[index] - path[index - 1]
		var outgoing = path[index + 1] - path[index]
		var avg = incoming + outgoing
		
		if abs(avg.x) > abs(avg.y):
			return Vector2i(sign(avg.x), 0)
		else:
			return Vector2i(0, sign(avg.y))

func get_average_surrounding_terrain_height(pos: Vector2i) -> float:
	var total_height = 0.0
	var count = 0
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var check_pos = Vector2i(pos.x + dx, pos.y + dy)
			if is_valid_position(check_pos):
				var terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
				var height = current_island_data.height_data[check_pos.y][check_pos.x]
				
				if terrain in [
					TerrainType.LEVEL0_GRASS, TerrainType.LEVEL0_DIRT,
					TerrainType.LEVEL1_GRASS, TerrainType.LEVEL1_DIRT,
					TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT,
					TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT,
					TerrainType.BEACH
				]:
					total_height += height
					count += 1
	
	return total_height / float(count) if count > 0 else current_island_data.height_data[pos.y][pos.x]

func calculate_river_height_for_level(level: int) -> float:
	match level:
		0:
			return water_threshold + 0.02
		1:
			return lowland_threshold + 0.02
		2:
			return highland_threshold + 0.02
		3:
			return cliff_level_2 + 0.02
		_:
			return water_threshold + 0.01

func create_river_mouths():
	print("Creating river mouths...")
	
	var mouths_created = 0
	var processed_positions = {}
	
	for y in range(island_height):
		for x in range(island_width):
			var current_terrain = current_island_data.terrain_data[y][x]
			
			if current_terrain in [TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2, TerrainType.RIVER_3]:
				var river_pos = Vector2i(x, y)
				
				var pos_key = str(x) + "," + str(y)
				if pos_key in processed_positions:
					continue
				
				if river_touches_ocean(x, y):
					create_mouth_at_river_end(river_pos, processed_positions)
					mouths_created += 1
	
	print("Created ", mouths_created, " river mouths")

func river_touches_ocean(river_x: int, river_y: int) -> bool:
	var directions = [
		Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	
	for direction in directions:
		var check_pos = Vector2i(river_x, river_y) + direction
		
		if not is_valid_position(check_pos):
			continue
		
		var neighbor_terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
		var neighbor_water_type = current_island_data.water_types[check_pos.y][check_pos.x]
		
		if (neighbor_terrain in [TerrainType.DEEP_OCEAN, TerrainType.SHALLOW_SALTWATER] and 
			neighbor_water_type == WaterType.SALT):
			return true
	
	return false

func create_mouth_at_river_end(river_pos: Vector2i, processed_positions: Dictionary):
	var flow_direction = find_river_flow_direction(river_pos)
	if flow_direction == Vector2i.ZERO:
		return
	
	var mouth_tiles = get_complete_river_mouth_area(river_pos, flow_direction)
	
	for tile_pos in mouth_tiles:
		if is_valid_position(tile_pos):
			var current_terrain = current_island_data.terrain_data[tile_pos.y][tile_pos.x]
			
			if should_become_river_mouth(current_terrain):
				current_island_data.terrain_data[tile_pos.y][tile_pos.x] = TerrainType.RIVER_MOUTH
				current_island_data.water_types[tile_pos.y][tile_pos.x] = WaterType.FRESH
				
				var pos_key = str(tile_pos.x) + "," + str(tile_pos.y)
				processed_positions[pos_key] = true
				
				if tile_pos not in current_island_data.river_mouths:
					current_island_data.river_mouths.append(tile_pos)

func find_river_flow_direction(river_pos: Vector2i) -> Vector2i:
	var directions = [
		Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	
	for direction in directions:
		var check_pos = river_pos + direction
		
		if not is_valid_position(check_pos):
			continue
		
		var neighbor_terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
		var neighbor_water_type = current_island_data.water_types[check_pos.y][check_pos.x]
		
		if (neighbor_terrain in [TerrainType.DEEP_OCEAN, TerrainType.SHALLOW_SALTWATER] and 
			neighbor_water_type == WaterType.SALT):
			return direction
	
	return Vector2i.ZERO

func should_become_river_mouth(terrain: TerrainType) -> bool:
	return terrain in [
		TerrainType.RIVER,
		TerrainType.RIVER_1,
		TerrainType.RIVER_2,
		TerrainType.RIVER_3,
		TerrainType.BEACH,
		TerrainType.LEVEL0_GRASS,
		TerrainType.LEVEL0_DIRT,
		TerrainType.SHALLOW_SALTWATER
	]

func get_complete_river_mouth_area(center_pos: Vector2i, flow_direction: Vector2i) -> Array[Vector2i]:
	var mouth_area: Array[Vector2i] = []
	
	var river_width = measure_river_width_at_position(center_pos, flow_direction)
	var max_expansion = (river_width - 1) / 2
	
	print("River width at mouth: ", river_width, ", max expansion: ", max_expansion)
	
	var perpendicular_dirs: Array[Vector2i] = []
	
	if flow_direction.x == 0:
		perpendicular_dirs = [Vector2i(1, 0), Vector2i(-1, 0)]
	elif flow_direction.y == 0:
		perpendicular_dirs = [Vector2i(0, 1), Vector2i(0, -1)]
	else:
		perpendicular_dirs = [
			Vector2i(flow_direction.y, flow_direction.x),
			Vector2i(-flow_direction.y, -flow_direction.x)
		]
	
	mouth_area.append(center_pos)
	
	for direction in perpendicular_dirs:
		for distance in range(1, max_expansion + 1):
			var check_pos = center_pos + direction * distance
			
			if not is_valid_position(check_pos):
				break
			
			var terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
			
			if should_become_river_mouth(terrain):
				mouth_area.append(check_pos)
			else:
				break
	
	return mouth_area

func measure_river_width_at_position(center_pos: Vector2i, flow_direction: Vector2i) -> int:
	var width = 1
	
	var perpendicular_dirs: Array[Vector2i] = []
	
	if flow_direction.x == 0:
		perpendicular_dirs = [Vector2i(1, 0), Vector2i(-1, 0)]
	elif flow_direction.y == 0:
		perpendicular_dirs = [Vector2i(0, 1), Vector2i(0, -1)]
	else:
		perpendicular_dirs = [
			Vector2i(flow_direction.y, flow_direction.x),
			Vector2i(-flow_direction.y, -flow_direction.x)
		]
	
	for direction in perpendicular_dirs:
		var distance = 1
		
		while distance <= 10:
			var check_pos = center_pos + direction * distance
			
			if not is_valid_position(check_pos):
				break
			
			var terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
			
			if terrain in [TerrainType.RIVER, TerrainType.RIVER_1, TerrainType.RIVER_2, TerrainType.RIVER_3]:
				width += 1
				distance += 1
			else:
				break
	
	return width

# ============================================================================
# BEACH AND COASTAL GENERATION
# ============================================================================

func create_beaches():
	print("Creating beaches around coastline (avoiding northern shores and freshwater)...")
	
	var beaches_placed = 0
	var northern_exclusion_zone = int(island_height * northern_shore_exclusion)
	
	for y in range(island_height):
		for x in range(island_width):
			var current_terrain = current_island_data.terrain_data[y][x]
			
			if current_terrain in [
				TerrainType.LEVEL0_GRASS,
				TerrainType.LEVEL0_DIRT,
				TerrainType.LEVEL1_GRASS,
				TerrainType.LEVEL1_DIRT,
				TerrainType.LEVEL2_GRASS,
				TerrainType.LEVEL2_DIRT,
				TerrainType.LEVEL3_GRASS,
				TerrainType.LEVEL3_DIRT,
				TerrainType.RIVER,
				TerrainType.RIVER_MOUTH
			]:
				if not touches_saltwater_only(x, y):
					continue
				
				if y < northern_exclusion_zone:
					if is_northern_shore(x, y):
						continue
				
				current_island_data.terrain_data[y][x] = TerrainType.BEACH
				current_island_data.height_data[y][x] = beach_threshold
				current_island_data.beach_zones[y][x] = true
				
				beaches_placed += 1
	
	print("Placed ", beaches_placed, " beach tiles (northern shores and freshwater excluded)")
	add_beach_extensions()

func touches_saltwater_only(x: int, y: int) -> bool:
	var directions = [
		Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	
	var touches_water = false
	
	for direction in directions:
		var check_pos = Vector2i(x, y) + direction
		
		if check_pos.x < 0 or check_pos.x >= island_width or check_pos.y < 0 or check_pos.y >= island_height:
			continue
		
		var neighbor_terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
		var neighbor_water_type = current_island_data.water_types[check_pos.y][check_pos.x]
		
		if neighbor_water_type == WaterType.FRESH:
			return false
		
		if neighbor_terrain in [TerrainType.DEEP_OCEAN, TerrainType.SHALLOW_SALTWATER] and neighbor_water_type == WaterType.SALT:
			touches_water = true
	
	return touches_water

func is_northern_shore(x: int, y: int) -> bool:
	var land_to_south = 0
	var land_to_north = 0
	
	for i in range(1, 4):
		if y + i < island_height:
			var south_terrain = current_island_data.terrain_data[y + i][x]
			if is_land_terrain(south_terrain):
				land_to_south += 1
		else:
			break
	
	for i in range(1, 4):
		if y - i >= 0:
			var north_terrain = current_island_data.terrain_data[y - i][x]
			if is_land_terrain(north_terrain):
				land_to_north += 1
		else:
			break
	
	return land_to_south > land_to_north

func is_land_terrain(terrain_type: TerrainType) -> bool:
	return terrain_type in [
		TerrainType.LEVEL0_GRASS,
		TerrainType.LEVEL0_DIRT,
		TerrainType.LEVEL1_GRASS,
		TerrainType.LEVEL1_DIRT,
		TerrainType.LEVEL2_GRASS,
		TerrainType.LEVEL2_DIRT,
		TerrainType.LEVEL3_GRASS,
		TerrainType.LEVEL3_DIRT,
		TerrainType.RIVER
	]

func add_beach_extensions():
	print("Adding beach extensions...")
   
	var current_beaches = []
	for y in range(island_height):
		for x in range(island_width):
			if current_island_data.terrain_data[y][x] == TerrainType.BEACH:
				current_beaches.append(Vector2i(x, y))
	
	for beach_pos in current_beaches:
		extend_beach_into_ocean(beach_pos.x, beach_pos.y)
		
# ============================================================================
# FINAL PART 3 - Add these remaining methods to complete your IslandDataGenerator.gd
# ============================================================================

func extend_beach_into_ocean(beach_x: int, beach_y: int):
	var south_extension = randi_range(south_beach_min, south_beach_max)
	for i in range(1, south_extension + 1):
		var extend_pos = Vector2i(beach_x, beach_y + i)
		if is_valid_position(extend_pos) and current_island_data.terrain_data[extend_pos.y][extend_pos.x] == TerrainType.DEEP_OCEAN:
			current_island_data.terrain_data[extend_pos.y][extend_pos.x] = TerrainType.BEACH
			current_island_data.beach_zones[extend_pos.y][extend_pos.x] = true
	
	var side_extension = randi_range(side_beach_min, side_beach_max)
	for direction in [Vector2i(1, 0), Vector2i(-1, 0)]:
		for i in range(1, side_extension + 1):
			var extend_pos = Vector2i(beach_x, beach_y) + direction * i
			if is_valid_position(extend_pos) and current_island_data.terrain_data[extend_pos.y][extend_pos.x] == TerrainType.DEEP_OCEAN:
				current_island_data.terrain_data[extend_pos.y][extend_pos.x] = TerrainType.BEACH
				current_island_data.beach_zones[extend_pos.y][extend_pos.x] = true

func create_shallow_water_zones():
	for y in range(island_height):
		for x in range(island_width):
			if current_island_data.beach_zones[y][x]:
				add_shallow_saltwater_around_beach(x, y)
	
	for river_mouth in current_island_data.river_mouths:
		add_shallow_freshwater_around_river_mouth(river_mouth)

func add_shallow_saltwater_around_beach(beach_x: int, beach_y: int):
	var directions = [
		Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	
	for depth in range(1, shallow_saltwater_depth + 1):
		for direction in directions:
			var check_pos = Vector2i(beach_x, beach_y) + direction * depth
			
			if is_valid_position(check_pos):
				var current_terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
				if current_terrain == TerrainType.DEEP_OCEAN:
					current_island_data.terrain_data[check_pos.y][check_pos.x] = TerrainType.SHALLOW_SALTWATER
					current_island_data.water_types[check_pos.y][check_pos.x] = WaterType.SALT
					current_island_data.height_data[check_pos.y][check_pos.x] = water_threshold

func add_shallow_freshwater_around_river_mouth(mouth_pos: Vector2i):
	var directions = [
		Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	
	for depth in range(1, 3):
		for direction in directions:
			var check_pos = mouth_pos + direction * depth
			
			if not is_valid_position(check_pos):
				continue
			
			var current_terrain = current_island_data.terrain_data[check_pos.y][check_pos.x]
			var current_water_type = current_island_data.water_types[check_pos.y][check_pos.x]
			
			if current_terrain == TerrainType.DEEP_OCEAN and current_water_type == WaterType.SALT:
				current_island_data.terrain_data[check_pos.y][check_pos.x] = TerrainType.SHALLOW_FRESHWATER
				current_island_data.water_types[check_pos.y][check_pos.x] = WaterType.FRESH
			elif current_terrain == TerrainType.SHALLOW_SALTWATER and current_water_type == WaterType.SALT:
				current_island_data.terrain_data[check_pos.y][check_pos.x] = TerrainType.SHALLOW_FRESHWATER
				current_island_data.water_types[check_pos.y][check_pos.x] = WaterType.FRESH
			elif current_terrain == TerrainType.BEACH:
				current_island_data.terrain_data[check_pos.y][check_pos.x] = TerrainType.BEACH

# ============================================================================
# UTILITY FUNCTIONS (COPY FROM YOUR ORIGINAL SCRIPT)
# ============================================================================

func get_elevation_level(height: float) -> int:
	if height <= water_threshold:
		return -1
	elif height < lowland_threshold:
		return 0
	elif height < highland_threshold:
		return 1
	elif height < cliff_level_2:
		return 2
	else:
		return 3

func calculate_height_for_level(level: int) -> float:
	match level:
		0:
			return lerp(beach_threshold, lowland_threshold, 0.5)
		1:
			return lerp(lowland_threshold, highland_threshold, 0.5)
		2:
			return lerp(highland_threshold, cliff_level_2, 0.5)
		3:
			return lerp(cliff_level_2, cliff_level_3, 0.5)
		_:
			return beach_threshold + 0.05

func calculate_pond_height_for_level(level: int) -> float:
	match level:
		0: return lowland_threshold - 0.05
		1: return highland_threshold - 0.05
		2: return cliff_level_2 - 0.05
		3: return cliff_level_3 - 0.05
		_: return lowland_threshold - 0.05

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < island_width and pos.y >= 0 and pos.y < island_height

# ============================================================================
# PRESET MANAGEMENT
# ============================================================================

func apply_generation_preset(preset_name: String):
	"""Apply predefined generation settings"""
	match preset_name.to_lower():
		"small":
			island_width = 100
			island_height = 60
			deep_pond_count = 3
			shallow_pond_count = 4
		"medium":
			island_width = 200
			island_height = 120
			deep_pond_count = 5
			shallow_pond_count = 6
		"large":
			island_width = 300
			island_height = 180
			deep_pond_count = 8
			shallow_pond_count = 10
		"archipelago":
			island_width = 250
			island_height = 150
			highland_transition = 0.3
			deep_pond_count = 12
			shallow_pond_count = 8
		_:
			print("Unknown preset: ", preset_name)
			return
	
	print("Applied preset: ", preset_name)

func get_available_presets() -> Array[String]:
	"""Get list of available generation presets"""
	return ["small", "medium", "large", "archipelago"]

# ============================================================================
# INSTRUCTIONS FOR COMPLETION
# ============================================================================

# TO COMPLETE YOUR SCRIPT:
# 1. Create a new script file called IslandDataGenerator.gd
# 2. Start with the content from Part 1 (the main script)  
# 3. Add all the methods from Part 2 to the same file
# 4. Add all the methods from Part 3 (this file) to the same file
# 5. Make sure you've copied ALL your @export variables from your old script
# 6. Save and test by running your LoadingScreen.tscn

# YOUR COMPLETE IslandDataGenerator.gd SHOULD HAVE THESE SECTIONS:
# - Class declaration and exports (from Part 1)
# - Signals and data structures (from Part 1) 
# - Core variables and initialization (from Part 1)
# - Main generation pipeline (from Part 1)
# - Elevation generation (from Part 1)
# - Terrain smoothing (from Part 1) 
# - Terrain placement (from Part 1)
# - Pond generation (from Parts 1 & 2)
# - River generation (from Part 2)
# - Beach and coastal generation (from Parts 2 & 3)
# - Utility functions (from Part 3)
# - Preset management (from Part 3)

# TESTING CHECKLIST:
# ✅ Script has class_name IslandDataGenerator at the top
# ✅ All your @export variables are copied from original script
# ✅ LoadingScreen.tscn runs without errors
# ✅ You see generation progress messages in console
# ✅ IslandDataStore.get_island_data() returns valid data after generation
