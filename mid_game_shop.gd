extends Control

@onready var character_image: TextureRect = $CharacterImage
@onready var start_back_9_button: Button = $StartBack9Button
@onready var place_flag_button: Button = $PlaceFlagButton
@onready var shop_entrance_button: TextureButton = $ShopEntrance
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var map_flag: Sprite2D = $Node2D/MapFlag

func _ready():
	# Set process mode to handle input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect the button signals
	if start_back_9_button:
		start_back_9_button.pressed.connect(_on_start_back_9_pressed)
	else:
		print("MidGameShop: ERROR - start_back_9_button is null!")
	
	if place_flag_button:
		place_flag_button.pressed.connect(_on_place_flag_pressed)
	else:
		print("MidGameShop: ERROR - place_flag_button is null!")
		
	if shop_entrance_button:
		shop_entrance_button.pressed.connect(_on_shop_entrance_pressed)
	else:
		print("MidGameShop: ERROR - shop_entrance_button is null!")
	
	# Set initial character image based on selected character
	_set_character_image()
	
	# Update UI based on current state
	_update_ui()

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

func _update_ui():
	"""Update UI based on current state"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if not save_file_manager:
		return
	
	# Check if back 9 flag upgrade is already purchased
	var flag_purchased = save_file_manager.get_story_flag("back_9_flag_upgrade_purchased")
	
	# Show/hide place flag button based on purchase status and available Looty
	if place_flag_button:
		if flag_purchased:
			# Flag already purchased - hide button and show flag
			place_flag_button.visible = false
			if map_flag:
				map_flag.visible = true
		else:
			# Check if player has enough Looty (300)
			var current_looty = Global.current_looty
			place_flag_button.visible = true
			place_flag_button.disabled = (current_looty < 300)
			
			# Update button text to show cost
			place_flag_button.text = "Place Back 9 Flag (300 $Looty)"
			
			# Show flag if purchased
			if map_flag:
				map_flag.visible = false

func _on_place_flag_pressed():
	"""Handle flag placement button press"""
	print("=== PLACING BACK 9 FLAG ===")
	
	# Check if player has enough Looty
	if Global.current_looty < 300:
		print("MidGameShop: ERROR - Not enough Looty for flag placement!")
		return
	
	# Deduct Looty
	Global.current_looty -= 300
	print("MidGameShop: Deducted 300 $Looty for flag placement. New balance:", Global.current_looty)
	
	# Set the story flag
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager:
		save_file_manager.set_story_flag("back_9_flag_upgrade_purchased", true)
		save_file_manager.save_current_game()
		print("MidGameShop: Back 9 flag upgrade purchased and saved")
	
	# Play the place_flag animation
	if animation_player:
		animation_player.play("place_flag")
		print("MidGameShop: Playing place_flag animation")
		
		# Wait for animation to complete
		await animation_player.animation_finished
		
		# Show the flag permanently
		if map_flag:
			map_flag.visible = true
		
		# Update UI
		_update_ui()
		
		print("MidGameShop: Flag placement complete!")
	else:
		print("MidGameShop: ERROR - Animation player not found!")

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
