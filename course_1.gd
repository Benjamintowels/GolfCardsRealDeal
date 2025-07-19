extends Control

# WorldTurnManager integration
signal player_turn_ended

@onready var gimme_scene = $UILayer/Gimme
@onready var character_image = $UILayer/CharacterImage
@onready var character_label = $UILayer/CharacterLabel
@onready var end_round_button = $UILayer/EndRoundButton
@onready var card_stack_display := $UILayer/CardStackDisplay
@onready var card_hand_anchor: Control = $UILayer/CardHandAnchor
@onready var card_anchor := $UILayer/CardAnchor
@onready var hud = $UILayer/HUD
@onready var ui_layer := self  # or a dedicated Control if you have one
@onready var movement_buttons_container: BoxContainer = $UILayer/CardHandAnchor/CardRow
@onready var card_click_sound: AudioStreamPlayer2D = $CardClickSound
@onready var card_play_sound: AudioStreamPlayer2D = $CardPlaySound
@onready var birds_tweeting_sound: AudioStreamPlayer2D = $BirdsTweeting
@onready var obstacle_layer = $ObstacleLayer
@onready var end_turn_button: Control = $UILayer/EndTurnButton
@onready var camera := $GameCamera
@onready var map_manager := $MapManager
@onready var build_map := $BuildMap
@onready var draw_cards_button: Control = $UILayer/DrawCards
@onready var draw_club_cards_button: Control = $UILayer/DrawClubCards
@onready var power_meter: Control = $UILayer/PowerMeter
@onready var mod_shot_room_button: Button
@onready var bag: Control = $UILayer/Bag
@onready var launch_manager = $LaunchManager
@onready var health_bar: HealthBar = $UILayer/HealthBar
@onready var block_health_bar: BlockHealthBar = $UILayer/BlockHealthBar
@onready var damage_button: Button = $UILayer/HealthTestButtons/DamageButton
@onready var heal_button: Button = $UILayer/HealthTestButtons/HealButton
@onready var kill_gangmember_button: Button = $UILayer/KillGangMemberButton
@onready var bag_upgrade_test_button: Button = $UILayer/BagUpgradeTestButton
@onready var background_manager: Node = $BackgroundManager
@onready var reach_ball_button: Control = $UILayer/ReachBallButton

# WorldTurnManager reference
@onready var world_turn_manager: Node = $WorldTurnManager

# Movement controller
const MovementController := preload("res://MovementController.gd")
var movement_controller: MovementController

# Attack handler
const AttackHandler := preload("res://AttackHandler.gd")
const WeaponHandler := preload("res://WeaponHandler.gd")
var attack_handler: AttackHandler
const GolfCourseLayout := preload("res://Maps/GolfCourseLayout.gd")
const HealthBar := preload("res://HealthBar.gd")
const BlockHealthBar := preload("res://BlockHealthBar.gd")
const EquipmentManager := preload("res://EquipmentManager.gd")

# Grid manager
const GridManager := preload("res://GridManager.gd")
var grid_manager: GridManager

# Player manager
const PlayerManager := preload("res://PlayerManager.gd")
var player_manager: PlayerManager

# Camera manager
const CameraManager := preload("res://CameraManager.gd")
var camera_manager: CameraManager

# UI manager
const UIManager := preload("res://UIManager.gd")
var ui_manager: UIManager

# Game state manager
const GameStateManager := preload("res://GameStateManager.gd")
var game_state_manager: GameStateManager = null

# Sound manager
const SoundManager := preload("res://SoundManager.gd")
var sound_manager: SoundManager = null

var obstacle_map: Dictionary = {}  # Vector2i -> BaseObstacle

var cell_size: int = 48 # This will be set by the main script

# Club selection variables (separate from movement)
var movement_buttons := []

# Camera panning variables (moved to CameraManager)
# var is_panning := false
# var pan_start_pos := Vector2.ZERO
# var camera_snap_back_pos := Vector2.ZERO

var mouse_world_pos := Vector2.ZERO
var tree_scene = preload("res://Obstacles/Tree.tscn")
var water_scene = preload("res://Obstacles/WaterHazard.tscn")

var deck_manager: DeckManager

# Inventory system for ModifyNext cards
var club_inventory: Array[CardData] = []
var movement_inventory: Array[CardData] = []
var pending_inventory_card: CardData = null

# StickyShot and card modification variables
var sticky_shot_active := false  # Track if StickyShot effect is active
var bouncey_shot_active := false  # Track if Bouncey effect is active
var fire_ball_active := false  # Track if FireBall effect is active
var ice_ball_active := false  # Track if IceBall effect is active
var explosive_shot_active := false  # Track if Explosive effect is active
var next_shot_modifier := ""  # Track what modifier to apply to next shot
var next_card_doubled := false  # Track if the next card should have its effect doubled
var rooboost_active := false  # Track if RooBoost effect is active
var next_movement_card_rooboost := false  # Track if next movement card should have RooBoost effect
var extra_turns_remaining := 0  # Track extra turns from CoffeeCard

# Block system variables
# var block_active := false  # Track if block is currently active
# var block_amount := 0  # Current block points

# Sound effects moved to SoundManager
var club_max_distances = {
	"Driver": 1200.0,        # Longest distance
	"Hybrid": 1050.0,        # Slightly less than Driver
	"Wood": 800.0,           # Slightly more than Iron
	"Iron": 600.0,           # Medium distance
	"Wooden": 350.0,         # Slightly better than Putter
	"Putter": 200.0,         # Shortest distance (now rolling only)
	"PitchingWedge": 200.0,  # Same as old Putter settings
	"ShotgunCard": 350.0,    # Shotgun range
	"SniperCard": 1500.0,    # Sniper range
	"ShurikenCard": 2000.0,  # Shuriken range (half power)
	"GrenadeLauncherClubCard": 2000.0  # Grenade launcher range (much higher velocity!)
}

# New club data with min distances, trailoff stats, and height ranges
var club_data = {
	"Driver": {
		"max_distance": 1200.0,
		"min_distance": 800.0,    # Smallest gap (400)
		"trailoff_forgiveness": 0.3,  # Less forgiving (lower = more severe undercharge penalty)
		"min_height": 10.0,       # Low min height for driver
		"max_height": 120.0       # Low max height for driver
	},
	"Hybrid": {
		"max_distance": 1050.0,
		"min_distance": 200.0,    # Biggest gap (850)
		"trailoff_forgiveness": 0.8,  # Most forgiving (higher = less severe undercharge penalty)
		"min_height": 15.0,       # Medium min height
		"max_height": 200.0       # Medium max height
	},
	"Wood": {
		"max_distance": 800.0,
		"min_distance": 300.0,    # Medium gap (500)
		"trailoff_forgiveness": 0.6,  # Medium forgiving
		"min_height": 18.0,       # Medium-high min height
		"max_height": 280.0       # Medium-high max height
	},
	"Iron": {
		"max_distance": 600.0,
		"min_distance": 250.0,    # Medium gap (350)
		"trailoff_forgiveness": 0.5,  # Medium forgiving
		"min_height": 19.0,       # High min height
		"max_height": 320.0       # High max height
	},
	"Wooden": {
		"max_distance": 350.0,
		"min_distance": 150.0,    # Small gap (200)
		"trailoff_forgiveness": 0.4,  # Less forgiving
		"min_height": 19.5,       # Very high min height
		"max_height": 360.0       # Very high max height
	},
	"Putter": {
		"max_distance": 200.0,
		"min_distance": 100.0,    # Smallest gap (100)
		"trailoff_forgiveness": 0.2,  # Least forgiving (most severe undercharge penalty)
		"is_putter": true  # Flag to identify this as a putter
	},
	"PitchingWedge": {
		"max_distance": 200.0,
		"min_distance": 100.0,    # Same as old Putter settings
		"trailoff_forgiveness": 0.2,  # Same as old Putter settings
		"min_height": 20.0,       # Highest min height for pitching wedge
		"max_height": 400.0       # Highest max height for pitching wedge
	},
	"Fire Club": {
		"max_distance": 900.0,
		"min_distance": 400.0,    # Medium gap (500)
		"trailoff_forgiveness": 0.5,  # Medium forgiving
		"min_height": 18.0,       # Medium-high min height
		"max_height": 280.0       # Medium-high max height
	},
	"Ice Club": {
		"max_distance": 900.0,
		"min_distance": 400.0,    # Medium gap (500)
		"trailoff_forgiveness": 0.5,  # Medium forgiving
		"min_height": 18.0,       # Medium-high min height
		"max_height": 280.0       # Medium-high max height
	},
	"GrenadeLauncherClubCard": {
		"max_distance": 2000.0,   # Much higher velocity - 3.3x more than before!
		"min_distance": 500.0,    # Increased min distance to match higher power
		"trailoff_forgiveness": 0.5,  # Medium forgiving
		"is_putter": true,  # Flag to identify this as a putter-like club (no height charge)
		"fixed_height": 50.0  # Fixed height in pixels (no height meter)
	},
	"ShotgunCard": {
		"max_distance": 350.0,
		"min_distance": 50.0,     # Very short range weapon
		"trailoff_forgiveness": 0.8,  # Forgiving for weapon
		"min_height": 15.0,       # Medium min height
		"max_height": 200.0       # Medium max height
	},
	"ShurikenCard": {
		"max_distance": 2000.0,   # Half power for shuriken (4000 / 2)
		"min_distance": 100.0,    # Reasonable min distance
		"trailoff_forgiveness": 0.8,  # Forgiving for weapon
		"min_height": 20.0,       # Medium min height
		"max_height": 300.0       # Medium max height
	}
}

# Add these variables at the top (after var launch_power, etc.)
var charge_time := 0.0  # Time spent charging (in seconds)
var max_charge_time := 3.0  # Maximum time to fully charge (varies by distance)

# Add this variable to track objects and their grid positions
var ysort_objects := [] # Array of {node: Node2D, grid_pos: Vector2i}

# Shop interaction variables
# shop_dialog, shop_overlay, mid_game_shop_overlay moved to UIManager

# Smart Performance Optimizer
var smart_optimizer: Node

# Move these variable declarations to just before build_map_from_layout_with_randomization
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
	"GENERATOR": preload("res://Interactables/GeneratorSwitch.tscn"),
	"PYLON": preload("res://Interactables/Pylon.tscn"),
	"VERTICAL_FIELD": preload("res://Interactables/VerticalField.tscn"),
	"HORIZONTAL_FIELD": preload("res://Interactables/HorizontalField.tscn"),
	"FORCE_FIELD_DOME": preload("res://Interactables/ForceFieldDome.tscn"),
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
	"GENERATOR": "Base",
	"PYLON": "Base",
	"VERTICAL_FIELD": "Base",
	"HORIZONTAL_FIELD": "Base",
	"FORCE_FIELD_DOME": "Base",
}

# Add these variables after the existing object_scene_map and object_to_tile_mapping
var random_seed_value: int = 0
var placed_objects: Array[Vector2i] = []  # Track placed objects for spacing rules

# Add these functions before build_map_from_layout_with_randomization
func clear_existing_objects() -> void:
	"""Clear all existing objects (trees, shop, etc.) from the map"""
	
	var objects_removed = 0
	
	# Remove ALL objects from obstacle_layer (complete cleanup)
	for child in obstacle_layer.get_children():
		var child_name = child.name  # Store before freeing
		# print("Clearing object:", child_name, "Type:", child.get_class())
		child.queue_free()
		objects_removed += 1
	
	# Clear obstacle_map entries for objects (including Pin now)
	var keys_to_remove: Array[Vector2i] = []
	for pos in obstacle_map.keys():
		var obstacle = obstacle_map[pos]
		if obstacle:
			# Check for trees by name or method
			var is_tree = obstacle.name == "Tree" or obstacle.has_method("_on_area_entered") and "Tree" in str(obstacle.get_script())
			# Check for shop by name
			var is_shop = obstacle.name == "Shop" or obstacle.name == "ShopExterior"
			# Check for pin by multiple methods
			var is_pin = false
			if obstacle.has_method("_on_area_entered"):
				var script_path = str(obstacle.get_script())
				is_pin = "Pin" in script_path or obstacle.name == "Pin" or "Pin.gd" in script_path
				# Also check if it has the hole_in_one signal (pin-specific)
				if obstacle.has_signal("hole_in_one"):
					is_pin = true
			# Check for oil drums by name or script
			var is_oil_drum = obstacle.name == "OilDrum" or (obstacle.get_script() and "oil_drum.gd" in str(obstacle.get_script().get_path()))
			# Check for stone walls by name or script
			var is_stone_wall = obstacle.name == "StoneWall" or (obstacle.get_script() and "StoneWall.gd" in str(obstacle.get_script().get_path()))
			# Check for police by name or script
			var is_police = obstacle.name == "Police" or (obstacle.get_script() and "police.gd" in str(obstacle.get_script().get_path()))
			# Check for zombies by name or script
			var is_zombie = obstacle.name == "ZombieGolfer" or (obstacle.get_script() and "ZombieGolfer.gd" in str(obstacle.get_script().get_path()))
			# Check for generator switches by name or script
			var is_generator_switch = obstacle.name == "GeneratorSwitch" or (obstacle.get_script() and "generator_switch.gd" in str(obstacle.get_script().get_path()))
			
			if is_tree or is_shop or is_pin or is_oil_drum or is_stone_wall or is_police or is_zombie or is_generator_switch:
				keys_to_remove.append(pos)
	
	for pos in keys_to_remove:
		obstacle_map.erase(pos)
	
	
	# Clear ysort_objects (including Pin now)
	var ysort_count = ysort_objects.size()
	ysort_objects.clear()
	placed_objects.clear()
	

func _get_tee_area_center() -> Vector2:
	var tee_positions: Array[Vector2i] = []
	for y in map_manager.level_layout.size():
		for x in map_manager.level_layout[y].size():
			if map_manager.get_tile_type(x, y) == "Tee":
				tee_positions.append(Vector2i(x, y))

	if tee_positions.is_empty():
		return get_viewport_rect().size / 2 # Fallback to screen center

	var min_pos := Vector2i(999, 999)
	var max_pos := Vector2i(-1, -1)
	for pos in tee_positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	var center_grid_pos = (min_pos + max_pos) / 2.0
	var center_world_pos = (center_grid_pos + Vector2(0.5, 0.5)) * cell_size
	return center_world_pos

func _process(delta):
	# Early return if game_state_manager is not initialized yet
	if not game_state_manager:
		return
		
	if smart_optimizer:
		smart_optimizer.smart_process(delta, self)
	
	# Update weapon rotation if GrenadeLauncherClubCard is selected
	if game_state_manager.get_selected_club() == "GrenadeLauncherClubCard" and weapon_handler:
		weapon_handler.update_weapon_rotation()
	
	# Update ReachBallButton visibility
	update_reach_ball_button_visibility()

func update_reach_ball_button_visibility() -> void:
	"""Update the visibility of the ReachBallButton based on game state"""
	# Early return if game_state_manager is not initialized yet
	if not game_state_manager:
		return
		
	if not reach_ball_button:
		return
	
	# Show button if:
	# 1. It's the player's turn (game_phase is "move" or "waiting_for_draw")
	# 2. We're waiting for player to reach the ball
	# 3. Player is not currently on the ball tile
	var is_player_turn = game_state_manager.get_game_phase() in ["move", "waiting_for_draw", "draw_cards"]
	var player_not_on_ball = player_manager.get_player_grid_pos() != game_state_manager.get_ball_landing_tile()
	var should_show = is_player_turn and game_state_manager.get_waiting_for_player_to_reach_ball() and player_not_on_ball
	
	if should_show and not reach_ball_button.visible:
		reach_ball_button.show_button()
	elif not should_show and reach_ball_button.visible:
		reach_ball_button.hide_button()

func update_ball_for_optimizer():
	"""Update ball state for the smart optimizer"""
	if smart_optimizer and launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
		var ball = launch_manager.golf_ball
		var ball_pos = ball.global_position
		var ball_velocity = ball.velocity if "velocity" in ball else Vector2.ZERO
		smart_optimizer.update_ball_state(ball_pos, ball_velocity)

func _ready() -> void:
	print("🔧 COURSE_1.GD _READY() CALLED!")
	add_to_group("course")
	
	# Clear any existing state to prevent dictionary conflicts
	_clear_existing_state()
	
	if Global.putt_putt_mode:
		print("=== PUTT PUTT MODE ENABLED ===")
		print("Available putters:", deck_manager.club_draw_pile.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		).map(func(card): return card.name))
		print("=== END PUTT PUTT MODE INFO ===")
	else:
		print("Normal mode - all clubs available")
	
	# Initialize GameStateManager first (needed by other managers)
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	
	# Initialize SoundManager
	sound_manager = SoundManager.new()
	add_child(sound_manager)
	
	# Initialize card effect handler
	var effect_handler_script = load("res://CardEffectHandler.gd")
	card_effect_handler = effect_handler_script.new()
	add_child(card_effect_handler)
	card_effect_handler.set_course_reference(self)
	card_effect_handler.scramble_complete.connect(_on_scramble_complete)
	
	# Setup build_map with necessary data
	build_map.setup(
		tile_scene_map,
		object_scene_map,
		object_to_tile_mapping,
		cell_size,
		obstacle_layer,
		obstacle_map,
		ysort_objects
	)
	build_map.current_hole = game_state_manager.get_current_hole_index() if game_state_manager else 0
	build_map.card_effect_handler = card_effect_handler
	
	# Initialize movement controller
	movement_controller = MovementController.new()
	add_child(movement_controller)
	
	# Initialize attack handler
	attack_handler = AttackHandler.new()
	add_child(attack_handler)
	
	# Initialize weapon handler
	weapon_handler = WeaponHandler.new()
	add_child(weapon_handler)
	
	# Initialize grid manager
	grid_manager = GridManager.new()
	add_child(grid_manager)
	
	# Initialize player manager
	player_manager = PlayerManager.new()
	add_child(player_manager)
	
	call_deferred("fix_ui_layers")
	ui_manager.display_selected_character()
	if end_round_button:
		end_round_button.pressed.connect(_on_end_round_pressed)
	
	# Connect health test buttons
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)
	if heal_button:
		heal_button.pressed.connect(_on_heal_button_pressed)
	
	# Connect reach ball button
	if reach_ball_button:
		reach_ball_button.reach_ball_pressed.connect(_on_reach_ball_pressed)
	
	# Initialize gimme button state
	ui_manager.hide_gimme_button()


	# Create camera container for grid manager
	var camera_container = Control.new()
	camera_container.name = "CameraContainer"
	add_child(camera_container)
	
	# Setup grid manager
	grid_manager.setup(Vector2i(50, 50), cell_size, camera_container)
	
	# Connect grid manager signals
	grid_manager.tile_mouse_entered.connect(_on_tile_mouse_entered)
	grid_manager.tile_mouse_exited.connect(_on_tile_mouse_exited)
	grid_manager.tile_input.connect(_on_tile_input)
	
	# Setup player manager
	player_manager.setup(
		grid_manager.get_grid_size(),
		cell_size,
		obstacle_map,
		ysort_objects,
		game_state_manager.get_shop_grid_position() if game_state_manager else Vector2i.ZERO,
		health_bar,
		block_health_bar
	)
	
	player_manager.create_player()
	
	# Setup player sounds in SoundManager
	sound_manager.setup_player_sounds(player_manager.get_player_node())
	launch_manager.set("camera_container", grid_manager.get_camera_container())
	launch_manager.ui_layer = $UILayer
	launch_manager.player_node = player_manager.get_player_node()
	launch_manager.cell_size = cell_size
	launch_manager.camera = camera
	launch_manager.card_effect_handler = card_effect_handler
	launch_manager.course_reference = self
	
	# Connect signals
	launch_manager.ball_launched.connect(_on_ball_launched)
	launch_manager.launch_phase_entered.connect(_on_launch_phase_entered)
	launch_manager.launch_phase_exited.connect(_on_launch_phase_exited)
	launch_manager.charging_state_changed.connect(_on_charging_state_changed)	
	
	if obstacle_layer.get_parent():
		obstacle_layer.get_parent().remove_child(obstacle_layer)
	grid_manager.get_camera_container().add_child(obstacle_layer)

	map_manager.load_map_data(GolfCourseLayout.LEVEL_LAYOUT)

	deck_manager = DeckManager.new()
	add_child(deck_manager)
	deck_manager.deck_updated.connect(ui_manager.update_deck_display)
	deck_manager.discard_recycled.connect(card_stack_display.animate_card_recycle)
	
	# Setup card stack sounds in SoundManager
	sound_manager.setup_card_stack_sounds(card_stack_display)
	
	# Add EquipmentManager
	var equipment_manager = EquipmentManager.new()
	equipment_manager.name = "EquipmentManager"
	add_child(equipment_manager)
	
	# Initialize CameraManager
	camera_manager = CameraManager.new()
	add_child(camera_manager)
	camera_manager.setup(camera, player_manager, grid_manager, background_manager, cell_size)
	
	# Initialize UIManager
	ui_manager = UIManager.new()
	add_child(ui_manager)
	ui_manager.setup($UILayer, self, player_manager, grid_manager, camera_manager, deck_manager, movement_controller, attack_handler, weapon_handler, launch_manager)
	
	# Setup GameStateManager (already initialized above)
	game_state_manager.setup(self, ui_manager, map_manager, build_map, player_manager, grid_manager, camera_manager, deck_manager, movement_controller, attack_handler, weapon_handler, launch_manager)
	
	# Starter equipment removed for basic loadout testing
	print("Course: No starter equipment - basic loadout mode")
	
	# Player starts with level 2 backpack (handled by bag system)
	print("Course: Player starts with level 2 backpack for their character")
	
	# Force sync with CurrentDeckManager immediately
	deck_manager.sync_with_current_deck()
	
	# Setup attack handler first (before movement controller)
	attack_handler.setup(
		player_manager.get_player_node(),
		grid_manager.get_grid_tiles(),
		grid_manager.get_grid_size(),
		cell_size,
		obstacle_map,
		player_manager.get_player_grid_pos(),
		player_manager.get_player_stats(),
		movement_buttons_container,  # Reuse the same container for now
		card_click_sound,
		card_play_sound,
		card_stack_display,
		deck_manager,
		card_effect_handler,
		player_manager.get_player_node().get_node_or_null("KickSound"),  # Add KickSound reference
		player_manager.get_player_node().get_node_or_null("PunchB"),  # Add PunchB sound reference
		player_manager.get_player_node().get_node_or_null("AssassinDash"),  # Add AssassinDash sound reference
		player_manager.get_player_node().get_node_or_null("AssassinCut"),  # Add AssassinCut sound reference
		movement_buttons_container  # Pass CardRow reference for animation
	)
	
	# Setup weapon handler after attack handler
	weapon_handler.setup(
		player_manager.get_player_node(),
		grid_manager.get_grid_tiles(),
		grid_manager.get_grid_size(),
		cell_size,
		obstacle_map,
		player_manager.get_player_grid_pos(),
		player_manager.get_player_stats(),
		camera,
		card_click_sound,
		card_play_sound,
		card_stack_display,
		deck_manager,
		card_effect_handler,
		launch_manager
	)
	
	# Setup movement controller last (after attack and weapon handlers are ready)
	movement_controller.setup(
		player_manager.get_player_node(),
		grid_manager.get_grid_tiles(),
		grid_manager.get_grid_size(),
		cell_size,
		obstacle_map,
		player_manager.get_player_grid_pos(),
		player_manager.get_player_stats(),
		movement_buttons_container,
		card_click_sound,
		card_play_sound,
		card_stack_display,
		deck_manager,
		card_effect_handler,
		attack_handler,
		weapon_handler,
		movement_buttons_container  # Pass CardRow reference for animation
	)
	

	
	# Set the movement controller reference for button cleanup
	attack_handler.set_movement_controller(movement_controller)
	weapon_handler.set_movement_controller(movement_controller)
	
	# Connect attack handler signals
	attack_handler.npc_attacked.connect(_on_npc_attacked)
	attack_handler.kick_attack_performed.connect(_on_kick_attack_performed)
	attack_handler.punchb_attack_performed.connect(_on_punchb_attack_performed)
	# Ash dog attack signal connection removed - handled by AttackHandler
	
	# Connect weapon handler signals
	weapon_handler.npc_shot.connect(_on_npc_shot)
	var pin = find_pin_in_scene()
	
	call_deferred("_connect_pin_signals")
	# Initialize background manager
	if background_manager:
		background_manager.set_camera_reference(camera)
		background_manager.set_theme("course1")
		print("✓ Background manager initialized with course1 theme")
		

		# Try to adjust positioning if needed
		call_deferred("adjust_background_positioning")
	
	# Setup SoundManager
	sound_manager.setup_ui_sounds(card_click_sound, card_play_sound, birds_tweeting_sound)
	sound_manager.setup_swing_sounds($SwingStrong, $SwingMed, $SwingSoft)
	sound_manager.setup_collision_sounds($WaterPlunk, $SandThunk, $TrunkThunk)
	sound_manager.setup_global_death_sound()

func adjust_background_positioning() -> void:
	"""Adjust background layer positioning for better visibility"""
	if not background_manager:
		return
	
	print("=== ADJUSTING BACKGROUND POSITIONING ===")
	
	# Get screen size and grid info
	var screen_size = get_viewport().get_visible_rect().size
	var grid_height = grid_manager.get_grid_size().y * cell_size
	var grid_top = (screen_size.y - grid_height) / 2
	
	print("Screen size: ", screen_size)
	print("Grid top position: ", grid_top)
	print("Grid height: ", grid_height)
	
	
	# Set the world grid center for parallax calculations
	# This should be at the top of your world grid, not the center
	var world_grid_center = Vector2(1200, 0)  # X is center, Y is top of grid
	background_manager.set_world_grid_center(world_grid_center)
	
	# Set the ParallaxBackground system position
	var parallax_system = background_manager.get_parallax_system()
	if parallax_system:
		parallax_system.position = Vector2(564.625, -161.635)
		print("✓ Set ParallaxBackground position to: ", parallax_system.position)
	
	# Position each layer in world coordinates (not screen-relative)
	# Calculate world-relative positions based on the grid dimensions
	var total_grid_height = grid_manager.get_grid_size().y * cell_size
	
	# Position layers at the top of the world grid with proper staggering
	# Use world-relative coordinates so they don't reset to screen center
	var base_y = -total_grid_height / 2 - 50  # Slightly above the world grid top
	var vertical_spacing = 80  # Space between layers
	
	background_manager.adjust_layer_position("TreeLine", Vector2(0, -910.77))
	background_manager.adjust_layer_position("TreeLine2", Vector2(0, -936.145))
	background_manager.adjust_layer_position("TreeLine3", Vector2(0, -990.785))
	background_manager.adjust_layer_position("City", Vector2(0, -1353.04))
	background_manager.adjust_layer_position("Clouds", Vector2(0, -1362.43))
	background_manager.adjust_layer_position("Mountains", Vector2(0, -1101.525))
	background_manager.adjust_layer_position("Sky", Vector2(0, -990.785))
	
	# Scale up layers to make them more visible and ensure horizontal coverage
	background_manager.set_layer_scale("Sky", Vector2(9.0, 5))
	background_manager.set_layer_scale("Mountains", Vector2(4.5, 2.0))
	background_manager.set_layer_scale("Clouds", Vector2(3.5, 2.0))
	background_manager.set_layer_scale("City", Vector2(3.5, 2.0))
	background_manager.set_layer_scale("TreeLine3", Vector2(3.0, 2.0))
	background_manager.set_layer_scale("TreeLine2", Vector2(2.8, 2.0))
	background_manager.set_layer_scale("TreeLine", Vector2(2.5, 2.0))
	
	print("=== BACKGROUND ADJUSTMENT COMPLETE ===")
	


	var hud := $UILayer/HUD

	ui_manager.update_deck_display()
	set_process_input(true)

	# Swing sounds are now handled by SoundManager

	card_hand_anchor.z_index = 245  # Keep original z_index from scene file
	card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Changed to IGNORE to allow clicks to pass through to grid tiles
	card_hand_anchor.get_parent().move_child(card_hand_anchor, card_hand_anchor.get_parent().get_child_count() - 1)

	hud.z_index = 101
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.get_parent().move_child(hud, hud.get_parent().get_child_count() - 1)
	var parent := card_hand_anchor.get_parent()
	parent.move_child(card_hand_anchor, parent.get_child_count() - 1)
	parent.move_child(hud,             parent.get_child_count() - 1)

	card_hand_anchor.z_index = 245  # Keep original z_index from scene file
	hud.z_index             = 101
	end_turn_button.get_node("TextureButton").pressed.connect(_on_end_turn_pressed)
	end_turn_button.z_index = 102
	end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	end_turn_button.get_parent().move_child(end_turn_button, end_turn_button.get_parent().get_child_count() - 1)

	grid_manager.get_grid_container().mouse_filter = Control.MOUSE_FILTER_IGNORE

	draw_cards_button.visible = false
	draw_cards_button.get_node("TextureButton").pressed.connect(_on_draw_cards_pressed)
	draw_club_cards_button.visible = false
	draw_club_cards_button.get_node("TextureButton").pressed.connect(_on_draw_club_cards_pressed)
	
	setup_bag_and_inventory()
	
	# Debug bag state after setup
	if bag and bag.has_method("debug_bag_state"):
		bag.debug_bag_state()
	
	# Connect to currency changes to update display
	# Note: We'll update the display manually since Global doesn't have a signal system
	# The display will be updated in update_deck_display() which is called regularly

	# Shop is now an overlay system - no need for state restoration

	if not game_state_manager:
		print("ERROR: game_state_manager not initialized in start_round()")
		return
		
	if Global.starting_back_9:
		print("=== STARTING BACK 9 MODE ===")
		game_state_manager.start_back_nine()
		Global.starting_back_9 = false  # Reset the flag
		print("Back 9 mode initialized, starting at hole:", game_state_manager.get_current_hole_index())
	else:
		print("=== STARTING FRONT 9 MODE ===")
		game_state_manager.start_front_nine()
	
	print("Front 9 mode initialized, starting at hole:", game_state_manager.get_current_hole_index())
	
	# Initialize smart performance optimizer
	var optimizer_script = load("res://SmartPerformanceOptimizer.gd")
	smart_optimizer = optimizer_script.new()
	add_child(smart_optimizer)
	print("Smart performance optimizer added to course")
	
	# Test the smart optimizer
	if smart_optimizer:
		smart_optimizer.update_game_state("tee_select", false, false, false)
		print("Smart optimizer test: Game state updated successfully")
	
	# Start with smart optimization enabled for better performance
	print("Smart optimization is ENABLED by default for better performance.")
	


	game_state_manager.is_placing_player = true
	map_manager.highlight_tee_tiles()

	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(game_state_manager.get_current_hole_index()))
	build_map.build_map_from_layout_with_randomization(map_manager.level_layout)
	
	# Sync shop grid position with build_map
	game_state_manager.set_shop_grid_position(build_map.shop_grid_pos)
	
	# Sync SuitCase grid position with build_map
	game_state_manager.set_suitcase_grid_position(build_map.get_suitcase_position())
	if game_state_manager.get_suitcase_grid_position() != Vector2i.ZERO:
		print("SuitCase placed at grid position:", game_state_manager.get_suitcase_grid_position())
	
	# Ensure Y-sort objects are properly registered for pin detection
	update_all_ysort_z_indices()
	game_state_manager.reset_hole_score()
	position_camera_on_pin()  # Add the camera positioning call

	update_hole_and_score_display()

	show_tee_selection_instruction()
	
	# Register any existing GangMembers with the Entities system
	world_turn_manager.register_existing_gang_members()
	
	# Register any existing Squirrels with the Entities system
	world_turn_manager.register_existing_squirrels()
	
	# Re-register all NPCs in Entities to ensure attack system works
	var entities = get_node_or_null("Entities")
	if entities:
		entities.re_register_all_npcs()
	
	# Initialize player mouse facing system
	var player = player_manager.get_player_node()
	if player and player.has_method("set_camera_reference"):
		player.set_camera_reference(camera)
		player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
	
	# Play birds tweeting sound when course loads
	sound_manager.play_birds_tweeting()

	var complete_hole_btn := Button.new()
	complete_hole_btn.name = "CompleteHoleButton"
	complete_hole_btn.text = "Complete Hole"
	complete_hole_btn.position = Vector2(400, 50)
	complete_hole_btn.z_index = 999
	$UILayer.add_child(complete_hole_btn)
	complete_hole_btn.pressed.connect(_on_complete_hole_pressed)


func _on_complete_hole_pressed():
	# Clear any existing balls before showing the hole completion dialog
	launch_manager.remove_all_balls()
	ui_manager.show_hole_completion_dialog()

func _input(event: InputEvent) -> void:
	# Early return if game_state_manager is not initialized yet
	if not game_state_manager:
		return
		
	# Handle escape key for pause menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		show_pause_menu()
		return

	# Debug: Log all left click events to see what phase we're in
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Course: Left click detected - current game_phase:", game_state_manager.get_game_phase())
	
	# Debug: Check if bag is receiving input events
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = event.position
		if bag and bag.has_method("debug_bag_state"):
			var bag_rect = Rect2(bag.global_position, bag.size)
			if bag_rect.has_point(mouse_pos):
				print("Course: Mouse click detected over bag area at", mouse_pos)
				print("Course: Bag rect:", bag_rect)
				bag.debug_bag_state()

	# Handle weapon mode input first
	if weapon_handler and weapon_handler.handle_input(event):
		return
	
	if game_state_manager.get_game_phase() == "aiming":
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				# Freeze grenade launcher if using GrenadeLauncherWeaponCard
				if weapon_handler and weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
					weapon_handler.freeze_grenade_launcher()
				
				# Freeze grenade launcher if using GrenadeLauncherClubCard
				if game_state_manager.get_selected_club() == "GrenadeLauncherClubCard" and weapon_handler:
					weapon_handler.freeze_grenade_launcher()
				
				game_state_manager.is_aiming_phase = false
				ui_manager.hide_aiming_circle()
				ui_manager.hide_aiming_instruction()
				camera_manager.restore_zoom_after_aiming(self)
				launch_manager.enter_launch_phase()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				game_state_manager.is_aiming_phase = false
				ui_manager.hide_aiming_circle()
				ui_manager.hide_aiming_instruction()
				camera_manager.restore_zoom_after_aiming(self)
				game_state_manager.set_game_phase("move")  # Return to move phase
				player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
	elif game_state_manager.get_game_phase() == "launch":
		# Handle launch input through LaunchManager
		if launch_manager.handle_input(event):
			return
		# Handle BallHop ability for Wand equipment
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Course: Left click detected during ball flight!")
			var equipment_manager = get_node_or_null("EquipmentManager")
			if equipment_manager and equipment_manager.has_wand():
				print("Course: Wand is equipped, checking for active ball...")
				# Check if there's an active ball to apply BallHop to
				var active_ball = launch_manager.golf_ball if launch_manager else null
				if active_ball and is_instance_valid(active_ball) and active_ball.has_method("ballhop"):
					print("Course: Active ball found, calling ballhop()...")
					if active_ball.ballhop():
						print("Course: BallHop applied successfully!")
					else:
						print("Course: BallHop failed - ball not in flight or on cooldown")
				else:
					print("Course: No active ball found for BallHop")
			else:
				print("Course: Wand not equipped - BallHop not available")
			return  # Return after handling BallHop to prevent other input processing
		
		# Handle camera panning with middle mouse button
		if camera_manager.handle_camera_panning(event):
			return  # Return after handling camera panning
		
		# If we get here, no ball_flying specific input was handled
		return  # Don't process other input during ball flight

	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		var node = get_viewport().gui_get_hovered_control()

	# Handle camera panning
	if camera_manager.handle_camera_panning(event):
		return

	if player_manager.get_player_node():
		pass

	# Grid tiles are static with smart optimization - no need to redraw

	queue_redraw()

func _draw() -> void:
	# Drawing functionality removed
	pass

# Health functions moved to PlayerManager


# Block system methods moved to PlayerManager

func _on_damage_button_pressed() -> void:
	"""Handle damage button press"""
	player_manager.take_damage(20)

func _on_heal_button_pressed() -> void:
	"""Handle heal button press"""
	player_manager.heal_player(20)

func _on_reach_ball_pressed() -> void:
	"""Handle reach ball button press - teleport player to ball"""
	print("Course: Reach ball button pressed - teleporting player to ball")
	
	# Check if we have a valid ball position
	if game_state_manager.get_ball_landing_tile() == Vector2i.ZERO:
		print("No ball landing tile available")
		return
	
	# Set the flag to indicate ReachBallButton was used
	game_state_manager.set_used_reach_ball_button(true)
	print("ReachBallButton used - proceeding to club card drawing")
	
	# Use the existing teleport functionality from CardEffectHandler
	if card_effect_handler and card_effect_handler.has_method("teleport_player_to_ball"):
		# Get the ball's current position
		var ball_position = Vector2.ZERO
		if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
			ball_position = launch_manager.golf_ball.global_position
		else:
			# Fallback: calculate position from ball_landing_tile
			ball_position = Vector2(game_state_manager.get_ball_landing_tile().x * cell_size + cell_size/2, game_state_manager.get_ball_landing_tile().y * cell_size + cell_size/2) + grid_manager.get_camera_container().global_position
		
		# Teleport the player to the ball
		card_effect_handler.teleport_player_to_ball(ball_position)
		
		# Clear the waiting state since player is now at the ball
		game_state_manager.set_waiting_for_player_to_reach_ball(false)
		
		# Remove ball landing highlight if it exists
		if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
			launch_manager.golf_ball.remove_landing_highlight()
		
		# Always show club card drawing after using reach ball button
		print("Reach ball button used - showing club card drawing")
		ui_manager.show_draw_club_cards_button()
		
		print("Player teleported to ball successfully")
	else:
		print("CardEffectHandler not available for teleport")

# Death handling moved to GameStateManager

# Player input handling moved to UIManager

# Camera functions moved to CameraManager - direct calls to camera_manager used instead

# Player position update moved to PlayerManager

# Ball management moved to LaunchManager

func create_movement_buttons() -> void:
	movement_controller.create_movement_buttons()
	attack_handler.create_attack_buttons()
	

func _on_movement_card_pressed(card: CardData, button: TextureButton) -> void:
	movement_controller._on_movement_card_pressed(card, button)


	
func calculate_valid_movement_tiles() -> void:
	movement_controller.calculate_valid_movement_tiles()

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return movement_controller.calculate_grid_distance(a, b)

func show_movement_highlights() -> void:
	movement_controller.show_movement_highlights()

func hide_all_movement_highlights() -> void:
	movement_controller.hide_all_movement_highlights()

func _on_tile_mouse_entered(x: int, y: int) -> void:
	movement_controller.handle_tile_mouse_entered(x, y, camera_manager.is_panning)
	attack_handler.handle_tile_mouse_entered(x, y, camera_manager.is_panning)

func _on_tile_mouse_exited(x: int, y: int) -> void:
	movement_controller.handle_tile_mouse_exited(x, y, camera_manager.is_panning)
	attack_handler.handle_tile_mouse_exited(x, y, camera_manager.is_panning)

func _on_tile_input(event: InputEvent, x: int, y: int) -> void:
	# Handle right-click for EtherDash cancellation
	if event is InputEventMouseButton and event.pressed and not camera_manager.is_panning and event.button_index == MOUSE_BUTTON_RIGHT:
		# Check if we're in EtherDash mode
		if player_manager.get_player_node() and player_manager.get_player_node().is_etherdash_mode:
			print("Right-click detected during EtherDash - cancelling EtherDash mode")
			# Use the same completion method to ensure card is discarded
			on_etherdash_complete()
			return
	
	if event is InputEventMouseButton and event.pressed and not camera_manager.is_panning and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := Vector2i(x, y)
		
		# Skip tile input handling during ball flying phase to allow BallHop to work
		if game_state_manager.get_game_phase() == "ball_flying":
			print("Course: Tile input ignored during ball flying phase - BallHop should handle this")
			return
		
		if game_state_manager.is_placing_player:
			if map_manager.get_tile_type(x, y) == "Tee":
				# Cancel any ongoing pin-to-tee transition
				var ongoing_tween = get_meta("pin_to_tee_tween", null)
				if ongoing_tween and ongoing_tween.is_valid():
					print("Cancelling ongoing pin-to-tee transition due to early player placement")
					ongoing_tween.kill()
					remove_meta("pin_to_tee_tween")
				
				player_manager.set_player_grid_pos(clicked)
				player_manager.create_player()  # This will reuse existing player or create new one
				game_state_manager.is_placing_player = false
				
				# Update player position and create ball
				player_manager.update_player_position_with_ball_creation(self)
				
				sound_manager.play_sand_thunk()
				game_state_manager.start_round_after_tee_selection(self, player_manager, deck_manager, ui_manager)
			else:
				pass # Please select a Tee Box to start your round.
		else:
			if player_manager.get_player_node().has_method("can_move_to"):
				print("player_manager.get_player_node().can_move_to(clicked):", player_manager.get_player_node().can_move_to(clicked))
			else:
				print("player_manager.get_player_node() does not have can_move_to method")
			
			if movement_controller.handle_tile_click(x, y):
				# Movement was successful, no need to do anything else here
				pass
			elif attack_handler.handle_tile_click(x, y):
				# Attack was successful, no need to do anything else here
				pass
			else:
				print("Invalid movement/attack tile or not in movement/attack mode")

# Round start function moved to GameStateManager

# Power meter functions moved to UIManager

# show_aiming_circle function moved to UIManager



# hide_aiming_circle function moved to UIManager

# update_aiming_circle function moved to UIManager

func launch_golf_ball(direction: Vector2, charged_power: float, height: float):
	# Determine if this is a tee shot (first shot of the hole)
	print("DEBUG: Launching ball, hole_score =", game_state_manager.get_hole_score())
	
	# Clear the previous ball landing information since we're taking a new shot
	game_state_manager.set_ball_landing_position(Vector2i.ZERO, Vector2.ZERO)
	game_state_manager.set_waiting_for_player_to_reach_ball(false)
	print("Cleared ball landing information for new shot")
	
	launch_manager.launch_golf_ball(direction, charged_power, height, 0.0, 0)
	
func _on_golf_ball_landed(tile: Vector2i):
	print("Course: Ball landed - exiting ball_flying phase!")
	print("DEBUG: Ball landed, hole_score before increment =", game_state_manager.get_hole_score())
	var is_first_shot = (game_state_manager.get_hole_score() == 0)  # Check if this is the first shot before incrementing
	game_state_manager.increment_hole_score()
	print("DEBUG: Ball landed, hole_score after increment =", game_state_manager.get_hole_score())
	print("Turning off camera following for golf ball")
	game_state_manager.set_camera_following_ball(false)
	game_state_manager.set_ball_landing_position(tile, Vector2.ZERO)
	
	# Note: Gimme detection is now handled by the Pin's GimmeArea Area2D
	# The gimme_triggered signal will be connected and handled separately
	
	# Hide grenade launcher weapon now that golf ball has landed (if using GrenadeLauncherClubCard)
	print("Golf ball landed - checking weapon handler:", weapon_handler != null, " weapon_instance:", weapon_handler.weapon_instance != null if weapon_handler else "N/A", " selected_club:", game_state_manager.get_selected_club())
	
	# Check if we have a grenade launcher weapon instance (either by club or by weapon type)
	var should_hide_weapon = false
	if weapon_handler and weapon_handler.weapon_instance:
		# Check if it's a grenade launcher by scene name
		var weapon_scene_name = weapon_handler.weapon_instance.scene_file_path
		if weapon_scene_name and "GrenadeLauncher" in weapon_scene_name:
			should_hide_weapon = true
			print("Detected grenade launcher by scene name:", weapon_scene_name)
		elif game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			should_hide_weapon = true
			print("Detected grenade launcher by club selection")
		elif weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
			should_hide_weapon = true
			print("Detected grenade launcher by weapon card selection")
	
	if should_hide_weapon:
		print("Hiding grenade launcher weapon after golf ball landing")
		weapon_handler.hide_weapon()
	
	# Reset ball in flight state in launch manager
	if launch_manager and launch_manager.has_method("set_ball_in_flight"):
		launch_manager.set_ball_in_flight(false)
		print("Ball in flight state reset to false")
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Re-enable player collision shape after ball lands
	if player_manager.get_player_node() and player_manager.get_player_node().has_method("enable_collision_shape"):
		player_manager.get_player_node().enable_collision_shape()
	
	# Check if the ball still exists (if not, it went in the hole)
	if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
		# Normal landing - ball still exists
		game_state_manager.set_ball_landing_position(game_state_manager.get_ball_landing_tile(), launch_manager.golf_ball.global_position)
		game_state_manager.set_waiting_for_player_to_reach_ball(true)
		
		# Check if player is already on the landing tile
		if player_manager.get_player_grid_pos() == game_state_manager.get_ball_landing_tile():
			print("Player is already on the ball landing tile - checking for gimme and showing buttons")
			# Player is already on the ball tile - remove landing highlight
			if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
				launch_manager.golf_ball.remove_landing_highlight()
			
			# Check if this ball is in gimme range
			ui_manager.check_and_show_gimme_button()
			
			# Show the "Draw Club Cards" button
			ui_manager.show_draw_club_cards_button()
		else:
			# Check if this ball was moved by RedJay - if so, don't show drive distance dialog
			if card_effect_handler and card_effect_handler.has_method("was_ball_moved_by_redjay") and card_effect_handler.was_ball_moved_by_redjay(launch_manager.golf_ball):
				print("Ball was moved by RedJay - skipping drive distance dialog")
				# Clear the RedJay moved ball reference since the ball has now landed
				if card_effect_handler.has_method("clear_redjay_moved_ball"):
					card_effect_handler.clear_redjay_moved_ball()
				game_state_manager.set_game_phase("move")
				player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
			else:
				# Player needs to move to the ball - show drive distance dialog on every shot
				if should_show_drive_distance_dialog(is_first_shot):
					var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
					var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
					var player_center = player_manager.get_player_node().global_position + player_size / 2
					var player_start_pos = player_center
					var ball_landing_pos = launch_manager.golf_ball.global_position
					game_state_manager.set_drive_distance(player_start_pos.distance_to(ball_landing_pos))
					var dialog_timer = get_tree().create_timer(0.5)  # Reduced from 1.5 to 0.5 second delay
					dialog_timer.timeout.connect(func():
						ui_manager.show_drive_distance_dialog(game_state_manager.get_drive_distance())
						# Tween camera back to player after showing drive distance dialog
						create_camera_tween(player_center, 0.8)
					)
					game_state_manager.set_game_phase("move")
					player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
				else:
					print("Not a tee shot or first shot - skipping drive distance dialog")
					# Tween camera back to player even when skipping dialog
					var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
					var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
					var player_center = player_manager.get_player_node().global_position + player_size / 2
					create_camera_tween(player_center, 0.8)
					game_state_manager.set_game_phase("move")
					player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
	else:
		# Ball went in the hole - don't show drive distance dialog
		# The hole completion dialog will be shown by the pin's hole_in_one signal
		print("Ball went in the hole - skipping drive distance dialog")
		# Clear the ball reference since it's been destroyed
		launch_manager.golf_ball = null

# Removed check_gimme_condition function - now using Pin's GimmeArea Area2D for detection


# Trigger gimme sequence function moved to UIManager

# Gimme sounds function moved to SoundManager

# Complete hole with gimme function moved to UIManager

# Clear gimme state function moved to UIManager

# Show gimme animation function moved to UIManager

# Complete gimme hole function moved to UIManager

# Highlight tee tiles function moved to MapManager

# Exit movement mode function moved to MapManager

func _on_end_turn_pressed() -> void:
	"""Called when the end turn button is pressed"""
	_end_turn_logic()

func _end_turn_logic() -> void:
	"""Core logic for ending a turn - can be called programmatically"""
	if movement_controller.is_in_movement_mode():
		map_manager.exit_movement_mode()
	if attack_handler.is_in_attack_mode():
		attack_handler.exit_attack_mode()
	if weapon_handler.is_in_weapon_mode():
		weapon_handler.exit_weapon_mode()

	var cards_to_discard = deck_manager.hand.size()
	print("End turn: Discarding", cards_to_discard, "cards from hand")
	
	# Create a copy of the hand to avoid modification during iteration
	var hand_copy = deck_manager.hand.duplicate()
	print("End turn: Hand copy contains", hand_copy.size(), "cards")
	for card in hand_copy:
		print("End turn: Discarding card:", card.name)
		deck_manager.discard(card)
	deck_manager.hand.clear()
	print("End turn: Hand cleared, final hand size:", deck_manager.hand.size())
	
	
	movement_controller.clear_all_movement_ui()
	attack_handler.clear_all_attack_ui()
	weapon_handler.clear_all_weapon_ui()
	game_state_manager.increment_turn_count()
	
	# Increment global turn counter for turn-based spawning
	Global.increment_global_turn()
	
	# Reset fire damage tracking for new turn
	player_manager.reset_fire_damage_tracking(game_state_manager)
	
	# Advance fire tiles to next turn
	map_manager.advance_fire_tiles()
	# Advance ice tiles to next turn
	map_manager.advance_ice_tiles()
	
	# Block persists during world turn - will be cleared when player's next turn begins
	# clear_block()  # REMOVED: Block should persist during world turn
	
	ui_manager.update_deck_display()
	
	if cards_to_discard > 0:
		sound_manager.play_discard_sound()
	elif cards_to_discard == 0:
		sound_manager.play_discard_empty_sound()

	# Check if player has extra turns
	if extra_turns_remaining > 0:
		extra_turns_remaining -= 1
		print("Using extra turn! Extra turns remaining:", extra_turns_remaining)
		
		# Show "Extra Turn" message
		ui_manager.show_turn_message("Extra Turn!", 2.0)
		
		# Continue with normal turn flow without World Turn
		if game_state_manager.get_waiting_for_player_to_reach_ball() and player_manager.get_player_grid_pos() == game_state_manager.get_ball_landing_tile():
			if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
				launch_manager.golf_ball.remove_landing_highlight()
			
			ui_manager.enter_draw_cards_phase()  # Start with club selection phase
		else:
			show_draw_cards_button_for_turn_start()
	else:
		# Use WorldTurnManager for NPC turn sequence
		_start_world_turn_sequence()

func _start_world_turn_sequence() -> void:
	"""Start the world turn sequence using WorldTurnManager"""
	print("=== STARTING WORLD TURN SEQUENCE ===")
	
	# Check if WorldTurnManager is available
	if world_turn_manager:
		print("WorldTurnManager found: ", world_turn_manager.name)
		# Emit player turn ended signal to trigger WorldTurnManager
		player_turn_ended.emit()
		
		# Disable end turn button during world turn
		if end_turn_button:
			end_turn_button.get_node("TextureButton").mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		print("ERROR: WorldTurnManager not found!")
		# Fallback to old system
		start_npc_turn_sequence()

func _continue_after_world_turn() -> void:
	"""Continue with player's turn after world turn completion"""
	print("=== CONTINUING AFTER WORLD TURN ===")
	
	# Continue with normal turn flow
	if game_state_manager.get_waiting_for_player_to_reach_ball() and player_manager.get_player_grid_pos() == game_state_manager.get_ball_landing_tile():
		if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
			launch_manager.golf_ball.remove_landing_highlight()
		
		ui_manager.enter_draw_cards_phase()  # Start with club selection phase
	else:
		show_draw_cards_button_for_turn_start()

func start_npc_turn_sequence() -> void:
	"""Handle the NPC turn sequence with priority-based turns for visible NPCs"""
	
	# Check if there are any active NPCs on the map (alive and not frozen, or will thaw this turn)
	if not game_state_manager.has_active_npcs():
		
		# Show "Your Turn" message immediately
		ui_manager.show_turn_message("Your Turn", 2.0)
		
		# Continue with normal turn flow
		if game_state_manager.get_waiting_for_player_to_reach_ball() and player_manager.get_player_grid_pos() == game_state_manager.get_ball_landing_tile():
			if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
				launch_manager.golf_ball.remove_landing_highlight()
			
			ui_manager.enter_draw_cards_phase()  # Start with club selection phase
		else:
			show_draw_cards_button_for_turn_start()
		return
	
	# Disable end turn button during NPC turn
	end_turn_button.get_node("TextureButton").mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Handle all NPC turns with priority-based system
	
	# Find all visible NPCs and sort by priority
	var visible_npcs = world_turn_manager.get_visible_npcs_by_priority(player_manager, game_state_manager, ghost_mode_active)
	
	if visible_npcs.is_empty():
		# Show "Your Turn" message immediately
		ui_manager.show_turn_message("Your Turn", 2.0)
		
		# Re-enable end turn button
		end_turn_button.get_node("TextureButton").mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Continue with normal turn flow
		if game_state_manager.get_waiting_for_player_to_reach_ball() and player_manager.get_player_grid_pos() == game_state_manager.get_ball_landing_tile():
			if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
				launch_manager.golf_ball.remove_landing_highlight()
			
			ui_manager.enter_draw_cards_phase()  # Start with club selection phase
		else:
			show_draw_cards_button_for_turn_start()
		return
	

	
	# Show "World Turn" message
	await ui_manager.show_turn_message("World Turn", 2.0)
	
	# Process each NPC's turn in priority order
	for npc in visible_npcs:
		
		# Transition camera to NPC and wait for it to complete
		await camera_manager.transition_camera_to_npc(npc)
		
		# Wait a moment for camera transition
		await get_tree().create_timer(0.25).timeout
		
		# Special handling for squirrels: update ball detection before turn
		var script_path = npc.get_script().resource_path if npc.get_script() else ""
		var is_squirrel = "Squirrel.gd" in script_path
		if is_squirrel:
			if npc.has_method("_check_vision_for_golf_balls"):
				npc._check_vision_for_golf_balls()
			if npc.has_method("_update_nearest_golf_ball"):
				npc._update_nearest_golf_ball()
			
			# Check if squirrel can detect ball after update
			if npc.has_method("has_detected_golf_ball"):
				var has_ball = npc.has_detected_golf_ball()
				
				# Skip squirrel's turn if it no longer detects a ball
				if not has_ball:
					await get_tree().create_timer(0.25).timeout
					continue
		
		# Take the NPC's turn
		npc.take_turn()
		
		# Wait for the NPC's turn to complete
		await npc.turn_completed
		
		# Wait a moment to let player see the result
		await get_tree().create_timer(0.25).timeout
	

	
	# Show "Your Turn" message
	ui_manager.show_turn_message("Your Turn", 2.0)
	
	# Wait for message to display, then transition camera back to player
	await get_tree().create_timer(0.5).timeout
	await camera_manager.transition_camera_to_player()
	
	# Re-enable end turn button
	end_turn_button.get_node("TextureButton").mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Continue with normal turn flow
	if game_state_manager.get_waiting_for_player_to_reach_ball() and player_manager.get_player_grid_pos() == game_state_manager.get_ball_landing_tile():
		if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
			launch_manager.golf_ball.remove_landing_highlight()
		
		ui_manager.enter_draw_cards_phase()  # Start with club selection phase
	else:
		show_draw_cards_button_for_turn_start()

# Get visible NPCs by priority function moved to WorldTurnManager

# NPC priority function moved to GameStateManager

# Nearest visible NPC function moved to GameStateManager

# Alive NPCs check moved to GameStateManager

# Active NPCs check moved to GameStateManager

# Camera transition functions moved to CameraManager - direct calls used

# Turn message function moved to UIManager

# Register existing gang members function moved to WorldTurnManager

func _find_gang_members_recursive(node: Node, gang_members: Array) -> void:
	"""Recursively search for GangMember nodes in the scene tree"""
	for child in node.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("GangMember.gd"):
			gang_members.append(child)
		_find_gang_members_recursive(child, gang_members)

# Register existing squirrels function moved to WorldTurnManager

func _find_squirrels_recursive(node: Node, squirrels: Array) -> void:
	"""Recursively search for Squirrel nodes in the scene tree"""
	for child in node.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("Squirrel.gd"):
			squirrels.append(child)
		_find_squirrels_recursive(child, squirrels)

# Utility reference functions moved to managers - direct calls used

# Extra turn function moved to GameStateManager

# Environment tile functions moved to MapManager
	player_manager.check_player_fire_damage(game_state_manager)

# Ice tiles function moved to MapManager

# Update deck display function moved to UIManager

# Display selected character function moved to UIManager

func _on_end_round_pressed() -> void:
	if movement_controller.is_in_movement_mode():
		map_manager.exit_movement_mode()
	call_deferred("_change_to_main")

func _change_to_main() -> void:
	Global.putt_putt_mode = false
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5)

func show_tee_selection_instruction() -> void:
	ui_manager.show_tee_selection_instruction()

# Drive distance dialog moved to UIManager - direct calls used
	
# Drive distance dialog input handling moved to UIManager

# Sound functions moved to SoundManager

# Swing sound function moved to SoundManager

# Start next shot from ball function moved to LaunchManager
	

func _on_golf_ball_out_of_bounds():
	
	sound_manager.play_water_plunk()
	game_state_manager.set_camera_following_ball(false)
	
	# Hide grenade launcher weapon now that golf ball has gone out of bounds (if using GrenadeLauncherClubCard)
	# Check if we have a grenade launcher weapon instance (either by club or by weapon type)
	var should_hide_weapon = false
	if weapon_handler and weapon_handler.weapon_instance:
		# Check if it's a grenade launcher by scene name
		var weapon_scene_name = weapon_handler.weapon_instance.scene_file_path
		if weapon_scene_name and "GrenadeLauncher" in weapon_scene_name:
			should_hide_weapon = true
		elif game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			should_hide_weapon = true
		elif weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
			should_hide_weapon = true
	
	if should_hide_weapon:
		weapon_handler.hide_weapon()
	
	# Reset ball in flight state in launch manager
	if launch_manager and launch_manager.has_method("set_ball_in_flight"):
		launch_manager.set_ball_in_flight(false)
		print("Ball in flight state reset to false (out of bounds)")
	
	# Re-enable player collision shape after ball goes out of bounds
	if player_manager.get_player_node() and player_manager.get_player_node().has_method("enable_collision_shape"):
		player_manager.get_player_node().enable_collision_shape()
	
	game_state_manager.increment_hole_score()
	if launch_manager.golf_ball:
		launch_manager.golf_ball.queue_free()
		launch_manager.golf_ball = null
	
	# Clear any existing balls to ensure clean state
	launch_manager.remove_all_balls()
	
	ui_manager.show_out_of_bounds_dialog()
	game_state_manager.set_ball_landing_position(game_state_manager.get_shot_start_position(), Vector2(game_state_manager.get_shot_start_position().x * cell_size + cell_size/2, game_state_manager.get_shot_start_position().y * cell_size + cell_size/2))
	game_state_manager.set_waiting_for_player_to_reach_ball(true)
	player_manager.set_player_grid_pos(game_state_manager.get_shot_start_position())
	player_manager.update_player_position_with_ball_creation(self)
	
	# Force create a new ball at the player's tile center position for the penalty shot
	var tile_center: Vector2 = Vector2(player_manager.get_player_grid_pos().x * cell_size + cell_size/2, player_manager.get_player_grid_pos().y * cell_size + cell_size/2) + grid_manager.get_camera_container().global_position
	launch_manager.force_create_ball_at_position(tile_center, self)
	
	game_state_manager.set_game_phase("draw_cards")
	player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)

# Out of bounds dialog moved to UIManager - direct calls used

# Reset player to tee function moved to PlayerManager

# Enter launch phase function moved to LaunchManager
	
func enter_aiming_phase() -> void:
	game_state_manager.set_game_phase("aiming")
	player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
	game_state_manager.set_is_aiming_phase(true)
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("aiming", false, true, false)
	
	# Set the shot start position to where the player currently is
	game_state_manager.set_shot_start_position(player_manager.get_player_grid_pos())
	print("Shot started from position:", game_state_manager.get_shot_start_position())
	
	ui_manager.show_aiming_circle()
	launch_manager.create_ghost_ball()
	ui_manager.show_aiming_instruction()
	var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_manager.get_player_node().global_position + player_size / 2
	create_camera_tween(player_center, 1.0)
	
	# Zoom out when entering aiming phase for better visibility
	if camera and camera.has_method("set_zoom_level"):
		# Store current zoom to restore later
		if not has_meta("pre_aiming_zoom"):
			set_meta("pre_aiming_zoom", camera.get_current_zoom())
		
		# Calculate zoom out based on shot distance potential
		var base_zoom = camera.get_default_zoom_position()
		var zoom_out_factor = 0.3  # Zoom out by 30%
		var aiming_zoom = base_zoom - zoom_out_factor
		
		# Ensure we don't go below minimum zoom
		if camera.has_method("current_min_zoom"):
			aiming_zoom = max(aiming_zoom, camera.current_min_zoom)
		
		print("Zooming out for aiming from", camera.get_current_zoom(), "to", aiming_zoom)
		camera.set_zoom_level(aiming_zoom)

# Aiming instruction function moved to UIManager

# Hide aiming instruction function moved to UIManager

# Zoom restoration moved to CameraManager

# Card drawing functions moved to DeckManager
	

# Start shot sequence function moved to GameStateManager

func draw_cards_for_next_shot() -> void:
	if card_stack_display.has_node("CardDraw"):
		var card_draw_sound = card_stack_display.get_node("CardDraw")
		if card_draw_sound and card_draw_sound.stream:
			card_draw_sound.play()
	deck_manager.draw_cards_for_shot(5, player_manager, game_state_manager)  # This now includes character modifiers
	create_movement_buttons()

func _on_golf_ball_sand_landing():
	sound_manager.play_sand_thunk()
	
	game_state_manager.set_camera_following_ball(false)
	
	# Hide grenade launcher weapon now that golf ball has landed in sand (if using GrenadeLauncherClubCard)
	# Check if we have a grenade launcher weapon instance (either by club or by weapon type)
	var should_hide_weapon = false
	if weapon_handler and weapon_handler.weapon_instance:
		# Check if it's a grenade launcher by scene name
		var weapon_scene_name = weapon_handler.weapon_instance.scene_file_path
		if weapon_scene_name and "GrenadeLauncher" in weapon_scene_name:
			should_hide_weapon = true
		elif game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			should_hide_weapon = true
		elif weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
			should_hide_weapon = true
	
	if should_hide_weapon:
		weapon_handler.hide_weapon()
	# Re-enable player collision shape after ball lands in sand
	if player_manager.get_player_node() and player_manager.get_player_node().has_method("enable_collision_shape"):
		player_manager.get_player_node().enable_collision_shape()
	
	if launch_manager.golf_ball and map_manager:
		var final_tile = Vector2i(floor(launch_manager.golf_ball.position.x / cell_size), floor(launch_manager.golf_ball.position.y / cell_size))
		_on_golf_ball_landed(final_tile)

func _on_grenade_landed(final_tile: Vector2i) -> void:
	"""Handle when a grenade lands"""
	print("Grenade landed at tile:", final_tile)
	
	# Hide grenade launcher weapon now that grenade has landed
	print("Grenade landed - checking weapon handler:", weapon_handler != null, " weapon_instance:", weapon_handler.weapon_instance != null if weapon_handler else "N/A", " selected_club:", game_state_manager.get_selected_club())
	
	# Check if we have a grenade launcher weapon instance (either by club or by weapon type)
	var should_hide_weapon = false
	if weapon_handler and weapon_handler.weapon_instance:
		# Check if it's a grenade launcher by scene name
		var weapon_scene_name = weapon_handler.weapon_instance.scene_file_path
		if weapon_scene_name and "GrenadeLauncher" in weapon_scene_name:
			should_hide_weapon = true
			print("Detected grenade launcher by scene name:", weapon_scene_name)
		elif game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			should_hide_weapon = true
			print("Detected grenade launcher by club selection")
		elif weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
			should_hide_weapon = true
			print("Detected grenade launcher by weapon card selection")
	
	if should_hide_weapon:
		print("Hiding grenade launcher weapon after landing")
		weapon_handler.hide_weapon()
		
		# Ensure weapon mode is properly exited to fix cursor stuck on reticle
		if weapon_handler.is_weapon_mode:
			weapon_handler.is_weapon_mode = false
			weapon_handler.selected_card = null
			weapon_handler.active_button = null
			print("Exited weapon mode after grenade landing")
	
	# Update smart optimizer state immediately when grenade lands
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Set game phase to move to allow movement cards
	game_state_manager.set_game_phase("move")
	# Reset ReachBallButton flag when entering move phase after grenade landing
	game_state_manager.set_used_reach_ball_button(false)
	print("ReachBallButton flag reset after grenade landing")
	
	# Pause for 1 second to let player see where grenade landed
	var pause_timer = get_tree().create_timer(1.0)
	pause_timer.timeout.connect(func():
		# After pause, tween camera back to player
		if player_manager.get_player_node() and camera:
			camera_manager.create_camera_tween(player_manager.get_player_node().global_position, 0.5, Tween.TRANS_LINEAR)
			var tween = camera_manager.get_current_camera_tween()
			if tween:
				tween.tween_callback(func():
					# Exit grenade mode and reset camera following after tween completes
					if launch_manager:
						launch_manager.exit_grenade_mode()
						print("Exited grenade mode after camera tween completed")
					game_state_manager.set_camera_following_ball(false)
				)
		else:
			# Fallback if no player or camera
			if launch_manager:
				launch_manager.exit_grenade_mode()
				print("Exited grenade mode (fallback)")
			game_state_manager.set_camera_following_ball(false)
	)

func _on_grenade_out_of_bounds() -> void:
	"""Handle when a grenade goes out of bounds"""
	print("Grenade went out of bounds")
	
	# Hide grenade launcher weapon now that grenade has gone out of bounds
	# Check if we have a grenade launcher weapon instance (either by club or by weapon type)
	var should_hide_weapon = false
	if weapon_handler and weapon_handler.weapon_instance:
		# Check if it's a grenade launcher by scene name
		var weapon_scene_name = weapon_handler.weapon_instance.scene_file_path
		if weapon_scene_name and "GrenadeLauncher" in weapon_scene_name:
			should_hide_weapon = true
		elif game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			should_hide_weapon = true
		elif weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
			should_hide_weapon = true
	
	if should_hide_weapon:
		weapon_handler.hide_weapon()
		
		# Ensure weapon mode is properly exited to fix cursor stuck on reticle
		if weapon_handler.is_weapon_mode:
			weapon_handler.is_weapon_mode = false
			weapon_handler.selected_card = null
			weapon_handler.active_button = null
			print("Exited weapon mode after grenade out of bounds")
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Set game phase to move to allow movement cards
	game_state_manager.set_game_phase("move")
	
	# Tween camera back to player immediately
	if player_manager.get_player_node() and camera:
		camera_manager.create_camera_tween(player_manager.get_player_node().global_position, 0.5, Tween.TRANS_LINEAR)
		var tween = camera_manager.get_current_camera_tween()
		if tween:
			tween.tween_callback(func():
				# Exit grenade mode and reset camera following after tween completes
				if launch_manager:
					launch_manager.exit_grenade_mode()
					print("Exited grenade mode after out of bounds")
				game_state_manager.set_camera_following_ball(false)
			)
	else:
		# Fallback if no player or camera
		if launch_manager:
			launch_manager.exit_grenade_mode()
			print("Exited grenade mode (fallback)")
		game_state_manager.set_camera_following_ball(false)

func _on_grenade_sand_landing() -> void:
	"""Handle when a grenade lands in sand"""
	print("Grenade landed in sand")
	
	# Hide grenade launcher weapon now that grenade has landed in sand
	# Check if we have a grenade launcher weapon instance (either by club or by weapon type)
	var should_hide_weapon = false
	if weapon_handler and weapon_handler.weapon_instance:
		# Check if it's a grenade launcher by scene name
		var weapon_scene_name = weapon_handler.weapon_instance.scene_file_path
		if weapon_scene_name and "GrenadeLauncher" in weapon_scene_name:
			should_hide_weapon = true
		elif game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			should_hide_weapon = true
		elif weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
			should_hide_weapon = true
	
	if should_hide_weapon:
		weapon_handler.hide_weapon()
		
		# Ensure weapon mode is properly exited to fix cursor stuck on reticle
		if weapon_handler.is_weapon_mode:
			weapon_handler.is_weapon_mode = false
			weapon_handler.selected_card = null
			weapon_handler.active_button = null
			print("Exited weapon mode after grenade sand landing")
	
	# Play sand landing sound
	sound_manager.play_sand_thunk()
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Set game phase to move to allow movement cards
	game_state_manager.set_game_phase("move")
	
	# Pause for 1 second to let player see where grenade landed
	var pause_timer = get_tree().create_timer(1.0)
	pause_timer.timeout.connect(func():
		# After pause, tween camera back to player
		if player_manager.get_player_node() and camera:
			camera_manager.create_camera_tween(player_manager.get_player_node().global_position, 0.5, Tween.TRANS_LINEAR)
			var tween = camera_manager.get_current_camera_tween()
			if tween:
				tween.tween_callback(func():
					# Exit grenade mode and reset camera following after tween completes
					if launch_manager:
						launch_manager.exit_grenade_mode()
						print("Exited grenade mode after sand landing")
					game_state_manager.set_camera_following_ball(false)
				)
		else:
			# Fallback if no player or camera
			if launch_manager:
				launch_manager.exit_grenade_mode()
				print("Exited grenade mode (fallback)")
			game_state_manager.set_camera_following_ball(false)
	)

# Sand landing dialog function moved to UIManager

# UI dialog functions moved to UIManager - direct calls used

# Add card to current deck function moved to DeckManager

# Equipment and reward functions moved to EquipmentManager - direct calls used

func _on_advance_to_next_hole():
	"""Handle when the advance button is pressed"""
	
	# Update HUD to reflect any changes (including $Looty balance)
	ui_manager.update_deck_display()
	
	# Special handling for hole 9 - show front nine completion dialog
	if game_state_manager.get_current_hole_index() == 8 and not game_state_manager.is_back_9_mode:  # Hole 9 (index 8) in front 9 mode
		ui_manager.show_front_nine_complete_dialog()
	else:
		# Show puzzle type selection dialog
		ui_manager.show_puzzle_type_selection()

# Puzzle type selection function moved to UIManager

# Puzzle type selected function moved to UIManager

func reset_for_next_hole():
	print("=== ADVANCING TO HOLE", game_state_manager.get_current_hole_index() + 2, "===")
	
	# Clear the player's hand when advancing to next hole
	if deck_manager:
		print("Clearing player hand for next hole - hand size before:", deck_manager.hand.size())
		deck_manager.hand.clear()
		print("Player hand cleared - hand size after:", deck_manager.hand.size())
		# Update the deck display to reflect the cleared hand
		ui_manager.update_deck_display()
		# Clear any movement buttons that might still be visible
		if movement_controller:
			movement_controller.clear_all_movement_ui()
		if attack_handler:
			attack_handler.clear_all_attack_ui()
		if weapon_handler:
			weapon_handler.clear_all_weapon_ui()
	
	# Clean up any existing reward UI
	var existing_suitcase = $UILayer.get_node_or_null("SuitCase")
	if existing_suitcase:
		existing_suitcase.queue_free()
	
	var existing_map_suitcase_overlay = $UILayer.get_node_or_null("MapSuitCaseOverlay")
	if existing_map_suitcase_overlay:
		existing_map_suitcase_overlay.queue_free()
	
	var existing_reward_dialog = $UILayer.get_node_or_null("RewardSelectionDialog")
	if existing_reward_dialog:
		existing_reward_dialog.queue_free()
	
	var existing_suitcase_reward_dialog = $UILayer.get_node_or_null("SuitCaseRewardDialog")
	if existing_suitcase_reward_dialog:
		existing_suitcase_reward_dialog.queue_free()
	
	# Clean up any crowd instances
	var crowd_instances = get_tree().get_nodes_in_group("crowd")
	for crowd in crowd_instances:
		if crowd.has_method("stop_cheering"):
			crowd.stop_cheering()
		crowd.queue_free()
	
	# Also check for any crowd nodes that might not be in the group
	var all_nodes = get_tree().get_nodes_in_group("")
	for node in all_nodes:
		if node.name == "Crowd" and node.has_method("stop_cheering"):
			node.stop_cheering()
			node.queue_free()
	
	# Reset launch manager state for new hole
	if launch_manager and launch_manager.has_method("set_ball_in_flight"):
		launch_manager.set_ball_in_flight(false)
	
	# Clear any existing balls from the previous hole
	launch_manager.remove_all_balls()
	
	game_state_manager.increment_current_hole()
	
	var round_end_hole = 0
	if game_state_manager.is_back_9_mode:
		round_end_hole = game_state_manager.back_9_start_hole + game_state_manager.NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		round_end_hole = game_state_manager.NUM_HOLES - 1  # Hole 9 (index 8)
	
	if game_state_manager.get_current_hole_index() > round_end_hole:
		return
		
	if player_manager.get_player_node() and is_instance_valid(player_manager.get_player_node()):
		# Disable animations before hiding player for next hole
		if player_manager.get_player_node().has_method("disable_animations"):
			player_manager.get_player_node().disable_animations()
		player_manager.get_player_node().visible = false
	
	# Apply the selected puzzle type for this hole
	game_state_manager.set_current_puzzle_type(game_state_manager.get_next_puzzle_type())
	print("🎯 PUZZLE TYPE: Applying puzzle type '", game_state_manager.get_current_puzzle_type(), "' to hole", game_state_manager.get_current_hole_index() + 1)
	
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(game_state_manager.get_current_hole_index()))
	build_map.build_map_from_layout_with_randomization(map_manager.level_layout, game_state_manager.get_current_hole_index(), game_state_manager.get_current_puzzle_type())
	
	# Sync shop grid position with build_map
	game_state_manager.set_shop_grid_position(build_map.shop_grid_pos)
	
	# Sync SuitCase grid position with build_map
	game_state_manager.set_suitcase_grid_position(build_map.get_suitcase_position())
	if game_state_manager.get_suitcase_grid_position() != Vector2i.ZERO:
		print("SuitCase placed at grid position:", game_state_manager.get_suitcase_grid_position())
	
	# Ensure Y-sort objects are properly registered for pin detection
	update_all_ysort_z_indices()
	
	position_camera_on_pin()  # Add camera positioning for next hole
	game_state_manager.reset_hole_score()
	game_state_manager.set_game_phase("tee_select")
	player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
	game_state_manager.set_chosen_landing_spot(Vector2.ZERO)
	game_state_manager.set_selected_club("")
	update_hole_and_score_display()
	if hud:
		hud.get_node("ShotLabel").text = "Shots: %d" % game_state_manager.get_hole_score()
	game_state_manager.set_is_placing_player(true)
	map_manager.highlight_tee_tiles()
	show_tee_selection_instruction()
	# After all NPCs are spawned/registered for the new hole
	var entities = get_node_or_null("Entities")
	if entities:
		entities.re_register_all_npcs()
		
func _connect_pin_signals():
	var pin = find_pin_in_scene()
	if pin:
		if not pin.gimme_triggered.is_connected(_on_gimme_triggered):
			pin.gimme_triggered.connect(_on_gimme_triggered)
		if not pin.gimme_ball_exited.is_connected(_on_gimme_ball_exited):
			pin.gimme_ball_exited.connect(_on_gimme_ball_exited)
	else:
		print("Pin not found when trying to connect gimme signals!")

# Course complete dialog function moved to UIManager

# Front nine complete dialog function moved to UIManager

# Back nine complete dialog function moved to UIManager

func update_hole_and_score_display():
	if hud:
		var label = hud.get_node_or_null("HoleLabel")
		if not label:
			label = Label.new()
			label.name = "HoleLabel"
			hud.add_child(label)
		
		var current_round_score = 0
		for score in game_state_manager.get_round_scores():
			current_round_score += score
		current_round_score += game_state_manager.get_hole_score()  # Include current hole score
		
		var total_par_so_far = 0
		if game_state_manager.is_back_9_mode:
			for i in range(game_state_manager.back_9_start_hole, game_state_manager.get_current_hole_index() + 1):
				total_par_so_far += GolfCourseLayout.get_hole_par(i)
		else:
			for i in range(game_state_manager.get_current_hole_index() + 1):
				total_par_so_far += GolfCourseLayout.get_hole_par(i)
		var round_vs_par = current_round_score - total_par_so_far
		
		label.text = "Hole: %d/%d    Round: %d (%+d)" % [game_state_manager.get_current_hole_index()+1, game_state_manager.NUM_HOLES, current_round_score, round_vs_par]
		label.position = Vector2(10, 10)
		label.z_index = 200

func _on_draw_cards_pressed() -> void:
	if game_state_manager.get_game_phase() == "draw_cards":
		print("Drawing club cards for selection...")
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		draw_club_cards()
	elif game_state_manager.get_game_phase() == "ball_tile_choice":
		print("Drawing club cards for shot from ball tile...")
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		draw_club_cards()
	elif game_state_manager.get_game_phase() == "waiting_for_draw":
		print("Drawing cards for turn start...")
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		deck_manager.draw_cards_for_shot(5, player_manager, game_state_manager)
		create_movement_buttons()
		draw_cards_button.visible = false
		print("Drew 5 new cards for turn start. DrawCards button hidden:", draw_cards_button.visible)
	else:
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		deck_manager.draw_cards_for_shot(5, player_manager, game_state_manager)
		create_movement_buttons()
		draw_cards_button.visible = false
		print("Drew 5 new cards after ending turn. DrawCards button hidden:", draw_cards_button.visible)

func _on_draw_club_cards_pressed() -> void:
	print("Draw Club Cards button pressed")
	if card_stack_display.has_node("CardDraw"):
		var card_draw_sound = card_stack_display.get_node("CardDraw")
		if card_draw_sound and card_draw_sound.stream:
			card_draw_sound.play()
	draw_club_cards()

# Update spin indicator function moved to LaunchManager
	
# Enter draw cards phase function moved to UIManager
	

func draw_club_cards() -> void:
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	
	# Note: BagCheck temporary club will be handled after normal club drawing
	
	# Clear existing action cards from hand before drawing club cards
	var cards_to_remove: Array[CardData] = []
	for card in deck_manager.hand:
		if not deck_manager.is_club_card(card):
			cards_to_remove.append(card)
	
	for card in cards_to_remove:
		deck_manager.discard(card)
	
	# Calculate how many club cards we need to draw
	var base_club_count = 2  # Default number of clubs to show
	var card_draw_modifier = player_manager.get_player_stats().get("card_draw", 0)
	var final_club_count = base_club_count + card_draw_modifier
	
	# Actually draw club cards to hand first - draw enough for the selection
	deck_manager.draw_club_cards_to_hand(final_club_count)
	
	# Check for PutterHelp equipment and add an extra putter card if equipped
	var equipment_manager = get_node_or_null("EquipmentManager")
	var putter_help_active = false
	if equipment_manager and equipment_manager.has_putter_help():
		print("PutterHelp equipment detected - adding virtual putter card")
		putter_help_active = deck_manager.add_virtual_putter_to_hand()
	
	# Check for BagCheck temporary club and add it as an extra option
	var bag_check_active = game_state_manager.is_bag_check_active()
	if game_state_manager.get_temporary_club() != null:
		print("BagCheck temporary club detected - adding as extra option:", game_state_manager.get_temporary_club().name)
		bag_check_active = true
		# Add the temporary club to the hand temporarily for selection
		deck_manager.hand.append(game_state_manager.get_temporary_club())
	
	# Then get available clubs from the hand
	var available_clubs = deck_manager.hand.filter(func(card): return deck_manager.is_club_card(card))
	if Global.putt_putt_mode:
		available_clubs = available_clubs.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		)
	
	# Calculate how many clubs we should show total (including virtual putter and BagCheck if active)
	var total_clubs_to_show = final_club_count
	if putter_help_active:
		total_clubs_to_show += 1  # Add one more slot for the virtual putter
		print("PutterHelp active - total clubs to show:", total_clubs_to_show)
	if bag_check_active:
		total_clubs_to_show += 1  # Add one more slot for the BagCheck club
		print("BagCheck active - total clubs to show:", total_clubs_to_show)
	
	total_clubs_to_show = max(1, min(total_clubs_to_show, available_clubs.size()))
	print("Available clubs in hand:", available_clubs.map(func(card): return card.name))
	print("Total clubs to show:", total_clubs_to_show)
	var selected_clubs: Array[CardData] = []
	var bonus_cards: Array[CardData] = []
	
	if not Global.putt_putt_mode:
		var putters = available_clubs.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		)
		
		# Always include at least one putter if available
		if putters.size() > 0:
			var random_putter_index = randi() % putters.size()
			var selected_putter = putters[random_putter_index]
			selected_clubs.append(selected_putter)
			available_clubs.erase(selected_putter)
			total_clubs_to_show -= 1

	# Select remaining clubs to fill the total count
	var club_candidates = available_clubs.filter(func(card): return card.effect_type != "ModifyNext" and card.effect_type != "ModifyNextCard")
	print("Club candidates for selection:", club_candidates.map(func(card): return card.name))
	for i in range(total_clubs_to_show):
		if club_candidates.size() > 0:
			var random_index = randi() % club_candidates.size()
			selected_clubs.append(club_candidates[random_index])
			club_candidates.remove_at(random_index)
	
	print("Final selected clubs:", selected_clubs.map(func(card): return card.name))
	
	var modify_next_candidates = available_clubs.filter(func(card): return card.effect_type == "ModifyNext")
	if force_stickyshot_bonus:
		for card in modify_next_candidates:
			if card.name == "Sticky Shot":
				bonus_cards.append(card)
				break
		force_stickyshot_bonus = false
	elif modify_next_candidates.size() > 0:
		if randi() % 2 == 0:
			var random_index = randi() % modify_next_candidates.size()
			bonus_cards.append(modify_next_candidates[random_index])
	
	if bonus_cards.size() > 0:
		print("Bonus cards:", bonus_cards.map(func(card): return card.name))
	
	var all_cards = selected_clubs + bonus_cards
	for i in all_cards.size():
		var club_card = all_cards[i]
		var club_name = club_card.name
		var club_info = club_data.get(club_name, {})
		var max_distance = club_info.get("max_distance", 0)
		
		var btn := TextureButton.new()
		btn.name = "ClubButton%d" % i
		btn.texture_normal = club_card.image  # Use the actual card image
		btn.custom_minimum_size = Vector2(100, 140)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		# Add PutterHelp indicator if this is a putter card and PutterHelp is active
		if putter_help_active and club_name == "Putter":
			# Create a small equipment indicator in the top-right corner
			var equipment_indicator = TextureRect.new()
			var putter_help_equipment = preload("res://Equipment/PutterHelp.tres")
			equipment_indicator.texture = putter_help_equipment.image
			equipment_indicator.custom_minimum_size = Vector2(20, 20)
			equipment_indicator.size = Vector2(20, 20)
			equipment_indicator.position = Vector2(btn.custom_minimum_size.x - 25, 5)
			equipment_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			equipment_indicator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			equipment_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			equipment_indicator.z_index = 1  # Ensure it appears on top
			btn.add_child(equipment_indicator)
			print("Added PutterHelp indicator to putter card")
		
		# Add BagCheck indicator if this is the BagCheck temporary club
		if bag_check_active and club_name == game_state_manager.get_temporary_club().name:
			# Create a small BagCheck indicator in the top-right corner
			var bag_check_indicator = Label.new()
			bag_check_indicator.text = "BAG"
			bag_check_indicator.add_theme_font_size_override("font_size", 8)
			bag_check_indicator.add_theme_color_override("font_color", Color.YELLOW)
			bag_check_indicator.add_theme_constant_override("outline_size", 1)
			bag_check_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
			bag_check_indicator.position = Vector2(btn.custom_minimum_size.x - 25, 5)
			bag_check_indicator.size = Vector2(20, 20)
			bag_check_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bag_check_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			bag_check_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bag_check_indicator.z_index = 1  # Ensure it appears on top
			btn.add_child(bag_check_indicator)
			print("Added BagCheck indicator to temporary club card")
		
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.z_index = 10
		
		var overlay := ColorRect.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(1, 0.84, 0, 0.25)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		btn.add_child(overlay)
		
		btn.mouse_entered.connect(func(): overlay.visible = true)
		btn.mouse_exited.connect(func(): overlay.visible = false)
		
		if club_card.effect_type == "ModifyNext":
			btn.pressed.connect(func(): card_effect_handler.handle_modify_next_card(club_card))
		elif club_card.effect_type == "ModifyNextCard":
			btn.pressed.connect(func(): card_effect_handler.handle_modify_next_card_card(club_card))
		else:
			btn.pressed.connect(func(): _on_club_card_pressed(club_name, club_info, btn))
		
		movement_buttons_container.add_child(btn)
		movement_buttons.append(btn)
	
	draw_club_cards_button.visible = false
	

func _on_club_card_pressed(club_name: String, club_info: Dictionary, button: TextureButton) -> void:
	game_state_manager.set_selected_club(club_name)
	var base_max_distance = club_info.get("max_distance", 600.0)  # Default fallback distance
	var strength_modifier = player_manager.get_player_stats().get("strength", 0)
	var strength_multiplier = 1.0 + (strength_modifier * 0.1)  # Same multiplier as power calculation
	game_state_manager.max_shot_distance = base_max_distance * strength_multiplier
	card_click_sound.play()
	
	# Special handling for GrenadeLauncherClubCard - show the weapon
	if club_name == "GrenadeLauncherClubCard" and weapon_handler:
		weapon_handler.show_grenade_launcher_weapon()
	else:
		# Hide weapon if switching to a different club
		if weapon_handler:
			weapon_handler.hide_weapon()
	
	# Find the selected club card
	var selected_card = null
	for card in deck_manager.hand:
		if card.name == club_name:
			selected_card = card
			break
	
	# Discard the selected club card
	if selected_card:
		deck_manager.discard(selected_card)
		print("Discarded selected club card:", club_name, "to club discard pile")
	
	# Check if this was the BagCheck temporary club and clear the effect
	if game_state_manager.is_bag_check_active() and club_name == game_state_manager.get_temporary_club().name:
		print("BagCheck temporary club used - clearing effect")
		clear_temporary_club()
	
	# Discard all remaining club cards from hand to club discard pile
	var remaining_club_cards: Array[CardData] = []
	for card in deck_manager.hand:
		if deck_manager.is_club_card(card):
			remaining_club_cards.append(card)
	
	print("DeckManager: Found", remaining_club_cards.size(), "remaining club cards to discard")
	for card in remaining_club_cards:
		deck_manager.discard(card)
		print("Discarded remaining club card:", card.name, "to club discard pile")
	
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	enter_aiming_phase()

func set_temporary_club(club_data: CardData):
	"""Set a temporary club from BagCheck card effect"""
	print("Course: Setting temporary club:", club_data.name)
	game_state_manager.set_temporary_club(club_data)

func clear_temporary_club():
	"""Clear the temporary club after use"""
	print("Course: Clearing temporary club")
	game_state_manager.clear_temporary_club()



# Player movement handling moved to PlayerManager

# Check and show gimme button function moved to UIManager

# UI functions moved to UIManager - direct calls to ui_manager used instead

# show_shop_entrance_dialog function removed - shop is now overlay system

func _on_shop_enter_yes():
	"""Handle shop enter yes button"""
	ui_manager._on_shop_enter_yes()

func show_shop_overlay():
	"""Show shop overlay"""
	ui_manager.show_shop_overlay()

func get_camera_offset() -> Vector2:
	"""Get the camera offset for positioning world objects"""
	return grid_manager.get_camera_offset()

func get_grid_manager() -> GridManager:
	"""Get the grid manager for external access"""
	return grid_manager

func on_etherdash_complete():
	"""Handle EtherDash completion - ensure card is discarded"""
	print("Course: EtherDash complete - handling card discard")
	# Force the movement controller to exit movement mode and discard the card
	if movement_controller and movement_controller.is_in_movement_mode():
		movement_controller.exit_movement_mode()
		print("Course: EtherDash card discarded via movement controller")

func _on_shop_overlay_return():
	"""Handle returning from shop overlay"""
	ui_manager._on_shop_overlay_return()

func is_mid_game_shop_mode() -> bool:
	"""Check if we're currently in mid-game shop mode"""
	# Check if we're in mid-game shop mode using the global flag
	return Global.in_mid_game_shop_mode

func show_mid_game_shop_overlay():
	"""Show the mid-game shop as an overlay"""
	ui_manager.show_mid_game_shop_overlay()

func enter_shop():
	"""Enter the shop from the mid-game shop overlay"""
	print("=== ENTERING SHOP FROM MID-GAME SHOP ===")
	
	# Set a flag to indicate we're in mid-game shop mode
	Global.in_mid_game_shop_mode = true
	
	# Show the shop overlay
	show_shop_overlay()
	
	print("=== ENTERED SHOP FROM MID-GAME SHOP ===")

func continue_to_hole_10():
	"""Continue the game by loading hole 10"""
	print("=== CONTINUING TO HOLE 10 ===")
	
	# Reset the mid-game shop mode flag
	Global.in_mid_game_shop_mode = false
	
	# Clear any reward dialog that might be present
	var existing_reward_dialog = $UILayer.get_node_or_null("RewardSelectionDialog")
	if existing_reward_dialog:
		existing_reward_dialog.queue_free()
	
	# Clear any suitcase that might be present
	var existing_suitcase = $UILayer.get_node_or_null("SuitCase")
	if existing_suitcase:
		existing_suitcase.queue_free()
	
	var existing_map_suitcase_overlay = $UILayer.get_node_or_null("MapSuitCaseOverlay")
	if existing_map_suitcase_overlay:
		existing_map_suitcase_overlay.queue_free()
	
	var existing_suitcase_reward_dialog = $UILayer.get_node_or_null("SuitCaseRewardDialog")
	if existing_suitcase_reward_dialog:
		existing_suitcase_reward_dialog.queue_free()
	
	# Unpause the game
	get_tree().paused = false
	
	# Set back 9 mode and start at hole 10
	game_state_manager.is_back_9_mode = true
	game_state_manager.set_current_hole(game_state_manager.back_9_start_hole)  # Start at hole 10 (index 9)
	
	# Fade to black and load hole 10
	FadeManager.fade_to_black(func(): load_hole_10(), 0.5)

func load_hole_10():
	"""Load hole 10 and continue the game"""
	print("=== LOADING HOLE 10 ===")
	
	# Reset launch manager state for new hole
	if launch_manager and launch_manager.has_method("set_ball_in_flight"):
		launch_manager.set_ball_in_flight(false)
	
	# Clear any existing balls from the previous hole
	launch_manager.remove_all_balls()
	
	# Load hole 10 layout
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(game_state_manager.get_current_hole_index()))
	build_map.build_map_from_layout_with_randomization(map_manager.level_layout, game_state_manager.get_current_hole_index())
	
	# Sync shop grid position with build_map
	game_state_manager.set_shop_grid_position(build_map.shop_grid_pos)
	
	# Sync SuitCase grid position with build_map
	game_state_manager.set_suitcase_grid_position(build_map.get_suitcase_position())
	if game_state_manager.get_suitcase_grid_position() != Vector2i.ZERO:
		print("SuitCase placed at grid position:", game_state_manager.get_suitcase_grid_position())
	
	# Ensure Y-sort objects are properly registered for pin detection
	update_all_ysort_z_indices()
	
	position_camera_on_pin()  # Add camera positioning for hole 10
	game_state_manager.reset_hole_score()
	game_state_manager.set_game_phase("tee_select")
	player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
	game_state_manager.set_chosen_landing_spot(Vector2.ZERO)
	game_state_manager.set_selected_club("")
	update_hole_and_score_display()
	if hud:
		hud.get_node("ShotLabel").text = "Shots: %d" % game_state_manager.get_hole_score()
	game_state_manager.set_is_placing_player(true)
	map_manager.highlight_tee_tiles()
	show_tee_selection_instruction()
	
	# After all NPCs are spawned/registered for the new hole
	var entities = get_node_or_null("Entities")
	if entities:
		entities.re_register_all_npcs()
	
	print("=== HOLE 10 LOADED AND READY ===")

func _on_shop_enter_no():
	"""Handle shop enter no button"""
	ui_manager._on_shop_enter_no()



# _on_shop_under_construction_input function removed - shop is now overlay system


		
# restore_game_state function removed - shop is now overlay system

func is_player_on_shop_tile() -> bool:
	return player_manager.get_player_grid_pos() == game_state_manager.get_shop_grid_position()





var ghost_ball: Node2D = null
var ghost_ball_active: bool = false

# Ghost mode variables
var ghost_mode_active: bool = false
var ghost_mode_tween: Tween

# Vampire mode variables
var vampire_mode_active: bool = false
var vampire_mode_tween: Tween

# Dodge mode variables
var dodge_mode_active: bool = false
var dodge_mode_tween: Tween

# Create ghost ball function moved to LaunchManager

# Activate ghost mode function moved to PlayerManager

# Deactivate ghost mode function moved to PlayerManager

# Is ghost mode active function moved to PlayerManager

# Activate vampire mode function moved to PlayerManager

# Deactivate vampire mode function moved to PlayerManager

# Is vampire mode active function moved to PlayerManager

# Activate dodge mode function moved to PlayerManager

# Removed switch_to_dodge_ready_sprite() - no longer needed with hue effect approach

# Dodge animation functions moved to PlayerManager

# Update ghost ball function moved to LaunchManager

# Remove ghost ball function moved to LaunchManager



var total_score := 0
var is_in_pin_transition := false



func find_pin_position() -> Vector2:
	"""Find the position of the pin in the current hole"""
	
	# First try to find by name in ysort_objects
	for obj in ysort_objects:
		if obj.has("node") and obj.node and is_instance_valid(obj.node):
			# Check if this is the pin by name or by checking if it has the pin script
			var is_pin = false
			if obj.node.name == "Pin" or obj.node.name.begins_with("Pin") or "Pin" in obj.node.name:
				is_pin = true
			elif obj.node.has_method("_on_area_entered"):
				# Check if this object has pin-related methods or signals
				if obj.node.has_signal("hole_in_one") or obj.node.has_signal("pin_flag_hit"):
					is_pin = true
				elif obj.node.get_script() and "Pin" in str(obj.node.get_script()):
					is_pin = true
			
			if is_pin:
				# Use manually calculated global position as fallback
				var calculated_global = obstacle_layer.global_position + obj.node.position
				return calculated_global
	
	# If not found in ysort_objects, search in obstacle_layer
	
	# Search for any object with "Pin" in the name or pin script
	for child in obstacle_layer.get_children():
		var is_pin = false
		if "Pin" in child.name or child.name.begins_with("Pin"):
			is_pin = true
		elif child.has_method("_on_area_entered"):
			# Check if this object has pin-related methods or signals
			if child.has_signal("hole_in_one") or child.has_signal("pin_flag_hit"):
				is_pin = true
			elif child.get_script() and "Pin" in str(child.get_script()):
				is_pin = true
		
		if is_pin:
			return child.global_position
	
	# Search recursively in all children of obstacle_layer
	for child in obstacle_layer.get_children():
		if child.has_method("get_children"):
			for grandchild in child.get_children():
				var is_pin = false
				if "Pin" in grandchild.name or grandchild.name.begins_with("Pin"):
					is_pin = true
				elif grandchild.has_method("_on_area_entered"):
					# Check if this object has pin-related methods or signals
					if grandchild.has_signal("hole_in_one") or grandchild.has_signal("pin_flag_hit"):
						is_pin = true
					elif grandchild.get_script() and "Pin" in str(grandchild.get_script()):
						is_pin = true
				
				if is_pin:
					return grandchild.global_position
	
	# Search in the entire scene tree
	var pin_node = find_child_by_name_recursive(self, "Pin")
	if pin_node:
		return pin_node.global_position
	
	return Vector2.ZERO

func find_child_by_name_recursive(node: Node, name: String) -> Node:
	"""Recursively search for a child node by name"""
	if node.name == name:
		return node
	
	for child in node.get_children():
		var result = find_child_by_name_recursive(child, name)
		if result:
			return result
	
	return null



func position_camera_on_pin(start_transition: bool = true):
	"""Position camera on pin immediately after map building"""
	
	# Update game state for smart optimizer
	if smart_optimizer:
		smart_optimizer.update_game_state("tee_select", false, false, false)
	
	# Add a small delay to ensure everything is properly added to the scene
	await get_tree().process_frame
	
	# Find pin position
	var pin_position = find_pin_position()
	if pin_position == Vector2.ZERO:
		camera.position = Vector2(0, 0)
		return
	
	# Use camera manager to position camera on pin
	var get_tee_center_func = Callable(self, "_get_tee_area_center")
	camera_manager.position_camera_on_pin(pin_position, start_transition, get_tee_center_func)

# start_pin_to_tee_transition function moved to CameraManager

# build_map_from_layout_with_saved_positions function removed - shop is now overlay system

func update_all_ysort_z_indices():
	"""Update z_index for all objects using the simple global Y-sort system"""
	# Use the global Y-sort system for all objects
	Global.update_all_objects_y_sort(ysort_objects)
	# Also update dynamically created objects in groups (explosions, etc.)
	Global.update_all_group_objects_y_sort()

func get_layout_at_position(pos: Vector2i) -> String:
	"""Get the tile type at a specific grid position"""
	if pos.y >= 0 and pos.y < map_manager.level_layout.size():
		if pos.x >= 0 and pos.x < map_manager.level_layout[pos.y].size():
			return map_manager.level_layout[pos.y][pos.x]
	return ""

func _on_hole_in_one(score: int):
	"""Handle hole completion when ball goes in the hole"""
	# Reset ball in flight state in launch manager
	if launch_manager and launch_manager.has_method("set_ball_in_flight"):
		launch_manager.set_ball_in_flight(false)
		print("Ball in flight state reset to false (hole completion)")
	
	ui_manager.show_hole_completion_dialog()

func _on_gimme_triggered(ball: Node2D):
	"""Handle gimme detection when ball enters gimme area"""
	# Early return if game_state_manager is not initialized yet
	if not game_state_manager:
		return
		
	print("=== GIMME DETECTED FROM PIN AREA ===")
	print("Ball entered gimme area:", ball.name)
	
	# Store the gimme ball reference for later use
	# The gimme button will be shown when the player reaches the ball
	game_state_manager.activate_gimme(ball)

func _on_gimme_ball_exited(ball: Node2D):
	"""Handle when ball exits gimme area"""
	# Early return if game_state_manager is not initialized yet
	if not game_state_manager:
		return
		
	print("=== GIMME BALL EXITED ===")
	print("Ball exited gimme area:", ball.name)
	print("Current gimme_ball:", game_state_manager.get_gimme_ball().name if game_state_manager.get_gimme_ball() else "null")
	print("Current launch_manager.golf_ball:", launch_manager.golf_ball.name if launch_manager.golf_ball else "null")
	
	# Clear the gimme ball reference when the ball exits the gimme area
	# This ensures that if the ball flies over the gimme area and lands elsewhere, 
	# the gimme option is not available
	if game_state_manager.get_gimme_ball() == ball:
		game_state_manager.deactivate_gimme()
		print("Cleared gimme ball reference - ball exited gimme area")
		# Hide the gimme button if it's currently visible
		ui_manager.hide_gimme_button()
	else:
		print("Ball that exited was not the tracked gimme ball - ignoring")

func find_pin_in_scene() -> Node2D:
	"""Find the pin in the scene for gimme tracking"""
	var pins = get_tree().get_nodes_in_group("pins")
	if pins.size() > 0:
		return pins[0]  # Return the first pin found
	return null

func _on_pin_flag_hit(ball: Node2D):
	"""Handle pin flag hit - ball velocity has already been reduced by the pin"""
	pass

var force_stickyshot_bonus := false

func show_inventory_choice(card: CardData):
	print("Attempting to show inventory choice dialog for card:", card.name)
	var parent = $UILayer if has_node("UILayer") else self
	var existing = parent.get_node_or_null("InventoryChoiceDialog")
	if existing:
		existing.queue_free()

	var dialog = AcceptDialog.new()
	dialog.name = "InventoryChoiceDialog"
	dialog.dialog_text = "Where would you like to put this card?"
	dialog.add_button("Add to Club Pile", true, "club")
	dialog.add_button("Add to Movement Pile", true, "move")
	dialog.connect("custom_action", Callable(self, "_on_inventory_choice"))
	parent.add_child(dialog)
	dialog.popup_centered()

func _on_inventory_choice(action: String):
	if pending_inventory_card == null:
		return
	if action == "club":
		club_inventory.append(pending_inventory_card)
		print("Added", pending_inventory_card.name, "to club inventory. Total:", club_inventory.size())
	elif action == "move":
		movement_inventory.append(pending_inventory_card)
		print("Added", pending_inventory_card.name, "to movement inventory. Total:", movement_inventory.size())
	pending_inventory_card = null
	# Remove dialog
	var dialog = $UILayer.get_node_or_null("InventoryChoiceDialog")
	if dialog:
		dialog.queue_free()

func setup_bag_and_inventory() -> void:
	# The bag now handles its own inventory display
	# No need to connect to the old inventory dialog
	
	if bag and bag.has_method("set_bag_level"):
		bag.set_bag_level(2)  # Start with level 2 for testing
		print("Bag initialized with level 2")
		print("Bag z_index:", bag.z_index, "position:", bag.position, "size:", bag.size)
		print("Bag global_position:", bag.global_position)
	else:
		print("ERROR: Bag not found or missing set_bag_level method")

func _on_bag_clicked() -> void:
	# The bag handles its own click events now
	pass

func _on_inventory_closed() -> void:
	print("Inventory closed")

func get_movement_cards_for_inventory() -> Array[CardData]:
	return movement_controller.get_movement_cards_for_inventory()

func get_club_cards_for_inventory() -> Array[CardData]:
	return deck_manager.club_draw_pile.duplicate()

func get_movement_controller() -> Node:
	"""Get the movement controller for external access"""
	return movement_controller


	

func fix_ui_layers() -> void:
	"""Fix UI layer z-indices and mouse filtering"""
	if card_hand_anchor:
		card_hand_anchor.z_index = 245  # Keep original z_index from scene file
		card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through to prevent blocking tile clicks
		
		# Ensure CardRow has lower z-index than DrawCardsButton
		var card_row = card_hand_anchor.get_node_or_null("CardRow")
		if card_row:
			card_row.z_index = 200  # Lower than DrawCardsButton (300)
	
	if hud:
		hud.z_index = 101
		hud.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if end_turn_button:
		end_turn_button.z_index = 102
		end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP

# Add this variable declaration after the existing card modification variables (around line 75)
var card_effect_handler: Node = null
var weapon_handler: Node = null
# Global death sound moved to SoundManager

# Add this function at the end of the file, before the final closing brace
func _on_scramble_complete(closest_ball_position: Vector2, closest_ball_tile: Vector2i):
	"""Handle completion of Florida Scramble effect"""
	# Early return if game_state_manager is not initialized yet
	if not game_state_manager:
		return
		
	# Check if the ball went in the hole (if waiting_for_player_to_reach_ball is false, it went in the hole)
	if not game_state_manager.get_waiting_for_player_to_reach_ball():
		print("Scramble ball went in the hole! Triggering hole completion")
		# Trigger hole completion dialog
		ui_manager.show_hole_completion_dialog()
		return
	
	# Update course state for normal scramble completion
	game_state_manager.set_ball_landing_position(closest_ball_tile, closest_ball_position)
	game_state_manager.set_waiting_for_player_to_reach_ball(true)
	
	# Check if player is already on the landing tile
	if player_manager.get_player_grid_pos() == game_state_manager.get_ball_landing_tile():
		print("Player is already on the scramble ball landing tile - checking for gimme and showing buttons")
		# Player is already on the ball tile - remove landing highlight
		if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
			launch_manager.golf_ball.remove_landing_highlight()
		
		# Check if this ball is in gimme range
		ui_manager.check_and_show_gimme_button()
		
		# Show the "Draw Club Cards" button instead of waiting for movement
		ui_manager.show_draw_club_cards_button()
	else:
		# Player needs to move to the ball - show drive distance dialog
		# Note: golf_ball is already set to the closest scramble ball in CardEffectHandler
		# Show drive distance dialog for the scramble result (same as normal shots)
		var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_manager.get_player_node().global_position + player_size / 2
		var drive_distance = player_center.distance_to(closest_ball_position)
		
		var dialog_timer = get_tree().create_timer(0.5)
		dialog_timer.timeout.connect(func():
			ui_manager.show_drive_distance_dialog(game_state_manager.get_drive_distance())
		)
		
		game_state_manager.set_game_phase("move")
		player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)

# LaunchManager signal handlers
func _on_ball_launched(ball: Node2D):
	# Early return if game_state_manager is not initialized yet
	if not game_state_manager:
		return
		
	# Clear any existing gimme state when a new ball is launched
	ui_manager.clear_gimme_state()
	
	# Set up ball properties that require course_1.gd references
	ball.map_manager = map_manager
	
	# Check if this is a throwing knife, grenade, spear, shuriken, or golf ball
	var is_knife = ball.has_method("is_throwing_knife") and ball.is_throwing_knife()
	var is_grenade = ball.has_method("is_grenade_weapon") and ball.is_grenade_weapon()
	var is_spear = ball.has_method("is_spear_weapon") and ball.is_spear_weapon()
	var is_shuriken = ball.has_method("is_shuriken_weapon") and ball.is_shuriken_weapon()
	
	if is_knife:
		# Handle throwing knife
		print("=== HANDLING THROWING KNIFE LAUNCH ===")
		
		# Play knife whoosh sound when launched
		var knife_whoosh = ball.get_node_or_null("ThrowKnifeWhoosh")
		if knife_whoosh:
			knife_whoosh.play()
			print("Playing knife whoosh sound")
		else:
			print("Warning: ThrowKnifeWhoosh sound not found on knife")
		
		# Connect knife signals
		ball.landed.connect(_on_knife_landed)
		ball.knife_hit_target.connect(_on_knife_hit_target)
		
		# Set camera following
		game_state_manager.set_camera_following_ball(true)
		
	elif is_grenade:
		# Handle grenade
		print("=== HANDLING GRENADE LAUNCH ===")
		
		# Check if using GrenadeLauncherWeaponCard - play launcher sound instead of whoosh sound
		# Note: Launcher sound is already played in WeaponHandler.launch_grenade_launcher()
		# so we don't need to play it again here
		if game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			print("GrenadeLauncherClubCard detected - launcher sound already played in WeaponHandler")
		else:
			# Play grenade whoosh sound when launched
			var grenade_whoosh = ball.get_node_or_null("GrenadeWhoosh")
			if grenade_whoosh:
				grenade_whoosh.play()
				print("Playing grenade whoosh sound")
			else:
				print("Warning: GrenadeWhoosh sound not found on grenade")
		
		# Connect grenade signals
		ball.landed.connect(_on_grenade_landed)
		ball.out_of_bounds.connect(_on_grenade_out_of_bounds)
		ball.sand_landing.connect(_on_grenade_sand_landing)
		ball.grenade_exploded.connect(_on_grenade_exploded)
		
		# Set camera following
		game_state_manager.set_camera_following_ball(true)
		print("Camera following set to true for grenade")
		
	elif is_spear:
		# Handle spear
		print("=== HANDLING SPEAR LAUNCH ===")
		
		# Play spear whoosh sound when launched
		var spear_whoosh = ball.get_node_or_null("SpearWhoosh")
		if spear_whoosh:
			spear_whoosh.play()
			print("Playing spear whoosh sound")
		else:
			print("Warning: SpearWhoosh sound not found on spear")
		
		# Connect spear signals
		ball.landed.connect(_on_spear_landed)
		ball.spear_hit_target.connect(_on_spear_hit_target)
		
		# Set camera following
		game_state_manager.set_camera_following_ball(true)
		print("Camera following set to true for spear")
		
	elif is_shuriken:
		# Handle shuriken
		print("=== HANDLING SHURIKEN LAUNCH ===")
		print("Shuriken detected - connecting to shuriken signal handlers")
		
		# Play shuriken throw sound when launched
		var throw_sound = ball.get_node_or_null("Throw")
		if throw_sound:
			throw_sound.play()
			print("Playing shuriken throw sound")
		else:
			print("Warning: Throw sound not found on shuriken")
		
		# Connect shuriken signals
		ball.landed.connect(_on_shuriken_landed)
		ball.shuriken_hit_target.connect(_on_shuriken_hit_target)
		ball.out_of_bounds.connect(_on_shuriken_out_of_bounds)
		
		# Set camera following
		game_state_manager.set_camera_following_ball(true)
		print("Camera following set to true for shuriken")
		
	else:
		# Handle golf ball
		print("=== HANDLING GOLF BALL LAUNCH ===")
		
		# Check if using GrenadeLauncherClubCard - play launcher sound instead of swing sound
		# Note: Launcher sound is already played in WeaponHandler.launch_grenade_launcher()
		# so we don't need to play it again here
		if game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			print("GrenadeLauncherClubCard detected - launcher sound already played in WeaponHandler")
		else:
			# Play normal swing sound for other clubs
			sound_manager.play_swing_sound(ball.get_final_power() if ball.has_method("get_final_power") else 0.0)
		
		# Set ball launch position for player collision delay system
		if player_manager.get_player_node() and player_manager.get_player_node().has_method("set_ball_launch_position"):
			player_manager.get_player_node().set_ball_launch_position(ball.global_position)
			print("Ball launch position set for player collision delay:", ball.global_position)
		
		# Connect ball signals
		ball.landed.connect(_on_golf_ball_landed)
		ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)
		ball.sand_landing.connect(_on_golf_ball_sand_landing)
		
		# Set camera following
		game_state_manager.set_camera_following_ball(true)
		print("Camera following set to true for golf ball")
		
		# Handle card effects
		if sticky_shot_active and next_shot_modifier == "sticky_shot":
			ball.sticky_shot_active = true
			sticky_shot_active = false
			next_shot_modifier = ""
		
		if bouncey_shot_active and next_shot_modifier == "bouncey_shot":
			ball.bouncey_shot_active = true
			bouncey_shot_active = false
			next_shot_modifier = ""
		
		if fire_ball_active and next_shot_modifier == "fire_ball":
			# Load the Fire element data and apply it to the ball
			var fire_element = preload("res://Elements/Fire.tres")
			ball.set_element(fire_element)
			fire_ball_active = false
			next_shot_modifier = ""
		
		if ice_ball_active and next_shot_modifier == "ice_ball":
			# Load the Ice element data and apply it to the ball
			var ice_element = preload("res://Elements/Ice.tres")
			ball.set_element(ice_element)
			ice_ball_active = false
			next_shot_modifier = ""
		
		if explosive_shot_active and next_shot_modifier == "explosive_shot":
			# Apply explosive effect to the ball
			ball.explosive_shot_active = true
			explosive_shot_active = false
			next_shot_modifier = ""
		
		# Handle elemental club effects
		if game_state_manager.get_selected_club() == "Fire Club":
			# Apply Fire element to the ball
			var fire_element = preload("res://Elements/Fire.tres")
			ball.set_element(fire_element)
			print("Fire Club selected - applying Fire element to ball")
			
			# Play flame sound effect
			var flame_sound = ball.get_node_or_null("FlameOn")
			if flame_sound:
				flame_sound.play()
				print("Playing Fire Club flame sound effect")
			
			# Fire Club special effect: Reduced friction on grass/rough tiles
			ball.fire_club_active = true
			print("Fire Club special effect: Reduced friction on grass/rough tiles")
		
		elif game_state_manager.get_selected_club() == "Ice Club":
			# Apply Ice element to the ball
			var ice_element = preload("res://Elements/Ice.tres")
			ball.set_element(ice_element)
			print("Ice Club selected - applying Ice element to ball")
			
			# Play ice sound effect
			var ice_sound = ball.get_node_or_null("IceOn")
			if ice_sound:
				ice_sound.play()
				print("Playing Ice Club ice sound effect")
			
			# Ice Club special effect: Can pass through water tiles
			ball.ice_club_active = true
			print("Ice Club special effect: Can pass through water tiles")

func _on_launch_phase_entered():
	game_state_manager.set_game_phase("launch")
	player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)

func _on_launch_phase_exited():
	# Hide weapon when launch phase ends, but keep grenade launcher visible until grenade lands
	if weapon_handler:
		# Check if we're using a grenade launcher - don't hide it yet
		var is_grenade_launcher = false
		if game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			is_grenade_launcher = true
		
		if not is_grenade_launcher:
			weapon_handler.hide_weapon()

	# Check if we're in grenade mode and the grenade has already exploded
	if launch_manager and launch_manager.is_grenade_mode:
		# If grenade mode is still active, the grenade hasn't exploded yet
		# So we should enter ball_flying phase
		print("Course: Entering ball_flying phase!")
		game_state_manager.set_game_phase("ball_flying")
		player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)
		# Disable player collision shape during ball flight
		if player_manager.get_player_node() and player_manager.get_player_node().has_method("disable_collision_shape"):
			player_manager.get_player_node().disable_collision_shape()
		
		# Update smart optimizer for ball flying phase
		if smart_optimizer:
			smart_optimizer.update_game_state("ball_flying", true, false, false)
	else:
		# Not in grenade mode, or grenade has already exploded
		# Don't change the game phase - let the explosion handler manage it
		print("Course: Launch phase exited but not entering ball_flying (grenade may have exploded)")
		player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)

func _on_charging_state_changed(charging: bool, charging_height: bool) -> void:
	"""Handle charging state changes from LaunchManager"""
	# Force update the player state to include is_selecting_height
	player_manager.update_player_mouse_facing_state(game_state_manager, launch_manager, camera, weapon_handler)

func _on_ball_collision_detected() -> void:
	"""Handle ball collision detection - re-enable player collision shape"""
	if player_manager.get_player_node() and player_manager.get_player_node().has_method("enable_collision_shape"):
		player_manager.get_player_node().enable_collision_shape()

func _on_npc_attacked(npc: Node, damage: int) -> void:
	"""Handle when an NPC is attacked"""
	if npc:
		print("NPC attacked:", npc.name, "Damage dealt:", damage)
	else:
		print("NPC attacked: No NPC found, Damage dealt:", damage)

func _on_kick_attack_performed() -> void:
	"""Handle when a kick attack is performed - trigger kick animation"""
	if player_manager.get_player_node() and player_manager.get_player_node().has_method("start_kick_animation"):
		player_manager.get_player_node().start_kick_animation()

func _on_punchb_attack_performed() -> void:
	"""Handle when a PunchB attack is performed - trigger punch animation"""
	if player_manager.get_player_node() and player_manager.get_player_node().has_method("start_punchb_animation"):
		player_manager.get_player_node().start_punchb_animation()

func _on_npc_shot(npc: Node, damage: int) -> void:
	"""Handle when an NPC is shot with a weapon"""
	if npc:
		print("NPC shot:", npc.name, "Damage dealt:", damage)
		
		# Play global death sound if NPC died
		if npc.has_method("get_is_dead") and npc.get_is_dead():
				sound_manager.play_global_death_sound()
				print("Playing global death sound")
	else:
		print("NPC shot: No NPC found, Damage dealt:", damage)

func _on_knife_landed(final_tile: Vector2i) -> void:
	"""Handle when a throwing knife lands"""
	print("Knife landed at tile:", final_tile)
	
	# Update smart optimizer state immediately when knife lands
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Pause for 1 second to let player see where knife landed
	var pause_timer = get_tree().create_timer(1.0)
	pause_timer.timeout.connect(func():
		# After pause, tween camera back to player
		if player_manager.get_player_node() and camera:
			camera_manager.create_camera_tween(player_manager.get_player_node().global_position, 0.5, Tween.TRANS_LINEAR)
			var tween = camera_manager.get_current_camera_tween()
			if tween:
				tween.tween_callback(func():
					# Exit knife mode and reset camera following after tween completes
					if launch_manager:
						launch_manager.exit_knife_mode()
						print("Exited knife mode after camera tween completed")
					game_state_manager.set_camera_following_ball(false)
				)
		else:
			# Fallback if no player or camera
			if launch_manager:
				launch_manager.exit_knife_mode()
				print("Exited knife mode (fallback)")
			game_state_manager.set_camera_following_ball(false)
	)

func _on_knife_hit_target(target: Node2D) -> void:
	"""Handle when a throwing knife hits a target"""
	print("Knife hit target:", target.name)
	
	# Play knife impact sound
	var knife = target.get_parent() if target.get_parent() else target
	if knife and knife.has_method("is_throwing_knife") and knife.is_throwing_knife():
		var knife_impact = knife.get_node_or_null("KnifeImpact")
		if knife_impact:
			knife_impact.play()
			print("Playing knife impact sound")

func _on_spear_landed(final_tile: Vector2i) -> void:
	"""Handle when a spear lands"""
	print("Spear landed at tile:", final_tile)
	
	# Update smart optimizer state immediately when spear lands
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Pause for 1 second to let player see where spear landed
	var pause_timer = get_tree().create_timer(1.0)
	pause_timer.timeout.connect(func():
		# After pause, tween camera back to player
		if player_manager.get_player_node() and camera:
			camera_manager.create_camera_tween(player_manager.get_player_node().global_position, 0.5, Tween.TRANS_LINEAR)
			var tween = camera_manager.get_current_camera_tween()
			if tween:
				tween.tween_callback(func():
					# Exit spear mode and reset camera following after tween completes
					if launch_manager:
						launch_manager.exit_spear_mode()
						print("Exited spear mode after camera tween completed")
					game_state_manager.set_camera_following_ball(false)
				)
		else:
			# Fallback if no player or camera
			if launch_manager:
				launch_manager.exit_spear_mode()
				print("Exited spear mode (fallback)")
			game_state_manager.set_camera_following_ball(false)
	)

func _on_spear_hit_target(target: Node2D) -> void:
	"""Handle when a spear hits a target"""
	print("Spear hit target:", target.name)
	
	# Play spear impact sound
	var spear = target.get_parent() if target.get_parent() else target
	if spear and spear.has_method("is_spear_weapon") and spear.is_spear_weapon():
		var spear_impact = spear.get_node_or_null("KnifeImpact")
		if spear_impact:
			spear_impact.play()
			print("Playing spear impact sound")

func _on_shuriken_landed(final_tile: Vector2i) -> void:
	"""Handle when a shuriken lands"""
	print("Shuriken landed at tile:", final_tile)
	
	# Clean up weapon mode immediately when shuriken lands
	if weapon_handler and weapon_handler.is_in_weapon_mode():
		weapon_handler.exit_weapon_mode()
		print("Exited weapon mode after shuriken landing")
	
	# Set game phase to move immediately to allow movement cards
	game_state_manager.set_game_phase("move")
	print("Set game phase to 'move' after shuriken landing")
	
	# Update smart optimizer state immediately when shuriken lands
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Keep camera focused on player (don't follow shuriken)
	game_state_manager.set_camera_following_ball(false)
	
	# Exit shuriken mode immediately
	if launch_manager:
		launch_manager.exit_shuriken_mode()
		print("Exited shuriken mode after shuriken landing")

func _on_shuriken_hit_target(target: Node2D) -> void:
	"""Handle when a shuriken hits a target"""
	print("Shuriken hit target:", target.name)
	
	# Clean up weapon mode immediately when shuriken hits target
	if weapon_handler and weapon_handler.is_in_weapon_mode():
		weapon_handler.exit_weapon_mode()
		print("Exited weapon mode after shuriken hit target")
	
	# Set game phase to move immediately to allow movement cards
	game_state_manager.set_game_phase("move")
	print("Set game phase to 'move' after shuriken hit target")
	
	# Play shuriken impact sound
	var shuriken = target.get_parent() if target.get_parent() else target
	if shuriken and shuriken.has_method("is_shuriken") and shuriken.is_shuriken:
		var throw_sound = shuriken.get_node_or_null("Throw")
		if throw_sound:
			throw_sound.play()
			print("Playing shuriken impact sound")

func _on_shuriken_out_of_bounds() -> void:
	"""Handle when a shuriken goes out of bounds"""
	print("Shuriken went out of bounds")
	
	# Clean up weapon mode immediately when shuriken goes out of bounds
	if weapon_handler and weapon_handler.is_in_weapon_mode():
		weapon_handler.exit_weapon_mode()
		print("Exited weapon mode after shuriken out of bounds")
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Set game phase to move to allow movement cards
	game_state_manager.set_game_phase("move")
	
	# Set ball in flight to false to allow movement cards
	if launch_manager:
		launch_manager.set_ball_in_flight(false)
		print("Set ball_in_flight to false after shuriken out of bounds")
	
	# Exit shuriken mode immediately
	if launch_manager:
		launch_manager.exit_shuriken_mode()
		print("Exited shuriken mode after out of bounds")
	
	# Reset camera following
	game_state_manager.set_camera_following_ball(false)

# Global death sound setup moved to SoundManager

# Player mouse facing state update moved to PlayerManager




# Camera tween management (moved to CameraManager)
# var current_camera_tween: Tween = null

func kill_current_camera_tween() -> void:
	"""Kill any currently running camera tween to prevent conflicts"""
	camera_manager.kill_current_camera_tween()

func get_camera_container() -> Control:
	"""Get the camera container for world-to-grid conversions"""
	return camera_manager.get_camera_container()

func get_launch_manager() -> LaunchManager:
	"""Get the launch manager reference"""
	return launch_manager

func create_camera_tween(target_position: Vector2, duration: float = 0.5, transition: Tween.TransitionType = Tween.TRANS_SINE, ease: Tween.EaseType = Tween.EASE_OUT) -> void:
	"""Create a camera tween with proper management to prevent conflicts"""
	camera_manager.create_camera_tween(target_position, duration, transition, ease)
# Fire damage handling moved to PlayerManager

func _clear_existing_state():
	"""Clear any existing state to prevent dictionary conflicts when scene is reloaded"""
	print("=== CLEARING EXISTING STATE ===")
	
	# Clear obstacle map
	obstacle_map.clear()
	
	# Clear ysort objects
	ysort_objects.clear()
	
	# Clear placed objects
	placed_objects.clear()
	
	# Clear any existing objects in obstacle_layer (if it exists)
	if obstacle_layer and is_instance_valid(obstacle_layer):
		for child in obstacle_layer.get_children():
			if child and is_instance_valid(child):
				child.queue_free()
	
	# Clear any remaining balls or projectiles in the scene tree
	var scene_tree = get_tree()
	var balls = scene_tree.get_nodes_in_group("balls")
	for ball in balls:
		if ball and is_instance_valid(ball):
			ball.queue_free()
	
	var knives = scene_tree.get_nodes_in_group("knives")
	for knife in knives:
		if knife and is_instance_valid(knife):
			knife.queue_free()
	
	# Clear any remaining explosions or particles
	var explosions = scene_tree.get_nodes_in_group("explosions")
	for explosion in explosions:
		if explosion and is_instance_valid(explosion):
			explosion.queue_free()
	
	print("=== EXISTING STATE CLEARED ===")

func _on_grenade_exploded(explosion_position: Vector2) -> void:
	"""Handle when a grenade explodes"""
	print("Grenade exploded at position:", explosion_position)
	
	# Hide grenade launcher weapon now that grenade has exploded
	# Check if we have a grenade launcher weapon instance (either by club or by weapon type)
	var should_hide_weapon = false
	if weapon_handler and weapon_handler.weapon_instance:
		# Check if it's a grenade launcher by scene name
		var weapon_scene_name = weapon_handler.weapon_instance.scene_file_path
		if weapon_scene_name and "GrenadeLauncher" in weapon_scene_name:
			should_hide_weapon = true
		elif game_state_manager.get_selected_club() == "GrenadeLauncherClubCard":
			should_hide_weapon = true
		elif weapon_handler.selected_card and weapon_handler.selected_card.name == "GrenadeLauncherWeaponCard":
			should_hide_weapon = true
	
	if should_hide_weapon:
		weapon_handler.hide_weapon()
		
		# Ensure weapon mode is properly exited to fix cursor stuck on reticle
		if weapon_handler.is_weapon_mode:
			weapon_handler.is_weapon_mode = false
			weapon_handler.selected_card = null
			weapon_handler.active_button = null
			print("Exited weapon mode after grenade explosion")
	
	# Set explosion in progress flag to prevent launch phase exit
	if launch_manager:
		launch_manager.grenade_explosion_in_progress = true
	
	# Update smart optimizer state immediately when grenade explodes
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Only set game phase to move if it's not already set (to avoid overriding landing handler)
	if game_state_manager.get_game_phase() != "move":
		game_state_manager.set_game_phase("move")
		print("Game phase set to 'move' after grenade explosion")
	
	# Set ball in flight to false to allow movement cards
	if launch_manager:
		launch_manager.set_ball_in_flight(false)
		print("Set ball_in_flight to false after grenade explosion")
	
	# Exit grenade mode immediately after explosion
	if launch_manager:
		launch_manager.exit_grenade_mode()
		print("Exited grenade mode after explosion")
	
	# Reset explosion in progress flag
	if launch_manager:
		launch_manager.grenade_explosion_in_progress = false
	
	game_state_manager.set_camera_following_ball(false)



func get_course_bounds() -> Rect2i:
	"""Get the bounds of the course as a Rect2i"""
	# Return bounds based on grid_size and cell_size
	return Rect2i(Vector2i.ZERO, grid_manager.get_grid_size())

func is_position_walkable(pos: Vector2i) -> bool:
	"""Check if a grid position is walkable (not occupied by obstacles)"""
	# Check if position is within bounds
	if pos.x < 0 or pos.x >= grid_manager.get_grid_size().x or pos.y < 0 or pos.y >= grid_manager.get_grid_size().y:
		return false
	
	# Check if position is occupied by an obstacle
	if pos in obstacle_map:
		var obstacle = obstacle_map[pos]
		if obstacle and is_instance_valid(obstacle):
			# Check if the obstacle blocks movement
			if obstacle.has_method("is_walkable"):
				return obstacle.is_walkable()
			else:
				# Default: obstacles block movement
				return false
	
	# Position is walkable if no obstacle is present
	return true



func should_show_drive_distance_dialog(is_first_shot: bool = false) -> bool:
	"""Check if drive distance dialog should be shown (now shows on every shot)"""
	# Show drive distance dialog on every shot
	print("Showing drive distance dialog for this shot")
	return true

func show_draw_cards_button_for_turn_start() -> void:
	"""Show the DrawCardsButton at the start of a player turn instead of automatically drawing cards"""
	ui_manager.show_draw_cards_button_for_turn_start()

func show_pause_menu():
	"""Show pause menu"""
	ui_manager.show_pause_menu()

func _on_pause_end_round_pressed(pause_dialog: Control):
	"""Handle End Round button press from pause menu"""
	# Clear all player score and effects
	clear_player_state()
	
	# Clear current deck
	if deck_manager:
		deck_manager.hand.clear()
		deck_manager.discard_pile.clear()
		ui_manager.update_deck_display()
	
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

func clear_player_state():
	"""Clear all player score and effects"""
	# Clear round scores
	game_state_manager.get_round_scores().clear()
	game_state_manager.round_complete = false
	
	# Reset hole score
	game_state_manager.reset_hole_score()
	
	# Clear any active effects
	sticky_shot_active = false
	bouncey_shot_active = false
	fire_ball_active = false
	ice_ball_active = false
	explosive_shot_active = false
	next_shot_modifier = ""
	next_card_doubled = false
	rooboost_active = false
	next_movement_card_rooboost = false
	extra_turns_remaining = 0
	
	# Clear block system
	player_manager.clear_block()
	
	# Reset character health
	Global.reset_character_health()
	
	# Clear equipment effects
	Global.equipped_items.clear()
	Global.apply_equipment_buffs()
	
	# Reset currency
	Global.current_looty = 50
	
	# Clear any active game states
	game_state_manager.set_game_phase("move")
	
	# Clear any active weapon/attack modes
	if weapon_handler:
		weapon_handler.exit_weapon_mode()
	if attack_handler:
		attack_handler.exit_attack_mode()
	if movement_controller:
		movement_controller.clear_all_movement_ui()
	
	print("Player state cleared")
