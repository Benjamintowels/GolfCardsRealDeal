extends Control

@onready var character_image: TextureRect = $CharacterImage
@onready var start_back_9_button: Button = $StartBack9Button
@onready var shop_entrance_button: TextureButton = $ShopEntrance

func _ready():
	# Set process mode to handle input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect the button signals
	if start_back_9_button:
		start_back_9_button.pressed.connect(_on_start_back_9_pressed)
	else:
		print("MidGameShop: ERROR - start_back_9_button is null!")
		
	if shop_entrance_button:
		shop_entrance_button.pressed.connect(_on_shop_entrance_pressed)
	else:
		print("MidGameShop: ERROR - shop_entrance_button is null!")
	
	# Set initial character image based on selected character
	_set_character_image()

func _set_character_image():
	# Get the selected character from Global
	var selected_character = Global.selected_character
	
	# Load and set the character image
	var character_texture = _get_character_texture(selected_character)
	if character_texture:
		character_image.texture = character_texture

func _get_character_texture(character_number: int) -> Texture2D:
	# Map character numbers to the specific mid-game character textures
	var character_textures = {
		1: preload("res://LaylaMid.png"),    # Layla
		2: preload("res://BennyMid.png"),    # Benny  
		3: preload("res://ClarkMid.png"),    # Clark
	}
	
	return character_textures.get(character_number, character_textures[1])

func _on_shop_entrance_pressed():
	"""Handle shop entrance button press - enter the actual shop"""
	# Get the course scene to enter the shop
	var course = get_tree().current_scene
	
	if course and course.has_method("enter_shop"):
		# Remove this mid-game shop overlay first
		queue_free()
		# Enter the actual shop
		course.enter_shop()
	else:
		print("MidGameShop: ERROR - Course scene not found or missing enter_shop method")

func _on_start_back_9_pressed():
	"""Handle starting the back 9 holes - load hole 10 and continue game"""
	# Set a flag to indicate we're starting back 9
	Global.starting_back_9 = true
	
	# Get the course scene to continue with hole 10
	var course = get_tree().current_scene
	
	if course and course.has_method("continue_to_hole_10"):
		# Remove this mid-game shop overlay first
		queue_free()
		# Continue to hole 10
		course.continue_to_hole_10()
	else:
		print("MidGameShop: ERROR - Course scene not found or missing continue_to_hole_10 method")
