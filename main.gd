extends Node

@onready var ui_layer = $UI

var main_menu_scene = preload("res://Main_Menu.tscn")
var loading_screen_scene = preload("res://Loading_Screen.tscn")
var controls_screen_scene = preload("res://ControlsScreen.tscn")
var game_world_scene = preload("res://GameWorld.tscn")
var current_screen = null
var game_world = null

func _ready():
	add_to_group("main")
	show_main_menu()

func show_main_menu():
	clear_current_screen()
	clear_game_world()  # Clean up game world too
	
	current_screen = main_menu_scene.instantiate()
	ui_layer.add_child(current_screen)
	current_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Connect menu buttons
	current_screen.play_pressed.connect(_on_play_pressed)
	current_screen.controls_pressed.connect(_on_controls_pressed)
	current_screen.quit_pressed.connect(_on_quit_pressed)

func show_loading_screen():
	clear_current_screen()
	current_screen = loading_screen_scene.instantiate()
	ui_layer.add_child(current_screen)


func show_game():
	clear_current_screen()
	if game_world:
		game_world.visible = true
		
		# Activate inventory UI now that game is ready
		var player = game_world.get_node_or_null("CharacterBody3D")  # Adjust path if needed
		if player and player.has_node("InventoryUI"):
			player.get_node("InventoryUI").show_inventory_ui()
			print("Inventory UI activated for gameplay!")
	# World already exists, just show it

func show_controls():
	clear_current_screen()
	current_screen = controls_screen_scene.instantiate()
	ui_layer.add_child(current_screen)
	current_screen.back_pressed.connect(show_main_menu)

func clear_current_screen():
	if current_screen:
		current_screen.queue_free()
		current_screen = null

func clear_game_world():
	if game_world:
		game_world.queue_free()
		game_world = null

func generate_new_island():
	await get_tree().create_timer(2.0).timeout
	show_game()
	
func create_game_world_now():
	if not game_world:
		game_world = game_world_scene.instantiate()
		add_child(game_world)
		# Don't make it visible yet - loading screen will handle that

# Add this method for loading screen to call when done
func loading_complete():
	show_game()



# These callback functions were missing!
func _on_play_pressed():
	show_loading_screen()

func _on_controls_pressed():
	show_controls()

func _on_quit_pressed():
	get_tree().quit()
	
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if game_world != null and current_screen == null:  # Game is active
				show_main_menu()
				get_viewport().set_input_as_handled()
