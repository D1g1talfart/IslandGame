# ============================================================================
# GAMEWORLD TIMING FIX - Load data when scene becomes active
# ============================================================================

extends Node3D  # or whatever your GameWorld root node type is

# Node references (same as before)
@onready var island_2d_display: TileMapLayer = $TileMapLayer
@onready var island_3d_renderer: Node3D = $"3D Renderer"
@onready var camera_2d: Camera2D = $Camera2D
@onready var camera_controller: Node3D = $"Camera Controller"

var camera_3d: Camera3D
var current_view: ViewMode = ViewMode.VIEW_3D
var current_screen = null
var displays_loaded = false

enum ViewMode {
	VIEW_2D,
	VIEW_3D
}

# ============================================================================
# PROPER INITIALIZATION - Wait for scene to become active
# ============================================================================

func _ready():
	print("GameWorld: Node ready, setting up...")
	
	# Find cameras
	setup_cameras()
	
	# Set initial view mode (but don't load data yet)
	set_initial_view_state()
	
	print("GameWorld: Setup complete, waiting to become active scene...")

func setup_cameras():
	if camera_controller:
		camera_3d = camera_controller.get_node("Camera Controller")
		if not camera_3d:
			for child in camera_controller.get_children():
				if child is Camera3D:
					camera_3d = child
					break
		print("GameWorld: Found 3D camera: ", camera_3d.name if camera_3d else "Not found")

func set_initial_view_state():
	"""Set up the initial view state without loading data"""
	# Just set camera states, don't load island data yet
	if current_view == ViewMode.VIEW_3D:
		if camera_3d:
			camera_3d.current = true
		if camera_2d:
			camera_2d.enabled = false
	else:
		if camera_2d:
			camera_2d.enabled = true
			camera_2d.make_current()
		if camera_3d:
			camera_3d.current = false

# ============================================================================
# DETECT WHEN SCENE BECOMES ACTIVE - More reliable approach
# ============================================================================

var scene_became_current = false
var initial_load_attempted = false

func _notification(what):
	# This is more reliable than _process for detecting scene changes
	if what == NOTIFICATION_READY:
		# Scene is fully ready, try loading after a short delay
		call_deferred("try_initial_load")

func try_initial_load():
	"""Try to load data after scene is fully initialized"""
	print("GameWorld: Trying initial load...")
	
	if initial_load_attempted:
		return
	
	initial_load_attempted = true
	
	# Wait a moment for everything to settle
	await get_tree().create_timer(0.2).timeout
	
	if IslandDataStore.has_island_data():
		print("GameWorld: Island data found on initial load!")
		load_island_displays()
		displays_loaded = true
	else:
		print("GameWorld: No island data on initial load, will wait for scene change")
		# Set up a timer to check periodically
		start_data_checking_timer()

func start_data_checking_timer():
	"""Start a timer to check for data periodically"""
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(check_for_data_periodically)
	timer.autostart = true
	add_child(timer)
	print("GameWorld: Started data checking timer")

func check_for_data_periodically():
	"""Check for island data every 0.5 seconds"""
	if displays_loaded:
		# Stop checking, we're done
		for child in get_children():
			if child is Timer:
				child.queue_free()
		return
	
	if IslandDataStore.has_island_data():
		print("GameWorld: Island data found via timer check!")
		load_island_displays()
		displays_loaded = true
		
		# Stop the timer
		for child in get_children():
			if child is Timer:
				child.queue_free()

# Remove the old _process function - replace with this simpler approach
# func _process(_delta):  # <-- REMOVE THIS ENTIRE FUNCTION

# ============================================================================
# LOADING FUNCTIONS (same as before but with better error checking)
# ============================================================================

func load_island_displays():
	"""Force load island displays from stored data"""
	
	if not IslandDataStore.has_island_data():
		print("GameWorld: ERROR - No island data in store!")
		return
	
	print("GameWorld: Loading island displays...")
	
	# Force 2D display to load
	if island_2d_display:
		if island_2d_display.has_method("display_island_from_store"):
			island_2d_display.display_island_from_store()
			print("GameWorld: 2D display loaded successfully")
		else:
			print("GameWorld: ERROR - Island2DDisplay script missing display_island_from_store method!")
	else:
		print("GameWorld: ERROR - Island2DDisplay node not found!")
	
	# Force 3D renderer to load  
	if island_3d_renderer:
		if island_3d_renderer.has_method("render_island_from_store"):
			island_3d_renderer.render_island_from_store()
			print("GameWorld: 3D renderer loaded successfully")
		else:
			print("GameWorld: ERROR - Island3DRenderer script missing render_island_from_store method!")
	else:
		print("GameWorld: ERROR - Island3DRenderer node not found!")
	
	# Apply current view after loading
	switch_to_view(current_view)

# ============================================================================
# VIEW SWITCHING (same as before but with fallback loading)
# ============================================================================

func _input(event):
	
	# Try multiple ways to detect tab/switch key
	if event.is_action_pressed("ui_focus_next"):  # This should be Tab
		print("GameWorld: ui_focus pressed (Tab) - toggling view")
		toggle_view()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		print("GameWorld: Raw Tab key pressed - toggling view")
		toggle_view()
	
	# Debug keys
	if event.is_action_pressed("ui_home"):  # Home - manual refresh
		print("GameWorld: Spacebar pressed - force refresh")
		force_refresh_displays()
	
	if event.is_action_pressed("ui_end"):  # End - debug info
		debug_island_data()

func toggle_view():
	"""Toggle between 2D and 3D view"""
	print("GameWorld: toggle_view() called!")
	print("GameWorld: Current view before toggle: ", "2D" if current_view == ViewMode.VIEW_2D else "3D")
	
	# Try to load data if we haven't yet (fallback)
	if not displays_loaded and IslandDataStore.has_island_data():
		print("GameWorld: Loading data during view toggle (fallback)")
		load_island_displays()
		displays_loaded = true
	
	if current_view == ViewMode.VIEW_2D:
		print("GameWorld: Switching from 2D to 3D")
		switch_to_view(ViewMode.VIEW_3D)
	else:
		print("GameWorld: Switching from 3D to 2D")
		switch_to_view(ViewMode.VIEW_2D)

func switch_to_view(view_mode: ViewMode):
	"""Switch to specific view mode"""
	current_view = view_mode
	
	match view_mode:
		ViewMode.VIEW_2D:
			switch_to_2d()
		ViewMode.VIEW_3D:
			switch_to_3d()

func switch_to_2d():
	"""Switch to 2D view"""
	print("GameWorld: Switching to 2D view")
	
	# Enable 2D camera
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()
	
	# Disable 3D camera  
	if camera_3d:
		camera_3d.current = false
	
	# Show 2D display, hide 3D renderer
	if island_2d_display:
		island_2d_display.visible = true
		if island_2d_display.has_method("refresh_display"):
			island_2d_display.refresh_display()
	
	if island_3d_renderer:
		island_3d_renderer.visible = false
	
	print("GameWorld: Now in 2D view")

func switch_to_3d():
	"""Switch to 3D view"""
	print("GameWorld: Switching to 3D view")
	
	# Enable 3D camera
	if camera_3d:
		camera_3d.current = true
	
	# Disable 2D camera
	if camera_2d:
		camera_2d.enabled = false
	
	# Show 3D renderer, hide 2D display  
	if island_3d_renderer:
		island_3d_renderer.visible = true
		if island_3d_renderer.has_method("refresh_3d_view"):
			island_3d_renderer.refresh_3d_view()
	
	if island_2d_display:
		island_2d_display.visible = false
	
	print("GameWorld: Now in 3D view")

# ============================================================================
# MANUAL REFRESH (same as before)
# ============================================================================

func force_refresh_displays():
	"""Force refresh both displays"""
	print("GameWorld: Manual refresh triggered")
	
	if not displays_loaded and IslandDataStore.has_island_data():
		load_island_displays()
		displays_loaded = true
	elif displays_loaded:
		# Just refresh existing displays
		if island_2d_display and island_2d_display.has_method("refresh_display"):
			island_2d_display.refresh_display()
		
		if island_3d_renderer and island_3d_renderer.has_method("refresh_3d_view"):
			island_3d_renderer.refresh_3d_view()
		
		print("GameWorld: Displays refreshed")

func debug_island_data():
	"""Debug function"""
	print("\n=== GAMEWORLD DEBUG ===")
	print("Scene is current: ", get_tree().current_scene == self)
	print("Scene became current: ", scene_became_current)
	print("Displays loaded: ", displays_loaded)
	print("Has island data: ", IslandDataStore.has_island_data())
	print("Current view: ", "2D" if current_view == ViewMode.VIEW_2D else "3D")
	print("2D display visible: ", island_2d_display.visible if island_2d_display else "N/A")
	print("3D renderer visible: ", island_3d_renderer.visible if island_3d_renderer else "N/A")
	print("======================\n")

# ============================================================================
# NOTES
# ============================================================================

# This version:
# 1. Sets up cameras immediately in _ready()
# 2. Waits until the scene becomes the active scene in _process()
# 3. Then tries to load island data
# 4. Has fallback loading during view switching
# 5. Provides detailed debug output

# Console flow should be:
# "GameWorld: Node ready, setting up..."
# "GameWorld: Setup complete, waiting to become active scene..."
# "GameWorld: Scene became active!"
# "GameWorld: Attempting to load island data..."
# "GameWorld: Island data found! Loading displays..."
