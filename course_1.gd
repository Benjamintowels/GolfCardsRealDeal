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
@onready var obstacle_layer = $ObstacleLayer
@onready var end_turn_button: Button = $UILayer/EndTurnButton
@onready var camera := $GameCamera
@onready var map_manager := $MapManager
@onready var build_map := $BuildMap
@onready var draw_cards_button: Button = $UILayer/DrawCards
@onready var mod_shot_room_button: Button
@onready var bag: Control = $UILayer/Bag
@onready var inventory_dialog: Control = $UILayer/InventoryDialog
@onready var launch_manager = $LaunchManager

# Movement controller
const MovementController := preload("res://MovementController.gd")
var movement_controller: MovementController
const GolfCourseLayout := preload("res://Maps/GolfCourseLayout.gd")

var is_placing_player := true

var obstacle_map: Dictionary = {}  # Vector2i -> BaseObstacle

var turn_count: int = 1

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
	}
}

# Bag pile for club cards
var bag_pile: Array[CardData] = [
	preload("res://Cards/Driver.tres"),
	preload("res://Cards/Hybrid.tres"),
	preload("res://Cards/Wood.tres"),
	preload("res://Cards/Iron.tres"),
	preload("res://Cards/Wooden.tres"),
	preload("res://Cards/Putter.tres"),
	preload("res://Cards/PitchingWedge.tres")
]



# Add these variables at the top (after var launch_power, etc.)
var charge_time := 0.0  # Time spent charging (in seconds)
var max_charge_time := 3.0  # Maximum time to fully charge (varies by distance)

# Add this variable to track objects and their grid positions
var ysort_objects := [] # Array of {node: Node2D, grid_pos: Vector2i}

# Shop interaction variables
var shop_dialog: Control = null
var shop_entrance_detected := false
var shop_grid_pos := Vector2i(2, 6)  # Position of shop from map layout

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
}

var object_to_tile_mapping := {
	"T": "Base",
	"P": "G",
	"SHOP": "Base",
	"GANG": "G",
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
			
			if is_tree or is_shop or is_pin:
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
	# Update LaunchManager
	launch_manager.chosen_landing_spot = chosen_landing_spot
	launch_manager.selected_club = selected_club
	launch_manager.club_data = club_data
	launch_manager.player_stats = player_stats
	
	if camera_following_ball and launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
		var ball_center = launch_manager.golf_ball.global_position
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", ball_center, 0.1).set_trans(Tween.TRANS_LINEAR)
	
	if card_hand_anchor and card_hand_anchor.z_index != 100:
		card_hand_anchor.z_index = 100
		card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(false)  # stop checking after setting
	
	if is_aiming_phase and aiming_circle:
		update_aiming_circle()

func _ready() -> void:
	add_to_group("course")
	if Global.putt_putt_mode:
		print("=== PUTT PUTT MODE ENABLED ===")
		print("Only putters will be available for club selection")
		print("Available putters:", bag_pile.filter(func(card): 
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
	
	call_deferred("fix_ui_layers")
	display_selected_character()
	if end_round_button:
		end_round_button.pressed.connect(_on_end_round_pressed)

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
	
	if obstacle_layer.get_parent():
		obstacle_layer.get_parent().remove_child(obstacle_layer)
	camera_container.add_child(obstacle_layer)

	map_manager.load_map_data(GolfCourseLayout.LEVEL_LAYOUT)

	deck_manager = DeckManager.new()
	add_child(deck_manager)
	deck_manager.deck_updated.connect(update_deck_display)
	deck_manager.discard_recycled.connect(card_stack_display.animate_card_recycle)
	
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
		card_effect_handler
	)

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

	is_placing_player = true
	highlight_tee_tiles()

	print("=== INITIALIZATION DEBUG ===")
	print("Loading map data for hole:", current_hole + 1)
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
	build_map.build_map_from_layout_with_randomization(map_manager.level_layout)
	hole_score = 0
	print("Map data loaded, building map...")
	print("Map built, positioning camera on pin...")
	position_camera_on_pin()  # Add the camera positioning call
	print("=== END INITIALIZATION DEBUG ===")

	update_hole_and_score_display()

	show_tee_selection_instruction()
	
	# Register any existing GangMembers with the Entities system
	register_existing_gang_members()

	var complete_hole_btn := Button.new()
	complete_hole_btn.name = "CompleteHoleButton"
	complete_hole_btn.text = "Complete Hole"
	complete_hole_btn.position = Vector2(400, 50)
	complete_hole_btn.z_index = 999
	$UILayer.add_child(complete_hole_btn)
	complete_hole_btn.pressed.connect(_on_complete_hole_pressed)

func _on_complete_hole_pressed():
	show_hole_completion_dialog()

func _input(event: InputEvent) -> void:
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
	elif game_phase == "launch":
		# Handle launch input through LaunchManager
		print("[DEBUG] In launch phase, handling input through LaunchManager")
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

	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("TileDrawer").queue_redraw()

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
	if player_node and is_instance_valid(player_node):
		player_node.position = Vector2(player_grid_pos.x, player_grid_pos.y) * cell_size + Vector2(2, 2)
		player_node.set_grid_position(player_grid_pos)
		player_node.visible = true
		update_player_position()
		return

	var player_scene = preload("res://Characters/Player1.tscn")
	player_node = player_scene.instantiate()
	player_node.name = "Player"
	player_node.position = Vector2(player_grid_pos.x, player_grid_pos.y) * cell_size + Vector2(2, 2)
	grid_container.add_child(player_node)

	var char_scene_path = ""
	var char_scale = Vector2.ONE  # Default scale
	var char_offset = Vector2.ZERO  # Default offset
	match Global.selected_character:
		1:
			char_scene_path = "res://Characters/LaylaChar.tscn"
			char_scale = Vector2(0.055, 0.055)
			char_offset = Vector2(0, -36.815)
		2:
			char_scene_path = "res://Characters/BennyChar.tscn"
			char_scale = Vector2(0.055, 0.055)
			char_offset = Vector2(0, -36.815)
		3:
			char_scene_path = "res://Characters/ClarkChar.tscn"
			char_scale = Vector2(0.055, 0.055)
			char_offset = Vector2(0, -36.815)
		_:
			char_scene_path = "res://Characters/BennyChar.tscn" # Default to Benny if unknown
			char_scale = Vector2(0.055, 0.055)
			char_offset = Vector2(0, -36.815)
	if char_scene_path != "":
		var char_scene = load(char_scene_path)
		if char_scene:
			var char_instance = char_scene.instantiate()
			char_instance.scale = char_scale  # Apply the scale
			char_instance.position = char_offset  # Apply the offset
			player_node.add_child(char_instance)

	var base_mobility = player_stats.get("base_mobility", 0)
	player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
	
	player_node.set_grid_position(player_grid_pos)

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

func update_player_position() -> void:
	if not player_node:
		return
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)

	player_node.position = Vector2(player_grid_pos.x, player_grid_pos.y) * cell_size + Vector2(2, 2)

	player_node.set_grid_position(player_grid_pos, ysort_objects)
	
	var player_center: Vector2 = player_node.global_position + player_size / 2
	camera_snap_back_pos = player_center
	
	if not is_placing_player:
		print("=== CAMERA MOVEMENT DEBUG ===")
		print("update_player_position moving camera from", camera.position, "to", player_center)
		print("player_node.visible:", player_node.visible, "is_placing_player:", is_placing_player)
		
		# Check if there's an ongoing pin-to-tee transition
		var ongoing_tween = get_meta("pin_to_tee_tween", null)
		if ongoing_tween and ongoing_tween.is_valid():
			print("Cancelling ongoing pin-to-tee transition for player placement")
			ongoing_tween.kill()
			remove_meta("pin_to_tee_tween")
		
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "position", player_center, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		print("=== END CAMERA MOVEMENT DEBUG ===")

func create_movement_buttons() -> void:
	movement_controller.create_movement_buttons()
	

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

func _on_tile_mouse_exited(x: int, y: int) -> void:
	movement_controller.handle_tile_mouse_exited(x, y, is_panning)

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
				var sprite = player_node.get_node_or_null("Sprite2D")
				var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
				var player_center = player_node.global_position + player_size / 2
				camera_snap_back_pos = player_center
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
			else:
				print("Invalid movement tile or not in movement mode")

func start_round_after_tee_selection() -> void:
	var instruction_label = $UILayer.get_node_or_null("TeeInstructionLabel")
	if instruction_label:
		instruction_label.queue_free()
	
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("Highlight").visible = false
	
	player_stats = Global.CHARACTER_STATS.get(Global.selected_character, {})
	
	deck_manager.initialize_deck(deck_manager.starter_deck)
	print("Deck initialized with", deck_manager.draw_pile.size(), "cards")

	has_started = true
	
	hole_score = 0
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
	
	var circle = ColorRect.new()
	circle.name = "CircleVisual"
	circle.size = Vector2(adjusted_circle_size, adjusted_circle_size)
	circle.color = Color(1, 0, 0, 0.6)  # Red with transparency
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(circle)
	
	circle.draw.connect(_draw_circle.bind(circle))
	
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

func _draw_circle(circle: ColorRect):
	var center = circle.size / 2
	var radius = min(circle.size.x, circle.size.y) / 2
	circle.draw_circle(center, radius, Color(1, 0, 0, 0.8))
	circle.draw_arc(center, radius, 0, 2 * PI, 32, Color(1, 0, 0, 1.0), 2.0)

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
			circle.color = Color(0, 1, 0, 0.8)  # Green
		else:
			circle.color = Color(1, 0, 0, 0.8)  # Red
	
	var target_camera_pos = clamped_position
	var current_camera_pos = camera.position
	var camera_speed = 5.0  # Adjust for faster/slower camera movement
	
	var new_camera_pos = current_camera_pos.lerp(target_camera_pos, camera_speed * get_process_delta_time())
	camera.position = new_camera_pos
	
	
	var distance_label = aiming_circle.get_node_or_null("DistanceLabel")
	if distance_label:
		distance_label.text = str(int(clamped_distance)) + "px"

func launch_golf_ball(direction: Vector2, charged_power: float, height: float):
	launch_manager.launch_golf_ball(direction, charged_power, height)
	
func _on_golf_ball_landed(tile: Vector2i):
	hole_score += 1
	camera_following_ball = false
	ball_landing_tile = tile
	
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
	update_deck_display()

func _on_end_turn_pressed() -> void:
	if movement_controller.is_in_movement_mode():
		exit_movement_mode()

	var cards_to_discard = deck_manager.hand.size()
	
	for card in deck_manager.hand:
		deck_manager.discard(card)
	deck_manager.hand.clear()
	movement_controller.clear_all_movement_ui()
	turn_count += 1
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
	"""Find the nearest NPC that is visible to the player"""
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

func transition_camera_to_npc(npc: Node) -> void:
	"""Transition camera to focus on the NPC"""
	if not npc:
		print("ERROR: No NPC provided for camera transition")
		return
	
	var npc_pos = npc.global_position
	print("Transitioning camera to NPC at position: ", npc_pos)
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", npc_pos, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

func transition_camera_to_player() -> void:
	"""Transition camera back to the player"""
	if not player_node:
		print("ERROR: No player node found for camera transition")
		return
	
	var player_center = player_node.global_position
	print("Transitioning camera back to player at position: ", player_center)
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

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

func update_deck_display() -> void:
	var hud := get_node("UILayer/HUD")
	hud.get_node("TurnLabel").text = "Turn: %d" % turn_count
	hud.get_node("DrawLabel").text = "Draw Pile: %d" % deck_manager.draw_pile.size()
	hud.get_node("DiscardLabel").text = "Discard Pile: %d" % deck_manager.discard_pile.size()
	hud.get_node("ShotLabel").text = "Shots: %d" % hole_score
	card_stack_display.update_draw_stack(deck_manager.draw_pile.size())
	card_stack_display.update_discard_stack(deck_manager.discard_pile.size())

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
		draw_cards_button.visible = true
		draw_cards_button.text = "Draw Cards"
		var dialog_player_sprite = player_node.get_node_or_null("Sprite2D")
		var dialog_player_size = dialog_player_sprite.texture.get_size() * dialog_player_sprite.scale if dialog_player_sprite and dialog_player_sprite.texture else Vector2(cell_size, cell_size)
		var player_center: Vector2 = player_node.global_position + dialog_player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func setup_swing_sounds() -> void:
	swing_strong_sound = $SwingStrong
	swing_med_sound = $SwingMed
	swing_soft_sound = $SwingSoft
	water_plunk_sound = $WaterPlunk
	sand_thunk_sound = $SandThunk

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
	
	hole_score += 1
	if launch_manager.golf_ball:
		launch_manager.golf_ball.queue_free()
		launch_manager.golf_ball = null
	show_out_of_bounds_dialog()
	ball_landing_tile = shot_start_grid_pos
	ball_landing_position = Vector2(shot_start_grid_pos.x * cell_size + cell_size/2, shot_start_grid_pos.y * cell_size + cell_size/2)
	waiting_for_player_to_reach_ball = true
	player_grid_pos = shot_start_grid_pos
	update_player_position()
	game_phase = "draw_cards"

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
	
func enter_aiming_phase() -> void:
	game_phase = "aiming"
	is_aiming_phase = true
	
	# Set the shot start position to where the player currently is
	shot_start_grid_pos = player_grid_pos
	print("Shot started from position:", shot_start_grid_pos)
	
	show_aiming_circle()
	create_ghost_ball()
	show_aiming_instruction()
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	var card_draw_modifier = player_stats.get("card_draw", 0)
	var final_card_count = card_count + card_draw_modifier
	final_card_count = max(1, final_card_count)
	
	deck_manager.draw_cards(final_card_count)

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
			reset_for_next_hole()
		else:
			if is_back_9_mode:
				show_back_nine_complete_dialog()
			else:
				show_front_nine_complete_dialog()
	)

func reset_for_next_hole():
	current_hole += 1
	var round_end_hole = 0
	if is_back_9_mode:
		round_end_hole = back_9_start_hole + NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		round_end_hole = NUM_HOLES - 1  # Hole 9 (index 8)
	
	if current_hole > round_end_hole:
		return
	if player_node and is_instance_valid(player_node):
		player_node.visible = false
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
	build_map.build_map_from_layout_with_randomization(map_manager.level_layout)
	position_camera_on_pin()  # Add camera positioning for next hole
	hole_score = 0
	game_phase = "tee_select"
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
	
	score_text += "\nClick to return to main menu."
	
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
		get_tree().reload_current_scene()
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
	print("Entered draw cards phase - selecting club for shot")
	
	draw_cards_button.visible = true
	draw_cards_button.text = "Draw Club Cards"
	
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	

func draw_club_cards() -> void:
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	var available_clubs = bag_pile.duplicate()
	if Global.putt_putt_mode:
		available_clubs = available_clubs.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		)
	
	var base_club_count = 2  # Default number of clubs to show
	var card_draw_modifier = player_stats.get("card_draw", 0)
	var final_club_count = base_club_count + card_draw_modifier
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
	var base_max_distance = club_info["max_distance"]
	var strength_modifier = player_stats.get("strength", 0)
	var strength_multiplier = 1.0 + (strength_modifier * 0.1)  # Same multiplier as power calculation
	max_shot_distance = base_max_distance * strength_multiplier
	card_click_sound.play()
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	enter_aiming_phase()

func _on_player_moved_to_tile(new_grid_pos: Vector2i) -> void:
	player_grid_pos = new_grid_pos
	movement_controller.update_player_position(new_grid_pos)
	
	if player_grid_pos == shop_grid_pos and not shop_entrance_detected:
		shop_entrance_detected = true
		show_shop_entrance_dialog()
		return  # Don't exit movement mode yet
	elif player_grid_pos != shop_grid_pos:
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
	print("Player is on ball tile - showing 'Draw Club Cards' button")
	
	# Show the "Draw Club Cards" button
	draw_cards_button.visible = true
	draw_cards_button.text = "Draw Club Cards"
	
	# Exit movement mode but don't automatically enter launch phase
	movement_controller.exit_movement_mode()
	update_deck_display()
	
	# Camera follows player to ball position
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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

func show_shop_under_construction_dialog():
	if shop_dialog:
		shop_dialog.queue_free()
	
	shop_dialog = Control.new()
	shop_dialog.name = "ShopUnderConstructionDialog"
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
	dialog_box.position = Vector2(400, 200)
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_dialog.add_child(dialog_box)
	
	var title_label := Label.new()
	title_label.text = "Shop Under Construction"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.ORANGE)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(100, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	var message_label := Label.new()
	message_label.text = "Shop under construction, brb!\n\nClick to return to the course."
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.position = Vector2(100, 80)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(message_label)
	
	var instruction_label := Label.new()
	instruction_label.text = "Click anywhere to continue"
	instruction_label.add_theme_font_size_override("font_size", 14)
	instruction_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	instruction_label.position = Vector2(120, 150)
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(instruction_label)
	background.gui_input.connect(_on_shop_under_construction_input)
	
	$UILayer.add_child(shop_dialog)

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
		build_map.build_map_from_layout_with_saved_positions(map_manager.level_layout)
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
		deck_manager.restore_deck_state(Global.saved_deck_manager_state)
		deck_manager.restore_discard_state(Global.saved_discard_pile_state)
		deck_manager.restore_hand_state(Global.saved_hand_state)
		has_started = Global.saved_has_started
		if Global.get("saved_game_phase") != null:
			game_phase = Global.saved_game_phase
		else:
			game_phase = "move"
		if deck_manager.hand.size() > 0:
			create_movement_buttons()
		update_deck_display()
		update_player_stats_from_equipment()
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		camera_snap_back_pos = player_center
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		print("No saved game state found")

func is_player_on_shop_tile() -> bool:
	return player_grid_pos == shop_grid_pos

func build_map_from_layout(layout: Array) -> void:
	obstacle_map.clear()
	ysort_objects.clear() # Clear previous objects
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size

			var tile_code: String = code
			if object_scene_map.has(code):
				tile_code = object_to_tile_mapping[code]
			if tile_scene_map.has(tile_code):
				var scene: PackedScene = tile_scene_map[tile_code]
				if scene == null:
					push_error("🚫 Tile scene for code '%s' is null at (%d,%d)" % [tile_code, x, y])
					continue
				var tile: Node2D = scene.instantiate() as Node2D
				if tile == null:
					push_error("❌ Tile instantiation failed for '%s' at (%d,%d)" % [tile_code, x, y])
					continue
				tile.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				tile.z_index = -5  # Ensure tiles are behind player & UI
				var sprite: Sprite2D = tile.get_node_or_null("Sprite2D")
				if sprite and sprite.texture:
					var texture_size: Vector2 = sprite.texture.get_size()
					if texture_size.x > 0 and texture_size.y > 0:
						var scale_x = cell_size / texture_size.x
						var scale_y = cell_size / texture_size.y
						sprite.scale = Vector2(scale_x, scale_y)
				if tile.has_meta("grid_position") or "grid_position" in tile:
					tile.set("grid_position", pos)
				else:
					push_warning("⚠️ Tile missing 'grid_position'. Type: %s" % tile.get_class())
				obstacle_layer.add_child(tile)
				obstacle_map[pos] = tile
			else:
				print("ℹ️ Skipping unmapped tile code '%s' at (%d,%d)" % [tile_code, x, y])
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size
			if object_scene_map.has(code):
				var scene: PackedScene = object_scene_map[code]
				if scene == null:
					push_error("🚫 Object scene for code '%s' is null at (%d,%d)" % [code, x, y])
					continue
				var object: Node2D = scene.instantiate() as Node2D
				if object == null:
					push_error("❌ Object instantiation failed for '%s' at (%d,%d)" % [code, x, y])
					continue
				object.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				if object.has_meta("grid_position") or "grid_position" in object:
					object.set("grid_position", pos)
				else:
					push_warning("⚠️ Object missing 'grid_position'. Type: %s" % object.get_class())
				
				# Set reference to CardEffectHandler for pins (scramble ball handling)
				if code == "P":
					object.set_meta("card_effect_handler", card_effect_handler)
				
				ysort_objects.append({"node": object, "grid_pos": pos})
				obstacle_layer.add_child(object)
				
				if object.has_signal("hole_in_one"):
					object.hole_in_one.connect(_on_hole_in_one)
				if object.has_signal("pin_flag_hit"):
					object.pin_flag_hit.connect(_on_pin_flag_hit)
				
				if object.has_method("blocks") and object.blocks():
					obstacle_map[pos] = object
				if code == "T":
					print("Tree created at grid position:", pos, "world position:", object.position, "global position:", object.global_position)
					if pos.x >= 16 and pos.x <= 18 and pos.y >= 10 and pos.y <= 12:
						print("*** TREE IN BALL PATH! Grid:", pos, "World:", object.position, "Global:", object.global_position)
				
				if code == "SHOP":
					var right_of_shop_pos = pos + Vector2i(1, 0)
					var blocker_scene = preload("res://Obstacles/InvisibleBlocker.tscn")
					var blocker = blocker_scene.instantiate()
					var blocker_world_pos = Vector2(right_of_shop_pos.x, right_of_shop_pos.y) * cell_size
					blocker.position = blocker_world_pos + Vector2(cell_size / 2, cell_size / 2)
					obstacle_layer.add_child(blocker)
					obstacle_map[right_of_shop_pos] = blocker
				
			elif not tile_scene_map.has(code):
				print("ℹ️ Skipping unmapped code '%s' at (%d,%d)" % [code, x, y])

func focus_camera_on_tee():
	var tee_center_local := _get_tee_area_center()
	var tee_center_global := camera_container.position + tee_center_local
	camera_snap_back_pos = tee_center_global
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", tee_center_global, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

var ghost_ball: Node2D = null
var ghost_ball_active: bool = false

func create_ghost_ball() -> void:
	if ghost_ball and is_instance_valid(ghost_ball):
		ghost_ball.queue_free()
	
	ghost_ball = preload("res://GhostBall.tscn").instantiate()
	
	var ghost_ball_area = ghost_ball.get_node_or_null("Area2D")
	if ghost_ball_area:
		ghost_ball_area.collision_layer = 1
		ghost_ball_area.collision_mask = 1  # Collide with layer 1 (trees)
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	
	player_center += Vector2(0, -cell_size * 0.5)

	var ball_local_position = player_center - camera_container.global_position
	ghost_ball.position = ball_local_position
	ghost_ball.cell_size = cell_size
	ghost_ball.map_manager = map_manager
	if selected_club in club_data:
		ghost_ball.set_club_info(club_data[selected_club])
	ghost_ball.set_putting_mode(club_data.get(selected_club, {}).get("is_putter", false))
	camera_container.add_child(ghost_ball)
	ghost_ball.add_to_group("balls")  # Add to group for collision detection
	ghost_ball_active = true
	update_ball_y_sort(ghost_ball)
	if chosen_landing_spot != Vector2.ZERO:
		ghost_ball.set_landing_spot(chosen_landing_spot)

func update_ghost_ball() -> void:
	"""Update the ghost ball's landing spot and launch it"""
	if not ghost_ball or not is_instance_valid(ghost_ball):
		return
	
	ghost_ball.set_landing_spot(chosen_landing_spot)

func remove_ghost_ball() -> void:
	"""Remove the ghost ball from the scene"""
	if ghost_ball and is_instance_valid(ghost_ball):
		ghost_ball.queue_free()
		ghost_ball = null
	ghost_ball_active = false

func update_ball_y_sort(ball_node: Node2D) -> void:
	if not ball_node or not is_instance_valid(ball_node):
		return

	var ball_global_pos = ball_node.global_position
	var ball_ground_pos = ball_global_pos
	if ball_node.has_method("get_ground_position"):
		ball_ground_pos = ball_node.get_ground_position()
	else:
		ball_ground_pos = ball_global_pos

	var ball_height = 0.0
	if ball_node.has_method("get_height"):
		ball_height = ball_node.get_height()
	elif "z" in ball_node:
		ball_height = ball_node.z

	var ball_sprite = ball_node.get_node_or_null("Sprite2D")
	if not ball_sprite:
		return

	# First, check if ball should be in front of or behind the pin
	var pin_node = null
	var pin_z_index = 1000  # Default pin z_index
	for obj in ysort_objects:
		if not obj.has("node") or not obj["node"] or not is_instance_valid(obj["node"]):
			continue
		
		var node = obj["node"]
		if node.name == "Pin" or "Pin" in node.name:
			pin_node = node
			pin_z_index = node.z_index
			break
	
	# If we found a pin, check if ball should be in front of it
	if pin_node != null:
		var pin_y = pin_node.global_position.y
		var ball_y = ball_ground_pos.y
		
		# If ball is below pin (higher Y coordinate), it should be in front
		if ball_y > pin_y:
			ball_sprite.z_index = pin_z_index + 10  # Higher than pin z_index
		else:
			ball_sprite.z_index = pin_z_index - 10  # Lower than pin z_index
		
		# Update shadow z_index
		var ball_shadow = ball_node.get_node_or_null("Shadow")
		if ball_shadow:
			ball_shadow.z_index = ball_sprite.z_index - 1
			if ball_shadow.z_index <= -5:
				ball_shadow.z_index = 1
		return

	# If no pin found, fall back to tree-based Y-sorting
	var closest_tree = null
	var closest_tree_y = 0.0
	var closest_tree_z = 0
	var min_dist = INF
	for obj in ysort_objects:
		if not obj.has("node") or not obj["node"] or not is_instance_valid(obj["node"]):
			continue
		
		var node = obj["node"]
		var is_tree = node.name == "Tree" or (node.get_script() and "Tree.gd" in str(node.get_script().get_path()))
		
		if is_tree:
			var tree_node = node
			var tree_y_sort_point = tree_node.global_position.y
			if tree_node.has_method("get_y_sort_point"):
				tree_y_sort_point = tree_node.get_y_sort_point()
			
			var tree_pos_2d = Vector2(tree_node.global_position.x, tree_y_sort_point)
			var ball_pos_2d = Vector2(ball_ground_pos.x, ball_ground_pos.y)
			var dist = ball_pos_2d.distance_to(tree_pos_2d)
			
			if dist < min_dist:
				min_dist = dist
				closest_tree = tree_node
				closest_tree_y = tree_y_sort_point
				closest_tree_z = tree_node.z_index

	if closest_tree != null:
		var tree_height = 1500.0  # Updated from 100.0 to 1500.0 to match max ball height of 2000
		
		var max_tree_distance = 200.0  # Only consider trees within 200 pixels
		if min_dist > max_tree_distance:
			ball_sprite.z_index = 100  # Default to in front
			return
		
		if ball_height >= tree_height:
			ball_sprite.z_index = closest_tree_z + 10  # Higher than tree z_index
		else:
			var significant_height_threshold = 200.0  # If ball is more than 200 pixels high, it should appear in front
			if ball_height >= significant_height_threshold:
				ball_sprite.z_index = closest_tree_z + 10
			else:
				var tree_threshold = closest_tree_y + 50  # 50 pixels higher threshold
				if ball_ground_pos.y > tree_threshold:
					ball_sprite.z_index = closest_tree_z + 10  # Higher than tree z_index
				else:
					ball_sprite.z_index = closest_tree_z - 10  # Lower than tree z_index to appear behind
	else:
		ball_sprite.z_index = 100  # Default to in front

	var ball_shadow = ball_node.get_node_or_null("Shadow")
	if ball_shadow:
		ball_shadow.z_index = ball_sprite.z_index - 1
		if ball_shadow.z_index <= -5:
			ball_shadow.z_index = 1

var current_hole := 0  # 0-based hole index (0-8 for front 9, 9-17 for back 9)
var total_score := 0
const NUM_HOLES := 9  # Number of holes per round (9 for front 9, 9 for back 9)
var is_in_pin_transition := false
var is_back_9_mode := false  # Flag to track if we're playing back 9
var back_9_start_hole := 9  # Starting hole for back 9 (hole 10, index 9)



func find_pin_position() -> Vector2:
	"""Find the position of the pin in the current hole"""
	print("Searching for pin in ysort_objects (size:", ysort_objects.size(), ")")
	
	# First try to find by name in ysort_objects
	for obj in ysort_objects:
		if obj.has("node") and obj.node and is_instance_valid(obj.node):
			# Check if this is the pin by name or by checking if it has the pin script
			if obj.node.name == "Pin" or "Pin" in obj.node.name or obj.node.has_method("_on_area_entered"):
				print("Found pin in ysort_objects at:", obj.node.global_position, "name:", obj.node.name)
				return obj.node.global_position
	
	# If not found in ysort_objects, search in obstacle_layer
	print("Pin not found in ysort_objects, searching obstacle_layer...")
	
	# Search for any object with "Pin" in the name or pin script
	for child in obstacle_layer.get_children():
		if "Pin" in child.name or child.has_method("_on_area_entered"):
			print("Found pin in obstacle_layer at:", child.global_position, "name:", child.name)
			return child.global_position
	
	# Search recursively in all children of obstacle_layer
	print("Searching recursively in obstacle_layer...")
	for child in obstacle_layer.get_children():
		if child.has_method("get_children"):
			for grandchild in child.get_children():
				if "Pin" in grandchild.name or grandchild.has_method("_on_area_entered"):
					print("Found pin as grandchild at:", grandchild.global_position, "name:", grandchild.name)
					return grandchild.global_position
	
	# Search in the entire scene tree
	print("Searching entire scene tree for pin...")
	var pin_node = find_child_by_name_recursive(self, "Pin")
	if pin_node:
		print("Found pin in scene tree at:", pin_node.global_position)
		return pin_node.global_position
	
	print("No pin found anywhere!")
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
	print("=== POSITION CAMERA ON PIN DEBUG ===")
	print("Positioning camera on pin...")
	
	# Add a small delay to ensure everything is properly added to the scene
	await get_tree().process_frame
	
	# Find pin position
	var pin_position = find_pin_position()
	if pin_position == Vector2.ZERO:
		print("Warning: No pin found, positioning camera at center")
		camera.position = Vector2(0, 0)
		return
	
	print("Pin found at:", pin_position)
	
	# Position camera directly on pin (no tween - immediate positioning)
	camera.position = pin_position
	camera_snap_back_pos = pin_position
	print("Camera positioned on pin at:", camera.position)
	
	# Only start the transition if requested
	if start_transition:
		print("Starting pin-to-tee transition...")
		start_pin_to_tee_transition()
	else:
		print("Skipping pin-to-tee transition (returning from shop)")
	print("=== END POSITION CAMERA ON PIN DEBUG ===")

func start_pin_to_tee_transition():
	"""Start the pin-to-tee transition after the fade-in"""
	print("Current camera position:", camera.position)
	
	# Store the tween reference so we can cancel it if needed
	var pin_to_tee_tween = get_tree().create_tween()
	pin_to_tee_tween.set_parallel(false)  # Sequential tweens
	
	# Wait 1.5 seconds at pin (as requested)
	print("Waiting 1.5 seconds at pin...")
	pin_to_tee_tween.tween_interval(1.5)
	
	# Tween to tee area
	var tee_center = _get_tee_area_center()
	var tee_center_global = camera_container.position + tee_center
	print("Tweening from pin to tee at", tee_center_global)
	pin_to_tee_tween.tween_property(camera, "position", tee_center_global, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Update camera snap back position only if player hasn't been placed yet
	pin_to_tee_tween.tween_callback(func(): 
		if is_placing_player:
			camera_snap_back_pos = tee_center_global
			print("Pin-to-tee transition complete - set snap back to tee center")
		else:
			print("Pin-to-tee transition complete - player already placed, keeping current snap back")
	)
	
	# Store the tween reference so we can cancel it if player places early
	set_meta("pin_to_tee_tween", pin_to_tee_tween)
	
	# Clean up the tween reference when it completes
	pin_to_tee_tween.finished.connect(func():
		if has_meta("pin_to_tee_tween"):
			remove_meta("pin_to_tee_tween")
	)
	
	print("=== END START PIN TO TEE TRANSITION DEBUG ===")

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
		"shop": Global.saved_shop_position  # Use the saved shop position
	}
	print("[DEBUG] About to place trees at positions:", object_positions.trees)
	
	# Place objects at saved positions
	build_map.place_objects_at_positions(object_positions, layout)
	
	# Place pin at saved position
	if Global.saved_pin_position != Vector2i.ZERO:
		var world_pos: Vector2 = Vector2(Global.saved_pin_position.x, Global.saved_pin_position.y) * cell_size
		var scene: PackedScene = object_scene_map["P"]
		if scene != null:
			var pin: Node2D = scene.instantiate() as Node2D
			var pin_id = randi()  # Generate unique ID for this pin
			pin.name = "Pin"
			pin.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
			pin.z_index = 1000  # Set high Z-index to ensure pin is always visible
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
	
	# Position camera on pin immediately after map is built (no transition when returning from shop)
	position_camera_on_pin(false)

func update_all_ysort_z_indices():
	"""Update z_index for all objects in ysort_objects based on their Y position"""
	
	# Sort objects by Y position (lower Y = higher z_index)
	var sorted_objects = ysort_objects.duplicate()
	sorted_objects.sort_custom(func(a, b): return a.grid_pos.y < b.grid_pos.y)
	
	# Assign z_index based on Y position
	for i in range(sorted_objects.size()):
		var obj = sorted_objects[i]
		if not obj.has("node") or not obj.has("grid_pos"):
			continue
		
		var node = obj.node
		if not node or not is_instance_valid(node):
			continue
		
		# Check if this is a tree by name or script
		var is_tree = node.name == "Tree" or (node.get_script() and "Tree.gd" in str(node.get_script().get_path()))
		
		# Base z_index on Y position (lower Y = higher z_index)
		var base_z = 10 + (sorted_objects.size() - i) * 10
		
		# Special handling for different object types
		if node.name == "Pin":
			# Skip pins - they have a fixed high z_index
			continue
		elif node.name == "Shop":
			node.z_index = base_z + 3  # Shop should be higher than most objects
		elif is_tree:
			node.z_index = base_z + 5  # Trees should be higher than most objects
		else:
			node.z_index = base_z

func get_layout_at_position(pos: Vector2i) -> String:
	"""Get the tile type at a specific grid position"""
	if pos.y >= 0 and pos.y < map_manager.level_layout.size():
		if pos.x >= 0 and pos.x < map_manager.level_layout[pos.y].size():
			return map_manager.level_layout[pos.y][pos.x]
	return ""

func _on_hole_in_one(score: int):
	"""Handle hole completion when ball goes in the hole"""
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
	# Connect bag click signal
	if bag and bag.has_signal("bag_clicked"):
		bag.bag_clicked.connect(_on_bag_clicked)
	
	if inventory_dialog:
		inventory_dialog.get_movement_cards = get_movement_cards_for_inventory
		inventory_dialog.get_club_cards = get_club_cards_for_inventory
		inventory_dialog.inventory_closed.connect(_on_inventory_closed)
	
	if bag and bag.has_method("set_bag_level"):
		bag.set_bag_level(1)  # Always start with level 1
		print("Bag initialized with level 1")

func _on_bag_clicked() -> void:
	if inventory_dialog:
		inventory_dialog.show_inventory()

func _on_inventory_closed() -> void:
	print("Inventory closed")

func get_movement_cards_for_inventory() -> Array[CardData]:
	return movement_controller.get_movement_cards_for_inventory()

func get_club_cards_for_inventory() -> Array[CardData]:
	return bag_pile.duplicate()


	

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

# LaunchManager signal handlers
func _on_ball_launched(ball: Node2D):
	# Set up ball properties that require course_1.gd references
	ball.map_manager = map_manager
	update_ball_y_sort(ball)
	play_swing_sound(ball.final_power if ball.has_method("get_final_power") else 0.0)
	
	# Connect ball signals
	ball.landed.connect(_on_golf_ball_landed)
	ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)
	ball.sand_landing.connect(_on_golf_ball_sand_landing)
	
	# Set camera following
	camera_following_ball = true
	
	# Handle card effects
	if sticky_shot_active and next_shot_modifier == "sticky_shot":
		ball.sticky_shot_active = true
		sticky_shot_active = false
		next_shot_modifier = ""
	
	if bouncey_shot_active and next_shot_modifier == "bouncey_shot":
		ball.bouncey_shot_active = true
		bouncey_shot_active = false
		next_shot_modifier = ""

func _on_launch_phase_entered():
	game_phase = "launch"

func _on_launch_phase_exited():
	game_phase = "ball_flying"
