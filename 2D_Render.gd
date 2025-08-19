extends TileMapLayer
class_name Island2DDisplay

# ============================================================================
# TILE IDS - Same as your original script
# ============================================================================

@export_group("Water Tile IDs")
@export var deep_ocean_id: int = 0
@export var shallow_saltwater_id: int = 1
@export var shallow_freshwater_id: int = 2
@export var deep_freshwater_id: int = 3
@export var river_id: int = 4
@export var river_1_id: int = 14
@export var river_2_id: int = 15
@export var river_3_id: int = 16
@export var river_mouth_id: int = 5

@export_group("Land Tile IDs")
@export var beach_id: int = 12
@export var level0_grass_id: int = 10
@export var level0_dirt_id: int = 11
@export var level1_grass_id: int = 20
@export var level1_dirt_id: int = 21
@export var level2_grass_id: int = 30
@export var level2_dirt_id: int = 31
@export var level3_grass_id: int = 40
@export var level3_dirt_id: int = 41

@export_group("Display Settings")
@export var auto_display_on_ready: bool = true
@export var auto_center_camera: bool = false  # You have your own camera controller

# ============================================================================
# TERRAIN ENUMS (matching the data generator)
# ============================================================================

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

# ============================================================================
# INTERNAL VARIABLES
# ============================================================================

var current_island_data
var is_displayed: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("island_2d_display")
	
	if not tile_set:
		print("Warning: No TileSet resource assigned to Island2DDisplay")
		print("Please assign your TileSet in the Inspector!")
	return
	
	
	# Auto-display if island data is available
	if auto_display_on_ready and IslandDataStore.has_island_data():
		display_island_from_store()
		print("Island2DDisplay: Auto-displayed island data on ready")

# ============================================================================
# MAIN DISPLAY FUNCTIONS
# ============================================================================

func display_island_from_store():
	"""Display island from the global IslandDataStore"""
	if not IslandDataStore.has_island_data():
		print("Island2DDisplay: No island data in store")
		return
	
	var island_data = IslandDataStore.get_island_data()
	display_island(island_data)

func display_island(island_data):
	"""Display the island data on the tilemap"""
	if not island_data or not island_data.is_valid():
		print("Island2DDisplay: Invalid island data provided")
		return
	
	print("Island2DDisplay: Displaying island on 2D tilemap...")
	current_island_data = island_data
	
	# Clear existing tiles
	clear()
	
	# Render all tiles
	render_terrain_tiles(island_data)
	
	# Center camera if enabled (you probably don't want this since you have camera controllers)
	if auto_center_camera:
		center_camera_on_island(island_data)
	
	is_displayed = true
	print("Island2DDisplay: 2D island display complete!")

func clear_display():
	"""Clear the tilemap display"""
	clear()
	current_island_data = null
	is_displayed = false
	print("Island2DDisplay: 2D display cleared")

func refresh_display():
	"""Refresh the display with current data from store"""
	if IslandDataStore.has_island_data():
		display_island_from_store()
	else:
		clear_display()

# ============================================================================
# TILE RENDERING
# ============================================================================

func render_terrain_tiles(island_data):
	"""Render all terrain tiles based on island data"""
	var terrain_data = island_data.terrain_data
	
	for y in range(island_data.island_height):
		for x in range(island_data.island_width):
			if y < terrain_data.size() and x < terrain_data[y].size():
				var terrain_type = terrain_data[y][x]
				var tile_id = get_tile_id_for_terrain_type(terrain_type)
				set_cell(Vector2i(x, y), tile_id, Vector2i(0, 0))
				

func get_tile_id_for_terrain_type(terrain_type: int) -> int:
	"""Convert terrain type to tile ID"""
	match terrain_type:
		TerrainType.DEEP_OCEAN: return deep_ocean_id
		TerrainType.SHALLOW_SALTWATER: return shallow_saltwater_id
		TerrainType.SHALLOW_FRESHWATER: return shallow_freshwater_id
		TerrainType.DEEP_FRESHWATER_POND: return deep_freshwater_id
		TerrainType.RIVER: return river_id
		TerrainType.RIVER_1: return river_1_id
		TerrainType.RIVER_2: return river_2_id
		TerrainType.RIVER_3: return river_3_id
		TerrainType.RIVER_MOUTH: return river_mouth_id
		TerrainType.BEACH: return beach_id
		TerrainType.LEVEL0_GRASS: return level0_grass_id
		TerrainType.LEVEL0_DIRT: return level0_dirt_id
		TerrainType.LEVEL1_GRASS: return level1_grass_id
		TerrainType.LEVEL1_DIRT: return level1_dirt_id
		TerrainType.LEVEL2_GRASS: return level2_grass_id
		TerrainType.LEVEL2_DIRT: return level2_dirt_id
		TerrainType.LEVEL3_GRASS: return level3_grass_id
		TerrainType.LEVEL3_DIRT: return level3_dirt_id
		_: return level0_grass_id

# ============================================================================
# CAMERA MANAGEMENT (Optional - you have your own controllers)
# ============================================================================

func center_camera_on_island(island_data):
	"""Center camera on the island - you probably won't need this"""
	var camera = get_node_or_null("../Camera2D")
	if camera:
		var center_x = island_data.island_width * 16
		var center_y = island_data.island_height * 16
		camera.global_position = Vector2(center_x, center_y)
		print("Island2DDisplay: Centered camera on island")

# ============================================================================
# GAMEPLAY INTERFACE (for your game logic)
# ============================================================================

func get_terrain_at(x: int, y: int) -> int:
	"""Get terrain type at position - for gameplay"""
	if not current_island_data or not current_island_data.is_valid():
		return TerrainType.DEEP_OCEAN
	
	if x < 0 or x >= current_island_data.island_width or y < 0 or y >= current_island_data.island_height:
		return TerrainType.DEEP_OCEAN
	
	return current_island_data.terrain_data[y][x]

func get_height_at(x: int, y: int) -> float:
	"""Get height at position - for gameplay"""
	if not current_island_data or not current_island_data.is_valid():
		return 0.0
	
	if x < 0 or x >= current_island_data.island_width or y < 0 or y >= current_island_data.island_height:
		return 0.0
	
	return current_island_data.height_data[y][x]

func get_water_type_at(x: int, y: int) -> int:
	"""Get water type at position - for gameplay"""
	if not current_island_data or not current_island_data.is_valid():
		return 0  # WaterType.NONE
	
	if x < 0 or x >= current_island_data.island_width or y < 0 or y >= current_island_data.island_height:
		return 0
	
	return current_island_data.water_types[y][x]

func is_walkable(x: int, y: int) -> bool:
	"""Check if position is walkable"""
	var terrain = get_terrain_at(x, y)
	return terrain not in [
		TerrainType.DEEP_OCEAN,
		TerrainType.DEEP_FRESHWATER_POND
	]

func is_water(x: int, y: int) -> bool:
	"""Check if position is water"""
	var terrain = get_terrain_at(x, y)
	return terrain in [
		TerrainType.DEEP_OCEAN,
		TerrainType.SHALLOW_SALTWATER,
		TerrainType.SHALLOW_FRESHWATER,
		TerrainType.DEEP_FRESHWATER_POND,
		TerrainType.RIVER,
		TerrainType.RIVER_1,
		TerrainType.RIVER_2,
		TerrainType.RIVER_3,
		TerrainType.RIVER_MOUTH
	]

# ============================================================================
# PUBLIC INTERFACE (for your main GameWorld script)
# ============================================================================

func has_island_displayed() -> bool:
	"""Check if island is currently displayed"""
	return is_displayed and current_island_data != null

func get_island_bounds() -> Rect2i:
	"""Get the bounds of the current island"""
	if not current_island_data:
		return Rect2i(0, 0, 0, 0)
	
	return Rect2i(0, 0, current_island_data.island_width, current_island_data.island_height)

# ============================================================================
# INPUT HANDLING (Optional - for debugging)
# ============================================================================

func _input(event):
	# You can add debug inputs here if needed
	if event.is_action_pressed("ui_home"):  # Home key for refresh
		refresh_display()
		print("Island2DDisplay: Manual refresh triggered")

# ============================================================================
# INTEGRATION WITH YOUR EXISTING SCRIPTS
# ============================================================================

# This script will work alongside your existing scripts:
# - Your 2D/3D switching script can call refresh_display() when switching views
# - Your camera controllers will handle camera positioning
# - Your main GameWorld script can call display_island_from_store() when needed
# - The script auto-detects island data from IslandDataStore
