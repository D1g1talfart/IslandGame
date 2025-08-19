extends Node3D

@export var mouse_sensitivity: float = 0.005
@export var zoom_speed: float = 2.0

@export_group("Orbit Settings")
@export var orbit_distance: float = 5.0
@export var min_orbit_distance: float = 0.5
@export var max_orbit_distance: float = 10
@export var orbit_height_offset: float = 1.0
@export var vertical_angle_limit: float = 80.0

var player: CharacterBody3D
var island_renderer: Island3DRenderer

var camera: Camera3D
var is_rotating: bool = false

var horizontal_angle: float = 0.0
var vertical_angle: float = 20.0

func _ready():
	print("=== CAMERA STARTING ===")
	print("Current scene:", get_tree().current_scene.name)
	
	# Create camera
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	add_child(camera)
	camera.current = true
	
	# Fix the node path - use the actual node name!
	island_renderer = get_node_or_null("../3D Renderer")
	print("CAMERA: Island renderer found:", island_renderer != null)
	
	if island_renderer:
		print("CAMERA: Island rendered status:", island_renderer.has_island_rendered())
	
	# Use a timer instead of call_deferred for better timing
	print("CAMERA: Starting player setup timer...")
	var timer = Timer.new()
	timer.wait_time = 2.0  # Give island 2 seconds to render
	timer.one_shot = true
	timer.timeout.connect(find_and_setup_player)
	add_child(timer)
	timer.start()

func find_and_setup_player():
	print("\n=== CAMERA: SETTING UP PLAYER ===")
	
	# Look for existing player first
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("CAMERA: No player found, creating one...")
		var player_scene = preload("res://Player.tscn")  # Adjust path
		player = player_scene.instantiate()
		player.add_to_group("player")
		get_parent().add_child(player)
		print("CAMERA: Player created")
	else:
		print("CAMERA: Found existing player at:", player.global_position)
	
	# Debug the island renderer state
	print("CAMERA: Checking island renderer...")
	if island_renderer:
		print("CAMERA: Island renderer exists:", island_renderer.name)
		print("CAMERA: Island rendered:", island_renderer.has_island_rendered())
		print("CAMERA: IslandDataStore has data:", IslandDataStore.has_island_data())
		
		if island_renderer.has_island_rendered():
			print("CAMERA: Getting island center position...")
			var center_pos = island_renderer.get_island_center_position()
			print("CAMERA: Calculated center position:", center_pos)
			
			# Make sure we got a valid position
			if center_pos != Vector3.ZERO:
				player.global_position = center_pos
				print("CAMERA: Player moved to island center:", player.global_position)
			else:
				print("CAMERA: Center position was zero, using fallback")
				player.global_position = Vector3(50, 2, 50)  # Fallback position
		else:
			print("CAMERA: Island not rendered yet, trying again in 1 second...")
			var retry_timer = Timer.new()
			retry_timer.wait_time = 1.0
			retry_timer.one_shot = true
			retry_timer.timeout.connect(find_and_setup_player)
			add_child(retry_timer)
			retry_timer.start()
			return
	else:
		print("CAMERA: No island renderer found! Using default position")
		player.global_position = Vector3(0, 2, 0)
	
	print("CAMERA: Final player position:", player.global_position)
	print("=== CAMERA SETUP COMPLETE ===\n")
	
	update_camera_position()

# Rest of your functions stay the same...
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			debug_camera_info()
			return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_rotating = event.pressed
			if is_rotating:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = max(min_orbit_distance, orbit_distance - zoom_speed)
			update_camera_position()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = min(max_orbit_distance, orbit_distance + zoom_speed)
			update_camera_position()
	
	elif event is InputEventMouseMotion and is_rotating:
		horizontal_angle -= event.relative.x * mouse_sensitivity
		vertical_angle = clamp(vertical_angle - event.relative.y * mouse_sensitivity, 
			0.0,  # Never go below horizontal (no looking up)
			deg_to_rad(vertical_angle_limit))  # Max downward angle
		update_camera_position()

func _process(delta):
	if player:
		update_camera_position()

func update_camera_position():
	if not player:
		return
		
	var target_pos = player.global_position
	
	var offset = Vector3()
	offset.x = orbit_distance * cos(vertical_angle) * sin(horizontal_angle)
	offset.y = orbit_distance * sin(vertical_angle) + orbit_height_offset
	offset.z = orbit_distance * cos(vertical_angle) * cos(horizontal_angle)
	
	camera.global_position = target_pos + offset
	camera.look_at(target_pos + Vector3(0, orbit_height_offset * 0.5, 0), Vector3.UP)

func debug_camera_info():
	print("\n=== CAMERA DEBUG ===")
	print("Camera position:", camera.global_position)
	print("Player position:", player.global_position if player else "NO PLAYER")
	print("Island renderer found:", island_renderer != null)
	if island_renderer:
		print("Island rendered:", island_renderer.has_island_rendered())
		print("Trying to get center again...")
		var center = island_renderer.get_island_center_position()
		print("Center position:", center)
	print("Orbit distance:", orbit_distance)
	print("====================\n")
