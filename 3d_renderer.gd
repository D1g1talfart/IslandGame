extends Node3D
class_name Island3DRenderer

signal island_rendered

# ============================================================================
# ISLAND 3D RENDERER - RESTORED with cliff and height functionality
# ============================================================================

@export_group("3D Rendering Settings")
@export var tile_size: float = 2.0
@export var height_scale: float = 3.0
@export var auto_render_on_ready: bool = true
@export var show_debug_info: bool = true

@export_group("Mesh Settings")
@export var use_smooth_normals: bool = true
@export var generate_uvs: bool = true
@export var create_collision: bool = true

@export_group("Visual Settings")
@export var show_wireframe: bool = false
@export var ambient_light_intensity: float = 0.3

@export_group("Transition Settings")
@export var corner_extension_multiplier: float = 1.2

@export_group("Water Settings")
@export var water_surface_offset: float = -0.05  # Water surface height (less offset than bed)
@export var water_bed_offset: float = -0.5      # Water bed height (current water_level_offset)
@export var water_surface_alpha: float = 0.7    # Transparency of water surface

# ============================================================================
# RENDERING DATA
# ============================================================================

var materials: Dictionary = {}
var mesh_instances: Array[MeshInstance3D] = []
var current_island_data
var is_rendered: bool = false

# Terrain type enum (matching the data generator)
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
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("island_3d_renderer")
	setup_materials()
	setup_lighting()
	
	if auto_render_on_ready and IslandDataStore.has_island_data():
		render_island_from_store()
		print("Island3DRenderer: Auto-rendered island data on ready")

# ============================================================================
# SETUP FUNCTIONS (keeping your existing setup)
# ============================================================================

func setup_lighting():
	var existing_light = get_node_or_null("MainLight")
	if existing_light:
		print("Island3DRenderer: Using existing lighting setup")
		return
	
	var light = DirectionalLight3D.new()
	light.name = "MainLight"
	light.position = Vector3(0, 10, 5)
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)
	
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = ambient_light_intensity
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		camera.environment = environment

func setup_materials():
	# Water BED materials (sand-colored, solid)
	materials["bed_" + str(TerrainType.DEEP_OCEAN)] = create_water_bed_material(Color(0.9, 0.8, 0.6))
	materials["bed_" + str(TerrainType.SHALLOW_SALTWATER)] = create_water_bed_material(Color(0.9, 0.8, 0.6))
	materials["bed_" + str(TerrainType.SHALLOW_FRESHWATER)] = create_water_bed_material(Color(0.8, 0.7, 0.5))
	materials["bed_" + str(TerrainType.DEEP_FRESHWATER_POND)] = create_water_bed_material(Color(0.7, 0.6, 0.4))
	materials["bed_" + str(TerrainType.RIVER)] = create_water_bed_material(Color(0.8, 0.7, 0.5))
	materials["bed_" + str(TerrainType.RIVER_1)] = create_water_bed_material(Color(0.8, 0.7, 0.5))
	materials["bed_" + str(TerrainType.RIVER_2)] = create_water_bed_material(Color(0.8, 0.7, 0.5))
	materials["bed_" + str(TerrainType.RIVER_3)] = create_water_bed_material(Color(0.8, 0.7, 0.5))
	materials["bed_" + str(TerrainType.RIVER_MOUTH)] = create_water_bed_material(Color(0.9, 0.8, 0.6))
	
	# Water SURFACE materials (transparent blue, no collision)
	materials["surface_" + str(TerrainType.DEEP_OCEAN)] = create_water_surface_material(Color(0.1, 0.2, 0.6, water_surface_alpha), true)
	materials["surface_" + str(TerrainType.SHALLOW_SALTWATER)] = create_water_surface_material(Color(0.2, 0.4, 0.8, water_surface_alpha), false)
	materials["surface_" + str(TerrainType.SHALLOW_FRESHWATER)] = create_water_surface_material(Color(0.3, 0.6, 0.8, water_surface_alpha), false)
	materials["surface_" + str(TerrainType.DEEP_FRESHWATER_POND)] = create_water_surface_material(Color(0.2, 0.3, 0.7, water_surface_alpha), true)
	materials["surface_" + str(TerrainType.RIVER)] = create_water_surface_material(Color(0.4, 0.7, 0.9, water_surface_alpha), false)
	materials["surface_" + str(TerrainType.RIVER_1)] = create_water_surface_material(Color(0.4, 0.7, 0.9, water_surface_alpha), false)
	materials["surface_" + str(TerrainType.RIVER_2)] = create_water_surface_material(Color(0.4, 0.7, 0.9, water_surface_alpha), false)
	materials["surface_" + str(TerrainType.RIVER_3)] = create_water_surface_material(Color(0.4, 0.7, 0.9, water_surface_alpha), false)
	materials["surface_" + str(TerrainType.RIVER_MOUTH)] = create_water_surface_material(Color(0.5, 0.8, 0.9, water_surface_alpha), false)
	
	# Land materials (unchanged)
	materials[TerrainType.BEACH] = create_land_material(Color(0.9, 0.8, 0.6))
	materials[TerrainType.LEVEL0_GRASS] = create_land_material(Color(0.3, 0.6, 0.2))
	materials[TerrainType.LEVEL0_DIRT] = create_land_material(Color(0.6, 0.4, 0.2))
	materials[TerrainType.LEVEL1_GRASS] = create_land_material(Color(0.4, 0.7, 0.3))
	materials[TerrainType.LEVEL1_DIRT] = create_land_material(Color(0.7, 0.5, 0.3))
	materials[TerrainType.LEVEL2_GRASS] = create_land_material(Color(0.5, 0.8, 0.4))
	materials[TerrainType.LEVEL2_DIRT] = create_land_material(Color(0.8, 0.6, 0.4))
	materials[TerrainType.LEVEL3_GRASS] = create_land_material(Color(0.6, 0.9, 0.5))
	materials[TerrainType.LEVEL3_DIRT] = create_land_material(Color(0.9, 0.7, 0.5))

# Add these new material creation functions
func create_water_bed_material(color: Color) -> StandardMaterial3D:
	"""Create sandy bottom material for water beds"""
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.9  # Sandy texture
	material.emission_enabled = true
	material.emission = color * 0.05
	return material

func create_water_surface_material(color: Color, is_deep: bool) -> StandardMaterial3D:
	"""Create transparent water surface material"""
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.1
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if is_deep:
		material.emission_enabled = true
		material.emission = Color(0.0, 0.1, 0.3) * 0.1
	
	# Make it look more water-like
	material.clearcoat_enabled = true
	material.clearcoat = 0.5
	material.rim_enabled = true
	material.rim = 0.3
	material.rim_tint = 0.5
	
	return material

func create_water_material(color: Color, is_deep: bool) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.1
	#material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if is_deep:
		material.emission_enabled = true
		material.emission = Color(0.0, 0.1, 0.3) * 0.2
	
	material.clearcoat_enabled = true
	material.clearcoat = 0.3
	
	return material

func create_land_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = color * 0.05
	return material

# ============================================================================
# MAIN RENDERING FUNCTIONS
# ============================================================================

func render_island_from_store():
	if not IslandDataStore.has_island_data():
		print("Island3DRenderer: No island data in store")
		return
	
	var island_data = IslandDataStore.get_island_data()
	render_island_from_data(island_data)

func render_island_from_data(island_data):
	if not island_data or not island_data.is_valid():
		print("Island3DRenderer: Invalid island data provided")
		return
	
	print("Island3DRenderer: Starting 3D island rendering from data...")
	current_island_data = island_data
	clear_existing_meshes()
	
	# Create 3D representation with RESTORED cliff functionality
	create_terrain_chunks_from_data(island_data)
	create_cliff_faces_from_data(island_data)  # RESTORED!
	create_sloped_transitions_from_data(island_data)
	create_corner_triangles_from_data(island_data)
	
	is_rendered = true
	print("Island3DRenderer: 3D island rendering complete!")
	
	island_rendered.emit()

func clear_existing_meshes():
	for mesh_instance in mesh_instances:
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
	mesh_instances.clear()

func clear_3d_display():
	clear_existing_meshes()
	current_island_data = null
	is_rendered = false
	print("Island3DRenderer: 3D display cleared")

func refresh_3d_view():
	if IslandDataStore.has_island_data():
		render_island_from_store()
	else:
		clear_3d_display()

# ============================================================================
# RESTORED HEIGHT CALCULATION SYSTEM
# ============================================================================

func get_terrain_level_height(terrain_type: int, tile_pos: Vector2i) -> float:
	"""Get height based on terrain level - uses water SURFACE height for water terrain"""
	if is_water_terrain(terrain_type):
		return get_water_surface_height(tile_pos)  # Use surface height for interactions
	else:
		return get_land_level_height(terrain_type)

func get_land_level_height(terrain_type: int) -> float:
	"""RESTORED: Get height for land terrain based on level"""
	match terrain_type:
		TerrainType.BEACH:
			return 0.0 * height_scale
		TerrainType.LEVEL0_GRASS, TerrainType.LEVEL0_DIRT:
			return 0.0 * height_scale
		TerrainType.LEVEL1_GRASS, TerrainType.LEVEL1_DIRT:
			return 1.0 * height_scale
		TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT:
			return 2.0 * height_scale
		TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT:
			return 3.0 * height_scale
		_:
			return 0.0 * height_scale

func get_water_bed_height(tile_pos: Vector2i) -> float:
	"""Get height for water bed (bottom of water)"""
	if not current_island_data:
		return water_bed_offset
	
	var water_terrain_type = current_island_data.terrain_data[tile_pos.y][tile_pos.x]
	
	# Ocean and saltwater beds at sea level
	if is_ocean_or_saltwater(water_terrain_type):
		return 0.0 + water_bed_offset
	
	# Rivers get fixed bed height levels
	if is_river_water(water_terrain_type):
		return get_river_level_height_bed(water_terrain_type)
	
	# Ponds adapt to surrounding terrain
	if is_pond_water(water_terrain_type):
		return get_pond_level_height_bed(tile_pos)
	
	return 0.0 + water_bed_offset

func get_water_surface_height(tile_pos: Vector2i) -> float:
	"""Get height for water surface (top of water)"""
	if not current_island_data:
		return water_surface_offset
	
	var water_terrain_type = current_island_data.terrain_data[tile_pos.y][tile_pos.x]
	
	# Ocean and saltwater surface at sea level
	if is_ocean_or_saltwater(water_terrain_type):
		return 0.0 + water_surface_offset
	
	# Rivers get fixed surface height levels
	if is_river_water(water_terrain_type):
		return get_river_level_height_surface(water_terrain_type)
	
	# Ponds adapt to surrounding terrain
	if is_pond_water(water_terrain_type):
		return get_pond_level_height_surface(tile_pos)
	
	return 0.0 + water_surface_offset

func get_river_level_height_bed(terrain_type: int) -> float:
	"""Get bed height for river water"""
	match terrain_type:
		TerrainType.RIVER, TerrainType.RIVER_MOUTH:
			return 0.0 * height_scale + water_bed_offset
		TerrainType.RIVER_1:
			return 1.0 * height_scale + water_bed_offset
		TerrainType.RIVER_2:
			return 2.0 * height_scale + water_bed_offset
		TerrainType.RIVER_3:
			return 3.0 * height_scale + water_bed_offset
		_:
			return 0.0 * height_scale + water_bed_offset

func get_river_level_height_surface(terrain_type: int) -> float:
	"""Get surface height for river water"""
	match terrain_type:
		TerrainType.RIVER, TerrainType.RIVER_MOUTH:
			return 0.0 * height_scale + water_surface_offset
		TerrainType.RIVER_1:
			return 1.0 * height_scale + water_surface_offset
		TerrainType.RIVER_2:
			return 2.0 * height_scale + water_surface_offset
		TerrainType.RIVER_3:
			return 3.0 * height_scale + water_surface_offset
		_:
			return 0.0 * height_scale + water_surface_offset

func get_pond_level_height_bed(tile_pos: Vector2i) -> float:
	"""Pond bed height"""
	var base_level = find_nearest_land_level(tile_pos, current_island_data.terrain_data)
	return base_level * height_scale + water_bed_offset

func get_pond_level_height_surface(tile_pos: Vector2i) -> float:
	"""Pond surface height"""
	var base_level = find_nearest_land_level(tile_pos, current_island_data.terrain_data)
	return base_level * height_scale + water_surface_offset

func is_river_water(terrain_type: int) -> bool:
	"""Check if terrain is river water with fixed height levels"""
	return terrain_type in [
		TerrainType.RIVER,
		TerrainType.RIVER_1,
		TerrainType.RIVER_2,
		TerrainType.RIVER_3,
		TerrainType.RIVER_MOUTH
	]

func is_pond_water(terrain_type: int) -> bool:
	"""Check if terrain is pond water that adapts to surroundings"""
	return terrain_type in [
		TerrainType.SHALLOW_FRESHWATER,
		TerrainType.DEEP_FRESHWATER_POND
	]



func is_ocean_or_saltwater(terrain_type: int) -> bool:
	"""RESTORED: Check if ocean/saltwater at sea level"""
	return terrain_type in [
		TerrainType.DEEP_OCEAN,
		TerrainType.SHALLOW_SALTWATER,
		TerrainType.RIVER_MOUTH
	]

func is_freshwater(terrain_type: int) -> bool:
	"""Check if terrain is any kind of freshwater"""
	return is_river_water(terrain_type) or is_pond_water(terrain_type)

func get_freshwater_level_height(tile_pos: Vector2i) -> float:
	"""RESTORED: Freshwater height based on surrounding terrain"""
	if not current_island_data:
		return water_bed_offset
	
	var base_level = find_nearest_land_level(tile_pos, current_island_data.terrain_data)
	return base_level * height_scale + water_bed_offset

func find_nearest_land_level(tile_pos: Vector2i, terrain_data: Array) -> float:
	"""RESTORED: Find nearest land level, expanding search radius"""
	var max_search_radius = 8
	
	for radius in range(1, max_search_radius + 1):
		var surrounding_levels = []
		
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) < radius and abs(dy) < radius:
					continue
					
				var check_pos = tile_pos + Vector2i(dx, dy)
				
				if check_pos.y < 0 or check_pos.y >= terrain_data.size() or \
				   check_pos.x < 0 or check_pos.x >= terrain_data[check_pos.y].size():
					continue
				
				var neighbor_terrain = terrain_data[check_pos.y][check_pos.x]
				
				if not is_water_terrain(neighbor_terrain):
					var neighbor_level = get_terrain_level_from_type(neighbor_terrain)
					surrounding_levels.append(neighbor_level)
		
		if surrounding_levels.size() > 0:
			return surrounding_levels.min()
	
	return 0.0

func get_terrain_level_from_type(terrain_type: int) -> int:
	"""RESTORED: Get numeric level (0,1,2,3) from terrain type"""
	match terrain_type:
		TerrainType.BEACH, TerrainType.LEVEL0_GRASS, TerrainType.LEVEL0_DIRT:
			return 0
		TerrainType.LEVEL1_GRASS, TerrainType.LEVEL1_DIRT:
			return 1
		TerrainType.LEVEL2_GRASS, TerrainType.LEVEL2_DIRT:
			return 2
		TerrainType.LEVEL3_GRASS, TerrainType.LEVEL3_DIRT:
			return 3
		_:
			return 0

func is_water_terrain(terrain_type: int) -> bool:
	"""RESTORED: Check if terrain is any kind of water"""
	return is_ocean_or_saltwater(terrain_type) or is_freshwater(terrain_type)

# ============================================================================
# RESTORED CLIFF GENERATION SYSTEM
# ============================================================================

func create_cliff_faces_from_data(island_data):
	"""RESTORED: Create vertical cliff faces with proper materials"""
	var land_cliff_groups = {}  # Grouped by terrain level for dirt materials
	var water_cliff_groups = {} # Grouped by terrain type for water materials
	
	for y in range(island_data.island_height):
		for x in range(island_data.island_width):
			if y < island_data.terrain_data.size() and x < island_data.terrain_data[y].size():
				var terrain_type = island_data.terrain_data[y][x]
				var current_height = get_terrain_level_height(terrain_type, Vector2i(x, y))
				
				# Check each cardinal direction for height differences
				var directions = [
					{"offset": Vector2i(0, -1), "edge_start": Vector3(-tile_size/2, 0, -tile_size/2), "edge_end": Vector3(tile_size/2, 0, -tile_size/2), "normal": Vector3(0, 0, -1)},
					{"offset": Vector2i(1, 0), "edge_start": Vector3(tile_size/2, 0, -tile_size/2), "edge_end": Vector3(tile_size/2, 0, tile_size/2), "normal": Vector3(1, 0, 0)},
					{"offset": Vector2i(0, 1), "edge_start": Vector3(tile_size/2, 0, tile_size/2), "edge_end": Vector3(-tile_size/2, 0, tile_size/2), "normal": Vector3(0, 0, 1)},
					{"offset": Vector2i(-1, 0), "edge_start": Vector3(-tile_size/2, 0, tile_size/2), "edge_end": Vector3(-tile_size/2, 0, -tile_size/2), "normal": Vector3(-1, 0, 0)}
				]
				
				var world_pos = Vector3(x * tile_size, current_height, y * tile_size)
				
				for dir in directions:
					var neighbor_pos = Vector2i(x, y) + dir.offset
					
					# Check bounds
					if neighbor_pos.y < 0 or neighbor_pos.y >= island_data.terrain_data.size() or \
					   neighbor_pos.x < 0 or neighbor_pos.x >= island_data.terrain_data[neighbor_pos.y].size():
						continue
					
					var neighbor_terrain = island_data.terrain_data[neighbor_pos.y][neighbor_pos.x]
					var neighbor_height = get_terrain_level_height(neighbor_terrain, neighbor_pos)
					
					# Create cliff face if we're higher than neighbor
					# Create cliff face if we're higher than neighbor (but skip small land-water transitions)
					var height_diff = current_height - neighbor_height
					if height_diff > 0.01:
	# Skip small land-water transitions (those will be slopes)
						if is_water_terrain(neighbor_terrain) and not is_water_terrain(terrain_type) and height_diff <= abs(water_bed_offset) + 0.1:
							continue
						var cliff_face_data = {
							"world_pos": world_pos,
							"edge_start": dir.edge_start,
							"edge_end": dir.edge_end,
							"normal": dir.normal,
							"height_diff": height_diff
						}
						
						# Separate water cliffs from land cliffs
						if is_water_terrain(terrain_type):
							if terrain_type not in water_cliff_groups:
								water_cliff_groups[terrain_type] = []
							water_cliff_groups[terrain_type].append(cliff_face_data)
						else:
							var terrain_level = get_terrain_level_from_type(terrain_type)
							if terrain_level not in land_cliff_groups:
								land_cliff_groups[terrain_level] = []
							land_cliff_groups[terrain_level].append(cliff_face_data)
	
	# Create cliff meshes
	for terrain_level in land_cliff_groups.keys():
		create_land_cliff_mesh(terrain_level, land_cliff_groups[terrain_level])
	
	for terrain_type in water_cliff_groups.keys():
		create_water_cliff_mesh(terrain_type, water_cliff_groups[terrain_type])

func create_land_cliff_mesh(terrain_level: int, cliff_faces: Array):
	"""RESTORED: Create land cliff mesh using dirt materials"""
	if cliff_faces.size() == 0:
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "LandCliffs_Level_" + str(terrain_level)
	
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	for cliff_data in cliff_faces:
		vertex_index = add_vertical_wall(
			vertices, normals, uvs, indices,
			cliff_data.world_pos,
			cliff_data.edge_start,
			cliff_data.edge_end,
			cliff_data.normal,
			cliff_data.height_diff,
			vertex_index
		)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Apply DIRT material based on terrain level
	var dirt_material = get_dirt_material_for_level(terrain_level)
	mesh_instance.material_override = dirt_material
	
	if create_collision:
		mesh_instance.create_trimesh_collision()
	
	if show_wireframe:
		var wireframe_material = dirt_material.duplicate()
		wireframe_material.flags_unshaded = true
		wireframe_material.wireframe = true
		mesh_instance.material_override = wireframe_material
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)

func create_water_cliff_mesh(terrain_type: int, cliff_faces: Array):
	"""RESTORED: Create water cliff mesh (waterfalls) using water materials"""
	if cliff_faces.size() == 0:
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "WaterCliffs_" + str(terrain_type)
	
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	for cliff_data in cliff_faces:
		vertex_index = add_vertical_wall(
			vertices, normals, uvs, indices,
			cliff_data.world_pos,
			cliff_data.edge_start,
			cliff_data.edge_end,
			cliff_data.normal,
			cliff_data.height_diff,
			vertex_index
		)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Keep water materials for beautiful blue waterfalls!
	if terrain_type in materials:
		mesh_instance.material_override = materials[terrain_type]
	
	if show_wireframe:
		var wireframe_material = materials[terrain_type].duplicate()
		wireframe_material.flags_unshaded = true
		wireframe_material.wireframe = true
		mesh_instance.material_override = wireframe_material
		
	if create_collision:
		mesh_instance.create_trimesh_collision()
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)
	
func create_water_bed_mesh(terrain_type: int, tiles: Array):
	"""Create water bed mesh (sandy bottom with collision)"""
	if tiles.size() == 0:
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "WaterBed_" + str(terrain_type)
	
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	for tile_data in tiles:
		var pos = tile_data.position
		var height = get_water_bed_height(pos)
		var world_pos = Vector3(pos.x * tile_size, height, pos.y * tile_size)
		
		vertex_index = add_horizontal_face(vertices, normals, uvs, indices, world_pos, vertex_index, true)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Apply bed material
	var bed_material_key = "bed_" + str(terrain_type)
	if bed_material_key in materials:
		mesh_instance.material_override = materials[bed_material_key]
	
	# Enable collision for bed
	if create_collision:
		mesh_instance.create_trimesh_collision()
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)

func create_water_surface_mesh(terrain_type: int, tiles: Array):
	"""Create water surface mesh (transparent blue, no collision)"""
	if tiles.size() == 0:
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "WaterSurface_" + str(terrain_type)
	
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	for tile_data in tiles:
		var pos = tile_data.position
		var height = get_water_surface_height(pos)
		var world_pos = Vector3(pos.x * tile_size, height, pos.y * tile_size)
		
		vertex_index = add_horizontal_face(vertices, normals, uvs, indices, world_pos, vertex_index, true)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Apply surface material
	var surface_material_key = "surface_" + str(terrain_type)
	if surface_material_key in materials:
		mesh_instance.material_override = materials[surface_material_key]
	
	# NO collision for water surface - players walk through it!
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)

func get_dirt_material_for_level(terrain_level: int) -> StandardMaterial3D:
	"""RESTORED: Get dirt material for terrain level"""
	match terrain_level:
		0:
			return materials[TerrainType.LEVEL0_DIRT]
		1:
			return materials[TerrainType.LEVEL1_DIRT]
		2:
			return materials[TerrainType.LEVEL2_DIRT] 
		3:
			return materials[TerrainType.LEVEL3_DIRT]
		_:
			return materials[TerrainType.LEVEL0_DIRT]

func add_vertical_wall(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, world_pos: Vector3, edge_start: Vector3, edge_end: Vector3, face_normal: Vector3, height_diff: float, vertex_index: int) -> int:
	"""RESTORED: Add a vertical wall face between height levels"""
	
	var top_start = world_pos + edge_start
	var top_end = world_pos + edge_end  
	var bottom_start = top_start - Vector3(0, height_diff, 0)
	var bottom_end = top_end - Vector3(0, height_diff, 0)
	
	# Add vertices
	vertices.append(bottom_start)
	vertices.append(bottom_end)
	vertices.append(top_end)
	vertices.append(top_start)
	
	# Add normals
	for i in range(4):
		normals.append(face_normal)
	
	# Add UVs
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))
	
	# Add triangles
	indices.append(vertex_index)
	indices.append(vertex_index + 1)
	indices.append(vertex_index + 2)
	
	indices.append(vertex_index)
	indices.append(vertex_index + 2)
	indices.append(vertex_index + 3)
	
	return vertex_index + 4

# ============================================================================
# UPDATED TERRAIN MESH GENERATION (now uses proper heights)
# ============================================================================

func create_terrain_chunks_from_data(island_data):
	"""Create terrain surfaces - separating water beds, water surfaces, and land"""
	var land_groups = {}
	var water_bed_groups = {}
	var water_surface_groups = {}
	
	for y in range(island_data.island_height):
		for x in range(island_data.island_width):
			if y < island_data.terrain_data.size() and x < island_data.terrain_data[y].size():
				var terrain_type = island_data.terrain_data[y][x]
				
				if is_water_terrain(terrain_type):
					# Separate water into bed and surface
					if terrain_type not in water_bed_groups:
						water_bed_groups[terrain_type] = []
					if terrain_type not in water_surface_groups:
						water_surface_groups[terrain_type] = []
					
					water_bed_groups[terrain_type].append({"position": Vector2i(x, y)})
					water_surface_groups[terrain_type].append({"position": Vector2i(x, y)})
				else:
					# Regular land terrain
					if terrain_type not in land_groups:
						land_groups[terrain_type] = []
					land_groups[terrain_type].append({"position": Vector2i(x, y)})
	
	# Create land meshes
	for terrain_type in land_groups.keys():
		create_terrain_mesh(terrain_type, land_groups[terrain_type], false)
	
	# Create water bed meshes (with collision)
	for terrain_type in water_bed_groups.keys():
		create_water_bed_mesh(terrain_type, water_bed_groups[terrain_type])
	
	# Create water surface meshes (no collision)
	for terrain_type in water_surface_groups.keys():
		create_water_surface_mesh(terrain_type, water_surface_groups[terrain_type])

func create_terrain_mesh(terrain_type: int, tiles: Array, is_water: bool = false):
	"""Create horizontal terrain mesh using RESTORED height system"""
	if tiles.size() == 0:
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Terrain_" + str(terrain_type)
	
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	for tile_data in tiles:
		var pos = tile_data.position
		var height = get_terrain_level_height(terrain_type, pos)  # RESTORED proper height!
		var world_pos = Vector3(pos.x * tile_size, height, pos.y * tile_size)
		
		# Create horizontal top face only (cliffs handled separately)
		vertex_index = add_horizontal_face(vertices, normals, uvs, indices, world_pos, vertex_index, true)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Apply material
	if terrain_type in materials:
		mesh_instance.material_override = materials[terrain_type]
	
	if create_collision:
		mesh_instance.create_trimesh_collision()
	
	if show_wireframe:
		var wireframe_material = materials[terrain_type].duplicate()
		wireframe_material.flags_unshaded = true
		wireframe_material.wireframe = true
		mesh_instance.material_override = wireframe_material
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)

func add_horizontal_face(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, world_pos: Vector3, vertex_index: int, face_up: bool = true) -> int:
	"""RESTORED: Add horizontal quad face"""
	var normal = Vector3.UP if face_up else Vector3.DOWN
	
	var quad_vertices = [
		world_pos + Vector3(-tile_size/2, 0, -tile_size/2),
		world_pos + Vector3(tile_size/2, 0, -tile_size/2),
		world_pos + Vector3(tile_size/2, 0, tile_size/2),
		world_pos + Vector3(-tile_size/2, 0, tile_size/2)
	]
	
	for vertex in quad_vertices:
		vertices.append(vertex)
		normals.append(normal)
	
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))
	
	if face_up:
		indices.append(vertex_index)
		indices.append(vertex_index + 1)
		indices.append(vertex_index + 2)
		indices.append(vertex_index)
		indices.append(vertex_index + 2)
		indices.append(vertex_index + 3)
	else:
		indices.append(vertex_index)
		indices.append(vertex_index + 2)
		indices.append(vertex_index + 1)
		indices.append(vertex_index)
		indices.append(vertex_index + 3)
		indices.append(vertex_index + 2)
	
	return vertex_index + 4
	
func create_sloped_transitions_from_data(island_data):
	"""Create 45-degree slopes where land meets water at same conceptual level"""
	var slope_faces = []
	
	for y in range(island_data.island_height):
		for x in range(island_data.island_width):
			if y < island_data.terrain_data.size() and x < island_data.terrain_data[y].size():
				var terrain_type = island_data.terrain_data[y][x]
				var current_height = get_terrain_level_height(terrain_type, Vector2i(x, y))
				
				# Only process land tiles
				if is_water_terrain(terrain_type):
					continue
				
				# Check each cardinal direction
				var directions = [
					{"offset": Vector2i(0, -1), "edge_start": Vector3(-tile_size/2, 0, -tile_size/2), "edge_end": Vector3(tile_size/2, 0, -tile_size/2), "normal": Vector3(0, 0, -1)},
					{"offset": Vector2i(1, 0), "edge_start": Vector3(tile_size/2, 0, -tile_size/2), "edge_end": Vector3(tile_size/2, 0, tile_size/2), "normal": Vector3(1, 0, 0)},
					{"offset": Vector2i(0, 1), "edge_start": Vector3(tile_size/2, 0, tile_size/2), "edge_end": Vector3(-tile_size/2, 0, tile_size/2), "normal": Vector3(0, 0, 1)},
					{"offset": Vector2i(-1, 0), "edge_start": Vector3(-tile_size/2, 0, tile_size/2), "edge_end": Vector3(-tile_size/2, 0, -tile_size/2), "normal": Vector3(-1, 0, 0)}
				]
				
				var world_pos = Vector3(x * tile_size, current_height, y * tile_size)
				
				for dir in directions:
					var neighbor_pos = Vector2i(x, y) + dir.offset
					
					# Check bounds
					if neighbor_pos.y < 0 or neighbor_pos.y >= island_data.terrain_data.size() or \
					   neighbor_pos.x < 0 or neighbor_pos.x >= island_data.terrain_data[neighbor_pos.y].size():
						continue
					
					var neighbor_terrain = island_data.terrain_data[neighbor_pos.y][neighbor_pos.x]
					var neighbor_height = get_terrain_level_height(neighbor_terrain, neighbor_pos)
					
					# Check if this is a land-water boundary with small height difference
					# Check if this is a land-water boundary - use bed height for proper depth
					var neighbor_bed_height = get_water_bed_height(neighbor_pos) if is_water_terrain(neighbor_terrain) else neighbor_height
					var height_diff = current_height - neighbor_bed_height
					if is_water_terrain(neighbor_terrain) and height_diff > 0.01 and height_diff <= abs(water_bed_offset) + 0.1:
						var slope_face_data = {
							"world_pos": world_pos,
							"edge_start": dir.edge_start,
							"edge_end": dir.edge_end,
							"normal": dir.normal,
							"height_diff": height_diff,
							"terrain_type": terrain_type
						}
						slope_faces.append(slope_face_data)
	
	# Create the slope mesh
	if slope_faces.size() > 0:
		create_slope_mesh(slope_faces)

func create_slope_mesh(slope_faces: Array):
	"""Create 45-degree slope mesh for land-water transitions"""
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "SlopeTransitions"
	
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	for slope_data in slope_faces:
		vertex_index = add_sloped_face(
			vertices, normals, uvs, indices,
			slope_data.world_pos,
			slope_data.edge_start,
			slope_data.edge_end,
			slope_data.normal,
			slope_data.height_diff,
			vertex_index
		)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Use beach/sand material for slopes
	mesh_instance.material_override = materials[TerrainType.BEACH]
	
	if create_collision:
		mesh_instance.create_trimesh_collision()
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)

func add_sloped_face(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, world_pos: Vector3, edge_start: Vector3, edge_end: Vector3, face_normal: Vector3, height_diff: float, vertex_index: int) -> int:
	"""Add a 45-degree sloped face for smooth transitions"""
	
	var top_start = world_pos + edge_start
	var top_end = world_pos + edge_end
	
	# Create slope by extending horizontally by the height difference
	var slope_direction = face_normal * height_diff
	var bottom_start = top_start - Vector3(0, height_diff, 0) + slope_direction
	var bottom_end = top_end - Vector3(0, height_diff, 0) + slope_direction
	
	# Add vertices (forming a sloped quad)
	vertices.append(bottom_start)
	vertices.append(bottom_end)
	vertices.append(top_end)
	vertices.append(top_start)
	
	# Calculate slope normal (45 degrees)
	var slope_normal = (Vector3.UP + face_normal).normalized()
	
	# Add normals
	for i in range(4):
		normals.append(slope_normal)
	
	# Add UVs
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))
	
	# Add triangles
	indices.append(vertex_index)
	indices.append(vertex_index + 1)
	indices.append(vertex_index + 2)
	
	indices.append(vertex_index)
	indices.append(vertex_index + 2)
	indices.append(vertex_index + 3)
	
	return vertex_index + 4
	
func create_corner_triangles_from_data(island_data):
	"""Create triangular corner pieces where two slope edges meet - SIMPLE VERSION"""
	var corner_faces = []
	
	print("=== CORNER DETECTION DEBUG ===")
	
	for y in range(island_data.island_height):
		for x in range(island_data.island_width):
			if y < island_data.terrain_data.size() and x < island_data.terrain_data[y].size():
				var terrain_type = island_data.terrain_data[y][x]
				
				# Only process land tiles
				if is_water_terrain(terrain_type):
					continue
				
				var current_height = get_terrain_level_height(terrain_type, Vector2i(x, y))
				
				# Check the 4 corners - simplified detection
				var corners = [
					{"water_dirs": [Vector2i(0, -1), Vector2i(1, 0)], "corner_offset": Vector3(0.5, 0, -0.5), "name": "NE"},
					{"water_dirs": [Vector2i(1, 0), Vector2i(0, 1)], "corner_offset": Vector3(0.5, 0, 0.5), "name": "SE"},
					{"water_dirs": [Vector2i(0, 1), Vector2i(-1, 0)], "corner_offset": Vector3(-0.5, 0, 0.5), "name": "SW"},
					{"water_dirs": [Vector2i(-1, 0), Vector2i(0, -1)], "corner_offset": Vector3(-0.5, 0, -0.5), "name": "NW"}
				]
				
				for corner in corners:
					var water_count = 0
					var valid_slopes = 0
					
					# Check if both directions have water that would create slopes
					for water_dir in corner.water_dirs:
						var neighbor_pos = Vector2i(x, y) + water_dir
						
						# Check bounds
						if neighbor_pos.y >= 0 and neighbor_pos.y < island_data.terrain_data.size() and \
						   neighbor_pos.x >= 0 and neighbor_pos.x < island_data.terrain_data[neighbor_pos.y].size():
							
							var neighbor_terrain = island_data.terrain_data[neighbor_pos.y][neighbor_pos.x]
							if is_water_terrain(neighbor_terrain):
								water_count += 1
								var neighbor_height = get_terrain_level_height(neighbor_terrain, neighbor_pos)
								var height_diff = current_height - neighbor_height
								
								# Check if this would create a slope (same logic as slopes)
								if height_diff > 0.01 and height_diff <= abs(water_bed_offset) + 0.1:
									valid_slopes += 1
					
					# If both adjacent sides have water that create slopes, we need a corner
					if water_count == 2 and valid_slopes == 2:
						
						corner_faces.append({
							"tile_pos": Vector2i(x, y),
							"world_pos": Vector3(x * tile_size, current_height, y * tile_size),
							"corner_offset": corner.corner_offset * tile_size,
							"height": current_height,
							"corner_name": corner.name
						})
	
	print("Total corners found: ", corner_faces.size())
	
	# Create the corner mesh
	if corner_faces.size() > 0:
		create_corner_mesh_simple(corner_faces)
	else:
		print("No corners detected!")

func create_corner_mesh_simple(corner_faces: Array):
	"""Create simple triangular corner pieces - FULLY FIXED VERSION"""
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "CornerTransitions"
	
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	print("Creating corner mesh with ", corner_faces.size(), " corners")
	
	for corner_data in corner_faces:
		var world_pos = corner_data.world_pos
		var corner_offset = corner_data.corner_offset
		var height = corner_data.height
		var corner_name = corner_data.corner_name
		
		# Create triangle that exactly matches where slope edges would meet
		var top_vertex = world_pos + corner_offset  # Top corner of land tile
		
		# Calculate where slope edges would actually intersect
		# Slopes extend outward by height_diff amount for 45-degree angle
		var height_diff = abs(water_bed_offset)
		
		# Bottom points should be exactly where two slope edges meet
		var bottom1: Vector3
		var bottom2: Vector3
		
		match corner_name:
			"NE":  # Northeast corner - slopes go North and East
				bottom1 = top_vertex + Vector3(height_diff, -height_diff, 0)      # East slope endpoint
				bottom2 = top_vertex + Vector3(0, -height_diff, -height_diff)     # North slope endpoint
			"SE":  # Southeast corner - slopes go South and East  
				bottom1 = top_vertex + Vector3(height_diff, -height_diff, 0)      # East slope endpoint
				bottom2 = top_vertex + Vector3(0, -height_diff, height_diff)      # South slope endpoint
			"SW":  # Southwest corner - slopes go South and West
				bottom1 = top_vertex + Vector3(-height_diff, -height_diff, 0)     # West slope endpoint
				bottom2 = top_vertex + Vector3(0, -height_diff, height_diff)      # South slope endpoint
			"NW":  # Northwest corner - slopes go North and West
				bottom1 = top_vertex + Vector3(-height_diff, -height_diff, 0)     # West slope endpoint  
				bottom2 = top_vertex + Vector3(0, -height_diff, -height_diff)     # North slope endpoint
		
		# Add vertices with CORRECT winding order for each corner
		match corner_name:
			"NE":  # Northeast corner - need to swap order
				vertices.append(top_vertex)
				vertices.append(bottom2)  # North first
				vertices.append(bottom1)  # East second
			"SE":  # Southeast corner - order is correct
				vertices.append(top_vertex)
				vertices.append(bottom1)  # East first  
				vertices.append(bottom2)  # South second
			"SW":  # Southwest corner - need to swap order
				vertices.append(top_vertex)
				vertices.append(bottom2)  # South first
				vertices.append(bottom1)  # West second
			"NW":  # Northwest corner - order is correct
				vertices.append(top_vertex)
				vertices.append(bottom1)  # West first
				vertices.append(bottom2)  # North second
		
		# Calculate proper normal
		var v1 = vertices[vertex_index + 1] - vertices[vertex_index]
		var v2 = vertices[vertex_index + 2] - vertices[vertex_index]
		var normal = v1.cross(v2).normalized()
		
		# Ensure normal points upward
		if normal.y < 0:
			normal = -normal
		
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
		
		# UVs
		uvs.append(Vector2(0.5, 0.5))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(0, 0))
		
		# Triangle indices
		indices.append(vertex_index)
		indices.append(vertex_index + 1)
		indices.append(vertex_index + 2)
		
		vertex_index += 3
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Use beach material to match slopes
	mesh_instance.material_override = materials[TerrainType.BEACH]
	
	if create_collision:
		mesh_instance.create_trimesh_collision()
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)
	
	print("Corner mesh created successfully!")

func add_corner_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, world_pos: Vector3, corner_pos: Vector3, water_height: float, vertex_index: int) -> int:
	"""Add a single triangle to fill corner gap"""
	
	var height_diff = world_pos.y - water_height
	
	# Triangle vertices
	var top_corner = world_pos + corner_pos  # Top of land tile at corner
	var bottom_corner = top_corner - Vector3(0, height_diff, 0) + Vector3(corner_pos.x, 0, corner_pos.z).normalized() * height_diff  # Bottom projected outward
	var mid_point = (top_corner + bottom_corner) * 0.5  # Mid point for better triangle
	
	# Add vertices 
	vertices.append(top_corner)
	vertices.append(bottom_corner)
	vertices.append(mid_point)
	
	# Calculate normal (roughly 45 degrees outward)
	var corner_normal = (Vector3.UP + Vector3(corner_pos.x, 0, corner_pos.z).normalized()).normalized()
	
	# Add normals
	for i in range(3):
		normals.append(corner_normal)
	
	# Add UVs
	uvs.append(Vector2(0.5, 1))
	uvs.append(Vector2(0.5, 0))
	uvs.append(Vector2(0, 0.5))
	
	# Add triangle
	indices.append(vertex_index)
	indices.append(vertex_index + 1)
	indices.append(vertex_index + 2)
	
	return vertex_index + 3

# ============================================================================
# YOUR EXISTING PUBLIC INTERFACE (keeping unchanged)
# ============================================================================

func has_island_rendered() -> bool:
	return is_rendered and current_island_data != null

func get_terrain_info_at_position(world_pos: Vector3) -> Dictionary:
	if not current_island_data:
		return {}
	
	var tile_x = int(world_pos.x / tile_size + 0.5)
	var tile_z = int(world_pos.z / tile_size + 0.5)
	
	if tile_x < 0 or tile_x >= current_island_data.island_width or tile_z < 0 or tile_z >= current_island_data.island_height:
		return {}
	
	var terrain_type = current_island_data.terrain_data[tile_z][tile_x]
	var height = get_terrain_level_height(terrain_type, Vector2i(tile_x, tile_z))  # Using proper height now!
	
	return {
		"terrain_type": terrain_type,
		"height": height,
		"tile_position": Vector2i(tile_x, tile_z),
		"world_position": world_pos
	}

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		refresh_3d_view()
		print("Island3DRenderer: Manual refresh triggered")
	
	if event.is_action_pressed("ui_up"):
		show_wireframe = !show_wireframe
		refresh_3d_view()
		print("Island3DRenderer: Wireframe mode: ", show_wireframe)

func replace_terrain_material(terrain_type: int, new_material: Material):
	materials[terrain_type] = new_material
	refresh_3d_view()

func export_terrain_layout() -> Dictionary:
	if not current_island_data:
		return {}
	
	return {
		"island_width": current_island_data.island_width,
		"island_height": current_island_data.island_height,
		"terrain_data": current_island_data.terrain_data,
		"height_data": current_island_data.height_data,
		"tile_size": tile_size,
		"height_scale": height_scale
	}

# ============================================================================
# PLAYER SPAWNING INTEGRATION
# ============================================================================

func get_island_center_position() -> Vector3:
	"""Get the world position of the island center with proper ground height"""
	print("\n=== CALCULATING ISLAND CENTER ===")
	
	if not current_island_data:
		print("ERROR: No island data available for center calculation")
		print("current_island_data is null!")
		return Vector3.ZERO
	
	print("Island data found:")
	print("- Width:", current_island_data.island_width)
	print("- Height:", current_island_data.island_height)
	print("- Has terrain data:", current_island_data.terrain_data != null)
	
	# Calculate center tile position
	var center_x = current_island_data.island_width / 2.0
	var center_z = current_island_data.island_height / 2.0
	var center_tile = Vector2i(int(center_x), int(center_z))
	
	print("- Calculated center tile:", center_tile)
	
	# Check bounds
	if center_tile.y >= current_island_data.terrain_data.size() or center_tile.x >= current_island_data.terrain_data[center_tile.y].size():
		print("ERROR: Center tile out of bounds!")
		return Vector3.ZERO
	
	# Get terrain type at center
	var terrain_type = current_island_data.terrain_data[center_tile.y][center_tile.x]
	print("- Terrain type at center:", terrain_type)
	
	# Find nearest land if center is water
	if is_water_terrain(terrain_type):
		print("- Center is water, finding nearest land...")
		center_tile = find_nearest_land_tile(center_tile)
		terrain_type = current_island_data.terrain_data[center_tile.y][center_tile.x]
		print("- New center tile:", center_tile)
		print("- New terrain type:", terrain_type)
	
	# Calculate world position with proper height
	var world_x = center_tile.x * tile_size
	var world_z = center_tile.y * tile_size
	var world_y = get_terrain_level_height(terrain_type, center_tile)
	
	print("- World position calculation:")
	print("  - world_x:", world_x, "(tile", center_tile.x, "* size", tile_size, ")")
	print("  - world_z:", world_z, "(tile", center_tile.y, "* size", tile_size, ")")
	print("  - world_y:", world_y)
	
	var center_pos = Vector3(world_x, world_y + 0.5, world_z)
	
	print("- Final center position:", center_pos)
	print("=================================\n")
	return center_pos

func find_nearest_land_tile(start_pos: Vector2i) -> Vector2i:
	"""Find the nearest land tile if spawning position is in water"""
	var max_search_radius = 20
	
	for radius in range(1, max_search_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) < radius and abs(dy) < radius:
					continue
					
				var check_pos = start_pos + Vector2i(dx, dy)
				
				# Check bounds
				if check_pos.y < 0 or check_pos.y >= current_island_data.island_height or \
				   check_pos.x < 0 or check_pos.x >= current_island_data.island_width:
					continue
				
				var terrain_type = current_island_data.terrain_data[check_pos.y][check_pos.x]
				
				# Found land!
				if not is_water_terrain(terrain_type):
					print("Island3DRenderer: Found land at tile: ", check_pos)
					return check_pos
	
	# Fallback to original position if no land found
	print("Island3DRenderer: Warning - No land found, using original position")
	return start_pos

func get_island_dimensions() -> Dictionary:
	"""Get island size info for camera setup"""
	if not current_island_data:
		return {}
	
	return {
		"width": current_island_data.island_width,
		"height": current_island_data.island_height,
		"tile_size": tile_size,
		"center_position": get_island_center_position()
	}
