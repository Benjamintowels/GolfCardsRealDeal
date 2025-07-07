extends Control

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
@onready var end_turn_button: Button = $UILayer/EndTurnButton
@onready var camera := $GameCamera
@onready var map_manager := $MapManager
@onready var build_map := $BuildMap
@onready var draw_cards_button: Button = $UILayer/DrawCards
@onready var mod_shot_room_button: Button
@onready var bag: Control = $UILayer/Bag
@onready var launch_manager = $LaunchManager
@onready var health_bar: HealthBar = $UILayer/HealthBar
@onready var damage_button: Button = $UILayer/HealthTestButtons/DamageButton
@onready var heal_button: Button = $UILayer/HealthTestButtons/HealButton
@onready var kill_gangmember_button: Button = $UILayer/KillGangMemberButton
@onready var bag_upgrade_test_button: Button = $UILayer/BagUpgradeTestButton

# Movement controller
const MovementController := preload("res://MovementController.gd")
var movement_controller: MovementController

# Attack handler
const AttackHandler := preload("res://AttackHandler.gd")
const WeaponHandler := preload("res://WeaponHandler.gd")
var attack_handler: AttackHandler
const GolfCourseLayout := preload("res://Maps/GolfCourseLayout.gd")
const HealthBar := preload("res://HealthBar.gd")
const EquipmentManager := preload("res://EquipmentManager.gd")

var is_placing_player := true

var obstacle_map: Dictionary = {}  # Vector2i -> BaseObstacle

var turn_count: int = 1
# Fire tile damage tracking
var fire_tiles_that_damaged_player: Array[Vector2i] = []  # Track which fire tiles have already damaged player this turn
var grid_size := Vector2i(50, 50)
var cell_size: int = 48 # This will be set by the main script
var grid_tiles = []
var grid_container: Control
var camera_container: Control

var player_node: Node2D
var player_grid_pos := Vector2i(25, 25)

# Club selection variables (separate from movement)
var movement_buttons := []

var is_panning := false
var pan_start_pos := Vector2.ZERO
var camera_offset := Vector2.ZERO
var camera_snap_back_pos := Vector2.ZERO

var flashlight_radius := 150.0
var mouse_world_pos := Vector2.ZERO
var player_flashlight_center := Vector2.ZERO
var tree_scene = preload("res://Obstacles/Tree.tscn")
var water_scene = preload("res://Obstacles/WaterHazard.tscn")

var deck_manager: DeckManager

# Inventory system for ModifyNext cards
var club_inventory: Array[CardData] = []
var movement_inventory: Array[CardData] = []
var pending_inventory_card: CardData = null

var player_stats = {} # Will be set after character selection

var CHARACTER_STATS = {
	1: { "name": "Layla", "base_mobility": 3 },
	2: { "name": "Benny", "base_mobility": 2 },
	3: { "name": "Clark", "base_mobility": 1 }
}

var game_phase := "tee_select" # Possible: tee_select, draw_cards, aiming, launch, ball_flying, move, etc.
var hole_score := 0

# StickyShot and card modification variables
var sticky_shot_active := false  # Track if StickyShot effect is active
var bouncey_shot_active := false  # Track if Bouncey effect is active
var fire_ball_active := false  # Track if FireBall effect is active
var ice_ball_active := false  # Track if IceBall effect is active
var next_shot_modifier := ""  # Track what modifier to apply to next shot
var next_card_doubled := false  # Track if the next card should have its effect doubled

# Multi-hole game loop variables
var round_scores := []  # Array to store scores for each hole
var round_complete := false  # Flag to track if front 9 is complete



# Camera following variables
var camera_following_ball := false
var drive_distance := 0.0
var drive_distance_dialog: Control = null

# Swing sound effects
var swing_strong_sound: AudioStreamPlayer2D
var swing_med_sound: AudioStreamPlayer2D
var swing_soft_sound: AudioStreamPlayer2D
var water_plunk_sound: AudioStreamPlayer2D
var sand_thunk_sound: AudioStreamPlayer2D
var trunk_thunk_sound: AudioStreamPlayer2D

# Multi-shot golf variables
var ball_landing_tile: Vector2i = Vector2i.ZERO
var ball_landing_position: Vector2 = Vector2.ZERO
var waiting_for_player_to_reach_ball := false
var shot_start_grid_pos: Vector2i = Vector2i.ZERO  # Store where the shot was taken from (grid position)

# Red circle aiming system variables
var aiming_circle: Control = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var max_shot_distance: float = 800.0  # Reduced from 2000.0 to something more on-screen
var is_aiming_phase: bool = false



# Club selection variables
var selected_club: String = ""
var club_max_distances = {
	"Driver": 1200.0,        # Longest distance
	"Hybrid": 1050.0,        # Slightly less than Driver
	"Wood": 800.0,           # Slightly more than Iron
	"Iron": 600.0,           # Medium distance
	"Wooden": 350.0,         # Slightly better than Putter
	"Putter": 200.0,         # Shortest distance (now rolling only)
	"PitchingWedge": 200.0   # Same as old Putter settings
}

# New club data with min distances and trailoff stats
var club_data = {
	"Driver": {
		"max_distance": 1200.0,
		"min_distance": 800.0,    # Smallest gap (400)
		"trailoff_forgiveness": 0.3  # Less forgiving (lower = more severe undercharge penalty)
	},
	"Hybrid": {
		"max_distance": 1050.0,
		"min_distance": 200.0,    # Biggest gap (850)
		"trailoff_forgiveness": 0.8  # Most forgiving (higher = less severe undercharge penalty)
	},
	"Wood": {
		"max_distance": 800.0,
		"min_distance": 300.0,    # Medium gap (500)
		"trailoff_forgiveness": 0.6  # Medium forgiving
	},
	"Iron": {
		"max_distance": 600.0,
		"min_distance": 250.0,    # Medium gap (350)
		"trailoff_forgiveness": 0.5  # Medium forgiving
	},
	"Wooden": {
		"max_distance": 350.0,
		"min_distance": 150.0,    # Small gap (200)
		"trailoff_forgiveness": 0.4  # Less forgiving
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
		"trailoff_forgiveness": 0.2  # Same as old Putter settings
	},
	"Fire Club": {
		"max_distance": 900.0,
		"min_distance": 400.0,    # Medium gap (500)
		"trailoff_forgiveness": 0.5  # Medium forgiving
	},
	"Ice Club": {
		"max_distance": 900.0,
		"min_distance": 400.0,    # Medium gap (500)
		"trailoff_forgiveness": 0.5  # Medium forgiving
	}
}

# Add these variables at the top (after var launch_power, etc.)
var charge_time := 0.0  # Time spent charging (in seconds)
var max_charge_time := 3.0  # Maximum time to fully charge (varies by distance)

# Add this variable to track objects and their grid positions
var ysort_objects := [] # Array of {node: Node2D, grid_pos: Vector2i}

# Shop interaction variables
var shop_dialog: Control = null

# Smart Performance Optimizer
var smart_optimizer: Node
var shop_entrance_detected := false
var shop_grid_pos := Vector2i(2, 4)  # Position of shop from map layout (moved left one tile, with blocked tiles around it)

var has_started := false

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
	"OIL": preload("res://Interactables/OilDrum.tscn"),
	"WALL": preload("res://Obstacles/StoneWall.tscn"),
}

var object_to_tile_mapping := {
	"T": "Base",
	"P": "G",
	"SHOP": "Base",
	"GANG": "G",
	"OIL": "Base",
	"WALL": "Base",
}

# Add these variables after the existing object_scene_map and object_to_tile_mapping
var random_seed_value: int = 0
var placed_objects: Array[Vector2i] = []  # Track placed objects for spacing rules

# Add these functions before build_map_from_layout_with_randomization
func clear_existing_objects() -> void:
	"""Clear all existing objects (trees, shop, etc.) from the map"""
	print("Clearing existing objects...")
	
	var objects_removed = 0
	
	# Remove ALL objects from obstacle_layer (complete cleanup)
	for child in obstacle_layer.get_children():
		var child_name = child.name  # Store before freeing
		# print("Clearing object:", child_name, "Type:", child.get_class())
		child.queue_free()
		objects_removed += 1
	
	print("Removed", objects_removed, "objects from obstacle_layer")
	
	# Debug: Show what objects remain in obstacle_layer
	# print("Remaining objects in obstacle_layer after clearing:")
	# for child in obstacle_layer.get_children():
	#     print("  -", child.name, "Type:", child.get_class())
	
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
			
			if is_tree or is_shop or is_pin or is_oil_drum or is_stone_wall:
				keys_to_remove.append(pos)
	
	for pos in keys_to_remove:
		obstacle_map.erase(pos)
	
	print("Removed", keys_to_remove.size(), "object entries from obstacle_map")
	
	# Clear ysort_objects (including Pin now)
	var ysort_count = ysort_objects.size()
	ysort_objects.clear()
	placed_objects.clear()
	
	print("Cleared", ysort_count, "ysort objects")
	print("Objects cleared. Remaining obstacles:", obstacle_map.size())

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
	if smart_optimizer:
		smart_optimizer.smart_process(delta, self)

func update_ball_for_optimizer():
	"""Update ball state for the smart optimizer"""
	if smart_optimizer and launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
		var ball = launch_manager.golf_ball
		var ball_pos = ball.global_position
		var ball_velocity = ball.velocity if "velocity" in ball else Vector2.ZERO
		smart_optimizer.update_ball_state(ball_pos, ball_velocity)

func _ready() -> void:
	add_to_group("course")
	if Global.putt_putt_mode:
		print("=== PUTT PUTT MODE ENABLED ===")
		print("Only putters will be available for club selection")
		print("Available putters:", deck_manager.club_draw_pile.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		).map(func(card): return card.name))
		print("=== END PUTT PUTT MODE INFO ===")
	else:
		print("Normal mode - all clubs available")
	
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
	build_map.current_hole = current_hole
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
	
	call_deferred("fix_ui_layers")
	display_selected_character()
	if end_round_button:
		end_round_button.pressed.connect(_on_end_round_pressed)
	
	# Connect health test buttons
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)
	if heal_button:
		heal_button.pressed.connect(_on_heal_button_pressed)


	create_grid()
	create_player()
	launch_manager.set("camera_container", camera_container)
	launch_manager.ui_layer = $UILayer
	launch_manager.player_node = player_node
	launch_manager.cell_size = cell_size
	launch_manager.camera = camera
	launch_manager.card_effect_handler = card_effect_handler
	
	# Connect signals
	launch_manager.ball_launched.connect(_on_ball_launched)
	launch_manager.launch_phase_entered.connect(_on_launch_phase_entered)
	launch_manager.launch_phase_exited.connect(_on_launch_phase_exited)
	launch_manager.charging_state_changed.connect(_on_charging_state_changed)	
	
	if obstacle_layer.get_parent():
		obstacle_layer.get_parent().remove_child(obstacle_layer)
	camera_container.add_child(obstacle_layer)

	map_manager.load_map_data(GolfCourseLayout.LEVEL_LAYOUT)

	deck_manager = DeckManager.new()
	add_child(deck_manager)
	deck_manager.deck_updated.connect(update_deck_display)
	deck_manager.discard_recycled.connect(card_stack_display.animate_card_recycle)
	
	# Add EquipmentManager
	var equipment_manager = EquipmentManager.new()
	equipment_manager.name = "EquipmentManager"
	add_child(equipment_manager)
	
	# Force sync with CurrentDeckManager immediately
	deck_manager.sync_with_current_deck()
	
	# Setup movement controller after deck_manager is created
	movement_controller.setup(
		player_node,
		grid_tiles,
		grid_size,
		cell_size,
		obstacle_map,
		player_grid_pos,
		player_stats,
		movement_buttons_container,
		card_click_sound,
		card_play_sound,
		card_stack_display,
		deck_manager,
		card_effect_handler,
		attack_handler,
		weapon_handler
	)
	
	# Setup attack handler after deck_manager is created
	attack_handler.setup(
		player_node,
		grid_tiles,
		grid_size,
		cell_size,
		obstacle_map,
		player_grid_pos,
		player_stats,
		movement_buttons_container,  # Reuse the same container for now
		card_click_sound,
		card_play_sound,
		card_stack_display,
		deck_manager,
		card_effect_handler,
		player_node.get_node_or_null("KickSound")  # Add KickSound reference
	)
	
	# Setup weapon handler after deck_manager is created
	weapon_handler.setup(
		player_node,
		grid_tiles,
		grid_size,
		cell_size,
		obstacle_map,
		player_grid_pos,
		player_stats,
		camera,
		card_click_sound,
		card_play_sound,
		card_stack_display,
		deck_manager,
		card_effect_handler,
		launch_manager
	)
	
	# Set the movement controller reference for button cleanup
	attack_handler.set_movement_controller(movement_controller)
	weapon_handler.set_movement_controller(movement_controller)
	
	# Connect attack handler signals
	attack_handler.npc_attacked.connect(_on_npc_attacked)
	
	# Connect weapon handler signals
	weapon_handler.npc_shot.connect(_on_npc_shot)
	
	# Setup global death sound
	setup_global_death_sound()
	


	var hud := $UILayer/HUD

	update_deck_display()
	set_process_input(true)

	setup_swing_sounds()

	card_hand_anchor.z_index = 100
	card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
	card_hand_anchor.get_parent().move_child(card_hand_anchor, card_hand_anchor.get_parent().get_child_count() - 1)

	hud.z_index = 101
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.get_parent().move_child(hud, hud.get_parent().get_child_count() - 1)
	var parent := card_hand_anchor.get_parent()
	parent.move_child(card_hand_anchor, parent.get_child_count() - 1)
	parent.move_child(hud,             parent.get_child_count() - 1)

	card_hand_anchor.z_index = 100
	hud.z_index             = 101
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	end_turn_button.z_index = 102
	end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	end_turn_button.get_parent().move_child(end_turn_button, end_turn_button.get_parent().get_child_count() - 1)

	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	draw_cards_button.visible = false
	draw_cards_button.pressed.connect(_on_draw_cards_pressed)
	
	setup_bag_and_inventory()

	if Global.saved_game_state == "shop_entrance":
		restore_game_state()
		return  # Skip tee selection/setup when returning from shop

	if Global.starting_back_9:
		print("=== STARTING BACK 9 MODE ===")
		is_back_9_mode = true
		current_hole = back_9_start_hole  # Start at hole 10 (index 9)
		Global.starting_back_9 = false  # Reset the flag
		print("Back 9 mode initialized, starting at hole:", current_hole + 1)
	else:
		print("=== STARTING FRONT 9 MODE ===")
		is_back_9_mode = false
		current_hole = 0  # Start at hole 1 (index 0)
	
	print("Front 9 mode initialized, starting at hole:", current_hole + 1)
	
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
	


	is_placing_player = true
	highlight_tee_tiles()

	print("=== INITIALIZATION DEBUG ===")
	print("Loading map data for hole:", current_hole + 1)
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
	build_map.build_map_from_layout_with_randomization(map_manager.level_layout)
	
	# Sync shop grid position with build_map
	shop_grid_pos = build_map.shop_grid_pos
	
	# Debug: Check if pin was created
	print("=== PIN CREATION DEBUG ===")
	print("ysort_objects size after map building:", ysort_objects.size())
	for i in range(ysort_objects.size()):
		var obj = ysort_objects[i]
		if obj.has("node") and obj.node:
			print("Object", i, ":", obj.node.name, "at grid pos:", obj.grid_pos)
		else:
			print("Object", i, ": Invalid object")
	print("=== END PIN CREATION DEBUG ===")
	
	# Ensure Y-sort objects are properly registered for pin detection
	update_all_ysort_z_indices()
	print("Y-sort updated after map building")
	hole_score = 0
	print("Map data loaded, building map...")
	print("Map built, positioning camera on pin...")
	position_camera_on_pin()  # Add the camera positioning call
	print("=== END INITIALIZATION DEBUG ===")

	update_hole_and_score_display()

	show_tee_selection_instruction()
	
	# Register any existing GangMembers with the Entities system
	register_existing_gang_members()
	
	# Initialize player mouse facing system
	if player_node and player_node.has_method("set_camera_reference"):
		player_node.set_camera_reference(camera)
		_update_player_mouse_facing_state()
	
	# Play birds tweeting sound when course loads
	if birds_tweeting_sound:
		birds_tweeting_sound.play()

	var complete_hole_btn := Button.new()
	complete_hole_btn.name = "CompleteHoleButton"
	complete_hole_btn.text = "Complete Hole"
	complete_hole_btn.position = Vector2(400, 50)
	complete_hole_btn.z_index = 999
	$UILayer.add_child(complete_hole_btn)
	complete_hole_btn.pressed.connect(_on_complete_hole_pressed)

func _on_complete_hole_pressed():
	# Clear any existing balls before showing the hole completion dialog
	remove_all_balls()
	show_hole_completion_dialog()

func _input(event: InputEvent) -> void:
	# Handle weapon mode input first
	if weapon_handler and weapon_handler.handle_input(event):
		return
	
	if game_phase == "aiming":
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				is_aiming_phase = false
				hide_aiming_circle()
				hide_aiming_instruction()
				enter_launch_phase()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				is_aiming_phase = false
				hide_aiming_circle()
				hide_aiming_instruction()
				game_phase = "move"  # Return to move phase
				_update_player_mouse_facing_state()
	elif game_phase == "launch":
		# Handle launch input through LaunchManager
		if launch_manager.handle_input(event):
			return
	elif game_phase == "ball_flying":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			if is_panning:
				pan_start_pos = event.position
			else:
				var tween := get_tree().create_tween()
				tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		elif event is InputEventMouseMotion and is_panning:
			var delta: Vector2 = event.position - pan_start_pos
			camera.position -= delta
			pan_start_pos = event.position
		return  # Don't process other input during ball flight

	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		var node = get_viewport().gui_get_hovered_control()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_panning = event.pressed
		if is_panning:
			pan_start_pos = event.position
		else:
			var tween := get_tree().create_tween()
			tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	elif event is InputEventMouseMotion and is_panning:
		var delta: Vector2 = event.position - pan_start_pos
		camera.position -= delta
		pan_start_pos = event.position

	if player_node:
		player_flashlight_center = get_flashlight_center()

	# Grid tiles are static with smart optimization - no need to redraw

	queue_redraw()

func _draw() -> void:
	draw_flashlight_effect()

func draw_flashlight_effect() -> void:
	var flashlight_pos := get_flashlight_center()
	var steps := 20
	for i in steps:
		var t := float(i) / steps
		var radius := flashlight_radius * t
		var alpha := 1.0 - t
		draw_circle(flashlight_pos, radius, Color(1, 1, 1, alpha * 0.1))

func get_flashlight_center() -> Vector2:
	if not player_node:
		return Vector2.ZERO
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var dir: Vector2 = mouse_pos - player_center
	var dist: float = dir.length()
	if dist > flashlight_radius:
		dir = dir.normalized() * flashlight_radius
	return player_center + dir

func create_grid() -> void:
	camera_container = Control.new()
	camera_container.name = "CameraContainer"
	add_child(camera_container)

	grid_container = Control.new()
	grid_container.name = "GridContainer"
	grid_container.z_index = -1  # Set grid overlay to appear behind other elements
	camera_container.add_child(grid_container)

	var total_size := Vector2(grid_size.x, grid_size.y) * cell_size
	grid_container.size = total_size
	camera_offset = (get_viewport_rect().size - total_size) / 2
	camera_container.position = camera_offset

	for y in grid_size.y:
		grid_tiles.append([])
		for x in grid_size.x:
			var tile := create_grid_tile(x, y)
			grid_tiles[y].append(tile)
			grid_container.add_child(tile)

func create_grid_tile(x: int, y: int) -> Control:
	var tile := Control.new()
	tile.name = "Tile_%d_%d" % [x, y]
	tile.position = Vector2(x, y) * cell_size
	tile.size = Vector2(cell_size, cell_size)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.z_index = -100  # Set tiles to appear behind highlights but above ground

	var drawer := Control.new()
	drawer.name = "TileDrawer"
	drawer.size = tile.size
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.draw.connect(_draw_tile.bind(drawer, x, y))
	tile.add_child(drawer)

	var red := ColorRect.new()
	red.name = "Highlight"
	red.size = tile.size
	red.color = Color(1, 0, 0, 0.3)
	red.visible = false
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red.z_index = 100  # High z_index to appear above land tiles
	tile.add_child(red)

	var green := ColorRect.new()
	green.name = "MovementHighlight"
	green.size = tile.size
	green.color = Color(0, 1, 0, 0.4)
	green.visible = false
	green.mouse_filter = Control.MOUSE_FILTER_IGNORE
	green.z_index = 100  # High z_index to appear above land tiles
	tile.add_child(green)

	tile.mouse_entered.connect(_on_tile_mouse_entered.bind(x, y))
	tile.mouse_exited.connect(_on_tile_mouse_exited.bind(x, y))
	tile.gui_input.connect(_on_tile_input.bind(x, y))
	return tile
	
func _draw_tile(drawer: Control, x: int, y: int) -> void:
	var tile_screen_pos := Vector2(x, y) * cell_size + Vector2(cell_size / 2, cell_size / 2) + camera_container.position
	var dist := tile_screen_pos.distance_to(player_flashlight_center)
	if dist <= flashlight_radius:
		var alpha: float = clamp(1.0 - (dist / flashlight_radius), 0.0, 1.0)
		drawer.draw_rect(Rect2(Vector2.ZERO, drawer.size), Color(0.1, 0.1, 0.1, alpha * 0.3), true)
		drawer.draw_rect(Rect2(Vector2.ZERO, drawer.size), Color(0.5, 0.5, 0.5, alpha * 0.8), false, 1.0)

func create_player() -> void:
	player_stats = Global.CHARACTER_STATS.get(Global.selected_character, {})
	
	# Initialize health bar with character stats
	if health_bar:
		var max_hp = player_stats.get("max_hp", 100)
		var current_hp = player_stats.get("current_hp", max_hp)
		health_bar.set_health(current_hp, max_hp)
		print("Health bar initialized: %d/%d HP" % [current_hp, max_hp])
	
	if player_node and is_instance_valid(player_node):
		player_node.set_grid_position(player_grid_pos, ysort_objects, shop_grid_pos)
		player_node.visible = true
		update_player_position()
		return

	var player_scene = preload("res://Characters/Player1.tscn")
	player_node = player_scene.instantiate()
	player_node.name = "Player"
	
	# Add player to groups for smart optimization
	player_node.add_to_group("players")
	player_node.add_to_group("collision_objects")
	
	grid_container.add_child(player_node)

	var char_scene_path = ""
	var char_scale = Vector2.ONE  # Default scale - no scaling needed since sprites are properly sized
	var char_offset = Vector2.ZERO  # Default offset
	match Global.selected_character:
		1:
			char_scene_path = "res://Characters/LaylaChar.tscn"
			char_scale = Vector2.ONE  # No scaling needed
			char_offset = Vector2.ZERO  # No offset needed
		2:
			char_scene_path = "res://Characters/BennyChar.tscn"
			char_scale = Vector2.ONE  # No scaling needed
			char_offset = Vector2.ZERO  # No offset needed
		3:
			char_scene_path = "res://Characters/ClarkChar.tscn"
			char_scale = Vector2.ONE  # No scaling needed
			char_offset = Vector2.ZERO  # No offset needed
		_:
			char_scene_path = "res://Characters/BennyChar.tscn" # Default to Benny if unknown
			char_scale = Vector2.ONE  # No scaling needed
			char_offset = Vector2.ZERO  # No offset needed
	if char_scene_path != "":
		var char_scene = load(char_scene_path)
		if char_scene:
			var char_instance = char_scene.instantiate()
			char_instance.scale = char_scale  # Apply the scale
			char_instance.position = char_offset  # Apply the offset
			player_node.add_child(char_instance)

	var base_mobility = player_stats.get("base_mobility", 0)
	player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
	
	player_node.set_grid_position(player_grid_pos, ysort_objects, shop_grid_pos)

	player_node.player_clicked.connect(_on_player_input)
	player_node.moved_to_tile.connect(_on_player_moved_to_tile)

	update_player_position()
	if player_node:
		player_node.visible = false

func update_player_stats_from_equipment() -> void:
	"""Update player stats to reflect equipment buffs"""
	player_stats = Global.CHARACTER_STATS.get(Global.selected_character, {})
	
	if player_node and is_instance_valid(player_node):
		var base_mobility = player_stats.get("base_mobility", 0)
		player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
		print("Updated player stats with equipment buffs:", player_stats)

func take_damage(amount: int) -> void:
	"""Player takes damage and updates health bar"""
	if health_bar:
		health_bar.take_damage(amount)
		# Update Global stats
		Global.CHARACTER_STATS[Global.selected_character]["current_hp"] = health_bar.current_hp
		print("Player took %d damage. Current HP: %d" % [amount, health_bar.current_hp])
		
		# Check if player is defeated
		if not health_bar.is_alive():
			print("Player is defeated!")
			# Trigger death sequence
			handle_player_death()

func heal_player(amount: int) -> void:
	"""Player heals and updates health bar"""
	if health_bar:
		health_bar.heal(amount)
		# Update Global stats
		Global.CHARACTER_STATS[Global.selected_character]["current_hp"] = health_bar.current_hp
		print("Player healed %d HP. Current HP: %d" % [amount, health_bar.current_hp])

func get_player_health() -> Dictionary:
	"""Get current player health info"""
	if health_bar:
		return {
			"current_hp": health_bar.current_hp,
			"max_hp": health_bar.max_hp,
			"is_alive": health_bar.is_alive()
		}
	return {"current_hp": 0, "max_hp": 0, "is_alive": false}

func _on_damage_button_pressed() -> void:
	"""Handle damage button press"""
	take_damage(20)

func _on_heal_button_pressed() -> void:
	"""Handle heal button press"""
	heal_player(20)

func handle_player_death() -> void:
	"""Handle player death - fade to black and show death screen"""
	print("Handling player death...")
	
	# Disable all input to prevent further actions
	set_process_input(false)
	
	# Fade to black and transition to death scene
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://DeathScene.tscn"), 1.0)

func _on_player_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_phase == "move":
			enter_aiming_phase()  # Start aiming phase instead of just drawing cards
		elif game_phase == "launch":
			if deck_manager.hand.size() == 0:
				draw_cards_for_next_shot()  # Draw cards for shot
			else:
				pass # Already have cards in launch phase - ready to take shot
		else:
			pass # Player clicked but not in move or launch phase

func update_camera_to_player() -> void:
	"""Update camera to follow player's current position (called during movement animation)"""
	if not player_node:
		return
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center: Vector2 = player_node.global_position + player_size / 2
	
	# Update camera snap back position
	camera_snap_back_pos = player_center
	
	# Smoothly follow player during movement (small tween for smooth following)
	var current_camera_pos = camera.position
	var target_camera_pos = player_center
	var follow_speed = 8.0  # How quickly camera follows during movement
	
	var new_camera_pos = current_camera_pos.lerp(target_camera_pos, follow_speed * get_process_delta_time())
	camera.position = new_camera_pos

func smooth_camera_to_player() -> void:
	"""Smoothly tween camera to player's final position (called after movement animation completes)"""
	if not player_node:
		return
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center: Vector2 = player_node.global_position + player_size / 2
	
	# Update camera snap back position
	camera_snap_back_pos = player_center
	
	# Smoothly tween camera to final position using managed tween
	create_camera_tween(player_center, 0.3)

func update_player_position() -> void:
	if not player_node:
		return
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)

	player_node.set_grid_position(player_grid_pos, ysort_objects)
	
	var player_center: Vector2 = player_node.global_position + player_size / 2
	camera_snap_back_pos = player_center
	
	# Only create ball if player is properly placed (not during initial setup)
	if not is_placing_player:
		# Create or update ball at tile center for all shots
		var tile_center: Vector2 = Vector2(player_grid_pos.x * cell_size + cell_size/2, player_grid_pos.y * cell_size + cell_size/2) + camera_container.global_position
		create_or_update_ball_at_player_center(tile_center)
	
	if not is_placing_player:
		# Check if there's an ongoing pin-to-tee transition
		var ongoing_tween = get_meta("pin_to_tee_tween", null)
		if ongoing_tween and ongoing_tween.is_valid():
			ongoing_tween.kill()
			remove_meta("pin_to_tee_tween")
		
		# Use the new camera tween management system
		create_camera_tween(player_center, 0.5)

func remove_all_balls() -> void:
	"""Remove all balls from the scene"""
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if is_instance_valid(ball):
			ball.queue_free()
	print("Removed", balls.size(), "balls from scene")

func create_or_update_ball_at_player_center(player_center: Vector2) -> void:
	"""Create a ball at the player center or update existing ball position"""
	# Check if a ball already exists
	var existing_balls = get_tree().get_nodes_in_group("balls")
	var existing_ball = null
	
	for ball in existing_balls:
		if is_instance_valid(ball):
			existing_ball = ball
			break
	
	if existing_ball:
		# Ball already exists - don't recreate it, just update its properties
		return
	

	
	# No ball exists - create a new one at player center
	var ball_scene = preload("res://GolfBall.tscn")
	var ball = ball_scene.instantiate()
	ball.name = "GolfBall"
	ball.add_to_group("balls")
	
	# Position the ball relative to the camera container
	var ball_local_position = player_center - camera_container.global_position
	ball.position = ball_local_position
	ball.cell_size = cell_size
	ball.map_manager = map_manager
	
	# Connect ball signals using the existing function names
	ball.landed.connect(_on_golf_ball_landed)
	ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)
	ball.sand_landing.connect(_on_golf_ball_sand_landing)
	
	# Add ball to camera container so it moves with the world
	camera_container.add_child(ball)

func force_create_ball_at_position(world_position: Vector2) -> void:
	"""Force create a new ball at the specified world position (ignores existing balls)"""
	# Create a new ball at the specified position
	var ball_scene = preload("res://GolfBall.tscn")
	var ball = ball_scene.instantiate()
	ball.name = "GolfBall"
	ball.add_to_group("balls")
	
	# Position the ball relative to the camera container
	var ball_local_position = world_position - camera_container.global_position
	ball.position = ball_local_position
	ball.cell_size = cell_size
	ball.map_manager = map_manager
	
	# Connect ball signals using the existing function names
	ball.landed.connect(_on_golf_ball_landed)
	ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)
	ball.sand_landing.connect(_on_golf_ball_sand_landing)
	
	# Add ball to camera container so it moves with the world
	camera_container.add_child(ball)
	
	# Set the launch manager's golf ball reference
	launch_manager.golf_ball = ball
	
	print("Force created new ball at position:", world_position)

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
	movement_controller.handle_tile_mouse_entered(x, y, is_panning)
	attack_handler.handle_tile_mouse_entered(x, y, is_panning)

func _on_tile_mouse_exited(x: int, y: int) -> void:
	movement_controller.handle_tile_mouse_exited(x, y, is_panning)
	attack_handler.handle_tile_mouse_exited(x, y, is_panning)

func _on_tile_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed and not is_panning and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := Vector2i(x, y)
		if is_placing_player:
			if map_manager.get_tile_type(x, y) == "Tee":
				# Cancel any ongoing pin-to-tee transition
				var ongoing_tween = get_meta("pin_to_tee_tween", null)
				if ongoing_tween and ongoing_tween.is_valid():
					print("Cancelling ongoing pin-to-tee transition due to early player placement")
					ongoing_tween.kill()
					remove_meta("pin_to_tee_tween")
				
				player_grid_pos = clicked
				create_player()  # This will reuse existing player or create new one
				is_placing_player = false
				
				# Update player position and create ball
				update_player_position()
				
				if sand_thunk_sound and sand_thunk_sound.stream:
					sand_thunk_sound.play()
				start_round_after_tee_selection()
			else:
				pass # Please select a Tee Box to start your round.
		else:
			if player_node.has_method("can_move_to"):
				print("player_node.can_move_to(clicked):", player_node.can_move_to(clicked))
			else:
				print("player_node does not have can_move_to method")
			
			if movement_controller.handle_tile_click(x, y):
				# Movement was successful, no need to do anything else here
				pass
			elif attack_handler.handle_tile_click(x, y):
				# Attack was successful, no need to do anything else here
				pass
			else:
				print("Invalid movement/attack tile or not in movement/attack mode")

func start_round_after_tee_selection() -> void:
	var instruction_label = $UILayer.get_node_or_null("TeeInstructionLabel")
	if instruction_label:
		instruction_label.queue_free()
	
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("Highlight").visible = false
	
	# Reset character health for new round
	Global.reset_character_health()
	
	# Reset global turn counter for new round
	Global.reset_global_turn()
	
	player_stats = Global.CHARACTER_STATS.get(Global.selected_character, {})
	
	deck_manager.initialize_separate_decks()
	print("Separate decks initialized - Club cards:", deck_manager.club_draw_pile.size(), "Action cards:", deck_manager.action_draw_pile.size())

	has_started = true
	
	hole_score = 0
	
	# Enable player movement animations after player is properly placed on tee
	if player_node and player_node.has_method("enable_animations"):
		player_node.enable_animations()
		print("Player movement animations enabled after tee placement")
	
	enter_draw_cards_phase()  # Start with club selection phase
	
	print("Round started! Player at position:", player_grid_pos)

func show_power_meter():
	launch_manager.show_power_meter()

func hide_power_meter():
	launch_manager.hide_power_meter()

func show_height_meter():
	launch_manager.show_height_meter()

func hide_height_meter():
	launch_manager.hide_height_meter()

func show_aiming_circle():
	if aiming_circle:
		aiming_circle.queue_free()
	
	var base_circle_size = 50.0
	var strength_modifier = player_stats.get("strength", 0)
	var strength_multiplier = 1.0 + (strength_modifier * 0.15)  # +15% size per strength point
	var adjusted_circle_size = base_circle_size * strength_multiplier
	
	aiming_circle = Control.new()
	aiming_circle.name = "AimingCircle"
	aiming_circle.size = Vector2(adjusted_circle_size, adjusted_circle_size)
	aiming_circle.z_index = 150  # Above the player but below UI
	camera_container.add_child(aiming_circle)
	
	# Load the target circle texture
	var target_circle_texture = preload("res://UI/TargetCircle.png")
	
	var circle = TextureRect.new()
	circle.name = "CircleVisual"
	circle.size = Vector2(adjusted_circle_size, adjusted_circle_size)
	circle.texture = target_circle_texture
	circle.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(circle)
	
	var distance_label = Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.text = "0"
	distance_label.add_theme_font_size_override("font_size", 12)
	distance_label.add_theme_color_override("font_color", Color.WHITE)
	distance_label.add_theme_constant_override("outline_size", 1)
	distance_label.add_theme_color_override("font_outline_color", Color.BLACK)
	distance_label.position = Vector2(adjusted_circle_size + 10, adjusted_circle_size / 2 - 10)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(distance_label)
	
	print("Aiming circle created with size:", adjusted_circle_size, "(base:", base_circle_size, "strength modifier:", strength_modifier, ")")



func hide_aiming_circle():
	if aiming_circle:
		aiming_circle.queue_free()
		aiming_circle = null
	
	remove_ghost_ball()

func update_aiming_circle():
	if not aiming_circle or not player_node:
		return
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var mouse_pos = camera.get_global_mouse_position()
	var direction = (mouse_pos - player_center).normalized()
	var distance = player_center.distance_to(mouse_pos)
	
	var clamped_distance = min(distance, max_shot_distance)
	var clamped_position = player_center + direction * clamped_distance
	
	aiming_circle.global_position = clamped_position - aiming_circle.size / 2
	
	chosen_landing_spot = clamped_position
	
	update_ghost_ball()
	
	var circle = aiming_circle.get_node_or_null("CircleVisual")
	if circle and selected_club in club_data:
		var min_distance = club_data[selected_club]["min_distance"]
		if clamped_distance >= min_distance:
			circle.modulate = Color(0, 1, 0, 0.8)  # Green
		else:
			circle.modulate = Color(1, 0, 0, 0.8)  # Red
	
	var target_camera_pos = clamped_position
	# Add vertical offset of -300 pixels to show player near bottom of screen and better see arc apex
	target_camera_pos.y -= 120
	var current_camera_pos = camera.position
	var camera_speed = 5.0  # Adjust for faster/slower camera movement
	
	var new_camera_pos = current_camera_pos.lerp(target_camera_pos, camera_speed * get_process_delta_time())
	camera.position = new_camera_pos
	
	
	var distance_label = aiming_circle.get_node_or_null("DistanceLabel")
	if distance_label:
		distance_label.text = str(int(clamped_distance)) + "px"

func launch_golf_ball(direction: Vector2, charged_power: float, height: float):
	# Determine if this is a tee shot (first shot of the hole)
	print("DEBUG: Launching ball, hole_score =", hole_score)
	launch_manager.launch_golf_ball(direction, charged_power, height, 0.0, 0)
	
func _on_golf_ball_landed(tile: Vector2i):
	print("DEBUG: Ball landed, hole_score before increment =", hole_score)
	hole_score += 1
	print("DEBUG: Ball landed, hole_score after increment =", hole_score)
	print("Turning off camera following for golf ball")
	camera_following_ball = false
	ball_landing_tile = tile
	
	# Reset ball in flight state in launch manager
	if launch_manager and launch_manager.has_method("set_ball_in_flight"):
		launch_manager.set_ball_in_flight(false)
		print("Ball in flight state reset to false")
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("move", false, false, false)
	
	# Re-enable player collision shape after ball lands
	if player_node and player_node.has_method("enable_collision_shape"):
		player_node.enable_collision_shape()
	
	# Check if the ball still exists (if not, it went in the hole)
	if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
		# Normal landing - ball still exists
		ball_landing_position = launch_manager.golf_ball.global_position
		waiting_for_player_to_reach_ball = true
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var player_start_pos = player_center
		var ball_landing_pos = launch_manager.golf_ball.global_position
		drive_distance = player_start_pos.distance_to(ball_landing_pos)
		var dialog_timer = get_tree().create_timer(0.5)  # Reduced from 1.5 to 0.5 second delay
		dialog_timer.timeout.connect(func():
			show_drive_distance_dialog()
		)
		game_phase = "move"
		_update_player_mouse_facing_state()
	else:
		# Ball went in the hole - don't show drive distance dialog
		# The hole completion dialog will be shown by the pin's hole_in_one signal
		print("Ball went in the hole - skipping drive distance dialog")
		# Clear the ball reference since it's been destroyed
		launch_manager.golf_ball = null
	
func highlight_tee_tiles():
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("Highlight").visible = false
	
	for y in grid_size.y:
		for x in grid_size.x:
			if map_manager.get_tile_type(x, y) == "Tee":
				grid_tiles[y][x].get_node("Highlight").visible = true
				# Change highlight color to blue for tee tiles
				var highlight = grid_tiles[y][x].get_node("Highlight")
				highlight.color = Color(0, 0.5, 1, 0.6)  # Blue with transparency

func exit_movement_mode() -> void:
	movement_controller.exit_movement_mode()
	if attack_handler.is_in_attack_mode():
		attack_handler.exit_attack_mode()
	if weapon_handler.is_in_weapon_mode():
		weapon_handler.exit_weapon_mode()
	update_deck_display()

func _on_end_turn_pressed() -> void:
	if movement_controller.is_in_movement_mode():
		exit_movement_mode()
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
	
	# Debug: Print deck state after discarding
	print("=== DECK STATE AFTER DISCARD ===")
	deck_manager.debug_print_state()
	print("=== END DECK STATE ===")
	
	movement_controller.clear_all_movement_ui()
	attack_handler.clear_all_attack_ui()
	weapon_handler.clear_all_weapon_ui()
	turn_count += 1
	
	# Increment global turn counter for turn-based spawning
	Global.increment_global_turn()
	
	# Reset fire damage tracking for new turn
	reset_fire_damage_tracking()
	
	# Advance fire tiles to next turn
	advance_fire_tiles()
	
	update_deck_display()
	
	if cards_to_discard > 0:
		if card_stack_display.has_node("Discard"):
			var discard_sound = card_stack_display.get_node("Discard")
			if discard_sound and discard_sound.stream:
				discard_sound.play()
	elif cards_to_discard == 0:
		if card_stack_display.has_node("DiscardEmpty"):
			var discard_empty_sound = card_stack_display.get_node("DiscardEmpty")
			if discard_empty_sound and discard_empty_sound.stream:
				discard_empty_sound.play()

	# Start NPC turn sequence
	start_npc_turn_sequence()

func start_npc_turn_sequence() -> void:
	"""Handle the NPC turn sequence with camera transitions and UI"""
	print("Starting NPC turn sequence...")
	
	# Check if there are any alive NPCs on the map
	if not has_alive_npcs():
		print("No alive NPCs found on the map, skipping World Turn and entering next player turn")
		
		# Show "Your Turn" message immediately
		show_turn_message("Your Turn", 2.0)
		
		# Continue with normal turn flow
		if waiting_for_player_to_reach_ball and player_grid_pos == ball_landing_tile:
			if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
				launch_manager.golf_ball.remove_landing_highlight()
			
			enter_draw_cards_phase()  # Start with club selection phase
		else:
			draw_cards_for_shot(3)
			create_movement_buttons()
			draw_cards_button.visible = false
		return
	
	# Disable end turn button during NPC turn
	end_turn_button.disabled = true
	
	# Find the nearest visible NPC
	var nearest_npc = find_nearest_visible_npc()
	print("Nearest NPC found: ", nearest_npc.name if nearest_npc else "None")
	
	if nearest_npc:
		print("Beginning World Turn phase...")
		
		# Transition camera to NPC and wait for it to complete
		await transition_camera_to_npc(nearest_npc)
		
		# Show "World Turn" message and wait for it to display
		await show_turn_message("World Turn", 2.0)
		
		# Manually trigger the NPC's turn (not through Entities system)
		print("Manually triggering NPC turn...")
		nearest_npc.take_turn()
		
		# Wait 1 second after NPC turn to let player see the result
		await get_tree().create_timer(1.0).timeout
		
		# Show "Your Turn" message
		show_turn_message("Your Turn", 2.0)
		
		# Wait for message to display, then transition camera back to player
		await get_tree().create_timer(1.0).timeout
		await transition_camera_to_player()
		
		print("World Turn phase completed")
	else:
		print("No visible NPCs found, skipping World Turn phase")
	
	# Re-enable end turn button
	end_turn_button.disabled = false
	
	# Continue with normal turn flow
	if waiting_for_player_to_reach_ball and player_grid_pos == ball_landing_tile:
		if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
			launch_manager.golf_ball.remove_landing_highlight()
		
		enter_draw_cards_phase()  # Start with club selection phase
	else:
		draw_cards_for_shot(3)
		create_movement_buttons()
		draw_cards_button.visible = false

func find_nearest_visible_npc() -> Node:
	"""Find the nearest NPC that is visible to the player and alive"""
	var entities = get_node_or_null("Entities")
	if not entities:
		print("ERROR: No Entities node found!")
		return null
	
	var npcs = entities.get_npcs()
	print("Found ", npcs.size(), " NPCs in Entities system")
	
	var nearest_npc = null
	var nearest_distance = INF
	
	for npc in npcs:
		if is_instance_valid(npc) and npc.has_method("get_grid_position"):
			# Check if NPC is alive
			var is_alive = true
			if npc.has_method("get_is_dead"):
				is_alive = not npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_alive = not npc.is_dead()
			elif "is_dead" in npc:
				is_alive = not npc.is_dead
			
			if not is_alive:
				print("NPC ", npc.name, " is dead, skipping")
				continue
			
			var npc_pos = npc.get_grid_position()
			var distance = player_grid_pos.distance_to(npc_pos)
			
			print("NPC ", npc.name, " at distance ", distance, " from player")
			
			# Check if NPC is within vision range (12 tiles)
			if distance <= 12 and distance < nearest_distance:
				nearest_distance = distance
				nearest_npc = npc
				print("New nearest NPC: ", npc.name, " at distance ", distance)
		else:
			print("Invalid NPC or missing get_grid_position method: ", npc.name if npc else "None")
	
	print("Final nearest NPC: ", nearest_npc.name if nearest_npc else "None")
	return nearest_npc

func has_alive_npcs() -> bool:
	"""Check if there are any alive NPCs on the map"""
	var entities = get_node_or_null("Entities")
	if not entities:
		print("ERROR: No Entities node found!")
		return false
	
	var npcs = entities.get_npcs()
	print("Checking for alive NPCs among ", npcs.size(), " total NPCs")
	
	for npc in npcs:
		if is_instance_valid(npc):
			# Check if NPC is alive
			var is_alive = true
			if npc.has_method("get_is_dead"):
				is_alive = not npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_alive = not npc.is_dead()
			elif "is_dead" in npc:
				is_alive = not npc.is_dead
			
			if is_alive:
				print("Found alive NPC: ", npc.name)
				return true
		else:
			print("Invalid NPC found, skipping")
	
	print("No alive NPCs found on the map")
	return false

func transition_camera_to_npc(npc: Node) -> void:
	"""Transition camera to focus on the NPC"""
	if not npc:
		print("ERROR: No NPC provided for camera transition")
		return
	
	var npc_pos = npc.global_position
	print("Transitioning camera to NPC at position: ", npc_pos)
	create_camera_tween(npc_pos, 1.0)
	await current_camera_tween.finished

func transition_camera_to_player() -> void:
	"""Transition camera back to the player"""
	if not player_node:
		print("ERROR: No player node found for camera transition")
		return
	
	var player_center = player_node.global_position
	print("Transitioning camera back to player at position: ", player_center)
	create_camera_tween(player_center, 1.0)
	await current_camera_tween.finished

func show_turn_message(message: String, duration: float) -> void:
	"""Show a turn message for the specified duration"""
	var message_label := Label.new()
	message_label.name = "TurnMessageLabel"
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 48)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the message on screen
	var viewport_size = get_viewport_rect().size
	message_label.position = Vector2(viewport_size.x / 2 - 150, viewport_size.y / 2 - 50)
	message_label.z_index = 1000
	$UILayer.add_child(message_label)
	
	# Remove message after duration
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	if is_instance_valid(message_label):
		message_label.queue_free()

func register_existing_gang_members() -> void:
	"""Register any existing GangMembers in the scene with the Entities system"""
	var entities = get_node_or_null("Entities")
	if not entities:
		print("ERROR: No Entities node found for registering GangMembers!")
		return
	
	# Search for GangMember nodes in the scene
	var gang_members = []
	_find_gang_members_recursive(self, gang_members)
	
	print("Found ", gang_members.size(), " existing GangMembers to register")
	
	# Register each GangMember
	for gang_member in gang_members:
		if is_instance_valid(gang_member):
			entities.register_npc(gang_member)
			print("Registered existing GangMember: ", gang_member.name)

func _find_gang_members_recursive(node: Node, gang_members: Array) -> void:
	"""Recursively search for GangMember nodes in the scene tree"""
	for child in node.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("GangMember.gd"):
			gang_members.append(child)
		_find_gang_members_recursive(child, gang_members)

func get_player_reference() -> Node:
	"""Get the player reference for NPCs to use"""
	print("get_player_reference called - player_node: ", player_node.name if player_node else "None")
	return player_node

func get_attack_handler() -> Node:
	"""Get the attack handler reference for NPCs to use"""
	return attack_handler

func advance_fire_tiles() -> void:
	"""Advance all fire tiles to the next turn"""
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		if is_instance_valid(fire_tile) and fire_tile.has_method("advance_turn"):
			fire_tile.advance_turn()
	
	# Check for fire damage at end of world turn
	check_player_fire_damage()

func update_deck_display() -> void:
	var hud := get_node("UILayer/HUD")
	hud.get_node("TurnLabel").text = "Turn: %d (Global: %d)" % [turn_count, Global.global_turn_count]
	
	# Show separate counts for club and action cards
	var club_draw_count = deck_manager.club_draw_pile.size()
	var club_discard_count = deck_manager.club_discard_pile.size()
	var action_draw_count = deck_manager.action_draw_pile.size()
	var action_discard_count = deck_manager.action_discard_pile.size()
	
	hud.get_node("DrawLabel").text = "Club Draw: %d | Action Draw: %d" % [club_draw_count, action_draw_count]
	hud.get_node("DiscardLabel").text = "Club Discard: %d | Action Discard: %d" % [club_discard_count, action_discard_count]
	hud.get_node("ShotLabel").text = "Shots: %d" % hole_score
	
	# Show next spawn increase milestone
	var next_milestone = ((Global.global_turn_count - 1) / 5 + 1) * 5
	var turns_until_milestone = next_milestone - Global.global_turn_count
	if turns_until_milestone > 0:
		hud.get_node("ShotLabel").text += " | Next spawn increase: %d turns" % turns_until_milestone
	
	# Update card stack display with total counts (for backward compatibility)
	var total_draw_cards = action_draw_count + club_draw_count
	var total_discard_cards = action_discard_count + club_discard_count
	card_stack_display.update_draw_stack(total_draw_cards)
	card_stack_display.update_discard_stack(total_discard_cards)

func display_selected_character() -> void:
	var character_name = ""
	if character_label:
		match Global.selected_character:
			1: character_name = "Layla"
			2: character_name = "Benny"
			3: character_name = "Clark"
			_: character_name = "Unknown"
		character_label.text = character_name
	if character_image:
		match Global.selected_character:
			1: 
				character_image.texture = load("res://character1.png")
				character_image.scale = Vector2(0.42, 0.42)
				character_image.position.y = 320.82
			2: 
				character_image.texture = load("res://character2.png")
			3: 
				character_image.texture = load("res://character3.png")
	
	if bag and bag.has_method("set_character"):
		bag.set_character(character_name)

func _on_end_round_pressed() -> void:
	if movement_controller.is_in_movement_mode():
		exit_movement_mode()
	call_deferred("_change_to_main")

func _change_to_main() -> void:
	Global.putt_putt_mode = false
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5)

func show_tee_selection_instruction() -> void:
	var instruction_label := Label.new()
	instruction_label.name = "TeeInstructionLabel"
	instruction_label.text = "Click on a Tee Box to start your round!"
	instruction_label.add_theme_font_size_override("font_size", 24)
	instruction_label.add_theme_color_override("font_color", Color.YELLOW)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	instruction_label.position = Vector2(400, 200)
	instruction_label.z_index = 200
	$UILayer.add_child(instruction_label)

func show_drive_distance_dialog() -> void:
	if drive_distance_dialog:
		drive_distance_dialog.queue_free()
	
	drive_distance_dialog = Control.new()
	drive_distance_dialog.name = "DriveDistanceDialog"
	drive_distance_dialog.size = get_viewport_rect().size
	drive_distance_dialog.z_index = 500  # Very high z-index to appear on top
	drive_distance_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = drive_distance_dialog.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP  # Make sure it can receive input
	drive_distance_dialog.add_child(background)
	background.gui_input.connect(_on_drive_distance_dialog_input)
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.9)
	dialog_box.size = Vector2(400, 200)
	dialog_box.position = (drive_distance_dialog.size - dialog_box.size) / 2  # Center the dialog
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drive_distance_dialog.add_child(dialog_box)
	var title_label := Label.new()
	title_label.text = "Drive Distance"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(150, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	var distance_label := Label.new()
	distance_label.text = "%d pixels" % drive_distance
	distance_label.add_theme_font_size_override("font_size", 36)
	distance_label.add_theme_color_override("font_color", Color.WHITE)
	distance_label.add_theme_constant_override("outline_size", 2)
	distance_label.add_theme_color_override("font_outline_color", Color.BLACK)
	distance_label.position = Vector2(150, 80)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(distance_label)
	var instruction_label := Label.new()
	instruction_label.text = "Click anywhere to continue"
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	instruction_label.position = Vector2(120, 150)
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(instruction_label)
	$UILayer.add_child(drive_distance_dialog)
	
func _on_drive_distance_dialog_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if drive_distance_dialog:
			drive_distance_dialog.queue_free()
			drive_distance_dialog = null
		
		game_phase = "move"
		_update_player_mouse_facing_state()
		draw_cards_button.visible = true
		draw_cards_button.text = "Draw Cards"
		var dialog_player_sprite = player_node.get_node_or_null("Sprite2D")
		var dialog_player_size = dialog_player_sprite.texture.get_size() * dialog_player_sprite.scale if dialog_player_sprite and dialog_player_sprite.texture else Vector2(cell_size, cell_size)
		var player_center: Vector2 = player_node.global_position + dialog_player_size / 2
		create_camera_tween(player_center, 1.0)

func setup_swing_sounds() -> void:
	swing_strong_sound = $SwingStrong
	swing_med_sound = $SwingMed
	swing_soft_sound = $SwingSoft
	water_plunk_sound = $WaterPlunk
	sand_thunk_sound = $SandThunk
	trunk_thunk_sound = $TrunkThunk

func play_swing_sound(power: float) -> void:
	var power_percentage = (power - 300.0) / (1200.0 - 300.0)  # Using hardcoded values since constants are removed	power_percentage = clamp(power_percentage, 0.0, 1.0)
	
	if power_percentage >= 0.7:  # Strong swing (70%+ power)
		swing_strong_sound.play()
	elif power_percentage >= 0.4:  # Medium swing (40-70% power)
		swing_med_sound.play()
	else:  # Soft swing (0-40% power)
		swing_soft_sound.play()

func start_next_shot_from_ball() -> void:
	if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
		launch_manager.golf_ball.queue_free()
		launch_manager.golf_ball = null
	
	waiting_for_player_to_reach_ball = false
	update_player_position()
	enter_draw_cards_phase()
	

func _on_golf_ball_out_of_bounds():
	
	if water_plunk_sound and water_plunk_sound.stream:
		water_plunk_sound.play()
	camera_following_ball = false
	
	# Reset ball in flight state in launch manager
	if launch_manager and launch_manager.has_method("set_ball_in_flight"):
		launch_manager.set_ball_in_flight(false)
		print("Ball in flight state reset to false (out of bounds)")
	
	# Re-enable player collision shape after ball goes out of bounds
	if player_node and player_node.has_method("enable_collision_shape"):
		player_node.enable_collision_shape()
	
	hole_score += 1
	if launch_manager.golf_ball:
		launch_manager.golf_ball.queue_free()
		launch_manager.golf_ball = null
	
	# Clear any existing balls to ensure clean state
	remove_all_balls()
	
	show_out_of_bounds_dialog()
	ball_landing_tile = shot_start_grid_pos
	ball_landing_position = Vector2(shot_start_grid_pos.x * cell_size + cell_size/2, shot_start_grid_pos.y * cell_size + cell_size/2)
	waiting_for_player_to_reach_ball = true
	player_grid_pos = shot_start_grid_pos
	update_player_position()
	
	# Force create a new ball at the player's tile center position for the penalty shot
	var tile_center: Vector2 = Vector2(player_grid_pos.x * cell_size + cell_size/2, player_grid_pos.y * cell_size + cell_size/2) + camera_container.global_position
	force_create_ball_at_position(tile_center)
	
	game_phase = "draw_cards"
	_update_player_mouse_facing_state()

func show_out_of_bounds_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Out of Bounds!"
	dialog.dialog_text = "Your ball went out of bounds!\n\nPenalty: +1 stroke\nYour ball has been returned to where you took the shot from.\n\nClick to select your club for the penalty shot."
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.RED)
	dialog.position = Vector2(400, 300)
	$UILayer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		enter_draw_cards_phase()  # Go directly to club selection
	)

func reset_player_to_tee():
	for y in map_manager.level_layout.size():
		for x in map_manager.level_layout[y].size():
			if map_manager.get_tile_type(x, y) == "Tee":
				player_grid_pos = Vector2i(x, y)
				update_player_position()
				return
	player_grid_pos = Vector2i(25, 25)
	update_player_position()

func enter_launch_phase() -> void:
	"""Enter the launch phase for taking a shot"""
	remove_ghost_ball()
	launch_manager.enter_launch_phase()
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("launch", true, false, true)
	
func enter_aiming_phase() -> void:
	game_phase = "aiming"
	_update_player_mouse_facing_state()
	is_aiming_phase = true
	
	# Update smart optimizer state
	if smart_optimizer:
		smart_optimizer.update_game_state("aiming", false, true, false)
	
	# Set the shot start position to where the player currently is
	shot_start_grid_pos = player_grid_pos
	print("Shot started from position:", shot_start_grid_pos)
	
	show_aiming_circle()
	create_ghost_ball()
	show_aiming_instruction()
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	create_camera_tween(player_center, 1.0)

func show_aiming_instruction() -> void:
	var existing_instruction = $UILayer.get_node_or_null("AimingInstructionLabel")
	if existing_instruction:
		existing_instruction.queue_free()
	var instruction_label := Label.new()
	instruction_label.name = "AimingInstructionLabel"
	if club_data.get(selected_club, {}).get("is_putter", false):
		instruction_label.text = "Move mouse to set landing spot\nLeft click to confirm, Right click to cancel\n(Putter: Power only, no height)"
	else:
		instruction_label.text = "Move mouse to set landing spot\nLeft click to confirm, Right click to cancel"
	
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.YELLOW)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	instruction_label.position = Vector2(400, 50)
	instruction_label.z_index = 200
	
	$UILayer.add_child(instruction_label)

func hide_aiming_instruction() -> void:
	var instruction_label = $UILayer.get_node_or_null("AimingInstructionLabel")
	if instruction_label:
		instruction_label.queue_free()

func draw_cards_for_shot(card_count: int = 3) -> void:
	print("=== DRAWING CARDS FOR SHOT ===")
	print("Requested card count:", card_count)
	var card_draw_modifier = player_stats.get("card_draw", 0)
	var final_card_count = card_count + card_draw_modifier
	final_card_count = max(1, final_card_count)
	print("Final card count (with modifier):", final_card_count)
	
	# Debug: Print deck state before drawing
	print("=== DECK STATE BEFORE DRAWING ===")
	deck_manager.debug_print_state()
	print("=== END DECK STATE ===")
	
	deck_manager.draw_action_cards_to_hand(final_card_count)
	
	# Debug: Print deck state after drawing
	print("=== DECK STATE AFTER DRAWING ===")
	deck_manager.debug_print_state()
	print("=== END DECK STATE ===")
	print("=== END DRAWING CARDS FOR SHOT ===")

func start_shot_sequence() -> void:
	enter_aiming_phase()

func draw_cards_for_next_shot() -> void:
	if card_stack_display.has_node("CardDraw"):
		var card_draw_sound = card_stack_display.get_node("CardDraw")
		if card_draw_sound and card_draw_sound.stream:
			card_draw_sound.play()
	draw_cards_for_shot(3)  # This now includes character modifiers
	create_movement_buttons()

func _on_golf_ball_sand_landing():
	if sand_thunk_sound and sand_thunk_sound.stream:
		sand_thunk_sound.play()
	
	camera_following_ball = false
	# Re-enable player collision shape after ball lands in sand
	if player_node and player_node.has_method("enable_collision_shape"):
		player_node.enable_collision_shape()
	
	if launch_manager.golf_ball and map_manager:
		var final_tile = Vector2i(floor(launch_manager.golf_ball.position.x / cell_size), floor(launch_manager.golf_ball.position.y / cell_size))
		_on_golf_ball_landed(final_tile)
		_on_golf_ball_landed(final_tile)

func show_sand_landing_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Sand Trap!"
	dialog.dialog_text = "Your ball landed in a sand trap!\n\nThis is a valid shot - no penalty.\nYou'll take your next shot from here."
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.ORANGE)
	dialog.position = Vector2(400, 300)
	$UILayer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
	)

func show_hole_completion_dialog():
	"""Show dialog when the ball goes in the hole"""
	print("=== SHOW_HOLE_COMPLETION_DIALOG CALLED ===")
	print("Current hole:", current_hole)
	print("Hole score:", hole_score)
	round_scores.append(hole_score)
	var hole_par = GolfCourseLayout.get_hole_par(current_hole)
	var score_vs_par = hole_score - hole_par
	var score_text = "Hole %d Complete!\n\n" % (current_hole + 1)
	score_text += "Hole Score: %d strokes\n" % hole_score
	score_text += "Par: %d\n" % hole_par
	if score_vs_par == 0:
		score_text += "Score: Par ✓\n"
	elif score_vs_par == 1:
		score_text += "Score: Bogey (+1)\n"
	elif score_vs_par == 2:
		score_text += "Score: Double Bogey (+2)\n"
	elif score_vs_par == -1:
		score_text += "Score: Birdie (-1) ✓\n"
	elif score_vs_par == -2:
		score_text += "Score: Eagle (-2) ✓\n"
	else:
		score_text += "Score: %+d\n" % score_vs_par
	var total_round_score = 0
	for score in round_scores:
		total_round_score += score
	var total_par = 0
	if is_back_9_mode:
		total_par = GolfCourseLayout.get_back_nine_par()
	else:
		total_par = GolfCourseLayout.get_front_nine_par()
	var round_vs_par = total_round_score - total_par
	
	score_text += "\nRound Progress: %d/%d holes\n" % [current_hole + 1, NUM_HOLES]
	score_text += "Round Score: %d\n" % total_round_score
	score_text += "Round vs Par: %+d\n" % round_vs_par
	var round_end_hole = 0
	if is_back_9_mode:
		round_end_hole = back_9_start_hole + NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		round_end_hole = NUM_HOLES - 1  # Hole 9 (index 8)
	if current_hole < round_end_hole:
		score_text += "\nClick to continue to the next hole."
	else:
		score_text += "\nClick to see your final round score!"
	var dialog = AcceptDialog.new()
	dialog.title = "Hole Complete!"
	dialog.dialog_text = score_text
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.GREEN)
	dialog.position = Vector2(400, 300)
	print("UILayer exists:", $UILayer != null)
	if $UILayer:
		print("Adding dialog to UILayer")
		$UILayer.add_child(dialog)
		print("Dialog added to UILayer")
	else:
		print("ERROR: UILayer not found!")
		return
	print("Creating hole completion dialog...")
	dialog.popup_centered()
	print("Dialog popped up")
	dialog.confirmed.connect(func():
		print("Dialog confirmed - cleaning up")
		dialog.queue_free()
		print("Hole completion dialog dismissed")
		if current_hole < round_end_hole:
			show_reward_phase()
		else:
			if is_back_9_mode:
				show_back_nine_complete_dialog()
			else:
				# For hole 9, show reward phase first, then front nine completion
				show_reward_phase()
	)

func show_reward_phase():
	"""Show the suitcase for reward selection"""
	print("Starting reward phase...")
	
	# Create and show the suitcase
	var suitcase_scene = preload("res://UI/SuitCase.tscn")
	var suitcase = suitcase_scene.instantiate()
	suitcase.name = "SuitCase"  # Give it a specific name for cleanup
	$UILayer.add_child(suitcase)
	
	# Debug: Check suitcase position and visibility
	print("Suitcase created and added to UILayer")
	print("Suitcase position:", suitcase.position)
	print("Suitcase global position:", suitcase.global_position)
	print("Suitcase visible:", suitcase.visible)
	print("Suitcase size:", suitcase.size)
	
	# Connect the suitcase opened signal
	suitcase.suitcase_opened.connect(_on_suitcase_opened)

func _on_suitcase_opened():
	"""Handle when the suitcase is opened - show reward selection"""
	print("Suitcase opened, showing reward selection...")
	
	# Create and show the reward selection dialog
	var reward_dialog_scene = preload("res://RewardSelectionDialog.tscn")
	var reward_dialog = reward_dialog_scene.instantiate()
	reward_dialog.name = "RewardSelectionDialog"  # Give it a specific name for cleanup
	$UILayer.add_child(reward_dialog)
	
	# Connect the reward selected signal
	reward_dialog.reward_selected.connect(_on_reward_selected)
	reward_dialog.advance_to_next_hole.connect(_on_advance_to_next_hole)
	
	# Show the reward selection
	reward_dialog.show_reward_selection()

func _on_reward_selected(reward_data: Resource, reward_type: String):
	"""Handle when a reward is selected"""
	if reward_data == null:
		print("ERROR: reward_data is null in _on_reward_selected! reward_type:", reward_type)
		return
	print("Reward selected:", reward_data.name, "Type:", reward_type)
	
	if reward_type == "equipment":
		var equip_data = reward_data as EquipmentData
		# TODO: Apply equipment effect
		print("Equipment selected:", equip_data.name)
	
	# Special handling for hole 9 - show front nine completion dialog
	if current_hole == 8 and not is_back_9_mode:  # Hole 9 (index 8) in front 9 mode
		print("Hole 9 completed, showing front nine completion dialog")
		show_front_nine_complete_dialog()
	else:
		# Fade to next hole
		FadeManager.fade_to_black(func(): reset_for_next_hole(), 0.5)

func _on_advance_to_next_hole():
	"""Handle when the advance button is pressed"""
	print("Advance to next hole button pressed")
	
	# Special handling for hole 9 - show front nine completion dialog
	if current_hole == 8 and not is_back_9_mode:  # Hole 9 (index 8) in front 9 mode
		print("Hole 9 completed, showing front nine completion dialog")
		show_front_nine_complete_dialog()
	else:
		# Fade to next hole
		FadeManager.fade_to_black(func(): reset_for_next_hole(), 0.5)

func reset_for_next_hole():
	# Clean up any existing reward UI
	var existing_suitcase = $UILayer.get_node_or_null("SuitCase")
	if existing_suitcase:
		existing_suitcase.queue_free()
		print("Cleaned up existing suitcase")
	
	var existing_reward_dialog = $UILayer.get_node_or_null("RewardSelectionDialog")
	if existing_reward_dialog:
		existing_reward_dialog.queue_free()
		print("Cleaned up existing reward dialog")
	
	current_hole += 1
	var round_end_hole = 0
	if is_back_9_mode:
		round_end_hole = back_9_start_hole + NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		round_end_hole = NUM_HOLES - 1  # Hole 9 (index 8)
	
	if current_hole > round_end_hole:
		return
	if player_node and is_instance_valid(player_node):
		# Disable animations before hiding player for next hole
		if player_node.has_method("disable_animations"):
			player_node.disable_animations()
			print("Player movement animations disabled for next hole")
		player_node.visible = false
	
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
	build_map.build_map_from_layout_with_randomization(map_manager.level_layout)
	
	# Sync shop grid position with build_map
	shop_grid_pos = build_map.shop_grid_pos
	
	# Ensure Y-sort objects are properly registered for pin detection
	update_all_ysort_z_indices()
	print("Y-sort updated after map building")
	
	# Checkpoint: Map building completed
	print("=== BuildMapCompleted Checkpoint ===")
	
	position_camera_on_pin()  # Add camera positioning for next hole
	hole_score = 0
	game_phase = "tee_select"
	_update_player_mouse_facing_state()
	chosen_landing_spot = Vector2.ZERO
	selected_club = ""
	update_hole_and_score_display()
	if hud:
		hud.get_node("ShotLabel").text = "Shots: %d" % hole_score
	is_placing_player = true
	highlight_tee_tiles()
	show_tee_selection_instruction()

func show_course_complete_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Course Complete!"
	dialog.dialog_text = "Congratulations! You've finished all holes!\n\nTotal Score: %d strokes\n" % total_score
	dialog.add_theme_font_size_override("font_size", 20)
	dialog.add_theme_color_override("font_color", Color.CYAN)
	dialog.position = Vector2(400, 300)
	$UILayer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		get_tree().reload_current_scene()
	)

func show_front_nine_complete_dialog():
	var total_round_score = 0
	for score in round_scores:
		total_round_score += score
	
	var total_par = GolfCourseLayout.get_front_nine_par()
	var round_vs_par = total_round_score - total_par
	var score_text = "Front 9 Complete!\n\n"
	score_text += "Hole-by-Hole Scores:\n"
	
	for i in range(round_scores.size()):
		var hole_score = round_scores[i]
		var hole_par = GolfCourseLayout.get_hole_par(i)
		var hole_vs_par = hole_score - hole_par
		score_text += "Hole %d: %d strokes" % [i + 1, hole_score]
		if hole_vs_par == 0:
			score_text += " (Par)"
		elif hole_vs_par == 1:
			score_text += " (+1)"
		elif hole_vs_par == 2:
			score_text += " (+2)"
		elif hole_vs_par == -1:
			score_text += " (-1)"
		elif hole_vs_par == -2:
			score_text += " (-2)"
		else:
			score_text += " (%+d)" % hole_vs_par
		score_text += "\n"
	
	score_text += "\nFinal Round Score: %d strokes\n" % total_round_score
	score_text += "Course Par: %d\n" % total_par
	
	if round_vs_par == 0:
		score_text += "Final Result: Even Par ✓\n"
	elif round_vs_par > 0:
		score_text += "Final Result: %+d (Over Par)\n" % round_vs_par
	else:
		score_text += "Final Result: %+d (Under Par) ✓\n" % round_vs_par
	
	score_text += "\nClick to continue to the Back 9!"
	
	var dialog = AcceptDialog.new()
	dialog.title = "Front 9 Complete!"
	dialog.dialog_text = score_text
	dialog.add_theme_font_size_override("font_size", 16)
	dialog.add_theme_color_override("font_color", Color.CYAN)
	dialog.position = Vector2(400, 300)
	$UILayer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		# Transition to mid-game shop scene
		FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://MidGameShop.tscn"), 0.5)
	)

func show_back_nine_complete_dialog():
	"""Show final round score dialog for back 9 completion"""
	var total_round_score = 0
	for score in round_scores:
		total_round_score += score
	
	var total_par = GolfCourseLayout.get_back_nine_par()
	var round_vs_par = total_round_score - total_par
	
	if current_hole == 17:  # 18th hole completed
		var total_18_hole_score = total_round_score
		Global.final_18_hole_score = total_18_hole_score
		FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://EndScene.tscn"), 0.5)
		return
	
	var score_text = "Back 9 Complete!\n\n"
	score_text += "Hole-by-Hole Scores:\n"
	
	for i in range(round_scores.size()):
		var hole_score = round_scores[i]
		var hole_par = GolfCourseLayout.get_hole_par(back_9_start_hole + i)
		var hole_vs_par = hole_score - hole_par
		
		score_text += "Hole %d: %d strokes" % [back_9_start_hole + i + 1, hole_score]
		if hole_vs_par == 0:
			score_text += " (Par)"
		elif hole_vs_par == 1:
			score_text += " (+1)"
		elif hole_vs_par == 2:
			score_text += " (+2)"
		elif hole_vs_par == -1:
			score_text += " (-1)"
		elif hole_vs_par == -2:
			score_text += " (-2)"
		else:
			score_text += " (%+d)" % hole_vs_par
		score_text += "\n"
	
	score_text += "\nFinal Round Score: %d strokes\n" % total_round_score
	score_text += "Course Par: %d\n" % total_par
	
	if round_vs_par == 0:
		score_text += "Final Result: Even Par ✓\n"
	elif round_vs_par > 0:
		score_text += "Final Result: %+d (Over Par)\n" % round_vs_par
	else:
		score_text += "Final Result: %+d (Under Par) ✓\n" % round_vs_par
	
	score_text += "\nClick to return to main menu."
	
	var dialog = AcceptDialog.new()
	dialog.title = "Back 9 Complete!"
	dialog.dialog_text = score_text
	dialog.add_theme_font_size_override("font_size", 16)
	dialog.add_theme_color_override("font_color", Color.CYAN)
	dialog.position = Vector2(400, 300)
	$UILayer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		get_tree().reload_current_scene()
	)

func update_hole_and_score_display():
	if hud:
		var label = hud.get_node_or_null("HoleLabel")
		if not label:
			label = Label.new()
			label.name = "HoleLabel"
			hud.add_child(label)
		
		var current_round_score = 0
		for score in round_scores:
			current_round_score += score
		current_round_score += hole_score  # Include current hole score
		
		var total_par_so_far = 0
		if is_back_9_mode:
			for i in range(back_9_start_hole, current_hole + 1):
				total_par_so_far += GolfCourseLayout.get_hole_par(i)
		else:
			for i in range(current_hole + 1):
				total_par_so_far += GolfCourseLayout.get_hole_par(i)
		var round_vs_par = current_round_score - total_par_so_far
		
		label.text = "Hole: %d/%d    Round: %d (%+d)" % [current_hole+1, NUM_HOLES, current_round_score, round_vs_par]
		label.position = Vector2(10, 10)
		label.z_index = 200

func _on_draw_cards_pressed() -> void:
	if game_phase == "draw_cards":
		print("Drawing club cards for selection...")
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		draw_club_cards()
	elif game_phase == "ball_tile_choice":
		print("Drawing club cards for shot from ball tile...")
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		draw_club_cards()
	else:
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		draw_cards_for_shot(3)
		create_movement_buttons()
		draw_cards_button.visible = false
		print("Drew 3 new cards after ending turn. DrawCards button hidden:", draw_cards_button.visible)

func update_spin_indicator():
	launch_manager.update_spin_indicator()
	
func enter_draw_cards_phase() -> void:
	"""Enter the club selection phase where player draws club cards"""
	game_phase = "draw_cards"
	_update_player_mouse_facing_state()
	print("Entered draw cards phase - selecting club for shot")
	
	draw_cards_button.visible = true
	draw_cards_button.text = "Draw Club Cards"
	
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	

func draw_club_cards() -> void:
	print("=== DRAWING CLUB CARDS ===")
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	
	# Debug: Print deck state before drawing club cards
	print("=== DECK STATE BEFORE DRAWING CLUB CARDS ===")
	deck_manager.debug_print_state()
	print("=== END DECK STATE ===")
	
	# Calculate how many club cards we need to draw
	var base_club_count = 2  # Default number of clubs to show
	var card_draw_modifier = player_stats.get("card_draw", 0)
	var final_club_count = base_club_count + card_draw_modifier
	
	# Actually draw club cards to hand first - draw enough for the selection
	deck_manager.draw_club_cards_to_hand(final_club_count)
	
	# Debug: Print deck state after drawing club cards
	print("=== DECK STATE AFTER DRAWING CLUB CARDS ===")
	deck_manager.debug_print_state()
	print("=== END DECK STATE ===")
	print("=== END DRAWING CLUB CARDS ===")
	
	# Then get available clubs from the hand
	var available_clubs = deck_manager.hand.filter(func(card): return deck_manager.is_club_card(card))
	if Global.putt_putt_mode:
		available_clubs = available_clubs.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		)
	
	final_club_count = max(1, min(final_club_count, available_clubs.size()))
	var selected_clubs: Array[CardData] = []
	var bonus_cards: Array[CardData] = []
	if not Global.putt_putt_mode:
		var putters = available_clubs.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		)
		
		if putters.size() > 0:
			var random_putter_index = randi() % putters.size()
			var selected_putter = putters[random_putter_index]
			selected_clubs.append(selected_putter)
			available_clubs.erase(selected_putter)
			final_club_count -= 1
	var club_candidates = available_clubs.filter(func(card): return card.effect_type != "ModifyNext" and card.effect_type != "ModifyNextCard")
	for i in range(final_club_count):
		if club_candidates.size() > 0:
			var random_index = randi() % club_candidates.size()
			selected_clubs.append(club_candidates[random_index])
			club_candidates.remove_at(random_index)
	
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
	
	draw_cards_button.visible = false
	

func _on_club_card_pressed(club_name: String, club_info: Dictionary, button: TextureButton) -> void:
	selected_club = club_name
	var base_max_distance = club_info.get("max_distance", 600.0)  # Default fallback distance
	var strength_modifier = player_stats.get("strength", 0)
	var strength_multiplier = 1.0 + (strength_modifier * 0.1)  # Same multiplier as power calculation
	max_shot_distance = base_max_distance * strength_multiplier
	card_click_sound.play()
	
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

func _on_player_moved_to_tile(new_grid_pos: Vector2i) -> void:
	player_grid_pos = new_grid_pos
	movement_controller.update_player_position(new_grid_pos)
	attack_handler.update_player_position(new_grid_pos)
	
	# Check for fire damage when player moves to new tile
	check_player_fire_damage()
	
	if player_grid_pos == shop_grid_pos and not shop_entrance_detected:
		print("=== SHOP ENTRANCE DETECTED ===")
		print("Player grid position:", player_grid_pos)
		print("Shop grid position:", shop_grid_pos)
		print("Shop entrance detected flag:", shop_entrance_detected)
		shop_entrance_detected = true
		show_shop_entrance_dialog()
		return  # Don't exit movement mode yet
	elif player_grid_pos != shop_grid_pos:
		if shop_entrance_detected:
			print("Player moved away from shop entrance")
		shop_entrance_detected = false
	
	update_player_position()
	
	# Check if player is on an active ball tile
	if waiting_for_player_to_reach_ball and player_grid_pos == ball_landing_tile:
		# Player is on the ball tile - show "Draw Club Cards" button
		if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball) and launch_manager.golf_ball.has_method("remove_landing_highlight"):
			launch_manager.golf_ball.remove_landing_highlight()
		
		# Show the "Draw Club Cards" button instead of automatically entering launch phase
		show_draw_club_cards_button()
	else:
		# Normal movement - exit movement mode
		exit_movement_mode()

func show_draw_club_cards_button() -> void:
	"""Show the 'Draw Club Cards' button when player is on an active ball tile"""
	game_phase = "ball_tile_choice"
	_update_player_mouse_facing_state()
	print("Player is on ball tile - showing 'Draw Club Cards' button")
	
	# Show the "Draw Club Cards" button
	draw_cards_button.visible = true
	draw_cards_button.text = "Draw Club Cards"
	
	# Exit movement mode but don't automatically enter launch phase
	movement_controller.exit_movement_mode()
	update_deck_display()
	
	# Camera follows player to ball position using managed tween
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	create_camera_tween(player_center, 1.0)

func show_shop_entrance_dialog():
	if shop_dialog:
		shop_dialog.queue_free()
	
	shop_dialog = Control.new()
	shop_dialog.name = "ShopEntranceDialog"
	shop_dialog.size = get_viewport_rect().size
	shop_dialog.z_index = 500
	shop_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = shop_dialog.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_dialog.add_child(background)
	
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.9)
	dialog_box.size = Vector2(400, 200)
	dialog_box.position = (shop_dialog.size - dialog_box.size) / 2  # Center the dialog
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_dialog.add_child(dialog_box)
	
	var title_label := Label.new()
	title_label.text = "Golf Shop"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(150, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	var question_label := Label.new()
	question_label.text = "Would you like to enter the shop?"
	question_label.add_theme_font_size_override("font_size", 18)
	question_label.add_theme_color_override("font_color", Color.WHITE)
	question_label.position = Vector2(100, 80)
	question_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(question_label)
	
	var yes_button := Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.position = Vector2(120, 140)
	yes_button.pressed.connect(_on_shop_enter_yes)
	dialog_box.add_child(yes_button)
	
	var no_button := Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.position = Vector2(220, 140)
	no_button.pressed.connect(_on_shop_enter_no)
	dialog_box.add_child(no_button)
	
	$UILayer.add_child(shop_dialog)
	print("Shop entrance dialog created")

func _on_shop_enter_yes():
	save_game_state()
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Shop/ShopInterior.tscn"), 0.5)

func _on_shop_enter_no():
	if shop_dialog:
		shop_dialog.queue_free()
		shop_dialog = null
	
	shop_entrance_detected = false
	
	exit_movement_mode()



func _on_shop_under_construction_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if shop_dialog:
			shop_dialog.queue_free()
			shop_dialog = null
		restore_game_state()
		shop_entrance_detected = false
		exit_movement_mode()

func save_game_state():
	Global.saved_player_grid_pos = player_grid_pos
	Global.saved_ball_position = launch_manager.golf_ball.global_position if launch_manager.golf_ball else Vector2.ZERO
	Global.saved_current_turn = turn_count
	Global.saved_shot_score = hole_score
	# Save global turn count for turn-based spawning
	Global.saved_global_turn_count = Global.global_turn_count
	Global.saved_deck_manager_state = deck_manager.get_deck_state()
	Global.saved_discard_pile_state = deck_manager.get_discard_state()
	Global.saved_hand_state = deck_manager.get_hand_state()
	Global.saved_game_state = "shop_entrance"
	Global.saved_has_started = has_started
	Global.saved_game_phase = game_phase  # Save current game phase
	
	Global.saved_ball_landing_tile = ball_landing_tile
	Global.saved_ball_landing_position = ball_landing_position
	Global.saved_waiting_for_player_to_reach_ball = waiting_for_player_to_reach_ball
	Global.saved_ball_exists = (launch_manager.golf_ball != null and is_instance_valid(launch_manager.golf_ball))
	
	Global.saved_tree_positions.clear()
	Global.saved_pin_position = Vector2i.ZERO
	Global.saved_shop_position = Vector2i.ZERO
	
	for i in range(ysort_objects.size()):
		var obj_data = ysort_objects[i]
		var node = obj_data.node
		var grid_pos = obj_data.grid_pos
	
	for obj_data in ysort_objects:
		var node = obj_data.node
		var grid_pos = obj_data.grid_pos
		
		var is_tree = false
		if node.name == "Tree":
			is_tree = true
		elif node.has_method("blocks") and node.blocks():
			is_tree = true
		elif node.get_script() and node.get_script().get_path().find("Tree.gd") != -1:
			is_tree = true
		
		if is_tree:
			Global.saved_tree_positions.append(grid_pos)
		
		if node.name == "Pin" or (node.has_method("get_class") and node.get_class() == "Pin"):
			Global.saved_pin_position = grid_pos
		
		if node.name == "Shop" or (node.has_method("get_class") and node.get_class() == "Shop"):
			Global.saved_shop_position = grid_pos
	
	if Global.saved_shop_position == Vector2i.ZERO:
		Global.saved_shop_position = shop_grid_pos
		
func restore_game_state():
	if Global.saved_game_state == "shop_entrance":
		map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
		build_map_from_layout_with_saved_positions(map_manager.level_layout)
		
		# Debug: Check if pin was created
		print("=== PIN CREATION DEBUG (Saved Positions) ===")
		print("ysort_objects size after saved positions map building:", ysort_objects.size())
		for i in range(ysort_objects.size()):
			var obj = ysort_objects[i]
			if obj.has("node") and obj.node:
				print("Object", i, ":", obj.node.name, "at grid pos:", obj.grid_pos)
			else:
				print("Object", i, ": Invalid object")
		print("=== END PIN CREATION DEBUG (Saved Positions) ===")
		
		player_grid_pos = Global.saved_player_grid_pos
		update_player_position()
		if player_node:
			player_node.visible = true
		is_placing_player = false
		ball_landing_tile = Global.saved_ball_landing_tile
		ball_landing_position = Global.saved_ball_landing_position
		waiting_for_player_to_reach_ball = Global.saved_waiting_for_player_to_reach_ball
		if Global.saved_ball_exists and Global.saved_ball_position != Vector2.ZERO:
			if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
				launch_manager.golf_ball.queue_free()
			launch_manager.golf_ball = preload("res://GolfBall.tscn").instantiate()
			var ball_area = launch_manager.golf_ball.get_node_or_null("Area2D")
			if ball_area:
				ball_area.collision_layer = 1
				ball_area.collision_mask = 1  # Collide with layer 1 (trees)
			launch_manager.golf_ball.collision_layer = 1
			launch_manager.golf_ball.collision_mask = 1  # Collide with layer 1 (trees)
			var ball_local_position = Global.saved_ball_position - camera_container.global_position
			launch_manager.golf_ball.position = ball_local_position
			launch_manager.golf_ball.cell_size = cell_size
			launch_manager.golf_ball.map_manager = map_manager
			camera_container.add_child(launch_manager.golf_ball)
			launch_manager.golf_ball.add_to_group("balls")  # Add to group for collision detection
		else:
			if launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
				launch_manager.golf_ball.queue_free()
				launch_manager.golf_ball = null
		turn_count = Global.saved_current_turn
		hole_score = Global.saved_shot_score
		# Restore global turn count for turn-based spawning
		Global.global_turn_count = Global.saved_global_turn_count
		deck_manager.restore_deck_state(Global.saved_deck_manager_state)
		deck_manager.restore_discard_state(Global.saved_discard_pile_state)
		deck_manager.restore_hand_state(Global.saved_hand_state)
		has_started = Global.saved_has_started
		if Global.get("saved_game_phase") != null:
			game_phase = Global.saved_game_phase
		else:
			game_phase = "move"
		_update_player_mouse_facing_state()
		if deck_manager.hand.size() > 0:
			create_movement_buttons()
		update_deck_display()
		update_player_stats_from_equipment()
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		camera_snap_back_pos = player_center
		create_camera_tween(player_center, 1.0)
	else:
		print("No saved game state found")

func is_player_on_shop_tile() -> bool:
	return player_grid_pos == shop_grid_pos





var ghost_ball: Node2D = null
var ghost_ball_active: bool = false

func create_ghost_ball() -> void:
	if ghost_ball and is_instance_valid(ghost_ball):
		ghost_ball.queue_free()
	
	ghost_ball = preload("res://GhostBall.tscn").instantiate()
	
	var ghost_ball_area = ghost_ball.get_node_or_null("Area2D")
	if ghost_ball_area:
		ghost_ball_area.collision_layer = 1
		ghost_ball_area.collision_mask = 0  # Don't collide with anything (including player)
	
	# Position ghost ball at tile center (same as real ball)
	var tile_center: Vector2 = Vector2(player_grid_pos.x * cell_size + cell_size/2, player_grid_pos.y * cell_size + cell_size/2) + camera_container.global_position
	var ball_local_position = tile_center - camera_container.global_position
	ghost_ball.position = ball_local_position
	ghost_ball.cell_size = cell_size
	ghost_ball.map_manager = map_manager
	if selected_club in club_data:
		ghost_ball.set_club_info(club_data[selected_club])
	ghost_ball.set_putting_mode(club_data.get(selected_club, {}).get("is_putter", false))
	camera_container.add_child(ghost_ball)
	ghost_ball.add_to_group("balls")  # Add to group for collision detection
	ghost_ball_active = true
	# Global Y-sort will be handled by the ball's update_y_sort() method
	if chosen_landing_spot != Vector2.ZERO:
		ghost_ball.set_landing_spot(chosen_landing_spot)

func update_ghost_ball() -> void:
	"""Update the ghost ball's landing spot"""
	if not ghost_ball or not is_instance_valid(ghost_ball):
		return
	
	# Only update the landing spot, don't reposition the ball
	ghost_ball.set_landing_spot(chosen_landing_spot)

func remove_ghost_ball() -> void:
	"""Remove the ghost ball from the scene"""
	if ghost_ball and is_instance_valid(ghost_ball):
		ghost_ball.queue_free()
		ghost_ball = null
	ghost_ball_active = false



var current_hole := 0  # 0-based hole index (0-8 for front 9, 9-17 for back 9)
var total_score := 0
const NUM_HOLES := 9  # Number of holes per round (9 for front 9, 9 for back 9)
var is_in_pin_transition := false
var is_back_9_mode := false  # Flag to track if we're playing back 9
var back_9_start_hole := 9  # Starting hole for back 9 (hole 10, index 9)



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
	
	# Position camera directly on pin (no tween - immediate positioning)
	camera.position = pin_position
	camera_snap_back_pos = pin_position
	
	# Only start the transition if requested
	if start_transition:
		start_pin_to_tee_transition()

func start_pin_to_tee_transition():
	"""Start the pin-to-tee transition after the fade-in"""
	
	# Store the tween reference so we can cancel it if needed
	var pin_to_tee_tween = get_tree().create_tween()
	pin_to_tee_tween.set_parallel(false)  # Sequential tweens
	
	# Wait 1.5 seconds at pin (as requested)
	pin_to_tee_tween.tween_interval(1.5)
	
	# Tween to tee area
	var tee_center = _get_tee_area_center()
	var tee_center_global = camera_container.position + tee_center
	pin_to_tee_tween.tween_property(camera, "position", tee_center_global, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Update camera snap back position only if player hasn't been placed yet
	pin_to_tee_tween.tween_callback(func(): 
		if is_placing_player:
			camera_snap_back_pos = tee_center_global
	)
	
	# Store the tween reference so we can cancel it if player places early
	set_meta("pin_to_tee_tween", pin_to_tee_tween)
	
	# Clean up the tween reference when it completes
	pin_to_tee_tween.finished.connect(func():
		if has_meta("pin_to_tee_tween"):
			remove_meta("pin_to_tee_tween")
	)

func build_map_from_layout_with_saved_positions(layout: Array) -> void:
	"""Build map with saved object positions (for returning from shop)"""
	print("Building map with saved positions for hole", current_hole + 1)
	
	# Clear existing objects first
	clear_existing_objects()
	
	# Build the base map (tiles only, no pin)
	build_map.build_map_from_layout_base(layout, false)
	
	# Create object positions dictionary from saved data
	var object_positions = {
		"trees": Global.saved_tree_positions.duplicate(),
		"shop": Global.saved_shop_position,  # Use the saved shop position
		"gang_members": []  # Empty array for gang members (not saved/restored)
	}
	print("[DEBUG] About to place trees at positions:", object_positions.trees)
	
	# Place objects at saved positions
	build_map.place_objects_at_positions(object_positions, layout)
	
	# Sync shop grid position with build_map
	shop_grid_pos = build_map.shop_grid_pos
	
	# Place pin at saved position
	if Global.saved_pin_position != Vector2i.ZERO:
		var world_pos: Vector2 = Vector2(Global.saved_pin_position.x, Global.saved_pin_position.y) * cell_size
		var scene: PackedScene = object_scene_map["P"]
		if scene != null:
			var pin: Node2D = scene.instantiate() as Node2D
			var pin_id = randi()  # Generate unique ID for this pin
			pin.name = "Pin" + str(current_hole + 1)  # Give unique name based on hole number
			pin.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
			# Let the global Y-sort system handle z_index
			if pin.has_meta("grid_position") or "grid_position" in pin:
				pin.set("grid_position", Global.saved_pin_position)
			
			# Set reference to CardEffectHandler for scramble ball handling
			pin.set_meta("card_effect_handler", card_effect_handler)
			
			# Connect pin signals if this is a pin
			if pin.has_signal("hole_in_one"):
				print("Connecting hole_in_one signal for pin:", pin.name, "pin ID:", pin_id)
				# Use Callable to ensure proper connection
				pin.hole_in_one.connect(Callable(self, "_on_hole_in_one"))
				print("hole_in_one signal connected successfully")
				# Verify connection
				var connections = pin.hole_in_one.get_connections()
				print("Signal connections after connecting:", connections.size())
				for conn in connections:
					print("  - Connected to:", conn.callable)
			else:
				print("WARNING: Pin does not have hole_in_one signal!")
			if pin.has_signal("pin_flag_hit"):
				pin.pin_flag_hit.connect(_on_pin_flag_hit)
			
			ysort_objects.append({"node": pin, "grid_pos": Global.saved_pin_position})
			obstacle_layer.add_child(pin)
			print("Pin placed at saved position:", Global.saved_pin_position, "pin ID:", pin_id, "pin name:", pin.name)
		else:
			print("ERROR: Pin scene is null!")
	
	# Ensure Y-sort objects are properly registered for pin detection
	update_all_ysort_z_indices()
	print("Y-sort updated after saved positions map building")
	
	# Checkpoint: Map building completed
	print("=== BuildMapCompleted Checkpoint (Saved Positions) ===")
	
	# Position camera on pin immediately after map is built (no transition when returning from shop)
	position_camera_on_pin(false)

func update_all_ysort_z_indices():
	"""Update z_index for all objects using the simple global Y-sort system"""
	# Use the global Y-sort system for all objects
	Global.update_all_objects_y_sort(ysort_objects)

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
	
	show_hole_completion_dialog()

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
		bag.set_bag_level(1)  # Always start with level 1
		print("Bag initialized with level 1")

func _on_bag_clicked() -> void:
	# The bag handles its own click events now
	pass

func _on_inventory_closed() -> void:
	print("Inventory closed")

func get_movement_cards_for_inventory() -> Array[CardData]:
	return movement_controller.get_movement_cards_for_inventory()

func get_club_cards_for_inventory() -> Array[CardData]:
	return deck_manager.club_draw_pile.duplicate()


	

func fix_ui_layers() -> void:
	"""Fix UI layer z-indices and mouse filtering"""
	if card_hand_anchor:
		card_hand_anchor.z_index = 100
		card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if hud:
		hud.z_index = 101
		hud.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if end_turn_button:
		end_turn_button.z_index = 102
		end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	

# Add this variable declaration after the existing card modification variables (around line 75)
var card_effect_handler: Node = null
var weapon_handler: Node = null
var global_death_sound: AudioStreamPlayer = null

# Add this function at the end of the file, before the final closing brace
func _on_scramble_complete(closest_ball_position: Vector2, closest_ball_tile: Vector2i):
	"""Handle completion of Florida Scramble effect"""
	
	# Check if the ball went in the hole (if waiting_for_player_to_reach_ball is false, it went in the hole)
	if not waiting_for_player_to_reach_ball:
		print("Scramble ball went in the hole! Triggering hole completion")
		# Trigger hole completion dialog
		show_hole_completion_dialog()
		return
	
	# Update course state for normal scramble completion
	ball_landing_tile = closest_ball_tile
	ball_landing_position = closest_ball_position
	waiting_for_player_to_reach_ball = true
	
	# Note: golf_ball is already set to the closest scramble ball in CardEffectHandler
	# Show drive distance dialog for the scramble result (same as normal shots)
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var drive_distance = player_center.distance_to(closest_ball_position)
	
	var dialog_timer = get_tree().create_timer(0.5)
	dialog_timer.timeout.connect(func():
		show_drive_distance_dialog()
	)
	
	game_phase = "move"
	_update_player_mouse_facing_state()

# LaunchManager signal handlers
func _on_ball_launched(ball: Node2D):
	# Set up ball properties that require course_1.gd references
	ball.map_manager = map_manager
	
	# Check if this is a throwing knife or golf ball
	var is_knife = ball.has_method("is_throwing_knife") and ball.is_throwing_knife()
	
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
		camera_following_ball = true
		
	else:
		# Handle golf ball
		print("=== HANDLING GOLF BALL LAUNCH ===")
		
		# Play swing sound for golf ball
		play_swing_sound(ball.final_power if ball.has_method("get_final_power") else 0.0)
		
		# Set ball launch position for player collision delay system
		if player_node and player_node.has_method("set_ball_launch_position"):
			player_node.set_ball_launch_position(ball.global_position)
			print("Ball launch position set for player collision delay:", ball.global_position)
		
		# Connect ball signals
		ball.landed.connect(_on_golf_ball_landed)
		ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)
		ball.sand_landing.connect(_on_golf_ball_sand_landing)
		
		# Set camera following
		camera_following_ball = true
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
		
		# Handle elemental club effects
		if selected_club == "Fire Club":
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
		
		elif selected_club == "Ice Club":
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
	game_phase = "launch"
	_update_player_mouse_facing_state()

func _on_launch_phase_exited():
	game_phase = "ball_flying"
	_update_player_mouse_facing_state()
	# Disable player collision shape during ball flight
	if player_node and player_node.has_method("disable_collision_shape"):
		player_node.disable_collision_shape()
	
	# Update smart optimizer for ball flying phase
	if smart_optimizer:
		smart_optimizer.update_game_state("ball_flying", true, false, false)

func _on_charging_state_changed(charging: bool, charging_height: bool) -> void:
	"""Handle charging state changes from LaunchManager"""
	_update_player_mouse_facing_state()

func _on_ball_collision_detected() -> void:
	"""Handle ball collision detection - re-enable player collision shape"""
	if player_node and player_node.has_method("enable_collision_shape"):
		player_node.enable_collision_shape()

func _on_npc_attacked(npc: Node, damage: int) -> void:
	"""Handle when an NPC is attacked"""
	print("NPC attacked:", npc.name, "Damage dealt:", damage)

func _on_npc_shot(npc: Node, damage: int) -> void:
	"""Handle when an NPC is shot with a weapon"""
	print("NPC shot:", npc.name, "Damage dealt:", damage)
	
	# Play global death sound if NPC died
	if npc.has_method("get_is_dead") and npc.get_is_dead():
		if global_death_sound:
			global_death_sound.play()
			print("Playing global death sound")

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
		if player_node and camera:
			create_camera_tween(player_node.global_position, 0.5, Tween.TRANS_LINEAR)
			current_camera_tween.tween_callback(func():
				# Exit knife mode and reset camera following after tween completes
				if launch_manager:
					launch_manager.exit_knife_mode()
					print("Exited knife mode after camera tween completed")
				camera_following_ball = false
			)
		else:
			# Fallback if no player or camera
			if launch_manager:
				launch_manager.exit_knife_mode()
				print("Exited knife mode (fallback)")
			camera_following_ball = false
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

func setup_global_death_sound() -> void:
	"""Setup global death sound that can be heard from anywhere"""
	global_death_sound = AudioStreamPlayer.new()
	var death_sound = preload("res://Sounds/DeathGroan.mp3")
	global_death_sound.stream = death_sound
	global_death_sound.volume_db = 0.0
	add_child(global_death_sound)
	print("Global death sound setup complete")

func _update_player_mouse_facing_state() -> void:
	"""Update the player's mouse facing state based on current game phase and launch state"""
	if not player_node or not player_node.has_method("set_game_phase"):
		return
	
	# Update game phase
	player_node.set_game_phase(game_phase)
	
	# Update launch state from LaunchManager
	var is_charging = false
	var is_charging_height = false
	if launch_manager:
		is_charging = launch_manager.is_charging
		is_charging_height = launch_manager.is_charging_height
	
	player_node.set_launch_state(is_charging, is_charging_height)
	
	# Update launch mode state
	var is_in_launch_mode = (game_phase == "ball_flying")
	player_node.set_launch_mode(is_in_launch_mode)
	
	# Set camera reference if not already set
	if player_node.has_method("set_camera_reference") and camera:
		player_node.set_camera_reference(camera)



func _on_swing_test_button_pressed() -> void:
	"""Handle when the swing test button is pressed"""
	print("=== SWING TEST BUTTON PRESSED ===")
	if player_node:
		player_node.manual_test_swing()
	else:
		print("✗ No player node found")

# Add camera tween management variables at the top of the class
var current_camera_tween: Tween = null

func kill_current_camera_tween() -> void:
	"""Kill any currently running camera tween to prevent conflicts"""
	if current_camera_tween and current_camera_tween.is_valid():
		current_camera_tween.kill()
		current_camera_tween = null

func create_camera_tween(target_position: Vector2, duration: float = 0.5, transition: Tween.TransitionType = Tween.TRANS_SINE, ease: Tween.EaseType = Tween.EASE_OUT) -> void:
	"""Create a camera tween with proper management to prevent conflicts"""
	# Kill any existing camera tween first
	kill_current_camera_tween()
	
	# Create new tween
	current_camera_tween = get_tree().create_tween()
	current_camera_tween.tween_property(camera, "position", target_position, duration).set_trans(transition).set_ease(ease)
	
	# Clean up when tween completes
	current_camera_tween.finished.connect(func(): current_camera_tween = null)
func check_player_fire_damage() -> void:
	"""Check if player should take fire damage from active fire tiles"""
	if not player_node or not player_node.has_method("take_damage"):
		return
	
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	var player_took_damage = false
	
	for fire_tile in fire_tiles:
		if not is_instance_valid(fire_tile) or not fire_tile.has_method("is_fire_active"):
			continue
		
		# Skip if fire tile is not active (scorched)
		if not fire_tile.is_fire_active():
			continue
		
		var fire_tile_pos = fire_tile.get_tile_position()
		
		# Check if this fire tile has already damaged the player this turn
		if fire_tile_pos in fire_tiles_that_damaged_player:
			continue
		
		# Check if player is on the fire tile or adjacent to it
		if _is_player_affected_by_fire_tile(fire_tile_pos):
			# Determine damage amount
			var damage = 30 if player_grid_pos == fire_tile_pos else 15
			
			# Apply damage to player
			player_node.take_damage(damage)
			print("Player took", damage, "fire damage from fire tile at", fire_tile_pos)
			
			# Play FlameOn sound effect
			play_flame_on_sound()
			
			# Mark this fire tile as having damaged the player this turn
			fire_tiles_that_damaged_player.append(fire_tile_pos)
			player_took_damage = true
	
	if player_took_damage:
		print("Player fire damage check complete - damage applied")

func play_flame_on_sound() -> void:
	"""Play the FlameOn sound effect when player takes fire damage"""
	# Try to find an existing FlameOn sound in the scene
	var flame_sounds = get_tree().get_nodes_in_group("flame_sounds")
	if flame_sounds.size() > 0:
		var flame_sound = flame_sounds[0]
		if flame_sound and flame_sound.has_method("play"):
			flame_sound.play()
			return
	
	# Fallback: create a temporary audio player
	var temp_audio = AudioStreamPlayer2D.new()
	var sound_file = load("res://Sounds/FlameOn.mp3")
	if sound_file:
		temp_audio.stream = sound_file
		temp_audio.volume_db = -5.0  # Slightly quieter for player damage
		temp_audio.position = player_node.global_position if player_node else Vector2.ZERO
		add_child(temp_audio)
		temp_audio.play()
		# Remove the audio player after it finishes
		temp_audio.finished.connect(func(): temp_audio.queue_free())

func _is_player_affected_by_fire_tile(fire_tile_pos: Vector2i) -> bool:
	"""Check if player is on the fire tile or adjacent to it"""
	# Direct hit - player is on the fire tile
	if player_grid_pos == fire_tile_pos:
		return true
	
	# Adjacent tiles (8-directional)
	var adjacent_positions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, -1),  # Up-right
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	
	for direction in adjacent_positions:
		if player_grid_pos == fire_tile_pos + direction:
			return true
	
	return false

func reset_fire_damage_tracking() -> void:
	"""Reset the fire damage tracking at the start of each turn"""
	fire_tiles_that_damaged_player.clear()
