extends Control

signal play_pressed
signal controls_pressed
signal quit_pressed
signal settings_pressed

func _ready():
	$VBoxContainer/Play_Button.pressed.connect(func(): play_pressed.emit())
	$VBoxContainer/Controls_Button.pressed.connect(func(): controls_pressed.emit())
	$VBoxContainer/Quit_Button.pressed.connect(func(): quit_pressed.emit())
	$VBoxContainer/Settings_Button.pressed.connect(func(): settings_pressed.emit())
