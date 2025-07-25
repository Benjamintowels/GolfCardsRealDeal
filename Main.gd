extends Control

@onready var character1_button = $UI/Character1Button
@onready var character2_button = $UI/Character2Button  
@onready var character3_button = $UI/Character3Button
@onready var start_putt_putt_button = $UI/StartPuttPutt
@onready var start_back_9_button = $UI/StartBack9
@onready var driving_range_button = $UI/DrivingRange
@onready var boss_room_button = $UI/BossRoom
@onready var fight_room_button = $UI/FightRoom
@onready var kendama_button = $UI/Kendama
@onready var select_sound = $Select
@onready var deck_select_sound = $DeckSelect

var selected_character = 1  # Default to character 1
var deck_selection_dialog: Control
var pending_game_mode = ""  # Store which game mode was selected while waiting for deck selection

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
	boss_room_button.pressed.connect(_on_boss_room_button_pressed)
	fight_room_button.pressed.connect(_on_fight_room_button_pressed)
	kendama_button.pressed.connect(_on_kendama_button_pressed)
	
	# Create and setup deck selection dialog
	_setup_deck_selection_dialog()
	
	print("Buttons connected successfully")
	print("Initial selected_character: ", selected_character)
	print("Deck selection dialog setup complete")

func _setup_deck_selection_dialog():
	"""Setup the deck selection dialog"""
	print("Setting up deck selection dialog...")
	var dialog_scene = preload("res://DeckSelectionDialog.tscn")
	print("Dialog scene preloaded successfully")
	deck_selection_dialog = dialog_scene.instantiate()
	print("Dialog instantiated successfully")
	add_child(deck_selection_dialog)
	print("Dialog added as child")
	
	# Connect dialog signals
	deck_selection_dialog.deck_selected.connect(_on_deck_selected)
	deck_selection_dialog.dialog_closed.connect(_on_deck_dialog_closed)
	print("Dialog signals connected")

func _play_select_sound():
	select_sound.play()

func _play_deck_select_sound():
	deck_select_sound.play()

func _on_character1_selected():
	_play_select_sound()
	selected_character = 1
	print("Character 1 (Layla) selected, selected_character = ", selected_character)
	print("About to show deck selection dialog...")
	_show_deck_selection_dialog()

func _on_character2_selected():
	_play_select_sound()
	selected_character = 2
	print("Character 2 (Benny) selected, selected_character = ", selected_character)
	print("About to show deck selection dialog...")
	_show_deck_selection_dialog()

func _on_character3_selected():
	_play_select_sound()
	selected_character = 3
	print("Character 3 (Clark) selected, selected_character = ", selected_character)
	print("About to show deck selection dialog...")
	_show_deck_selection_dialog()

func _show_deck_selection_dialog():
	"""Show the deck selection dialog"""
	print("_show_deck_selection_dialog() called")
	if deck_selection_dialog:
		print("Deck selection dialog found, showing...")
		deck_selection_dialog.show_dialog()
	else:
		print("ERROR: Deck selection dialog is null!")

func _on_deck_selected(deck_type: String):
	"""Handle deck selection from dialog"""
	print("Deck selected:", deck_type)
	# Play deck selection sound
	_play_deck_select_sound()
	# Store the selected deck type in Global for reference
	Global.selected_deck_type = deck_type
	
	# If there was a pending game mode, start it now
	if pending_game_mode != "":
		_start_pending_game_mode()

func _on_deck_dialog_closed():
	"""Handle deck dialog being closed without selection"""
	print("Deck selection dialog closed without selection")
	pending_game_mode = ""  # Clear any pending game mode

func _on_start_round_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	Global.putt_putt_mode = false  # Ensure normal mode for regular rounds
	print("Selected character: ", selected_character, " - Starting normal round")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "normal_round"
		_show_deck_selection_dialog()
	else:
		# Change scene on next frame
		call_deferred("_change_scene")

func _on_start_putt_putt_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	Global.putt_putt_mode = true  # Enable putt putt mode
	print("Selected character: ", selected_character, " - Starting Putt Putt mode")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "putt_putt"
		_show_deck_selection_dialog()
	else:
		# Change scene on next frame
		call_deferred("_change_scene")

func _on_start_back_9_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Back 9")
	print("Global.selected_character set to: ", Global.selected_character)
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "back_9"
		_show_deck_selection_dialog()
	else:
		# Set back 9 mode flag and start normal course
		Global.starting_back_9 = true
		call_deferred("_change_scene")

func _on_driving_range_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Driving Range")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "driving_range"
		_show_deck_selection_dialog()
	else:
		# Change to the driving range scene
		call_deferred("_change_to_driving_range")

func _on_boss_room_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Boss Room")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "boss_room"
		_show_deck_selection_dialog()
	else:
		# Set boss room mode flag
		Global.boss_room_mode = true
		# Change to Course1 scene with boss room mode
		call_deferred("_change_to_boss_room")

func _on_fight_room_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Fight Room")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "fight_room"
		_show_deck_selection_dialog()
	else:
		# Set fight room mode flag
		Global.fight_room_mode = true
		# Change to Course1 scene with fight room mode
		call_deferred("_change_to_fight_room")

func _on_kendama_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Kendama Game")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "kendama"
		_show_deck_selection_dialog()
	else:
		# Change to the Kendama game scene
		call_deferred("_change_to_kendama_game")

func _start_pending_game_mode():
	"""Start the pending game mode after deck selection"""
	match pending_game_mode:
		"normal_round":
			_change_scene()
		"putt_putt":
			_change_scene()
		"back_9":
			Global.starting_back_9 = true
			_change_scene()
		"driving_range":
			_change_to_driving_range()
		"boss_room":
			Global.boss_room_mode = true
			_change_to_boss_room()
		"fight_room":
			Global.fight_room_mode = true
			_change_to_fight_room()
		"kendama":
			_change_to_kendama_game()
	
	pending_game_mode = ""  # Clear the pending mode

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

func _change_to_boss_room():
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func _change_to_fight_room():
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func _change_to_kendama_game():
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Stages/KendamaGame/KendamaGame.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()
