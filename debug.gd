extends Node
# Debug script to help troubleshoot 3D rendering issues
# Attach this to any Node in your scene temporarily

func _ready():
	print("\n=== 3D RENDERER DEBUG ===")
	await get_tree().process_frame
	debug_scene_setup()

func _input(event):
	if event.is_action_pressed("ui_home"):  # Home key for debug info
		debug_scene_setup()

func debug_scene_setup():
	print("\n--- Scene Structure ---")
	print_node_tree(get_tree().current_scene, 0)
	
	print("\n--- Camera Information ---")
	debug_cameras()
	
	print("\n--- Island Generator Status ---")
	debug_island_generator()
	
	print("\n--- 3D Renderer Status ---")
	debug_3d_renderer()
	
	print("\n--- Viewport Information ---")
	debug_viewport()

func print_node_tree(node: Node, depth: int):
	var indent = ""
	for i in depth:
		indent += "  "
	
	var info = indent + node.name + " (" + node.get_class() + ")"
	
	# Safe visibility check - only for nodes that have the visible property
	if node is CanvasItem or node is Node3D:
		if not node.visible:
			info += " [HIDDEN]"
	
	# Safe position check - only for nodes that have position
	if node is Node2D:
		info += " pos:" + str(node.position)
	elif node is Node3D:
		info += " pos:" + str(node.position)
	
	print(info)
	
	for child in node.get_children():
		print_node_tree(child, depth + 1)

func debug_cameras():
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.is_empty():
		# Look for Camera3D nodes manually
		cameras = find_all_cameras(get_tree().current_scene)
	
	if cameras.is_empty():
		print("❌ No cameras found in scene!")
		return
	
	for i in range(cameras.size()):
		var camera = cameras[i]
		print("Camera ", i, ": ", camera.name)
		print("  Position: ", camera.global_position)
		print("  Current: ", camera.is_current())
		
		if camera is Camera3D:
			print("  3D Camera - Looking at 3D world")
			print("  Projection: ", "Perspective" if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else "Orthogonal")
		elif camera is Camera2D:
			print("  2D Camera - Looking at 2D world")
			print("  Enabled: ", camera.enabled)

func find_all_cameras(node: Node) -> Array:
	var cameras = []
	
	if node is Camera3D or node is Camera2D:
		cameras.append(node)
	
	for child in node.get_children():
		cameras.append_array(find_all_cameras(child))
	
	return cameras

func debug_island_generator():
	var generators = get_tree().get_nodes_in_group("island_generator")
	
	if generators.is_empty():
		print("❌ No island generator found!")
		return
	
	for generator in generators:
		print("Generator: ", generator.name, " (", generator.get_class(), ")")
		
		# Safe visibility check
		if generator is CanvasItem or generator is Node3D:
			print("  Visible: ", generator.visible)
		
		# Safe position check
		if generator is Node2D:
			print("  Position: ", generator.position)
		elif generator is Node3D:
			print("  Position: ", generator.position)
		
		# Check if it has our expected properties using has_method/get
		print("  Island Width: ", generator.get("island_width") if generator.has_method("get") else "N/A")
		print("  Island Height: ", generator.get("island_height") if generator.has_method("get") else "N/A")
		
		var terrain_data = generator.get("terrain_data") if generator.has_method("get") else null
		var height_data = generator.get("height_data") if generator.has_method("get") else null
		
		print("  Terrain Data: ", "OK (" + str(terrain_data.size()) + " rows)" if terrain_data != null and terrain_data.size() > 0 else "MISSING/EMPTY")
		print("  Height Data: ", "OK (" + str(height_data.size()) + " rows)" if height_data != null and height_data.size() > 0 else "MISSING/EMPTY")

func debug_3d_renderer():
	var renderers = []
	find_3d_renderers(get_tree().current_scene, renderers)
	
	if renderers.is_empty():
		print("❌ No 3D renderer found!")
		return
	
	for renderer in renderers:
		print("3D Renderer: ", renderer.name)
		print("  Position: ", renderer.global_position)
		
		# Safe visibility check
		if renderer is CanvasItem or renderer is Node3D:
			print("  Visible: ", renderer.visible)
		
		print("  Children: ", renderer.get_child_count())
		
		# Check for mesh instances
		var mesh_count = count_mesh_instances(renderer)
		print("  Mesh Instances: ", mesh_count)
		
		if mesh_count == 0:
			print("  ⚠️  No mesh instances found - this might be the problem!")

func find_3d_renderers(node: Node, renderers: Array):
	if node.get_script() != null:
		var script_path = node.get_script().resource_path
		if "3d" in script_path.to_lower() or "renderer" in script_path.to_lower():
			renderers.append(node)
	
	for child in node.get_children():
		find_3d_renderers(child, renderers)

func count_mesh_instances(node: Node) -> int:
	var count = 0
	
	if node is MeshInstance3D:
		count += 1
	
	for child in node.get_children():
		count += count_mesh_instances(child)
	
	return count

func debug_viewport():
	var viewport = get_viewport()
	print("Viewport size: ", viewport.size)
	print("Viewport render mode: ", viewport.get_world_3d() != null)
	
	var current_camera = viewport.get_camera_3d()
	if current_camera:
		print("Current 3D camera: ", current_camera.name)
		print("Camera position: ", current_camera.global_position)
	else:
		print("❌ No current 3D camera!")
		
		var camera_2d = viewport.get_camera_2d()
		if camera_2d:
			print("Current 2D camera: ", camera_2d.name)
			print("⚠️  You might be viewing in 2D mode!")

func _exit_tree():
	print("=== DEBUG COMPLETE ===\n")
