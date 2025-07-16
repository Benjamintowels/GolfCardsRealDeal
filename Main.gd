extends Control

@onready var character1_button = $UI/Character1Button
@onready var character2_button = $UI/Character2Button  
@onready var character3_button = $UI/Character3Button
@onready var start_putt_putt_button = $UI/StartPuttPutt
@onready var start_back_9_button = $UI/StartBack9
@onready var driving_range_button = $UI/DrivingRange
@onready var select_sound = $Select

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
	start_putt_putt_button.pressed.connect(_on_start_putt_putt_button_pressed)
	start_back_9_button.pressed.connect(_on_start_back_9_pressed)
	driving_range_button.pressed.connect(_on_driving_range_button_pressed)
	
	print("Buttons connected successfully")
	print("Initial selected_character: ", selected_character)

func _play_select_sound():
	select_sound.play()

func _on_character1_selected():
	_play_select_sound()
	selected_character = 1
	print("Character 1 (Layla) selected, selected_character = ", selected_character)

func _on_character2_selected():
	_play_select_sound()
	selected_character = 2
	print("Character 2 (Benny) selected, selected_character = ", selected_character)

func _on_character3_selected():
	_play_select_sound()
	selected_character = 3
	print("Character 3 (Clark) selected, selected_character = ", selected_character)

func _on_start_round_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	Global.putt_putt_mode = false  # Ensure normal mode for regular rounds
	print("Selected character: ", selected_character, " - Starting normal round")
	
	# Change scene on next frame
	call_deferred("_change_scene")

func _on_start_putt_putt_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	Global.putt_putt_mode = true  # Enable putt putt mode
	print("Selected character: ", selected_character, " - Starting Putt Putt mode")
	
	# Change scene on next frame
	call_deferred("_change_scene")

func _on_start_back_9_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Back 9")
	print("Global.selected_character set to: ", Global.selected_character)
	
	# Set back 9 mode flag and start normal course
	Global.starting_back_9 = true
	call_deferred("_change_scene")

func _on_driving_range_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Driving Range")
	
	# Change to driving range scene
	call_deferred("_change_to_driving_range")

func _change_scene():
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func _change_to_driving_range():
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Stages/DrivingRange.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()
