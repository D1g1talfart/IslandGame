class_name Settings
extends Control

@onready var video_section = $ScrollContainer/VBoxContainer/VideoSection
@onready var audio_section = $ScrollContainer/VBoxContainer/AudioSection
@onready var gameplay_section = $ScrollContainer/VBoxContainer/GameplaySection

# Video settings nodes
@onready var fullscreen_check = $ScrollContainer/VBoxContainer/VideoSection/VBox/FullscreenCheck
@onready var vsync_check = $ScrollContainer/VBoxContainer/VideoSection/VBox/VsyncCheck
@onready var resolution_option = $ScrollContainer/VBoxContainer/VideoSection/VBox/ResolutionOption
@onready var apply_button = $ScrollContainer/VBoxContainer/VideoSection/VBox/ApplyButton  # ADD THIS

# Audio settings nodes (non-functional for now)
@onready var master_volume = $ScrollContainer/VBoxContainer/AudioSection/VBox/MasterVolume
@onready var sfx_volume = $ScrollContainer/VBoxContainer/AudioSection/VBox/SFXVolume
@onready var music_volume = $ScrollContainer/VBoxContainer/AudioSection/VBox/MusicVolume

# Store pending changes
var pending_resolution_index: int = -1
var pending_fullscreen: bool = false
var pending_vsync: bool = false

signal settings_closed

func _ready():
	setup_video_settings()
	setup_audio_settings()
	
	# Connect close button
	$Header/CloseButton.pressed.connect(close_settings)

func setup_video_settings():
	# Setup resolution dropdown
	var resolutions = [
		"1920x1080",
		"1600x900", 
		"1366x768",
		"1280x720",
		"2560x1440",
		"3840x2160"
	]
	
	for res in resolutions:
		resolution_option.add_item(res)
	
	# Load and set current settings
	var current_size = DisplayServer.window_get_size()
	var current_res_text = str(current_size.x) + "x" + str(current_size.y)
	
	# Find matching resolution in dropdown
	for i in range(resolution_option.get_item_count()):
		if resolution_option.get_item_text(i) == current_res_text:
			resolution_option.select(i)
			break
	
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	
	# Store current settings as pending
	pending_resolution_index = resolution_option.selected
	pending_fullscreen = fullscreen_check.button_pressed
	pending_vsync = vsync_check.button_pressed
	
	# Connect signals - but don't apply immediately
	fullscreen_check.toggled.connect(_on_fullscreen_changed)
	vsync_check.toggled.connect(_on_vsync_changed)
	resolution_option.item_selected.connect(_on_resolution_changed)
	apply_button.pressed.connect(_on_apply_pressed)
	
	# Initially disable apply button
	apply_button.disabled = true

func setup_audio_settings():
	# Set up sliders (non-functional placeholders)
	master_volume.min_value = 0
	master_volume.max_value = 100
	master_volume.value = 75
	
	sfx_volume.min_value = 0
	sfx_volume.max_value = 100
	sfx_volume.value = 75
	
	music_volume.min_value = 0
	music_volume.max_value = 100
	music_volume.value = 50

# These just store the pending changes and enable apply button
func _on_fullscreen_changed(pressed: bool):
	pending_fullscreen = pressed
	check_for_changes()

func _on_vsync_changed(pressed: bool):
	pending_vsync = pressed
	check_for_changes()

func _on_resolution_changed(index: int):
	pending_resolution_index = index
	check_for_changes()

func check_for_changes():
	# Enable apply button if there are pending changes
	var current_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var current_vsync = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	var current_size = DisplayServer.window_get_size()
	var current_res_text = str(current_size.x) + "x" + str(current_size.y)
	
	var has_changes = (
		pending_fullscreen != current_fullscreen or
		pending_vsync != current_vsync or
		resolution_option.get_item_text(pending_resolution_index) != current_res_text
	)
	
	apply_button.disabled = not has_changes
	apply_button.text = "Apply" if not has_changes else "Apply Changes"

func _on_apply_pressed():
	print("Applying video settings...")
	
	# Apply resolution first (in windowed mode)
	if not pending_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().process_frame  # Wait a frame
		
		var resolutions = [
			Vector2i(1920, 1080),
			Vector2i(1600, 900),
			Vector2i(1366, 768),
			Vector2i(1280, 720),
			Vector2i(2560, 1440),
			Vector2i(3840, 2160)
		]
		
		if pending_resolution_index < resolutions.size():
			DisplayServer.window_set_size(resolutions[pending_resolution_index])
			print("Resolution set to: ", resolutions[pending_resolution_index])
	
	# Apply fullscreen mode
	if pending_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("Fullscreen enabled")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Windowed mode enabled")
	
	# Apply VSync
	if pending_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		print("VSync enabled")
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("VSync disabled")
	
	# Disable apply button
	apply_button.disabled = true
	apply_button.text = "Applied!"
	
	# Reset button text after a moment
	await get_tree().create_timer(1.0).timeout
	apply_button.text = "Apply"

func close_settings():
	settings_closed.emit()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_settings()
