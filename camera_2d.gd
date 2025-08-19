extends Camera2D

@export var pan_speed: float = 300.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.1
@export var max_zoom: float = 6.0

# Cache these references to avoid repeated lookups
var main_scene = null
var view_controller = null

func _ready():
	# Cache references once
	main_scene = get_tree().get_first_node_in_group("main")  # Better approach
	if not main_scene:
		# Fallback: try to find it manually
		main_scene = get_node("/root").get_child(0)  # Usually the first child
	
	view_controller = get_parent()  # GameWorld node
	
	# Start with a good overview of the island
	zoom = Vector2(0.5, 0.5)
	print("Camera2D ready. Main scene: ", main_scene, " View controller: ", view_controller)

func is_input_allowed() -> bool:
	"""Simplified input checking"""
	if not main_scene:
		return true
	
	# Simple checks using get() instead of has_property()
	if main_scene.get("current_screen") != null:
		return false
	if main_scene.get("game_world") and not main_scene.get("game_world").visible:
		return false
	
	# Check if in 2D view
	if view_controller and view_controller.has_method("is_2d_view"):
		return view_controller.is_2d_view()
	
	return true
	
func _process(delta):
	if not is_input_allowed():
		return
	
	# WASD or Arrow Keys for panning
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_down"):
		input_vector.y += 1
	if Input.is_action_pressed("ui_up"):
		input_vector.y -= 1
	
	# Move camera (with better calculation)
	if input_vector != Vector2.ZERO:
		var movement = input_vector * pan_speed * delta
		# Adjust movement speed based on zoom level
		movement = movement / zoom.x
		global_position += movement
		

func _input(event):
	if not is_input_allowed():
		return

	# Mouse wheel for zooming
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			
	
	# Right mouse button drag for panning
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var movement = -event.relative / zoom.x
		global_position += movement
		

func zoom_in():
	var new_zoom = zoom.x + zoom_speed
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

func zoom_out():
	var new_zoom = zoom.x - zoom_speed  
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
