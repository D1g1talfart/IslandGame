extends Control

@export var progress_bar: ProgressBar
@export var status_label: Label

var setup_steps = [
	"Generating Island...",
	"Rendering Terrain...", 
	"Setting up Camera...",
	"Spawning Player...",
	"Finalizing World..."
]
var current_step = 0

func _ready():
	start_full_setup()

func start_full_setup():
	update_progress("Starting...", 0.0)
	
	# Step 1: Generate Island
	update_progress(setup_steps[0], 0.0)
	var island_generator = $IslandGenerator
	island_generator.generation_progress.connect(_on_generation_progress)
	island_generator.generation_complete.connect(_on_generation_complete)
	
	await get_tree().process_frame
	island_generator.generate_new_island()

func _on_generation_progress(step_name: String, progress: float):
	# Generation takes up first 40% of total progress
	var total_progress = progress * 0.4
	update_progress(setup_steps[0] + " - " + step_name, total_progress)

func _on_generation_complete(island_data):
	IslandDataStore.set_island_data(island_data)
	
	# Step 2: Wait for rendering
	current_step = 1
	update_progress(setup_steps[1], 0.4)
	
	# Find main node (it's the current scene)
	var main = get_tree().current_scene
	if main and main.has_method("create_game_world_now"):
		main.create_game_world_now()
	
	await setup_renderer_and_camera()

func setup_renderer_and_camera():
	var attempts = 0
	var max_attempts = 50
	
	while attempts < max_attempts:
		# Find renderer through the scene tree
		var main = get_tree().current_scene
		var game_world = main.get_node_or_null("GameWorld")
		var renderer = null
		if game_world:
			renderer = game_world.get_node_or_null("3D Renderer")
		
		if renderer and renderer.has_method("is_rendered") and renderer.is_rendered():
			break
			
		attempts += 1
		var progress = 0.4 + (attempts / float(max_attempts)) * 0.3
		update_progress(setup_steps[1], progress)
		await get_tree().create_timer(0.1).timeout
	
	# Step 3: Setup Camera
	current_step = 2
	update_progress(setup_steps[2], 0.7)
	await setup_camera_system()
	
	# Step 4: Setup Player
	current_step = 3
	update_progress(setup_steps[3], 0.85)
	await setup_player_system()
	
	# Step 5: Final setup
	current_step = 4
	update_progress(setup_steps[4], 0.95)
	await get_tree().create_timer(0.5).timeout  # Brief pause
	
	# Complete!
	update_progress("Ready!", 1.0)
	await get_tree().create_timer(0.5).timeout
	
	# Signal main to show the game
	var main = get_node("/root/Node")
	if main:
		main.loading_complete()

func setup_camera_system():
	# Find and setup camera
	var camera = get_node_or_null("/root/Main/GameWorld/Camera2D")
	if camera and camera.has_method("force_setup"):
		camera.force_setup()
		await get_tree().create_timer(0.2).timeout

func setup_player_system():
	# Ensure player is properly positioned
	await get_tree().create_timer(0.3).timeout

func update_progress(text: String, progress: float):
	if status_label:
		status_label.text = text
	if progress_bar:
		progress_bar.value = progress * 100
	print("Loading: ", text, " (", int(progress * 100), "%)")
	
func loading_complete():
	var main = get_tree().current_scene
	if main and main.has_method("loading_complete"):
		main.loading_complete()
