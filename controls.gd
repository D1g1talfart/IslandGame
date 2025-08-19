extends Control

signal back_pressed

func _ready():
	$VBoxContainer/Back_Button.pressed.connect(func(): back_pressed.emit())
	
	# Set up your controls text
	$VBoxContainer/ControlsList.text = """
	WASD - Move Camera
	Mouse - Look Around
	Space - Generate New Island
	ESC - Return to Menu
	"""
