extends Node3D

# ============================================================================
# BASIC 3D ISLAND RENDERER
# ============================================================================
# This script takes the 2D tilemap data from your island generator and 
# creates a basic 3D representation using simple meshes. Artists can later
# replace these with proper models and textures.

@export_group("3D Rendering Settings")
@export var tile_size: float = 1.0
@export var height_scale: float = 5.0
@export var water_level_offset: float = -0.5
@export var enable_auto_refresh: bool = true
@export var show_debug_info: bool = true

@export_group("Mesh Settings")
@export var use_smooth_normals: bool = true
@export var generate_uvs: bool = true
@export var create_collision: bool = false

@export_group("Visual Settings")
@export var show_wireframe: bool = false
@export var ambient_light_intensity: float = 0.3

# Materials for different terrain types
var materials: Dictionary = {}
var mesh_instances: Array[MeshInstance3D] = []
var island_generator: TileMapLayer

# Terrain type mapping from your original code
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
	setup_materials()
	setup_lighting()
	find_island_generator()
	
	if island_generator and enable_auto_refresh:
		# Connect to the island generator if it has signals
		if island_generator.has_signal("generation_complete"):
			island_generator.generation_complete.connect(_on_island_generated)
		else:
			# Otherwise, check periodically
			var timer = Timer.new()
			timer.wait_time = 2.0
			timer.timeout.connect(_check_for_new_data)
			timer.autostart = true
			add_child(timer)

func find_island_generator():
	# Try to find the island generator in various locations
	island_generator = get_node_or_null("../IslandGenerator")
	if not island_generator:
		island_generator = get_tree().get_first_node_in_group("island_generator")
	if not island_generator:
		for node in get_tree().get_nodes_in_group("island_generator"):
			if node is TileMapLayer:
				island_generator = node
				break
	
	if island_generator:
		print("Found island generator: ", island_generator.name)
		render_island()
	else:
		print("Island generator not found - will search again later")

func setup_lighting():
	# Add basic directional light for the scene
	var light = DirectionalLight3D.new()
	light.name = "MainLight"
	light.position = Vector3(0, 10, 5)
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)
	
	# Add ambient light
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = ambient_light_intensity
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		camera.environment = environment

func setup_materials():
	# Create basic materials for each terrain type
	# Artists can replace these with proper materials later
	
	# Water materials
	materials[TerrainType.DEEP_OCEAN] = create_water_material(Color(0.1, 0.2, 0.6, 0.8), true)
	materials[TerrainType.SHALLOW_SALTWATER] = create_water_material(Color(0.2, 0.4, 0.8, 0.7), false)
	materials[TerrainType.SHALLOW_FRESHWATER] = create_water_material(Color(0.3, 0.6, 0.8, 0.7), false)
	materials[TerrainType.DEEP_FRESHWATER_POND] = create_water_material(Color(0.2, 0.3, 0.7, 0.8), true)
	
	# River materials
	materials[TerrainType.RIVER] = create_water_material(Color(0.4, 0.7, 0.9, 0.7), false)
	materials[TerrainType.RIVER_1] = create_water_material(Color(0.4, 0.7, 0.9, 0.7), false)
	materials[TerrainType.RIVER_2] = create_water_material(Color(0.4, 0.7, 0.9, 0.7), false)
	materials[TerrainType.RIVER_3] = create_water_material(Color(0.4, 0.7, 0.9, 0.7), false)
	materials[TerrainType.RIVER_MOUTH] = create_water_material(Color(0.5, 0.8, 0.9, 0.6), false)
	
	# Land materials
	materials[TerrainType.BEACH] = create_land_material(Color(0.9, 0.8, 0.6))
	materials[TerrainType.LEVEL0_GRASS] = create_land_material(Color(0.3, 0.6, 0.2))
	materials[TerrainType.LEVEL0_DIRT] = create_land_material(Color(0.6, 0.4, 0.2))
	materials[TerrainType.LEVEL1_GRASS] = create_land_material(Color(0.4, 0.7, 0.3))
	materials[TerrainType.LEVEL1_DIRT] = create_land_material(Color(0.7, 0.5, 0.3))
	materials[TerrainType.LEVEL2_GRASS] = create_land_material(Color(0.5, 0.8, 0.4))
	materials[TerrainType.LEVEL2_DIRT] = create_land_material(Color(0.8, 0.6, 0.4))
	materials[TerrainType.LEVEL3_GRASS] = create_land_material(Color(0.6, 0.9, 0.5))
	materials[TerrainType.LEVEL3_DIRT] = create_land_material(Color(0.9, 0.7, 0.5))

func create_water_material(color: Color, is_deep: bool) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.1
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if is_deep:
		material.emission_enabled = true
		material.emission = Color(0.0, 0.1, 0.3) * 0.2
	
	# Add some basic reflection
	material.clearcoat_enabled = true
	material.clearcoat = 0.3
	
	return material

func create_land_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.8
	
	# Add slight variation to make it look more natural
	material.emission_enabled = true
	material.emission = color * 0.05
	
	return material

# ============================================================================
# 3D RENDERING FUNCTIONS
# ============================================================================

func render_island():
	if not island_generator:
		print("No island generator found")
		return
	
	print("Starting 3D island rendering...")
	clear_existing_meshes()
	
	# Get island data
	var island_width = island_generator.get("island_width")
	var island_height = island_generator.get("island_height")
	var terrain_data = island_generator.get("terrain_data")
	var height_data = island_generator.get("height_data")
	
	if not terrain_data or not height_data:
		print("Island data not ready yet")
		return
	
	print("Island dimensions: ", island_width, "x", island_height)
	
	# Create 3D representation
	create_terrain_chunks(island_width, island_height, terrain_data, height_data)
	
	# Center the camera on the island
	setup_camera_position(island_width, island_height)
	
	print("3D island rendering complete!")

func clear_existing_meshes():
	for mesh_instance in mesh_instances:
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
	mesh_instances.clear()

func create_terrain_chunks(island_width: int, island_height: int, terrain_data: Array, height_data: Array):
	# Group tiles by terrain type for efficient rendering
	var terrain_groups = {}
	
	for y in range(island_height):
		for x in range(island_width):
			if y < terrain_data.size() and x < terrain_data[y].size():
				var terrain_type = terrain_data[y][x]
				var height = height_data[y][x] if y < height_data.size() and x < height_data[y].size() else 0.0
				
				if terrain_type not in terrain_groups:
					terrain_groups[terrain_type] = []
				
				terrain_groups[terrain_type].append({
					"position": Vector2i(x, y),
					"height": height
				})
	
	# Create meshes for each terrain type
	for terrain_type in terrain_groups.keys():
		create_terrain_mesh(terrain_type, terrain_groups[terrain_type])

func create_terrain_mesh(terrain_type: int, tiles: Array):
	if tiles.size() == 0:
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Terrain_" + str(terrain_type)
	
	# Create the mesh
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_index = 0
	
	for tile_data in tiles:
		var pos = tile_data.position
		var height = tile_data.height * height_scale
		
		# Adjust height for water tiles
		if is_water_terrain(terrain_type):
			height += water_level_offset
		
		# Create a simple quad for each tile
		var world_pos = Vector3(pos.x * tile_size, height, pos.y * tile_size)
		
		# Define quad vertices (facing up)
		var quad_vertices = [
			world_pos + Vector3(-tile_size/2, 0, -tile_size/2),  # Bottom-left
			world_pos + Vector3(tile_size/2, 0, -tile_size/2),   # Bottom-right
			world_pos + Vector3(tile_size/2, 0, tile_size/2),    # Top-right
			world_pos + Vector3(-tile_size/2, 0, tile_size/2)    # Top-left
		]
		
		# Add vertices
		for vertex in quad_vertices:
			vertices.append(vertex)
		
		# Add normals (pointing up for now - can be improved later)
		for i in range(4):
			normals.append(Vector3.UP)
		
		# Add UVs
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		
		# Add indices for two triangles forming a quad
		indices.append(vertex_index)
		indices.append(vertex_index + 1)
		indices.append(vertex_index + 2)
		
		indices.append(vertex_index)
		indices.append(vertex_index + 2)
		indices.append(vertex_index + 3)
		
		vertex_index += 4
	
	# Create the mesh
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
	
	# Add collision if enabled
	if create_collision and not is_water_terrain(terrain_type):
		mesh_instance.create_trimesh_collision()
	
	# Enable wireframe mode if requested
	if show_wireframe:
		var wireframe_material = materials[terrain_type].duplicate()
		wireframe_material.flags_unshaded = true
		wireframe_material.wireframe = true
		mesh_instance.material_override = wireframe_material
	
	add_child(mesh_instance)
	mesh_instances.append(mesh_instance)

func is_water_terrain(terrain_type: int) -> bool:
	return terrain_type in [
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

func setup_camera_position(island_width: int, island_height: int):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		# Create a basic camera if none exists
		camera = Camera3D.new()
		add_child(camera)
	
	# Position camera to view the entire island
	var center_x = (island_width * tile_size) / 2.0
	var center_z = (island_height * tile_size) / 2.0
	var camera_height = max(island_width, island_height) * tile_size * 0.8
	
	camera.position = Vector3(center_x, camera_height, center_z + island_height * tile_size * 0.3)
	camera.look_at(Vector3(center_x, 0, center_z), Vector3.UP)

# ============================================================================
# UPDATE AND REFRESH FUNCTIONS
# ============================================================================

func _check_for_new_data():
	if not island_generator:
		find_island_generator()
		return
	
	# Check if the island generator has new data
	var terrain_data = island_generator.get("terrain_data")
	if terrain_data and terrain_data.size() > 0:
		render_island()

func _on_island_generated():
	print("Island generation complete - updating 3D view")
	render_island()

func refresh_3d_view():
	"""Call this function to manually refresh the 3D view"""
	render_island()

# ============================================================================
# DEBUG AND UTILITY FUNCTIONS
# ============================================================================

func _input(event):
	if event.is_action_pressed("ui_select"):  # Typically spacebar
		refresh_3d_view()
		print("3D view refreshed manually")
	
	if event.is_action_pressed("ui_up"):  # Toggle wireframe
		show_wireframe = !show_wireframe
		render_island()
		print("Wireframe mode: ", show_wireframe)

func get_terrain_info_at_position(world_pos: Vector3) -> Dictionary:
	"""Get terrain information at a world position - useful for gameplay"""
	if not island_generator:
		return {}
	
	var tile_x = int(world_pos.x / tile_size + 0.5)
	var tile_z = int(world_pos.z / tile_size + 0.5)
	
	var terrain_type = island_generator.call("get_terrain_at", tile_x, tile_z)
	var height = island_generator.call("get_height_at", tile_x, tile_z)
	
	return {
		"terrain_type": terrain_type,
		"height": height,
		"tile_position": Vector2i(tile_x, tile_z),
		"world_position": world_pos
	}

func print_debug_info():
	if not show_debug_info:
		return
	
	print("\n=== 3D Renderer Debug Info ===")
	print("Mesh instances created: ", mesh_instances.size())
	print("Tile size: ", tile_size)
	print("Height scale: ", height_scale)
	print("Materials loaded: ", materials.size())
	print("Island generator found: ", island_generator != null)
	if island_generator:
		var island_width = island_generator.get("island_width")
		var island_height = island_generator.get("island_height")
		print("Island dimensions: ", island_width, "x", island_height)
	print("==============================\n")

# ============================================================================
# ARTIST-FRIENDLY FUNCTIONS
# ============================================================================

func replace_terrain_material(terrain_type: int, new_material: Material):
	"""Replace a terrain material - useful for artists testing new materials"""
	materials[terrain_type] = new_material
	render_island()  # Refresh to apply new material

func replace_terrain_with_scene(terrain_type: int, scene_path: String):
	"""Replace simple meshes with complex 3D models - for future use"""
	# This is a placeholder for when you want to replace simple quads
	# with actual 3D models loaded from .tscn or .gltf files
	print("TODO: Implement scene replacement for terrain type: ", terrain_type)
	print("Scene path: ", scene_path)

func export_terrain_layout() -> Dictionary:
	"""Export terrain layout data for external tools"""
	if not island_generator:
		return {}
	
	return {
		"island_width": island_generator.get("island_width"),
		"island_height": island_generator.get("island_height"),
		"terrain_data": island_generator.get("terrain_data"),
		"height_data": island_generator.get("height_data"),
		"tile_size": tile_size,
		"height_scale": height_scale
	}
