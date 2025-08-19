extends Button

# Set this in the inspector to point to your loading screen scene
@export var loading_scene_path: String = "res://scenes/Loading_Screen.tscn"

func _ready():
	# Connect the button press
	pressed.connect(_on_generate_button_pressed)

func _on_generate_button_pressed():
	print("Generate button pressed - switching to loading screen")
	
	# Switch to your loading screen scene
	if loading_scene_path and ResourceLoader.exists(loading_scene_path):
		get_tree().change_scene_to_file(loading_scene_path)
	else:
		print("Error: Loading screen scene not found at: ", loading_scene_path)
