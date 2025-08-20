extends Node3D
class_name ResourceSpawner

# ============================================================================
# RESOURCE SPAWNER - Visual representation of terrain resources
# ============================================================================

signal resource_collected(resource_type: String, world_pos: Vector3)

@export_group("Spawner Settings")
@export var auto_create_visuals: bool = true
@export var resource_interaction_range: float = 2.0
@export var show_interaction_prompts: bool = true
@export var enable_resource_collection: bool = true

@export_group("Visual Settings")
@export var resource_scale: float = 1.0
@export var add_collision: bool = true
@export var show_debug_names: bool = false

# ============================================================================
# CORE DATA
# ============================================================================

var terrain_manager: TerrainManager
var spawned_visual_resources: Array = []
var player_reference: Node = null

# Resource visual cache (so we don't recreate meshes)
var resource_meshes: Dictionary = {}
var resource_materials: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("resource_spawner")
	print("ResourceSpawner: Initializing...")
	
	# Find terrain manager
	terrain_manager = get_node_or_null("../TerrainManager")
	if not terrain_manager:
		terrain_manager = get_tree().get_first_node_in_group("terrain_manager")
	
	if terrain_manager:
		print("ResourceSpawner: Connected to TerrainManager")
		terrain_manager.resource_spawned.connect(_on_resource_spawned)
		terrain_manager.resource_collected.connect(_on_resource_collected)
		
		# Wait for terrain manager to be fully ready before creating visuals
		if terrain_manager.current_island_data == null:
			print("ResourceSpawner: Waiting for TerrainManager to initialize...")
			terrain_manager.terrain_updated.connect(_on_terrain_ready)
		else:
			call_deferred("create_visuals_when_ready")
	else:
		print("ResourceSpawner: No TerrainManager found!")
	
	# Find player for interaction
	call_deferred("find_player")
	
	# Create resource meshes and materials
	setup_resource_visuals()

func _on_terrain_ready():
	"""Called when terrain manager finishes initializing"""
	print("ResourceSpawner: Terrain ready, creating visuals...")
	call_deferred("create_visuals_when_ready")

func create_visuals_when_ready():
	"""Create visuals only after terrain manager is ready"""
	if terrain_manager and terrain_manager.spawned_resources.size() > 0:
		# Clear any existing visuals first
		clear_all_visuals()
		# Create visuals for terrain manager's resources
		create_all_existing_resource_visuals()
		print("ResourceSpawner: Created visuals for ", terrain_manager.spawned_resources.size(), " resources")

func find_player():
	"""Find player reference for interactions"""
	player_reference = get_tree().get_first_node_in_group("player")
	if not player_reference:
		# Try common player names
		player_reference = get_node_or_null("../Player")
	
	if player_reference:
		print("ResourceSpawner: Found player reference")

# ============================================================================
# RESOURCE VISUAL CREATION
# ============================================================================

func setup_resource_visuals():
	"""Create meshes and materials for different resource types"""
	print("ResourceSpawner: Setting up resource visuals...")
	
	# Trees (trunk and crown separate)
	resource_meshes["small_tree_trunk"] = create_tree_mesh(1.0, 0.6)
	resource_meshes["small_tree_crown"] = create_tree_crown_mesh(1.0, 0.6)
	resource_meshes["oak_tree_trunk"] = create_tree_mesh(2.0, 1.2)
	resource_meshes["oak_tree_crown"] = create_tree_crown_mesh(2.0, 1.2)
	resource_meshes["ancient_tree_trunk"] = create_tree_mesh(3.5, 2.0)
	resource_meshes["ancient_tree_crown"] = create_tree_crown_mesh(3.5, 2.0)
	
	# Pine trees (keep as single mesh - already looks good)
	resource_meshes["pine_tree"] = create_pine_mesh(2.5, 0.8)
	
	# Stones
	resource_meshes["stone_small"] = create_rock_mesh(0.3)
	resource_meshes["stone_medium"] = create_rock_mesh(0.6)
	
	# Special resources
	resource_meshes["crystal_node"] = create_crystal_mesh()  # Now bigger!
	resource_meshes["berry_bush"] = create_bush_mesh()
	
	# Beach resources
	resource_meshes["driftwood"] = create_log_mesh()
	resource_meshes["seashell"] = create_shell_mesh()
	
	# Water resources
	resource_meshes["water_lily"] = create_lily_mesh()
	resource_meshes["reed"] = create_reed_mesh()
	
	# Materials
	resource_materials["trunk"] = create_trunk_material()  # NEW!
	resource_materials["tree_crown"] = create_tree_material()  # Renamed
	resource_materials["pine"] = create_pine_material()
	resource_materials["ancient_crown"] = create_ancient_tree_material()
	resource_materials["stone"] = create_stone_material()
	resource_materials["crystal"] = create_crystal_material()
	resource_materials["berry"] = create_berry_material()
	resource_materials["wood"] = create_wood_material()
	resource_materials["shell"] = create_shell_material()
	resource_materials["water_plant"] = create_water_plant_material()

# ============================================================================
# MESH CREATORS
# ============================================================================

func create_tree_mesh(height: float, trunk_radius: float) -> ArrayMesh:
	"""Create TRUNK ONLY - we'll make crown separately"""
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	var segments = 8
	var trunk_height = height * 0.7
	
	for i in range(segments + 1):
		var angle = i * PI * 2.0 / segments
		var x = cos(angle) * trunk_radius * 0.15  # Slightly thicker trunk
		var z = sin(angle) * trunk_radius * 0.15
		
		# Bottom vertex
		vertices.append(Vector3(x, 0, z))
		normals.append(Vector3(x, 0, z).normalized())
		
		# Top vertex
		vertices.append(Vector3(x, trunk_height, z))
		normals.append(Vector3(x, 0, z).normalized())
	
	# Create trunk triangles
	for i in range(segments):
		var base = i * 2
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 1)
		
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 3)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

func create_tree_crown_mesh(height: float, crown_radius: float) -> ArrayMesh:
	"""Create tree crown as separate mesh"""
	var array_mesh = ArrayMesh.new()
	
	# Use a proper sphere for the crown
	var sphere = SphereMesh.new()
	sphere.radius = crown_radius * 0.8
	sphere.height = crown_radius * 1.2
	sphere.radial_segments = 8
	sphere.rings = 6
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sphere.get_mesh_arrays())
	return array_mesh

func create_pine_mesh(height: float, base_radius: float) -> ArrayMesh:
	"""Create a pine tree (cone shape)"""
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	var segments = 8
	
	# Base center
	vertices.append(Vector3(0, 0.1, 0))
	normals.append(Vector3.UP)
	
	# Top point
	vertices.append(Vector3(0, height, 0))
	normals.append(Vector3.UP)
	
	# Base circle
	for i in range(segments):
		var angle = i * PI * 2.0 / segments
		var x = cos(angle) * base_radius * 0.3
		var z = sin(angle) * base_radius * 0.3
		
		vertices.append(Vector3(x, 0, z))
		normals.append(Vector3(x, 0.5, z).normalized())  # Sloped normal
		
		# Create triangles
		var next_i = (i + 1) % segments
		
		# Base triangle
		indices.append(0)
		indices.append(i + 2)
		indices.append(next_i + 2)
		
		# Side triangle
		indices.append(1)
		indices.append(next_i + 2)
		indices.append(i + 2)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

func create_rock_mesh(size: float) -> ArrayMesh:
	"""Create a simple rock mesh (deformed cube)"""
	var array_mesh = ArrayMesh.new()
	
	# Create a cube and deform it slightly
	var cube_size = size
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Cube vertices with slight random deformation
	var base_vertices = [
		Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),  # Back face
		Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)      # Front face
	]
	
	for vertex in base_vertices:
		# Add slight randomness to make it look like a rock
		var deform = Vector3(
			randf_range(-0.4, 0.4),
			randf_range(-0.3, 0.3),
			randf_range(-0.7, 0.7)
		)
		vertices.append((vertex + deform) * cube_size)
		normals.append(vertex.normalized())
	
	# Cube indices
	var cube_indices = [
		0, 1, 2, 0, 2, 3,  # Back
		4, 6, 5, 4, 7, 6,  # Front  
		0, 4, 5, 0, 5, 1,  # Bottom
		2, 6, 7, 2, 7, 3,  # Top
		0, 3, 7, 0, 7, 4,  # Left
		1, 5, 6, 1, 6, 2   # Right
	]
	
	for idx in cube_indices:
		indices.append(idx)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

func create_crystal_mesh() -> ArrayMesh:
	"""Create a BIG IMPRESSIVE crystal/gem mesh (diamond shape)"""
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# BIGGER diamond shape vertices
	var height = 1.8      # Much taller!
	var width = 0.6       # Much wider!
	
	vertices.append(Vector3(0, height, 0))      # Top point
	vertices.append(Vector3(0, -height*0.3, 0)) # Bottom point
	vertices.append(Vector3(width, height*0.3, 0))       # Right
	vertices.append(Vector3(-width, height*0.3, 0))      # Left  
	vertices.append(Vector3(0, height*0.3, width))       # Forward
	vertices.append(Vector3(0, height*0.3, -width))      # Back
	
	# Middle ring for more interesting shape
	vertices.append(Vector3(width*0.7, 0, 0))       # Mid-Right
	vertices.append(Vector3(-width*0.7, 0, 0))      # Mid-Left  
	vertices.append(Vector3(0, 0, width*0.7))       # Mid-Forward
	vertices.append(Vector3(0, 0, -width*0.7))      # Mid-Back
	
	# Normals (pointing outward from center)
	for vertex in vertices:
		normals.append(vertex.normalized())
	
	# More complex diamond faces
	var diamond_indices = [
		# Top pyramid
		0, 2, 4,  0, 4, 3,  0, 3, 5,  0, 5, 2,
		# Upper middle sections
		2, 6, 4,  4, 8, 3,  3, 7, 5,  5, 9, 2,
		6, 8, 4,  8, 7, 3,  7, 9, 5,  9, 6, 2,
		# Lower sections to bottom point
		1, 4, 6,  1, 3, 8,  1, 5, 7,  1, 2, 9,
		1, 6, 8,  1, 8, 7,  1, 7, 9,  1, 9, 6
	]
	
	for idx in diamond_indices:
		indices.append(idx)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

func create_bush_mesh() -> ArrayMesh:
	"""Create a simple bush (small sphere)"""
	var array_mesh = ArrayMesh.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.4
	sphere_mesh.height = 0.6
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 6
	
	# Convert to ArrayMesh
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sphere_mesh.get_mesh_arrays())
	return array_mesh

func create_log_mesh() -> ArrayMesh:
	"""Create driftwood (horizontal cylinder)"""
	var array_mesh = ArrayMesh.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.15
	cylinder.height = 0.8
	cylinder.radial_segments = 8
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cylinder.get_mesh_arrays())
	return array_mesh

func create_shell_mesh() -> ArrayMesh:
	"""Create seashell (small flattened sphere)"""
	var array_mesh = ArrayMesh.new()
	var shell = SphereMesh.new()
	shell.radius = 0.15
	shell.height = 0.1
	shell.radial_segments = 6
	shell.rings = 4
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shell.get_mesh_arrays())
	return array_mesh

func create_lily_mesh() -> ArrayMesh:
	"""Create water lily (flat disc)"""
	var array_mesh = ArrayMesh.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.02
	disc.radial_segments = 8
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, disc.get_mesh_arrays())
	return array_mesh

func create_reed_mesh() -> ArrayMesh:
	"""Create reed (tall thin cylinder)"""
	var array_mesh = ArrayMesh.new()
	var reed = CylinderMesh.new()
	reed.top_radius = 0.02
	reed.bottom_radius = 0.03
	reed.height = 1.2
	reed.radial_segments = 6
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, reed.get_mesh_arrays())
	return array_mesh

# ============================================================================
# MATERIAL CREATORS
# ============================================================================

func create_tree_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.7, 0.3)  # Green
	material.roughness = 0.8
	return material

func create_trunk_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.25, 0.1)  # Brown trunk
	material.roughness = 0.9
	return material

func create_pine_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.3)  # Dark green
	material.roughness = 0.9
	return material

func create_ancient_tree_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.2)  # Deep green
	material.emission_enabled = true
	material.emission = Color(0.1, 0.3, 0.1) * 0.2  # Slight glow
	material.roughness = 0.7
	return material

func create_stone_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.6, 0.5)  # Gray stone
	material.roughness = 0.9
	material.metallic = 0.1
	return material

func create_crystal_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.8, 1.0, 0.9)  # Brighter blue crystal
	material.emission_enabled = true
	material.emission = Color(0.4, 0.7, 1.0) * 1  # Stronger glow!
	material.roughness = 0.05  # More reflective
	material.metallic = 0.3
	material.clearcoat_enabled = true
	material.clearcoat = 0.8
	return material

func create_berry_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.8, 0.3)  # Light green with berries
	material.roughness = 0.7
	return material

func create_wood_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown wood
	material.roughness = 0.8
	return material

func create_shell_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.8, 0.7)  # Cream/white
	material.roughness = 0.3
	material.metallic = 0.4
	return material

func create_water_plant_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 0.4)  # Bright water plant green
	material.roughness = 0.6
	return material

# ============================================================================
# RESOURCE SPAWNING RESPONSE
# ============================================================================

func _on_resource_spawned(resource_type: String, world_pos: Vector3):
	"""Called when TerrainManager spawns a resource"""
	if auto_create_visuals:
		create_resource_visual(resource_type, world_pos)

func create_all_existing_resource_visuals():
	"""Create visuals for all resources that already exist"""
	if not terrain_manager:
		return
	
	var resource_count = 0
	for resource in terrain_manager.spawned_resources:
		create_resource_visual(resource.type, resource.world_pos)
		resource_count += 1
	
	print("ResourceSpawner: Created ", resource_count, " resource visuals")

func create_resource_visual(resource_type: String, world_pos: Vector3):
	"""Create a single resource visual - FIXED VERSION"""
	
	# Handle composite trees (trunk + crown)
	if resource_type in ["small_tree", "oak_tree", "ancient_tree"]:
		create_composite_tree_visual(resource_type, world_pos)
		return
	
	# Handle single-mesh resources
	if resource_type not in resource_meshes:
		print("ResourceSpawner: Unknown resource type: ", resource_type)
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = resource_type + "_" + str(spawned_visual_resources.size())
	mesh_instance.position = world_pos
	
	# Set mesh
	mesh_instance.mesh = resource_meshes[resource_type]
	
	# Set material based on type
	var material_key = get_material_key_for_resource(resource_type)
	if material_key in resource_materials:
		mesh_instance.material_override = resource_materials[material_key]
	
	# Scale
	mesh_instance.scale = Vector3.ONE * resource_scale
	
	# Special positioning for some resources
	apply_special_positioning(mesh_instance, resource_type)
	
	# Add collision for interaction
	if add_collision:
		add_resource_collision(mesh_instance, resource_type, world_pos)
	
	# Debug label
	if show_debug_names:
		add_debug_label(mesh_instance, resource_type)
	
	add_child(mesh_instance)
	spawned_visual_resources.append({
		"type": resource_type,
		"world_pos": world_pos,
		"visual_node": mesh_instance
	})
	
func create_composite_tree_visual(tree_type: String, world_pos: Vector3):
	"""Create trees with separate trunk and crown"""
	var tree_parent = Node3D.new()
	tree_parent.name = tree_type + "_" + str(spawned_visual_resources.size())
	tree_parent.position = world_pos
	
	# Create trunk
	var trunk_mesh = MeshInstance3D.new()
	trunk_mesh.name = "Trunk"
	trunk_mesh.mesh = resource_meshes[tree_type + "_trunk"]
	trunk_mesh.material_override = resource_materials["trunk"]  # Brown!
	trunk_mesh.scale = Vector3.ONE * resource_scale
	tree_parent.add_child(trunk_mesh)
	
	# Create crown (positioned at top of trunk)
	var crown_mesh = MeshInstance3D.new()
	crown_mesh.name = "Crown"
	crown_mesh.mesh = resource_meshes[tree_type + "_crown"]
	
	# Use appropriate crown material
	var crown_material_key = "ancient_crown" if tree_type == "ancient_tree" else "tree_crown"
	crown_mesh.material_override = resource_materials[crown_material_key]
	
	# Position crown at top of trunk
	var tree_heights = {"small_tree": 0.7, "oak_tree": 1.4, "ancient_tree": 2.45}
	crown_mesh.position.y = tree_heights.get(tree_type, 0.7)
	crown_mesh.scale = Vector3.ONE * resource_scale
	tree_parent.add_child(crown_mesh)
	
	# Add collision to the parent
	if add_collision:
		add_tree_collision(tree_parent, tree_type, world_pos)
	
	# Debug label
	if show_debug_names:
		add_debug_label(tree_parent, tree_type)
	
	add_child(tree_parent)
	spawned_visual_resources.append({
		"type": tree_type,
		"world_pos": world_pos,
		"visual_node": tree_parent
	})

func apply_special_positioning(mesh_instance: MeshInstance3D, resource_type: String):
	"""Apply special positioning for certain resource types"""
	match resource_type:
		"driftwood":
			mesh_instance.rotation_degrees.y = randf_range(0, 360)
			mesh_instance.rotation_degrees.z = randf_range(-15, 15)
		"seashell":
			mesh_instance.rotation_degrees.y = randf_range(0, 360)
		"crystal_node":
			mesh_instance.rotation_degrees.y = randf_range(0, 360)
			# Crystals can be slightly tilted for more natural look
			mesh_instance.rotation_degrees.x = randf_range(-10, 70)
			mesh_instance.rotation_degrees.z = randf_range(-10, 70)

func add_tree_collision(tree_node: Node3D, tree_type: String, world_pos: Vector3):
	"""Add collision to composite tree - FIXED VERSION"""
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()  # Use box instead of cylinder
	
	# Different collision sizes for different trees
	match tree_type:
		"small_tree":
			shape.size = Vector3(0.6, 1.0, 0.6)
		"oak_tree":
			shape.size = Vector3(1.0, 2.0, 1.0)
		"ancient_tree":
			shape.size = Vector3(1.6, 3.5, 1.6)
		_:
			shape.size = Vector3(0.8, 1.5, 0.8)
	
	collision_shape.shape = shape
	collision_shape.position.y = shape.size.y * 0.5  # Center the collision
	
	var static_body = StaticBody3D.new()
	static_body.add_child(collision_shape)
	tree_node.add_child(static_body)
	
	# Add to interaction group
	static_body.add_to_group("resources")
	static_body.set_meta("resource_type", tree_type)
	static_body.set_meta("world_pos", world_pos)
	
func add_resource_collision(mesh_instance: MeshInstance3D, resource_type: String, world_pos: Vector3):
	"""Add collision for single-mesh resources - FIXED VERSION"""
	var collision_shape = CollisionShape3D.new()
	
	# Custom collision shapes per resource type
	match resource_type:
		"crystal_node":
			var shape = BoxShape3D.new()
			shape.size = Vector3(1.2, 3.6, 1.2) * resource_scale  # Tall crystal collision
			collision_shape.shape = shape
		
		"pine_tree":
			var shape = BoxShape3D.new()  # Use box instead of cylinder
			shape.size = Vector3(0.8, 2.5, 0.8)
			collision_shape.shape = shape
			collision_shape.position.y = 1.25  # Center it
		
		"stone_small":
			var shape = SphereShape3D.new()
			shape.radius = 0.3 * resource_scale
			collision_shape.shape = shape
		
		"stone_medium":
			var shape = SphereShape3D.new()
			shape.radius = 0.6 * resource_scale
			collision_shape.shape = shape
		
		"berry_bush":
			var shape = SphereShape3D.new()
			shape.radius = 0.4 * resource_scale
			collision_shape.shape = shape
		
		"driftwood":
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.8, 0.2, 0.2) * resource_scale  # Long and thin
			collision_shape.shape = shape
		
		"seashell":
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.3, 0.1, 0.3) * resource_scale  # Flat and small
			collision_shape.shape = shape
		
		"water_lily":
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.6, 0.04, 0.6) * resource_scale  # Very flat
			collision_shape.shape = shape
		
		"reed":
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.1, 1.2, 0.1) * resource_scale  # Tall and thin
			collision_shape.shape = shape
			collision_shape.position.y = 0.6  # Center it
		
		_:
			# Default collision
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.5, 0.5, 0.5) * resource_scale
			collision_shape.shape = shape
	
	var static_body = StaticBody3D.new()
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)
	
	# Add to interaction group
	static_body.add_to_group("resources")
	static_body.set_meta("resource_type", resource_type)
	static_body.set_meta("world_pos", world_pos)

func add_debug_label(parent_node: Node3D, resource_type: String):
	"""Add debug label to resource"""
	var label = Label3D.new()
	label.text = resource_type
	label.position.y += 2.0  # Higher for big crystals
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent_node.add_child(label)

func get_material_key_for_resource(resource_type: String) -> String:
	"""Get material key for resource type"""
	match resource_type:
		"pine_tree":
			return "pine"
		"stone_small", "stone_medium":
			return "stone"
		"crystal_node":
			return "crystal"
		"berry_bush":
			return "berry"
		"driftwood":
			return "wood"
		"seashell":
			return "shell"
		"water_lily", "reed":
			return "water_plant"
		_:
			return "tree_crown"  # Default

# ============================================================================
# DEBUG AND UTILITIES
# ============================================================================

func clear_all_visuals():
	"""Remove all resource visuals"""
	for resource_data in spawned_visual_resources:
		if is_instance_valid(resource_data.visual_node):
			resource_data.visual_node.queue_free()
	
	spawned_visual_resources.clear()
	print("ResourceSpawner: Cleared all resource visuals")

func get_resources_near_position(world_pos: Vector3, radius: float) -> Array:
	"""Get visual resources near position"""
	var nearby = []
	
	for resource_data in spawned_visual_resources:
		var distance = world_pos.distance_to(resource_data.world_pos)
		if distance <= radius:
			nearby.append(resource_data)
	
	return nearby

func print_resource_stats():
	"""Debug resource statistics"""
	print("=== RESOURCE SPAWNER STATS ===")
	print("Visual resources: ", spawned_visual_resources.size())
	print("Mesh types: ", resource_meshes.size())
	print("Material types: ", resource_materials.size())
	print("Auto create visuals: ", auto_create_visuals)

# ============================================================================
# RESOURCE COLLECTION HANDLING (NEW)
# ============================================================================

func _on_resource_collected(resource_data: Dictionary, drops: Array):
	"""Called when TerrainManager collects a resource - remove the visual"""
	print("ResourceSpawner: Resource collected - removing visual for ", resource_data.type)
	remove_resource_visual(resource_data)

func remove_resource_visual(resource_data: Dictionary):
	"""Remove the visual for a specific resource"""
	var visual_to_remove = null
	var index_to_remove = -1
	
	# Find matching visual by type and position
	for i in range(spawned_visual_resources.size()):
		var visual_resource = spawned_visual_resources[i]
		
		# Match by type and approximate position (allow small differences due to floating point)
		if visual_resource.type == resource_data.type:
			var distance = visual_resource.world_pos.distance_to(resource_data.world_pos)
			if distance < 0.1:  # Very close match
				visual_to_remove = visual_resource
				index_to_remove = i
				break
	
	# Remove the visual
	if visual_to_remove and is_instance_valid(visual_to_remove.visual_node):
		print("ResourceSpawner: Removing visual node for ", resource_data.type)
		visual_to_remove.visual_node.queue_free()
		spawned_visual_resources.remove_at(index_to_remove)
	else:
		print("ResourceSpawner: WARNING - Could not find visual to remove for ", resource_data.type)

func remove_resource_visual_by_position(world_pos: Vector3, resource_type: String = ""):
	"""Alternative way to remove resource visual by position"""
	for i in range(spawned_visual_resources.size() - 1, -1, -1):  # Iterate backwards
		var visual_resource = spawned_visual_resources[i]
		var distance = visual_resource.world_pos.distance_to(world_pos)
		
		if distance < 1.0:  # Within 1 meter
			if resource_type == "" or visual_resource.type == resource_type:
				print("ResourceSpawner: Removing visual at position ", world_pos)
				if is_instance_valid(visual_resource.visual_node):
					visual_resource.visual_node.queue_free()
				spawned_visual_resources.remove_at(i)
				return true
	
	return false
