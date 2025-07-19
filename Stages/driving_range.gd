extends Control

const AimingCircleManager = preload("res://AimingCircleManager.gd")

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
@onready var camera := $DrivingRangeCamera
@onready var map_manager := $MapManager
@onready var build_map := $BuildMap
@onready var draw_club_cards_button: Control = $UILayer/DrawClubCards
@onready var power_meter: Control = $UILayer/PowerMeter
@onready var launch_manager = $DrivingRangeLaunchManager
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

# Game state variables
var game_phase := "setup"  # setup, draw_clubs, aiming, launch, ball_flying, distance_dialog
var current_shot_distance := 0.0
var current_record_distance := 0.0
var shots_taken := 0
var max_shots := 10  # Number of shots per session

# Auto-aiming variables
var aiming_circle: Control = null
var aiming_circle_manager: AimingCircleManager = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var max_shot_distance: float = 800.0

# Distance dialog
var drive_distance_dialog: Control = null

# Range flag for marking ball landing position
var range_flag_scene = preload("res://Stages/RangeFlag.tscn")

# Return to clubhouse button
var return_button: Button = null



# Club data for driving range
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
	
	# Build the map from layout using custom driving range function
	map_manager.load_map_data(DrivingRangeLayout.LAYOUT)
	if build_map:
		build_driving_range_map(map_manager.level_layout)
	else:
		print("ERROR: build_map is null, cannot build map!")
	
	# Place player on tee
	place_player_on_tee()
	
	# Set up camera
	setup_driving_range_camera()
	
	# Set up custom driving range background using existing layers
	if background_manager:
		# Add camera to the camera group for background system compatibility
		camera.add_to_group("camera")
		
		background_manager.set_camera_reference(camera)
		
		# Get the BackgroundLayers node from the scene
		var background_layers = get_node_or_null("BackgroundLayers")
		if background_layers:
			# Configure background manager to use existing layers
			background_manager.set_use_existing_layers(true, background_layers)
			background_manager.set_theme("driving_range")
			
			# Disable vertical parallax for now to prevent glitching
			# background_manager.setup_driving_range_vertical_parallax()
			# background_manager.enable_vertical_parallax(true)
			
			print("✓ Background manager initialized with existing driving_range layers")
		else:
			# Fallback to creating layers with code
			background_manager.set_theme("driving_range")
			print("✓ Background manager initialized with driving_range theme (code-created layers)")
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

func setup_driving_range_camera():
	"""Setup the driving range camera"""
	if not camera:
		print("ERROR: Cannot setup camera - camera is null")
		return
	
	if not player_node:
		print("ERROR: Cannot setup camera - player_node is null")
		return
	
	# Calculate player center position
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	
	# Setup the driving range camera
	camera.setup(player_center, camera_container)
	camera.position_on_player()
	
	# Make this camera the current camera
	camera.make_current()
	
	# Connect camera signals
	camera.camera_returned_to_player.connect(_on_camera_returned_to_player)
	
	print("DrivingRangeCamera setup complete")

func _on_camera_returned_to_player():
	"""Handle camera returning to player"""
	print("Camera returned to player - ready for next shot")

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
	print("DEBUG: Game phase set to:", game_phase)

	# Always reset player_grid_pos to tee for driving range
	player_grid_pos = Vector2i(8, 0)  # or whatever your tee position is

	# Reset camera tracking state to ensure it's ready for the new ball
	if camera and camera.has_method("stop_ball_tracking"):		camera.stop_ball_tracking()

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
	
	# Remove all existing balls before placing a new one
	for ball in camera_container.get_children():
		if ball.is_in_group("balls"):
			ball.queue_free()
	
	# Create new ball
	var ball_scene = preload("res://GolfBall.tscn")
	var new_ball = ball_scene.instantiate()
	new_ball.name = "GolfBall"  # Give it a name for easy access
	
	# Position ball on tee
	var ball_position = Vector2(player_grid_pos.x * cell_size + cell_size / 2, 
							   player_grid_pos.y * cell_size + cell_size / 2)
	new_ball.position = ball_position
	new_ball.cell_size = cell_size
	new_ball.map_manager = map_manager
	new_ball.collision_layer = 0 # Disable collision for the ball
	new_ball.collision_mask = 0 # Disable collision for the ball
	
	# Ensure ball is properly initialized for launch
	if new_ball.has_method("reset_ball_state"):
		new_ball.reset_ball_state()
	
	# Set ball properties to ensure it's available for launch
	if "landed_flag" in new_ball:
		new_ball.landed_flag = false
	if "in_flight" in new_ball:
		new_ball.in_flight = false
	if "velocity" in new_ball:
		new_ball.velocity = Vector2.ZERO
	
	# Add ball to camera container
	camera_container.add_child(new_ball)
	new_ball.add_to_group("balls")
	
	# Set ball reference in launch manager
	launch_manager.set_ball(new_ball)
	launch_manager.set_ball_in_flight(false)
	
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
	print("DEBUG: Current game phase:", game_phase)
	draw_club_cards()

func draw_club_cards():
	"""Draw 2 random club cards for selection"""
	print("Drawing club cards...")
	
	# Check if movement_buttons_container is available
	if not movement_buttons_container:
		print("ERROR: movement_buttons_container is null!")
		return
	
	print("DEBUG: movement_buttons_container found:", movement_buttons_container.name)
	print("DEBUG: movement_buttons_container mouse_filter before:", movement_buttons_container.mouse_filter)
	
	# Clear existing buttons
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	
	# Fix the mouse_filter to allow interactions
	movement_buttons_container.mouse_filter = Control.MOUSE_FILTER_PASS
	print("DEBUG: movement_buttons_container mouse_filter after:", movement_buttons_container.mouse_filter)
	
	# Reset container positioning for proper display
	movement_buttons_container.position = Vector2(400, 500)  # Center of screen
	movement_buttons_container.scale = Vector2.ONE  # Normal scale
	print("DEBUG: Container repositioned to:", movement_buttons_container.position, "scale:", movement_buttons_container.scale)
	
	# Generate 2 random club cards
	var remaining_cards = available_club_cards.duplicate()
	var selected_cards: Array[CardData] = []
	
	for i in range(2):
		if remaining_cards.size() > 0:
			var random_index = randi() % remaining_cards.size()
			selected_cards.append(remaining_cards[random_index])
			remaining_cards.remove_at(random_index)
	
	print("DEBUG: Selected cards:", selected_cards.map(func(card): return card.name))
	
	# Create club selection buttons
	for i in range(selected_cards.size()):
		var club_card = selected_cards[i]
		var club_name = club_card.name
		var club_info = club_data.get(club_name, {})
		
		print("DEBUG: Creating button for club:", club_name)
		
		var btn := TextureButton.new()
		btn.name = "ClubButton%d" % i
		btn.texture_normal = club_card.image
		btn.custom_minimum_size = Vector2(100, 140)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.z_index = 10
		
		# Position buttons side by side
		btn.position = Vector2(i * 120, 0)  # 120 pixels apart
		
		print("DEBUG: Button created - mouse_filter:", btn.mouse_filter, "name:", btn.name, "position:", btn.position)
		
		# Add hover effect
		var overlay := ColorRect.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(1, 0.84, 0, 0.25)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		btn.add_child(overlay)
		
		btn.mouse_entered.connect(func(): 
			print("DEBUG: Mouse entered club button:", club_name)
			overlay.visible = true
		)
		btn.mouse_exited.connect(func(): 
			print("DEBUG: Mouse exited club button:", club_name)
			overlay.visible = false
		)
		btn.pressed.connect(func(): _on_club_card_pressed(club_name, club_info, btn))
		
		movement_buttons_container.add_child(btn)
		movement_buttons.append(btn)
		
		print("DEBUG: Button added to container. Container children count:", movement_buttons_container.get_child_count())
	
	draw_club_cards_button.visible = false
	print("DEBUG: Club cards drawn and displayed. Total buttons:", movement_buttons.size())
	print("DEBUG: Container children:", movement_buttons_container.get_children().map(func(child): return child.name))

func _on_club_card_pressed(club_name: String, club_info: Dictionary, button: TextureButton):
	"""Handle club card selection"""
	print("DEBUG: Club card pressed! Club:", club_name, "Button:", button.name)
	
	selected_club = club_name
	max_shot_distance = club_info.get("max_distance", 600.0)
	card_click_sound.play()
	
	print("Selected club:", club_name, "Max distance:", max_shot_distance)
	
	# Clear club selection UI
	if movement_buttons_container:
		for child in movement_buttons_container.get_children():
			child.queue_free()
	movement_buttons.clear()
	
	# Auto-set aiming position and go straight to launch phase
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	
	# Calculate auto-aim position (straight to the right at max distance)
	chosen_landing_spot = player_center + Vector2(max_shot_distance, 0)
	
	# Create aiming circle for visual feedback
	create_aiming_circle(chosen_landing_spot)
	
	# Go straight to launch phase
	enter_launch_phase()

func enter_aiming_phase():
	"""Enter aiming phase with auto-aiming - skip manual aiming"""
	game_phase = "aiming"
	print("Entering aiming phase with auto-aiming - skipping manual aiming")
	
	# Auto-place aiming circle at max distance to the right
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	
	# Calculate auto-aim position (straight to the right at max distance)
	chosen_landing_spot = player_center + Vector2(max_shot_distance, 0)
	
	# Create aiming circle (optional - for visual feedback)
	create_aiming_circle(chosen_landing_spot)
	
	# Skip manual aiming and go straight to launch phase
	enter_launch_phase()

func create_aiming_circle(position: Vector2):
	"""Create the aiming circle at the specified position"""
	# Create AimingCircleManager if it doesn't exist
	if not aiming_circle_manager:
		aiming_circle_manager = preload("res://AimingCircleManager.tscn").instantiate()
		camera_container.add_child(aiming_circle_manager)
	
	# Create the aiming circle using the manager
	aiming_circle_manager.create_aiming_circle(position, int(max_shot_distance))
	print("Aiming circle created at:", position)

func enter_launch_phase():
	"""Enter launch phase"""
	game_phase = "launch"
	print("Entering launch phase")
	
	# Check if launch_manager is available
	if not launch_manager:
		print("ERROR: launch_manager is null!")
		return
	
	# Set up specialized DrivingRangeLaunchManager
	launch_manager.setup(camera, camera_container, ui_layer, power_meter, map_manager, cell_size, player_grid_pos, player_node)
	launch_manager.set_launch_parameters(chosen_landing_spot, selected_club, club_data)
	
	# Ensure camera is ready for tracking by resetting its state
	if camera and camera.has_method("stop_ball_tracking"):		camera.stop_ball_tracking()
	
	# Disconnect any existing signals to prevent duplicate connections
	if launch_manager.ball_landed.is_connected(_on_golf_ball_landed):
		launch_manager.ball_landed.disconnect(_on_golf_ball_landed)
	if launch_manager.ball_out_of_bounds.is_connected(_on_golf_ball_out_of_bounds):
		launch_manager.ball_out_of_bounds.disconnect(_on_golf_ball_out_of_bounds)
	
	# Connect launch manager signals
	launch_manager.ball_landed.connect(_on_golf_ball_landed)
	launch_manager.ball_out_of_bounds.connect(_on_golf_ball_out_of_bounds)
	
	# Connect to ball launched signal to start tracking
	if launch_manager.has_signal("ball_launched"):# Disconnect first to prevent duplicate connections
		if launch_manager.ball_launched.is_connected(_on_ball_launched):
			launch_manager.ball_launched.disconnect(_on_ball_launched)
		launch_manager.ball_launched.connect(_on_ball_launched)
		print("Ball launched signal connected")
	else:
		print("WARNING: ball_launched signal not found in launch_manager")
	
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
	var ball = camera_container.get_node_or_null("GolfBall")
	var ball_position = ball.global_position if ball else Vector2.ZERO
	current_shot_distance = player_center.distance_to(ball_position)
	
	print("Drive distance:", current_shot_distance, "pixels")
	
	# Clear the ball to prevent infinite recursion
	if ball:
		print("Clearing golf ball to prevent infinite recursion")
		ball.queue_free()
	
	# Place a range flag where the ball landed
	if range_flag_scene:
		var range_flag = range_flag_scene.instantiate()
		range_flag.position = ball_position
		camera_container.add_child(range_flag)
		print("Range flag placed at ball landing position")
	
	# Stop ball tracking and focus camera on landing position
	if camera and camera.has_method("stop_ball_tracking"):
		camera.stop_ball_tracking()
	if camera and camera.has_method("focus_on_ball_landing"):
		camera.focus_on_ball_landing(ball_position)
	
	# Wait for ball to stop, then show distance dialog
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(show_drive_distance_dialog)

func _on_golf_ball_out_of_bounds():
	"""Handle ball going out of bounds"""
	print("Ball went out of bounds")
	current_shot_distance = 0.0
	# Clear the ball to prevent any potential recursion
	var ball = camera_container.get_node_or_null("GolfBall")
	if ball:
		print("Clearing golf ball (out of bounds) to prevent recursion")
		ball.queue_free()
	
	show_drive_distance_dialog()

func _on_ball_launched(ball: Node2D):
	"""Handle ball launch - start camera tracking"""
	print("Ball launched - starting camera tracking")
	print("DEBUG: Ball launched function called with ball:", ball)
	print("DEBUG: Camera reference:", camera)
	print("DEBUG: Camera has start_ball_tracking method:", camera.has_method("start_ball_tracking") if camera else "No camera")
	game_phase = "ball_flying"
	
	# Ensure the ball is properly named for camera tracking
	if ball:
		ball.name = "GolfBall"
		print("DEBUG: Ball renamed to GolfBall for camera tracking")
	
	# Start ball tracking with the new camera
	if camera and camera.has_method("start_ball_tracking"):
		camera.start_ball_tracking()
		print("DEBUG: Camera start_ball_tracking called")
		print("DEBUG: Camera tracking state after start:", camera.is_tracking_ball() if camera.has_method("is_tracking_ball") else "No is_tracking_ball method")
		
		# Check what ball the camera is tracking
		if camera.has_method("get_tracked_ball"):
			var tracked_ball = camera.get_tracked_ball()
			print("DEBUG: Camera tracked ball:", tracked_ball)
			print("DEBUG: Current ball reference:", ball)
			print("DEBUG: Ball references match:", tracked_ball == ball)
	else:
		print("DEBUG: Could not start ball tracking - camera or method missing")



func show_drive_distance_dialog():
	"""Show the drive distance dialog"""
	print("Showing drive distance dialog")
	game_phase = "distance_dialog"
	
	# Check if this is a new record
	var is_new_record = current_shot_distance > current_record_distance
	
	# Get the existing dialog from the scene
	drive_distance_dialog = $UILayer/DrivingRangeDistanceDialog
	
	if not drive_distance_dialog:
		print("ERROR: Could not find DrivingRangeDistanceDialog in scene")
		return
	
	# Connect dialog signal if not already connected
	if not drive_distance_dialog.dialog_closed.is_connected(_on_drive_distance_dialog_closed):
		drive_distance_dialog.dialog_closed.connect(_on_drive_distance_dialog_closed)
	
	# Show dialog with information
	drive_distance_dialog.show_dialog(current_shot_distance, is_new_record, shots_taken + 1, max_shots)
	
	# Update record if it's a new record
	if is_new_record:
		current_record_distance = current_shot_distance
		save_driving_range_record()
	
	print("Drive distance dialog shown")

func _on_drive_distance_dialog_closed():
	"""Handle drive distance dialog closing"""
	print("Drive distance dialog closed")
	
	# Increment shot counter
	shots_taken += 1
	
	# Clear the dialog reference
	drive_distance_dialog = null
	
	# Tween camera back to player
	tween_camera_back_to_player()
	
	# Start next shot or end session
	if shots_taken < max_shots:
		start_new_shot()
	else:
		show_session_complete_dialog()

func tween_camera_back_to_player():
	"""Tween camera back to player position"""
	if camera and camera.has_method("return_to_player"):
		camera.return_to_player()
		print("DEBUG: About to return camera to player")
		print("Camera returning to player")
		print("DEBUG: Camera return_to_player called")
	else:
		print("DEBUG: Camera return_to_player method not found")

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
	
	# Clean up camera tracking
	cleanup_camera_tracking()
	
	# Remove camera from group
	if camera and camera.is_in_group("camera"):
		camera.remove_from_group("camera")
	
	# Clean up vertical parallax before leaving
	if background_manager:
		background_manager.cleanup_vertical_parallax()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_return_to_clubhouse_pressed():
	"""Handle return to clubhouse button press"""
	print("Return to clubhouse button pressed")
	
	# Clean up camera tracking
	cleanup_camera_tracking()
	
	# Remove camera from group
	if camera and camera.is_in_group("camera"):
		camera.remove_from_group("camera")
	
	# Clean up vertical parallax before leaving
	if background_manager:
		background_manager.cleanup_vertical_parallax()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://Main.tscn")

func cleanup_camera_tracking():
	"""Clean up camera tracking resources"""
	if camera and camera.has_method("cleanup"):
		camera.cleanup()

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
	# Handle escape key for pause menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		show_pause_menu()
		return
	
	if game_phase == "launch":
		# Launch manager handles input
		launch_manager.handle_input(event)
	elif game_phase == "draw_clubs":
		# Debug input during club selection phase
		if event is InputEventMouseButton and event.pressed:
			print("DEBUG: Mouse button pressed during draw_clubs phase - Button:", event.button_index, "Position:", event.position)
			print("DEBUG: movement_buttons_container visible:", movement_buttons_container.visible)
			print("DEBUG: movement_buttons_container mouse_filter:", movement_buttons_container.mouse_filter)
			print("DEBUG: movement_buttons_container children count:", movement_buttons_container.get_child_count())
			for child in movement_buttons_container.get_children():
				print("DEBUG: Child:", child.name, "mouse_filter:", child.mouse_filter, "visible:", child.visible)

func _on_power_meter_changed(power_value: float):
	"""Handle power meter value changes"""
	print("Driving Range: Power meter changed to ", power_value, "%")

func _on_sweet_spot_hit():
	"""Handle sweet spot hit"""
	print("Driving Range: Sweet spot hit!")
	# You can add visual/audio feedback here

func show_pause_menu():
	"""Show the pause menu dialog with Return to Clubhouse, Quit Game, and Cancel options"""
	# Don't show if already showing a dialog
	if get_tree().get_nodes_in_group("pause_menu").size() > 0:
		return
	
	# Create the pause menu dialog
	var pause_dialog = Control.new()
	pause_dialog.name = "PauseMenu"
	pause_dialog.add_to_group("pause_menu")
	pause_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_dialog.z_index = 3000
	pause_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(400, 300)
	main_container.position = Vector2(-200, -150)
	main_container.z_index = 3000
	pause_dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = -1
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	title.text = "Driving Range Pause"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.position = Vector2(100, 30)
	title.size = Vector2(200, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Button container
	var button_container = VBoxContainer.new()
	button_container.position = Vector2(100, 100)
	button_container.size = Vector2(200, 150)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(button_container)
	
	# Return to Clubhouse button
	var return_button = Button.new()
	return_button.text = "Return to Clubhouse"
	return_button.size = Vector2(200, 40)
	return_button.pressed.connect(_on_pause_return_to_clubhouse_pressed.bind(pause_dialog))
	button_container.add_child(return_button)
	
	# Quit Game button
	var quit_game_button = Button.new()
	quit_game_button.text = "Quit Game"
	quit_game_button.size = Vector2(200, 40)
	quit_game_button.pressed.connect(_on_quit_game_pressed)
	button_container.add_child(quit_game_button)
	
	# Cancel button
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.size = Vector2(200, 40)
	cancel_button.pressed.connect(_on_cancel_pause_pressed.bind(pause_dialog))
	button_container.add_child(cancel_button)
	
	# Add to UI layer
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(pause_dialog)
	else:
		add_child(pause_dialog)

func _on_pause_return_to_clubhouse_pressed(pause_dialog: Control):
	"""Handle Return to Clubhouse button press from pause menu"""
	# Clean up camera tracking
	cleanup_camera_tracking()
	
	# Remove camera from group
	if camera and camera.is_in_group("camera"):
		camera.remove_from_group("camera")
	
	# Clean up vertical parallax before leaving
	if background_manager:
		background_manager.cleanup_vertical_parallax()
	
	# Remove pause dialog
	pause_dialog.queue_free()
	
	# Transition to Main.tscn
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_quit_game_pressed():
	"""Handle Quit Game button press"""
	get_tree().quit()

func _on_cancel_pause_pressed(pause_dialog: Control):
	"""Handle Cancel button press"""
	pause_dialog.queue_free()

func build_driving_range_map(layout: Array) -> void:
	"""Custom build map function for driving range - no StoneWall layers"""
	print("Building Driving Range map...")
	
	# Clear existing objects
	build_map.clear_existing_objects()
	
	# Build base tiles
	build_map.build_map_from_layout_base(layout, false)  # No pin for driving range
	
	# Get random positions for objects (excluding stone walls)
	var object_positions = get_driving_range_object_positions(layout)
	
	# Place objects at positions
	place_driving_range_objects(object_positions, layout)
	
	# Place TreeLineVert borders
	build_map.place_treeline_vert_borders(layout)
	
	print("✓ Driving Range map built successfully")

func get_driving_range_object_positions(layout: Array) -> Dictionary:
	"""Get object positions for driving range (no stone walls)"""
	var positions = {
		"trees": [],
		"shop": Vector2i.ZERO,
		"gang_members": [],
		"oil_drums": [],
		"stone_walls": [],  # Empty for driving range
		"boulders": [],
		"bushes": [],
		"grass": [],
		"police": [],
		"zombies": [],
		"squirrels": [],
		"bonfires": [],
		"suitcase": Vector2i.ZERO,
		"wraiths": []
	}
	
	# Use difficulty tier spawning
	var npc_counts = Global.get_difficulty_tier_npc_counts(0)  # Driving range is hole 0
	
	randomize()
	var random_seed_value = 0 * 1000 + randi()  # Driving range seed
	seed(random_seed_value)
	
	# Get valid positions for trees and other objects
	var valid_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			var pos = Vector2i(x, y)
			if build_map.is_valid_position_for_object(pos, layout):
				valid_positions.append(pos)
	
	# Place trees (fewer for driving range)
	var num_trees = 4  # Reduced from 8
	var trees_placed = 0
	var placed_objects: Array = []
	
	while trees_placed < num_trees and valid_positions.size() > 0:
		var tree_index = randi() % valid_positions.size()
		var tree_pos = valid_positions[tree_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(tree_pos.x - placed_pos.x), abs(tree_pos.y - placed_pos.y))
			if distance < 8:
				valid = false
				break
		if valid:
			positions.trees.append(tree_pos)
			placed_objects.append(tree_pos)
			trees_placed += 1
		valid_positions.remove_at(tree_index)
	
	# Place boulders (fewer for driving range)
	var num_boulders = 2  # Reduced from 4
	var boulders_placed = 0
	while boulders_placed < num_boulders and valid_positions.size() > 0:
		var boulder_index = randi() % valid_positions.size()
		var boulder_pos = valid_positions[boulder_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(boulder_pos.x - placed_pos.x), abs(boulder_pos.y - placed_pos.y))
			if distance < 6:
				valid = false
				break
		if valid:
			positions.boulders.append(boulder_pos)
			placed_objects.append(boulder_pos)
			boulders_placed += 1
		valid_positions.remove_at(boulder_index)
	
	# Place bushes (fewer for driving range)
	var num_bushes = 3  # Reduced from 6
	var bushes_placed = 0
	while bushes_placed < num_bushes and valid_positions.size() > 0:
		var bush_index = randi() % valid_positions.size()
		var bush_pos = valid_positions[bush_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(bush_pos.x - placed_pos.x), abs(bush_pos.y - placed_pos.y))
			if distance < 4:
				valid = false
				break
		if valid:
			positions.bushes.append(bush_pos)
			placed_objects.append(bush_pos)
			bushes_placed += 1
		valid_positions.remove_at(bush_index)
	
	# Place grass (reduced for driving range)
	var num_grass = 15  # Reduced from 30
	var grass_placed = 0
	
	# Find base tiles that are adjacent to rough tiles
	var rough_adjacent_positions: Array = []
	for pos in valid_positions:
		var is_adjacent_to_rough = false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var check_pos = pos + Vector2i(dx, dy)
				if check_pos.y >= 0 and check_pos.y < layout.size() and check_pos.x >= 0 and check_pos.x < layout[check_pos.y].size():
					if layout[check_pos.y][check_pos.x] == "R":
						is_adjacent_to_rough = true
						break
			if is_adjacent_to_rough:
				break
		if is_adjacent_to_rough:
			rough_adjacent_positions.append(pos)
	
	# Place grass patches
	while grass_placed < num_grass and rough_adjacent_positions.size() > 0:
		var grass_index = randi() % rough_adjacent_positions.size()
		var grass_pos = rough_adjacent_positions[grass_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(grass_pos.x - placed_pos.x), abs(grass_pos.y - placed_pos.y))
			if distance < 2:  # Closer spacing for grass
				valid = false
				break
		if valid:
			positions.grass.append(grass_pos)
			placed_objects.append(grass_pos)
			grass_placed += 1
		rough_adjacent_positions.remove_at(grass_index)
	
	return positions

func place_driving_range_objects(object_positions: Dictionary, layout: Array) -> void:
	"""Place objects for driving range (no stone walls)"""
	
	# Get TreeManager for random tree variations
	var tree_manager = get_node_or_null("/root/TreeManager")
	if not tree_manager:
		var TreeManager = preload("res://Obstacles/TreeManager.gd")
		tree_manager = TreeManager.new()
		get_tree().root.add_child(tree_manager)
		tree_manager.name = "TreeManager"
	
	# Place Trees
	for tree_pos in object_positions.trees:
		var scene: PackedScene = object_scene_map["T"]
		if scene == null:
			push_error("🚫 Tree scene is null")
			continue
		var tree: Node2D = scene.instantiate() as Node2D
		if tree == null:
			push_error("❌ Tree instantiation failed at (%d,%d)" % [tree_pos.x, tree_pos.y])
			continue
		
		# Apply random tree variation
		var tree_data = tree_manager.get_random_tree_data()
		if tree_data and tree.has_method("set_tree_data"):
			tree.set_tree_data(tree_data)
		elif tree_data and "tree_data" in tree:
			tree.tree_data = tree_data
		
		var world_pos: Vector2 = Vector2(tree_pos.x, tree_pos.y) * cell_size
		tree.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		if tree.has_meta("grid_position") or "grid_position" in tree:
			tree.set("grid_position", tree_pos)
		else:
			push_warning("⚠️ Tree missing 'grid_position'. Type: %s" % tree.get_class())
		
		tree.add_to_group("trees")
		tree.add_to_group("collision_objects")
		
		build_map.ysort_objects.append({"node": tree, "grid_pos": tree_pos})
		obstacle_layer.add_child(tree)
		if tree.has_method("blocks") and tree.blocks():
			build_map.obstacle_map[tree_pos] = tree
	
	# Place Boulders
	for boulder_pos in object_positions.boulders:
		var scene: PackedScene = object_scene_map["BOULDER"]
		if scene == null:
			push_error("🚫 Boulder scene is null")
			continue
		var boulder: Node2D = scene.instantiate() as Node2D
		if boulder == null:
			push_error("❌ Boulder instantiation failed at (%d,%d)" % [boulder_pos.x, boulder_pos.y])
			continue
		var world_pos: Vector2 = Vector2(boulder_pos.x, boulder_pos.y) * cell_size
		boulder.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		boulder.set_meta("grid_position", boulder_pos)
		boulder.add_to_group("boulders")
		boulder.add_to_group("collision_objects")
		build_map.ysort_objects.append({"node": boulder, "grid_pos": boulder_pos})
		obstacle_layer.add_child(boulder)
	
	# Place Bushes
	var bush_manager = get_node_or_null("/root/BushManager")
	if not bush_manager:
		var BushManager = preload("res://Obstacles/BushManager.gd")
		bush_manager = BushManager.new()
		get_tree().root.add_child(bush_manager)
		bush_manager.name = "BushManager"
	
	for bush_pos in object_positions.bushes:
		var scene: PackedScene = object_scene_map["BUSH"]
		if scene == null:
			push_error("🚫 Bush scene is null")
			continue
		var bush: Node2D = scene.instantiate() as Node2D
		if bush == null:
			push_error("❌ Bush instantiation failed at (%d,%d)" % [bush_pos.x, bush_pos.y])
			continue
		
		# Apply random bush variation
		var bush_data = bush_manager.get_random_bush_data()
		if bush_data and bush.has_method("set_bush_data"):
			bush.set_bush_data(bush_data)
		elif bush_data and "bush_data" in bush:
			bush.bush_data = bush_data
		
		var world_pos: Vector2 = Vector2(bush_pos.x, bush_pos.y) * cell_size
		bush.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		bush.set_meta("grid_position", bush_pos)
		bush.add_to_group("bushes")
		bush.add_to_group("collision_objects")
		build_map.ysort_objects.append({"node": bush, "grid_pos": bush_pos})
		obstacle_layer.add_child(bush)
	
	# Place Grass
	for grass_pos in object_positions.grass:
		var scene: PackedScene = object_scene_map["GRASS"]
		if scene == null:
			push_error("🚫 Grass scene is null")
			continue
		var grass: Node2D = scene.instantiate() as Node2D
		if grass == null:
			push_error("❌ Grass instantiation failed at (%d,%d)" % [grass_pos.x, grass_pos.y])
			continue
		var world_pos: Vector2 = Vector2(grass_pos.x, grass_pos.y) * cell_size
		grass.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		grass.set_meta("grid_position", grass_pos)
		grass.add_to_group("grass")
		grass.add_to_group("collision_objects")
		build_map.ysort_objects.append({"node": grass, "grid_pos": grass_pos})
		obstacle_layer.add_child(grass)
	
	build_map.update_all_ysort_z_indices()
