extends Control

# Driving Range Minigame
signal driving_range_completed

@onready var character_image = $UILayer/CharacterImage
@onready var character_label = $UILayer/CharacterLabel
@onready var card_stack_display := $UILayer/CardStackDisplay
@onready var card_hand_anchor: Control = $UILayer/CardHandAnchor
@onready var card_anchor := $UILayer/CardAnchor
@onready var hud = $UILayer/HUD
@onready var ui_layer := self
@onready var movement_buttons_container: BoxContainer = $UILayer/CardHandAnchor/CardRow
@onready var card_click_sound: AudioStreamPlayer2D = $CardClickSound
@onready var card_play_sound: AudioStreamPlayer2D = $CardPlaySound
@onready var birds_tweeting_sound: AudioStreamPlayer2D = $BirdsTweeting
@onready var obstacle_layer = $ObstacleLayer
@onready var camera := $GameCamera
@onready var map_manager := $MapManager
@onready var build_map := $BuildMap
@onready var draw_club_cards_button: Control = $UILayer/DrawClubCards
@onready var power_meter: Control = $UILayer/PowerMeter
@onready var launch_manager = $LaunchManager
@onready var background_manager: Node = $BackgroundManager

# Driving Range specific variables
var player_node: Node2D
var player_grid_pos := Vector2i(8, 0)  # Tee position (far left)
var cell_size: int = 48
var grid_size := Vector2i(250, 10)  # Wide and narrow layout
var grid_tiles = []
var grid_container: Control
var camera_container: Control

# Club selection variables
var movement_buttons := []
var selected_club: String = ""
var club_data = {
	"Driver": {
		"max_distance": 1200.0,
		"min_distance": 800.0,
		"trailoff_forgiveness": 0.3,
		"min_height": 10.0,
		"max_height": 120.0
	},
	"Hybrid": {
		"max_distance": 1050.0,
		"min_distance": 200.0,
		"trailoff_forgiveness": 0.8,
		"min_height": 15.0,
		"max_height": 200.0
	},
	"Wood": {
		"max_distance": 800.0,
		"min_distance": 300.0,
		"trailoff_forgiveness": 0.6,
		"min_height": 18.0,
		"max_height": 280.0
	},
	"Iron": {
		"max_distance": 600.0,
		"min_distance": 250.0,
		"trailoff_forgiveness": 0.5,
		"min_height": 19.0,
		"max_height": 320.0
	},
	"Wooden": {
		"max_distance": 350.0,
		"min_distance": 200.0,
		"trailoff_forgiveness": 0.7,
		"min_height": 20.0,
		"max_height": 350.0
	},
	"Putter": {
		"max_distance": 200.0,
		"min_distance": 50.0,
		"trailoff_forgiveness": 0.9,
		"min_height": 0.0,
		"max_height": 50.0
	},
	"PitchingWedge": {
		"max_distance": 200.0,
		"min_distance": 100.0,
		"trailoff_forgiveness": 0.8,
		"min_height": 25.0,
		"max_height": 400.0
	},
	"FireClub": {
		"max_distance": 800.0,
		"min_distance": 300.0,
		"trailoff_forgiveness": 0.6,
		"min_height": 18.0,
		"max_height": 280.0
	},
	"IceClub": {
		"max_distance": 800.0,
		"min_distance": 300.0,
		"trailoff_forgiveness": 0.6,
		"min_height": 18.0,
		"max_height": 280.0
	},
	"GrenadeLauncherClubCard": {
		"max_distance": 2000.0,
		"min_distance": 500.0,
		"trailoff_forgiveness": 0.4,
		"min_height": 30.0,
		"max_height": 500.0
	}
}

# Available club cards for random selection
var available_club_cards: Array[CardData] = [
	preload("res://Cards/Putter.tres"),
	preload("res://Cards/Wood.tres"),
	preload("res://Cards/Wooden.tres"),
	preload("res://Cards/Iron.tres"),
	preload("res://Cards/Hybrid.tres"),
	preload("res://Cards/Driver.tres"),
	preload("res://Cards/PitchingWedge.tres"),
	preload("res://Cards/FireClub.tres"),
	preload("res://Cards/IceClub.tres"),
	preload("res://Cards/GrenadeLauncherClubCard.tres")
]

# Game state variables
var game_phase := "setup"  # setup, draw_clubs, aiming, launch, ball_flying, distance_dialog
var current_shot_distance := 0.0
var current_record_distance := 0.0
var shots_taken := 0
var max_shots := 10  # Number of shots per session

# Auto-aiming variables
var aiming_circle: Control = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var max_shot_distance: float = 800.0

# Distance dialog
var drive_distance_dialog: Control = null
var distance_dialog_scene = preload("res://UI/DrivingRangeDistanceDialog.tscn")

# Return to clubhouse button
var return_button: Button = null

# Required variables for build_map setup
var obstacle_map: Dictionary = {}
var ysort_objects: Array = []

# Scene maps for build_map setup
var tile_scene_map := {
	"W": preload("res://Obstacles/WaterHazard.tscn"),
	"F": preload("res://Obstacles/Fairway.tscn"),
	"S": preload("res://Obstacles/SandTrap.tscn"),
	"R": preload("res://Obstacles/Rough.tscn"),
	"G": preload("res://Obstacles/Green.tscn"),
	"Tee": preload("res://Obstacles/Tee.tscn"),
	"Base": preload("res://Obstacles/Base.tscn"),
	"SHOP": preload("res://Obstacles/Base.tscn"),
}

var object_scene_map := {
	"T": preload("res://Obstacles/Tree.tscn"),
	"P": preload("res://Obstacles/Pin.tscn"),
	"SHOP": preload("res://Shop/ShopExterior.tscn"),
	"BLOCK": preload("res://Obstacles/InvisibleBlocker.tscn"),
	"GANG": preload("res://NPC/Gang/GangMember.tscn"),
	"POLICE": preload("res://NPC/Police/Police.tscn"),
	"OIL": preload("res://Interactables/OilDrum.tscn"),
	"WALL": preload("res://Obstacles/StoneWall.tscn"),
	"BOULDER": preload("res://Obstacles/Boulder.tscn"),
	"BUSH": preload("res://Obstacles/Bush.tscn"),
	"GRASS": preload("res://Obstacles/GrassVariations/SummerGrass.tscn"),
	"ZOMBIE": preload("res://NPC/Zombies/ZombieGolfer.tscn"),
	"SQUIRREL": preload("res://NPC/Animals/Squirrel.tscn"),
	"BONFIRE": preload("res://Interactables/Bonfire.tscn"),
	"SUITCASE": preload("res://MapSuitCase.tscn"),
	"WRAITH": preload("res://NPC/Bosses/Wraith.tscn"),
}

var object_to_tile_mapping := {
	"T": "Base",
	"P": "G",
	"SHOP": "Base",
	"GANG": "G",
	"POLICE": "R",
	"OIL": "Base",
	"WALL": "Base",
	"BOULDER": "Base",
	"BUSH": "Base",
	"GRASS": "Base",
	"ZOMBIE": "S",
	"SQUIRREL": "Base",
	"BONFIRE": "Base",
	"WRAITH": "G",
}

func _ready():
	# Initialize the driving range
	setup_driving_range()
	
	# Load current record
	load_driving_range_record()
	
	# Start the game
	start_driving_range_session()

func setup_driving_range():
	"""Initialize the driving range scene"""
	print("Setting up Driving Range...")
	
	# Check critical @onready variables
	if not movement_buttons_container:
		print("ERROR: movement_buttons_container is null!")
	if not draw_club_cards_button:
		print("ERROR: draw_club_cards_button is null!")
	if not power_meter:
		print("ERROR: power_meter is null!")
	if not launch_manager:
		print("ERROR: launch_manager is null!")
	if not map_manager:
		print("ERROR: map_manager is null!")
	if not build_map:
		print("ERROR: build_map is null!")
	if not background_manager:
		print("ERROR: background_manager is null!")
	
	# Set up camera container
	camera_container = Control.new()
	camera_container.name = "CameraContainer"
	add_child(camera_container)
	
	# Set up grid container
	grid_container = Control.new()
	grid_container.name = "GridContainer"
	camera_container.add_child(grid_container)
	
	# Initialize grid
	initialize_grid()
	
	# Setup build_map with necessary data
	if build_map:
		build_map.setup(
			tile_scene_map,
			object_scene_map,
			object_to_tile_mapping,
			cell_size,
			obstacle_layer,
			obstacle_map,
			ysort_objects
		)
		build_map.current_hole = 0  # Driving range is hole 0
	else:
		print("ERROR: build_map is null!")
	
	# Build the map from layout
	map_manager.load_map_data(DrivingRangeLayout.LAYOUT)
	if build_map:
		build_map.build_map_from_layout_with_randomization(map_manager.level_layout)
	else:
		print("ERROR: build_map is null, cannot build map!")
	
	# Place player on tee
	place_player_on_tee()
	
	# Set up camera
	position_camera_on_player()
	
	# Set up background
	if background_manager:
		background_manager.set_camera_reference(camera)
		background_manager.set_theme("course1")
		print("✓ Background manager initialized with course1 theme")
	else:
		print("ERROR: background_manager is null!")
	
	# Play ambient sounds
	if birds_tweeting_sound:
		birds_tweeting_sound.play()
	
	# Connect DrawClubCards button signal
	if draw_club_cards_button:
		var texture_button = draw_club_cards_button.get_node_or_null("TextureButton")
		if texture_button:
			texture_button.pressed.connect(_on_draw_club_cards_pressed)
		else:
			print("ERROR: Could not find TextureButton in draw_club_cards_button")
	else:
		print("ERROR: draw_club_cards_button is null!")
	
	# Connect PowerMeter signal
	if power_meter:
		power_meter.power_changed.connect(_on_power_meter_changed)
		power_meter.sweet_spot_hit.connect(_on_sweet_spot_hit)
	else:
		print("ERROR: power_meter is null!")

func initialize_grid():
	"""Initialize the grid system"""
	grid_tiles = []
	for y in grid_size.y:
		grid_tiles.append([])
		for x in grid_size.x:
			grid_tiles[y].append(null)

func place_player_on_tee():
	"""Place the player on the tee position"""
	print("Placing player on tee at position:", player_grid_pos)
	
	# Create player node using simplified DrivingRange player
	var player_scene = preload("res://Characters/DrivingRangePlayer.tscn")
	player_node = player_scene.instantiate()
	
	# Set up player
	player_node.setup(grid_size, cell_size, 2, {})  # Base mobility 2
	player_node.set_grid_position(player_grid_pos)
	
	# Add character sprite based on selected character
	add_character_sprite_to_player()
	
	# Add player to camera container
	camera_container.add_child(player_node)
	
	# Connect player signals
	player_node.player_clicked.connect(_on_player_clicked)
	
	# Set camera reference for mouse facing
	player_node.set_camera_reference(camera)
	
	# Set up character image in UI
	setup_character_image()
	
	print("Player placed on tee successfully")

func add_character_sprite_to_player():
	"""Add the appropriate character sprite to the player based on selected character"""
	var char_scene_path = ""
	var char_scale = Vector2.ONE
	var char_offset = Vector2.ZERO
	
	match Global.selected_character:
		1:
			char_scene_path = "res://Characters/LaylaChar.tscn"
			char_scale = Vector2.ONE
			char_offset = Vector2.ZERO
		2:
			char_scene_path = "res://Characters/BennyChar.tscn"
			char_scale = Vector2.ONE
			char_offset = Vector2.ZERO
		3:
			char_scene_path = "res://Characters/ClarkChar.tscn"
			char_scale = Vector2.ONE
			char_offset = Vector2.ZERO
		_:
			char_scene_path = "res://Characters/BennyChar.tscn" # Default to Benny if unknown
			char_scale = Vector2.ONE
			char_offset = Vector2.ZERO
	
	if char_scene_path != "":
		var char_scene = load(char_scene_path)
		if char_scene:
			var char_instance = char_scene.instantiate()
			char_instance.scale = char_scale
			char_instance.position = char_offset
			player_node.add_child(char_instance)
			print("Added character sprite:", char_scene_path)
		else:
			print("ERROR: Could not load character scene:", char_scene_path)

func setup_character_image():
	"""Set up the character image in the UI based on selected character"""
	if not character_image:
		print("ERROR: character_image is null!")
		return
	
	var character_texture = null
	match Global.selected_character:
		1:
			character_texture = load("res://Character1.png")
			character_image.scale = Vector2(0.42, 0.42)
			character_image.position.y = 320.82
		2:
			character_texture = load("res://Character2.png")
			character_image.scale = Vector2(0.42, 0.42)
			character_image.position.y = 320.82
		3:
			character_texture = load("res://Character3.png")
			character_image.scale = Vector2(0.42, 0.42)
			character_image.position.y = 320.82
		_:
			character_texture = load("res://Character2.png") # Default to Benny
			character_image.scale = Vector2(0.42, 0.42)
			character_image.position.y = 320.82
	
	if character_texture:
		character_image.texture = character_texture
		print("Set character image for character:", Global.selected_character)
	else:
		print("ERROR: Could not load character texture for character:", Global.selected_character)

func position_camera_on_player():
	"""Position camera on the player"""
	if player_node and camera:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		camera.position = player_center
		print("Camera positioned on player")

func start_driving_range_session():
	"""Start a new driving range session"""
	print("Starting Driving Range session...")
	game_phase = "draw_clubs"
	shots_taken = 0
	
	# Show current record in HUD
	update_hud()
	
	# Start first shot
	start_new_shot()

func start_new_shot():
	"""Start a new shot sequence"""
	if shots_taken >= max_shots:
		show_session_complete_dialog()
		return
	
	print("Starting shot", shots_taken + 1, "of", max_shots)
	game_phase = "draw_clubs"
	
	# Place new ball on tee
	place_ball_on_tee()
	
	# Show draw club cards button
	show_draw_club_cards_button()

func place_ball_on_tee():
	"""Place a new golf ball on the tee"""
	# Check if launch_manager is available
	if not launch_manager:
		print("ERROR: launch_manager is null!")
		return
	
	# Remove existing ball
	if launch_manager.golf_ball:
		launch_manager.golf_ball.queue_free()
		launch_manager.golf_ball = null
	
	# Create new ball
	var ball_scene = preload("res://GolfBall.tscn")
	launch_manager.golf_ball = ball_scene.instantiate()
	
	# Position ball on tee
	var ball_position = Vector2(player_grid_pos.x * cell_size + cell_size / 2, 
							   player_grid_pos.y * cell_size + cell_size / 2)
	launch_manager.golf_ball.position = ball_position
	launch_manager.golf_ball.cell_size = cell_size
	launch_manager.golf_ball.map_manager = map_manager
	
	# Add ball to camera container
	camera_container.add_child(launch_manager.golf_ball)
	launch_manager.golf_ball.add_to_group("balls")
	
	print("New ball placed on tee")

func show_draw_club_cards_button():
	"""Show the draw club cards button"""
	if draw_club_cards_button:
		draw_club_cards_button.visible = true
		print("Draw Club Cards button shown")
	else:
		print("ERROR: draw_club_cards_button is null!")

func _on_draw_club_cards_pressed():
	"""Handle draw club cards button press"""
	print("Draw Club Cards button pressed")
	draw_club_cards()

func draw_club_cards():
	"""Draw 2 random club cards for selection"""
	print("Drawing club cards...")
	
	# Check if movement_buttons_container is available
	if not movement_buttons_container:
		print("ERROR: movement_buttons_container is null!")
		return
	
	# Clear existing buttons
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	
	# Generate 2 random club cards
	var remaining_cards = available_club_cards.duplicate()
	var selected_cards: Array[CardData] = []
	
	for i in range(2):
		if remaining_cards.size() > 0:
			var random_index = randi() % remaining_cards.size()
			selected_cards.append(remaining_cards[random_index])
			remaining_cards.remove_at(random_index)
	
	# Create club selection buttons
	for i in range(selected_cards.size()):
		var club_card = selected_cards[i]
		var club_name = club_card.name
		var club_info = club_data.get(club_name, {})
		
		var btn := TextureButton.new()
		btn.name = "ClubButton%d" % i
		btn.texture_normal = club_card.image
		btn.custom_minimum_size = Vector2(100, 140)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.z_index = 10
		
		# Add hover effect
		var overlay := ColorRect.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(1, 0.84, 0, 0.25)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		btn.add_child(overlay)
		
		btn.mouse_entered.connect(func(): overlay.visible = true)
		btn.mouse_exited.connect(func(): overlay.visible = false)
		btn.pressed.connect(func(): _on_club_card_pressed(club_name, club_info, btn))
		
		movement_buttons_container.add_child(btn)
		movement_buttons.append(btn)
	
	draw_club_cards_button.visible = false
	print("Club cards drawn and displayed")

func _on_club_card_pressed(club_name: String, club_info: Dictionary, button: TextureButton):
	"""Handle club card selection"""
	selected_club = club_name
	max_shot_distance = club_info.get("max_distance", 600.0)
	card_click_sound.play()
	
	print("Selected club:", club_name, "Max distance:", max_shot_distance)
	
	# Clear club selection UI
	if movement_buttons_container:
		for child in movement_buttons_container.get_children():
			child.queue_free()
	movement_buttons.clear()
	
	# Enter aiming phase with auto-aiming
	enter_aiming_phase()

func enter_aiming_phase():
	"""Enter aiming phase with auto-aiming"""
	game_phase = "aiming"
	print("Entering aiming phase with auto-aiming")
	
	# Auto-place aiming circle at max distance to the right
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	
	# Calculate auto-aim position (straight to the right at max distance)
	chosen_landing_spot = player_center + Vector2(max_shot_distance, 0)
	
	# Create aiming circle
	create_aiming_circle(chosen_landing_spot)
	
	# Enter launch phase immediately
	enter_launch_phase()

func create_aiming_circle(position: Vector2):
	"""Create the aiming circle at the specified position"""
	if aiming_circle:
		aiming_circle.queue_free()
	
	aiming_circle = Control.new()
	aiming_circle.name = "AimingCircle"
	aiming_circle.position = position - Vector2(25, 25)  # Center the circle
	aiming_circle.z_index = 100
	
	# Create circle visual
	var circle := ColorRect.new()
	circle.name = "CircleVisual"
	circle.size = Vector2(50, 50)
	circle.color = Color(1, 0, 0, 0.8)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(circle)
	
	# Add distance label
	var distance_label := Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.text = str(int(max_shot_distance)) + "px"
	distance_label.add_theme_font_size_override("font_size", 12)
	distance_label.add_theme_color_override("font_color", Color.WHITE)
	distance_label.add_theme_constant_override("outline_size", 1)
	distance_label.add_theme_color_override("font_outline_color", Color.BLACK)
	distance_label.position = Vector2(0, 55)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(distance_label)
	
	camera_container.add_child(aiming_circle)
	print("Aiming circle created at:", position)

func enter_launch_phase():
	"""Enter launch phase"""
	game_phase = "launch"
	print("Entering launch phase")
	
	# Check if launch_manager is available
	if not launch_manager:
		print("ERROR: launch_manager is null!")
		return
	
	# Set up launch manager
	launch_manager.camera_container = camera_container
	launch_manager.ui_layer = ui_layer
	launch_manager.player_node = player_node
	launch_manager.cell_size = cell_size
	launch_manager.chosen_landing_spot = chosen_landing_spot
	launch_manager.selected_club = selected_club
	launch_manager.club_data = club_data
	
	# Connect launch manager signals
	launch_manager.ball_landed.connect(_on_golf_ball_landed)
	launch_manager.ball_out_of_bounds.connect(_on_golf_ball_out_of_bounds)
	
	# Start height selection
	launch_manager.enter_launch_phase()

func _on_golf_ball_landed(tile: Vector2i):
	"""Handle golf ball landing"""
	print("Ball landed at tile:", tile)
	game_phase = "ball_flying"
	
	# Calculate drive distance
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var ball_position = launch_manager.golf_ball.global_position
	current_shot_distance = player_center.distance_to(ball_position)
	
	print("Drive distance:", current_shot_distance, "pixels")
	
	# Follow ball with camera
	follow_ball_with_camera()
	
	# Wait for ball to stop, then show distance dialog
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(show_drive_distance_dialog)

func _on_golf_ball_out_of_bounds():
	"""Handle ball going out of bounds"""
	print("Ball went out of bounds")
	current_shot_distance = 0.0
	show_drive_distance_dialog()

func follow_ball_with_camera():
	"""Follow the ball with the camera"""
	if not launch_manager or not launch_manager.golf_ball or not camera:
		print("ERROR: Cannot follow ball - missing required components")
		return
	
	var ball_position = launch_manager.golf_ball.global_position
	var tween = create_tween()
	tween.tween_property(camera, "position", ball_position, 1.0)
	print("Camera following ball")

func show_drive_distance_dialog():
	"""Show the drive distance dialog"""
	print("Showing drive distance dialog")
	game_phase = "distance_dialog"
	
	# Check if this is a new record
	var is_new_record = current_shot_distance > current_record_distance
	
	if drive_distance_dialog:
		drive_distance_dialog.queue_free()
	
	drive_distance_dialog = distance_dialog_scene.instantiate()
	
	# Connect dialog signal
	drive_distance_dialog.dialog_closed.connect(_on_drive_distance_dialog_closed)
	
	# Show dialog with information
	drive_distance_dialog.show_dialog(current_shot_distance, is_new_record, shots_taken + 1, max_shots)
	
	# Update record if it's a new record
	if is_new_record:
		current_record_distance = current_shot_distance
		save_driving_range_record()
	
	ui_layer.add_child(drive_distance_dialog)

func _on_drive_distance_dialog_closed():
	"""Handle drive distance dialog closing"""
	print("Drive distance dialog closed")
	
	# Increment shot counter
	shots_taken += 1
	
	# Tween camera back to player
	tween_camera_back_to_player()
	
	# Start next shot or end session
	if shots_taken < max_shots:
		start_new_shot()
	else:
		show_session_complete_dialog()

func tween_camera_back_to_player():
	"""Tween camera back to player position"""
	if player_node and camera:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var tween = create_tween()
		tween.tween_property(camera, "position", player_center, 1.0)
		print("Camera returning to player")

func show_session_complete_dialog():
	"""Show session complete dialog"""
	print("Showing session complete dialog")
	game_phase = "session_complete"
	
	var dialog = AcceptDialog.new()
	dialog.title = "Driving Range Session Complete!"
	dialog.dialog_text = "Session Complete!\n\nShots taken: %d\nBest distance: %d pixels\nCurrent record: %d pixels" % [shots_taken, current_record_distance, current_record_distance]
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.CYAN)
	dialog.position = Vector2(400, 300)
	ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(_on_session_complete_confirmed)

func _on_session_complete_confirmed():
	"""Handle session complete confirmation"""
	print("Session complete confirmed")
	# Return to main menu
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_return_to_clubhouse_pressed():
	"""Handle return to clubhouse button press"""
	print("Return to clubhouse button pressed")
	# Return to main menu
	get_tree().change_scene_to_file("res://Main.tscn")

func update_hud():
	"""Update the HUD display"""
	if hud:
		# Update shot counter
		var shot_label = hud.get_node_or_null("ShotLabel")
		if not shot_label:
			shot_label = Label.new()
			shot_label.name = "ShotLabel"
			hud.add_child(shot_label)
		shot_label.text = "Shot: %d/%d" % [shots_taken + 1, max_shots]
		
		# Update record display
		var record_label = hud.get_node_or_null("RecordLabel")
		if not record_label:
			record_label = Label.new()
			record_label.name = "RecordLabel"
			hud.add_child(record_label)
		record_label.text = "Record: %d pixels" % current_record_distance
		record_label.add_theme_color_override("font_color", Color.GOLD)

func _on_player_clicked():
	"""Handle player click (not used in driving range)"""
	pass

func load_driving_range_record():
	"""Load the current driving range record"""
	var save_file = FileAccess.open("user://driving_range_record.save", FileAccess.READ)
	if save_file:
		current_record_distance = save_file.get_float()
		save_file.close()
		print("Loaded driving range record:", current_record_distance)
	else:
		current_record_distance = 0.0
		print("No previous record found, starting fresh")

func save_driving_range_record():
	"""Save the current driving range record"""
	var save_file = FileAccess.open("user://driving_range_record.save", FileAccess.WRITE)
	if save_file:
		save_file.store_float(current_record_distance)
		save_file.close()
		print("Saved new driving range record:", current_record_distance)
	else:
		print("Failed to save driving range record")

func _input(event):
	"""Handle input events"""
	if game_phase == "aiming":
		# Auto-aiming is handled automatically
		pass
	elif game_phase == "launch":
		# Launch manager handles input
		launch_manager.handle_input(event)

func _on_power_meter_changed(power_value: float):
	"""Handle power meter value changes"""
	print("Driving Range: Power meter changed to ", power_value, "%")

func _on_sweet_spot_hit():
	"""Handle sweet spot hit"""
	print("Driving Range: Sweet spot hit!")
	# You can add visual/audio feedback here
