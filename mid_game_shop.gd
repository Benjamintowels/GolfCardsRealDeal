extends Control

@onready var character_image: TextureRect = $CharacterImage
@onready var start_back_9_button: Button = $StartBack9Button

func _ready():
	# Connect the button signal
	start_back_9_button.pressed.connect(_on_start_back_9_pressed)
	
	# Set initial character image based on selected character
	_set_character_image()

func _set_character_image():
	# Get the selected character from Global
	var selected_character = Global.selected_character
	print("MidGameShop: Global.selected_character = ", selected_character)
	
	# Load and set the character image
	var character_texture = _get_character_texture(selected_character)
	if character_texture:
		character_image.texture = character_texture
		print("MidGameShop: Set character texture for character ", selected_character)
	else:
		print("MidGameShop: Failed to load character texture for character ", selected_character)

func _get_character_texture(character_number: int) -> Texture2D:
	print("MidGameShop: Getting texture for character number: ", character_number)
	
	# Map character numbers to the specific mid-game character textures
	var character_textures = {
		1: preload("res://LaylaMid.png"),    # Layla
		2: preload("res://BennyMid.png"),    # Benny  
		3: preload("res://ClarkMid.png"),    # Clark
	}
	
	var texture = character_textures.get(character_number, character_textures[1])
	print("MidGameShop: Returning texture for character ", character_number)
	return texture

func _on_start_back_9_pressed():
	# Handle starting the back 9 holes
	print("Starting Back 9...")
	
	# Set a flag to indicate we're starting back 9
	Global.starting_back_9 = true
	
	# Use FadeManager for smooth transition to course
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
