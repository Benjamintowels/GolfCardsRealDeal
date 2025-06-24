extends Control

@onready var character1_button = $UI/Character1Button
@onready var character2_button = $UI/Character2Button  
@onready var character3_button = $UI/Character3Button
@onready var start_round_button = $UI/StartRoundButton

var selected_character = 1  # Default to character 1

func _ready():
	# Set up button group for exclusive selection
	var button_group = ButtonGroup.new()
	character1_button.button_group = button_group
	character2_button.button_group = button_group
	character3_button.button_group = button_group
	
	# Set character 1 as default selected
	character1_button.button_pressed = true
	
	# Connect button signals
	character1_button.pressed.connect(_on_character1_selected)
	character2_button.pressed.connect(_on_character2_selected)
	character3_button.pressed.connect(_on_character3_selected)
	start_round_button.pressed.connect(_on_start_round_pressed)
	
	print("Buttons connected successfully")

func _on_character1_selected():
	selected_character = 1
	print("Character 1 selected")

func _on_character2_selected():
	selected_character = 2
	print("Character 2 selected")

func _on_character3_selected():
	selected_character = 3
	print("Character 3 selected")

func _on_start_round_pressed():
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character)
	
	# Change scene on next frame
	call_deferred("_change_scene")

func _change_scene():
	get_tree().change_scene_to_file("res://Course1.tscn")
