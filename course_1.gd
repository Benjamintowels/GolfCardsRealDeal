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
@onready var draw_cards_button: Button = $UILayer/DrawCards
@onready var mod_shot_room_button: Button
@onready var bag: Control = $UILayer/Bag
@onready var inventory_dialog: Control = $UILayer/InventoryDialog

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

var golf_ball: Node2D = null
var power_meter: Control = null
var height_meter: Control = null
var launch_power := 0.0
var launch_height := 0.0
var launch_direction := Vector2.ZERO
var is_charging := false
var is_charging_height := false
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0
const POWER_CHARGE_RATE := 300.0 # units per second (reduced from 900.0)
const MAX_LAUNCH_HEIGHT := 2000.0
const MIN_LAUNCH_HEIGHT := 400.0
const HEIGHT_CHARGE_RATE := 600.0 # units per second
const HEIGHT_SWEET_SPOT_MIN := 0.4 # 40% of max height
const HEIGHT_SWEET_SPOT_MAX := 0.6 # 60% of max height

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

# Add at the top with other variables
var original_aim_mouse_pos: Vector2 = Vector2.ZERO
var launch_spin: float = 0.0
var current_charge_mouse_pos: Vector2 = Vector2.ZERO
var spin_indicator: Line2D = null
var is_putting: bool = false  # Flag for putter-only rolling mechanics

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

# --- 1. Add these variables at the top (after var launch_power, etc.) ---
var power_for_target := 0.0
var max_power_for_bar := 0.0

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
}

var object_to_tile_mapping := {
	"T": "Base",
	"P": "G",
	"SHOP": "Base",
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

func is_valid_position_for_object(pos: Vector2i, layout: Array) -> bool:
	"""Check if a position is valid for placing trees or shop"""
	# Check bounds
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	
	# Get tile type at position
	var tile_type = layout[pos.y][pos.x]
	
	# Don't place on restricted areas
	if tile_type in ["F", "Tee", "G", "W", "S", "P"]:
		return false
	
	# Don't place on water, sand, or pin
	if tile_type in ["W", "S", "P"]:
		return false
	
	# NEW RULE: Don't place trees within 2 tiles of the edge of the Green
	# Check if position is within 2 tiles of any Green tile
	for dy in range(-2, 3):  # Check 2 tiles in each direction
		for dx in range(-2, 3):
			var check_x = pos.x + dx
			var check_y = pos.y + dy
			# Check bounds for the position we're checking
			if check_x >= 0 and check_y >= 0 and check_y < layout.size() and check_x < layout[check_y].size():
				if layout[check_y][check_x] == "G":
					return false  # Too close to Green
	
	# Check 8x8 grid spacing rule with other placed objects (increased from 6x6)
	for placed_pos in placed_objects:
		var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
		if distance < 8:
			return false
	
	return true

func get_random_positions_for_objects(layout: Array, num_trees: int = 8, include_shop: bool = true) -> Dictionary:
	"""Generate random positions for trees and shop"""
	var positions = {
		"trees": [],
		"shop": Vector2i.ZERO
	}
	
	# Set random seed based on current hole for consistent placement
	randomize()  # Ensure proper randomization
	random_seed_value = current_hole * 1000 + randi()
	seed(random_seed_value)
	print("=== RANDOMIZATION DEBUG ===")
	print("Random seed for hole", current_hole + 1, ":", random_seed_value)
	print("Current hole:", current_hole)
	print("Target trees:", num_trees)
	print("Include shop:", include_shop)
	
	var valid_positions: Array[Vector2i] = []
	
	# Find all valid positions
	for y in layout.size():
		for x in layout[y].size():
			var pos = Vector2i(x, y)
			if is_valid_position_for_object(pos, layout):
				valid_positions.append(pos)
	
	print("Found", valid_positions.size(), "valid positions for objects")
	
	# Place shop first (if needed)
	if include_shop and valid_positions.size() > 0:
		var shop_index = randi() % valid_positions.size()
		positions.shop = valid_positions[shop_index]
		placed_objects.append(positions.shop)
		valid_positions.remove_at(shop_index)
		print("Shop placed at:", positions.shop)
	
	# Place trees
	var trees_placed = 0
	while trees_placed < num_trees and valid_positions.size() > 0:
		var tree_index = randi() % valid_positions.size()
		var tree_pos = valid_positions[tree_index]
		
		# Double-check spacing rule
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
			print("Tree placed at:", tree_pos)
		
		valid_positions.remove_at(tree_index)
	
	print("Placed", positions.trees.size(), "trees and shop at", positions.shop)
	print("=== END RANDOMIZATION DEBUG ===")
	return positions

func build_map_from_layout_with_randomization(layout: Array) -> void:
	"""Build map with randomized object placement"""
	print("=== BUILD MAP WITH RANDOMIZATION DEBUG ===")
	print("Building map with randomization for hole", current_hole + 1)
	print("Current hole variable:", current_hole)
	print("Layout size:", layout.size(), "x", layout[0].size() if layout.size() > 0 else "empty")
	
	# Ensure proper randomization for this map build
	randomize()
	
	# Clear existing objects first
	print("About to clear existing objects...")
	clear_existing_objects()
	
	# Build the base map (tiles only)
	build_map_from_layout_base(layout)
	
	# Generate random positions for objects
	var object_positions = get_random_positions_for_objects(layout, 8, true)
	
	# Place objects at random positions
	place_objects_at_positions(object_positions, layout)
	position_camera_on_pin()

func build_map_from_layout_base(layout: Array, place_pin: bool = true) -> void:
	"""Build only the base tiles without objects"""
	obstacle_map.clear()
	
	# Place all tiles (ground only)
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size

			# Only place tiles, skip objects for now (except Pin which should be placed in fixed position)
			var tile_code: String = code
			if object_scene_map.has(code) and code != "P":
				# This is an object, place the appropriate tile underneath
				tile_code = object_to_tile_mapping[code]
			
			# Place the tile
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
				
				# Scale tiles to match grid size
				var sprite: Sprite2D = tile.get_node_or_null("Sprite2D")
				if sprite and sprite.texture:
					var texture_size: Vector2 = sprite.texture.get_size()
					if texture_size.x > 0 and texture_size.y > 0:
						var scale_x = cell_size / texture_size.x
						var scale_y = cell_size / texture_size.y
						sprite.scale = Vector2(scale_x, scale_y)
				
				# Set grid_position if the property exists
				if tile.has_meta("grid_position") or "grid_position" in tile:
					tile.set("grid_position", pos)
				else:
					push_warning("⚠️ Tile missing 'grid_position'. Type: %s" % tile.get_class())
				
				obstacle_layer.add_child(tile)
				obstacle_map[pos] = tile
			else:
				print("ℹ️ Skipping unmapped tile code '%s' at (%d,%d)" % [tile_code, x, y])
	
	# --- Pin randomization on Green (not on edge) ---
	if place_pin:
		# Set the same random seed used for other object placement
		randomize()  # Ensure proper randomization
		random_seed_value = current_hole * 1000 + randi()
		seed(random_seed_value)
		
		var green_positions: Array = []
		var green_inner_positions: Array = []
		# First, collect all green tile positions
		for y in layout.size():
			for x in layout[y].size():
				if layout[y][x] == "G":
					green_positions.append(Vector2i(x, y))
		# Now, filter out edge green tiles
		for pos in green_positions:
			var x = pos.x
			var y = pos.y
			var is_edge = false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx < 0 or ny < 0 or ny >= layout.size() or nx >= layout[ny].size():
						is_edge = true
					elif layout[ny][nx] != "G":
						is_edge = true
			if not is_edge:
				green_inner_positions.append(pos)
		
		# Pick a random inner green tile for the Pin
		var pin_pos = Vector2i.ZERO
		if green_inner_positions.size() > 0:
			pin_pos = green_inner_positions[randi() % green_inner_positions.size()]
		elif green_positions.size() > 0:
			pin_pos = green_positions[randi() % green_positions.size()]
		else:
			# Fallback: try to find ANY green tile in the layout
			for y in layout.size():
				for x in layout[y].size():
					if layout[y][x] == "G":
						pin_pos = Vector2i(x, y)
						break
				if pin_pos != Vector2i.ZERO:
					break
		
		# Place the Pin at the chosen position
		if pin_pos != Vector2i.ZERO:
			var world_pos: Vector2 = Vector2(pin_pos.x, pin_pos.y) * cell_size
			var scene: PackedScene = object_scene_map["P"]
			if scene != null:
				var pin: Node2D = scene.instantiate() as Node2D
				pin.name = "Pin"
				pin.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				pin.z_index = 1000  # Set high Z-index to ensure pin is always visible
				if pin.has_meta("grid_position") or "grid_position" in pin:
					pin.set("grid_position", pin_pos)
				
				# Set reference to CardEffectHandler for scramble ball handling
				pin.set_meta("card_effect_handler", card_effect_handler)
			
				obstacle_layer.add_child(pin)
				
				# Connect pin signals if this is a pin
				if pin.has_signal("hole_in_one"):
					pin.hole_in_one.connect(_on_hole_in_one)
				if pin.has_signal("pin_flag_hit"):
					pin.pin_flag_hit.connect(_on_pin_flag_hit)
				
				# DEBUG: Add pin to ysort_objects for proper layering
				ysort_objects.append({"node": pin, "grid_pos": pin_pos})
				
				# Update z-indices for all objects including the new pin
				update_all_ysort_z_indices()

func place_objects_at_positions(object_positions: Dictionary, layout: Array) -> void:
	"""Place objects at the specified positions"""
	print("Placing objects at positions:", object_positions)
	
	# Place trees
	for tree_pos in object_positions.trees:
		print("[DEBUG] Placing tree at:", tree_pos)
		var scene: PackedScene = object_scene_map["T"]
		if scene == null:
			push_error("🚫 Tree scene is null")
			continue
		var tree: Node2D = scene.instantiate() as Node2D
		if tree == null:
			push_error("❌ Tree instantiation failed at (%d,%d)" % [tree_pos.x, tree_pos.y])
			continue
		var world_pos: Vector2 = Vector2(tree_pos.x, tree_pos.y) * cell_size
		tree.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		# Don't set z_index here - let update_all_ysort_z_indices handle it
		if tree.has_meta("grid_position") or "grid_position" in tree:
			tree.set("grid_position", tree_pos)
		else:
			push_warning("⚠️ Tree missing 'grid_position'. Type: %s" % tree.get_class())
		ysort_objects.append({"node": tree, "grid_pos": tree_pos})
		obstacle_layer.add_child(tree)
		if tree.has_method("blocks") and tree.blocks():
			obstacle_map[tree_pos] = tree
		print("[DEBUG] Tree placed at:", tree_pos)
	print("Placed", object_positions.trees.size(), "trees")
	
	# Place shop
	if object_positions.shop != Vector2i.ZERO:
		var scene: PackedScene = object_scene_map["SHOP"]
		if scene == null:
			push_error("🚫 Shop scene is null")
		else:
			var shop: Node2D = scene.instantiate() as Node2D
			if shop == null:
				push_error("❌ Shop instantiation failed at (%d,%d)" % [object_positions.shop.x, object_positions.shop.y])
			else:
				var world_pos: Vector2 = Vector2(object_positions.shop.x, object_positions.shop.y) * cell_size
				shop.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				if shop.has_meta("grid_position") or "grid_position" in shop:
					shop.set("grid_position", object_positions.shop)
				ysort_objects.append({"node": shop, "grid_pos": object_positions.shop})
				obstacle_layer.add_child(shop)
				shop_grid_pos = object_positions.shop
				var right_of_shop_pos = object_positions.shop + Vector2i(1, 0)
				var blocker_scene = preload("res://Obstacles/InvisibleBlocker.tscn")
				var blocker = blocker_scene.instantiate()
				var blocker_world_pos = Vector2(right_of_shop_pos.x, right_of_shop_pos.y) * cell_size
				blocker.position = blocker_world_pos + Vector2(cell_size / 2, cell_size / 2)
				obstacle_layer.add_child(blocker)
				obstacle_map[right_of_shop_pos] = blocker
	update_all_ysort_z_indices()

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
	if is_charging and game_phase == "launch":
		max_charge_time = 3.0  # Default for close shots
		if chosen_landing_spot != Vector2.ZERO:
			var sprite = player_node.get_node_or_null("Sprite2D")
			var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
			var player_center = player_node.global_position + player_size / 2
			var distance_to_target = player_center.distance_to(chosen_landing_spot)
			var distance_factor = distance_to_target / max_shot_distance
			max_charge_time = 3.0 - (distance_factor * 2.0)  # 3.0 to 1.0 seconds
			max_charge_time = clamp(max_charge_time, 1.0, 3.0)
		
		charge_time = min(charge_time + delta, max_charge_time)
		
		if power_meter:
			var meter_fill = power_meter.get_node_or_null("MeterFill")
			var value_label = power_meter.get_node_or_null("PowerValue")
			var time_percent = charge_time / max_charge_time
			time_percent = clamp(time_percent, 0.0, 1.0)
			
			if meter_fill:
				meter_fill.size.x = 300 * time_percent
				if time_percent >= 0.65 and time_percent <= 0.75:
					meter_fill.color = Color(0, 1, 0, 0.8)
					if player_node and player_node.has_method("show_highlight"):
						player_node.show_highlight()
				else:
					meter_fill.color = Color(1, 0.8, 0.2, 0.8)
					if player_node and player_node.has_method("hide_highlight"):
						player_node.hide_highlight()
			if value_label:
				value_label.text = str(int(time_percent * 100)) + "%"
	
	if is_charging_height and game_phase == "launch":
		launch_height = min(launch_height + HEIGHT_CHARGE_RATE * delta, MAX_LAUNCH_HEIGHT)
		if height_meter:
			var meter_fill = height_meter.get_node_or_null("MeterFill")
			var value_label = height_meter.get_node_or_null("HeightValue")
			if meter_fill:
				var height_percentage = (launch_height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
				meter_fill.size.y = 300 * height_percentage
				meter_fill.position.y = 330 - meter_fill.size.y  # Start from bottom
			if value_label:
				value_label.text = str(int(launch_height))
			
			var height_percentage = (launch_height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
			if meter_fill:
				if height_percentage >= HEIGHT_SWEET_SPOT_MIN and height_percentage <= HEIGHT_SWEET_SPOT_MAX:
					meter_fill.color = Color(0, 1, 0, 0.8)  # Green for sweet spot
				else:
					meter_fill.color = Color(1, 0.8, 0.2, 0.8)  # Yellow for other areas
	
	if game_phase == "launch" and (is_charging or is_charging_height):
		current_charge_mouse_pos = get_global_mouse_position()
	
	if camera_following_ball and golf_ball and is_instance_valid(golf_ball):
		var ball_center = golf_ball.global_position
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", ball_center, 0.1).set_trans(Tween.TRANS_LINEAR)
	
	if card_hand_anchor and card_hand_anchor.z_index != 100:
		card_hand_anchor.z_index = 100
		card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(false)  # stop checking after setting
	
	if is_aiming_phase and aiming_circle:
		update_aiming_circle()
	
	if game_phase == "launch" and not is_charging and not is_charging_height and spin_indicator and spin_indicator.visible:
		update_spin_indicator()
	if (is_charging or is_charging_height) and spin_indicator and spin_indicator.visible:
		spin_indicator.visible = false

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
	
	# Initialize movement controller
	movement_controller = MovementController.new()
	add_child(movement_controller)
	
	call_deferred("fix_ui_layers")
	display_selected_character()
	if end_round_button:
		end_round_button.pressed.connect(_on_end_round_pressed)

	create_grid()
	create_player()

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
	print("Map data loaded, building map...")
	build_map_from_layout_with_randomization(map_manager.level_layout)
	print("Map built, camera should be positioned on pin")
	print("=== END INITIALIZATION DEBUG ===")

	update_hole_and_score_display()

	show_tee_selection_instruction()

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
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed and not is_charging and not is_charging_height:
					is_charging = true
					charge_time = 0.0  # Reset charge time
					
					if player_node and player_node.has_method("force_reset_highlight"):
						print("Force resetting highlight state for new charge")
						player_node.force_reset_highlight()
					
					var input_start_sprite = player_node.get_node_or_null("Sprite2D")
					var input_start_player_size = input_start_sprite.texture.get_size() * input_start_sprite.scale if input_start_sprite and input_start_sprite.texture else Vector2(cell_size, cell_size)
					var input_start_player_center = player_node.global_position + input_start_player_size / 2
					launch_direction = (chosen_landing_spot - input_start_player_center).normalized()
				elif not event.pressed and is_charging:
					is_charging = false
					
					if player_node and player_node.has_method("hide_highlight"):
						player_node.hide_highlight()
						
					if is_putting:
						print("Putter: Skipping height charge, launching directly")
						launch_golf_ball(launch_direction, 0.0, launch_height)  # Pass 0.0 since we calculate power from charge_time
						hide_power_meter()
						game_phase = "ball_flying"
					else:
						is_charging_height = true
						launch_height = MIN_LAUNCH_HEIGHT
				elif not event.pressed and is_charging_height:
					is_charging_height = false
					launch_golf_ball(launch_direction, 0.0, launch_height)  # Pass 0.0 since we calculate power from charge_time
					hide_power_meter()
					hide_height_meter()
					game_phase = "ball_flying"
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				if is_charging or is_charging_height:
					is_charging = false
					is_charging_height = false
					charge_time = 0.0  # Reset charge time
					
					if player_node and player_node.has_method("hide_highlight"):
						player_node.hide_highlight()
					
					hide_power_meter()
					if not is_putting:
						hide_height_meter()
		elif event is InputEventMouseMotion and (is_charging or is_charging_height):
			# Update direction while charging (but keep the same landing spot)
			var input_motion_sprite = player_node.get_node_or_null("Sprite2D")
			var input_motion_player_size = input_motion_sprite.texture.get_size() * input_motion_sprite.scale if input_motion_sprite and input_motion_sprite.texture else Vector2(cell_size, cell_size)
			var input_motion_player_center = player_node.global_position + input_motion_player_size / 2
			launch_direction = (chosen_landing_spot - input_motion_player_center).normalized()
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
		var mouse_pos = get_global_mouse_position()
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
	var mouse_pos: Vector2 = get_global_mouse_position()
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

func handle_modify_next_card(card: CardData) -> void:
	"""Handle cards with ModifyNext effect type"""
	print("Handling ModifyNext card:", card.name)
	
	if card.name == "Sticky Shot":
		sticky_shot_active = true
		next_shot_modifier = "sticky_shot"
		print("StickyShot effect applied to next shot")
		
		if deck_manager.hand.has(card):
			deck_manager.discard(card)
			card_stack_display.animate_card_discard(card.name)
			update_deck_display()
			create_movement_buttons()  # Refresh the card display
		else:
			print("Error: StickyShot card not found in hand")
	
	elif card.name == "Bouncey":
		bouncey_shot_active = true
		next_shot_modifier = "bouncey_shot"
		print("Bouncey effect applied to next shot")
		
		if deck_manager.hand.has(card):
			deck_manager.discard(card)
			card_stack_display.animate_card_discard(card.name)
			update_deck_display()
			create_movement_buttons()  # Refresh the card display
		else:
			print("Error: Bouncey card not found in hand")
	
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
	if power_meter:
		power_meter.queue_free()
	
	power_for_target = MIN_LAUNCH_POWER  # Default if no target
	max_power_for_bar = MAX_LAUNCH_POWER  # Default

	if chosen_landing_spot != Vector2.ZERO:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
		# Use your existing logic for physics compensation
		var ball_physics_factor = 0.8  # Reduced from 1.8 to 0.8
		var base_power_per_distance = 0.6  # Reduced from 1.2 to 0.6
		var required_power = distance_to_target * base_power_per_distance * ball_physics_factor
		power_for_target = max(required_power, 0.0)
		# 100% = target + 25% of club's max power
		var club_max = club_data[selected_club]["max_distance"] if selected_club in club_data else MAX_LAUNCH_POWER
		max_power_for_bar = power_for_target + 0.25 * club_max
		print("=== POWER BAR MAPPING DEBUG ===")
		print("Distance to target:", distance_to_target)
		print("Power for target (75%):", power_for_target)
		print("Club max:", club_max)
		print("Max power for bar (100%):", max_power_for_bar)
		print("=== END POWER BAR MAPPING DEBUG ===")
	
	power_meter = Control.new()
	power_meter.name = "PowerMeter"
	power_meter.size = Vector2(350, 80)
	power_meter.position = Vector2(50, get_viewport_rect().size.y - 120)
	$UILayer.add_child(power_meter)
	power_meter.z_index = 200
	
	var background := ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1, 0.8)
	background.size = power_meter.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(background)
	
	var border := ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.size = Vector2(power_meter.size.x + 4, power_meter.size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(border)
	border.z_index = -1
	
	var title_label := Label.new()
	title_label.text = "CHARGE TIME (0-100%)"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(10, 5)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(title_label)
	
	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.2, 0.2, 0.2, 0.9)
	meter_bg.size = Vector2(300, 20)
	meter_bg.position = Vector2(10, 30)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(meter_bg)
	
	var sweet_spot := ColorRect.new()
	sweet_spot.name = "SweetSpot"
	sweet_spot.color = Color(0, 0.8, 0, 0.3)  # Green with transparency
	sweet_spot.size = Vector2(30, 20)  # 10% of 300 (65-75% = 10% range)
	sweet_spot.position = Vector2(195, 30)  # 65% of 300 = 195
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(sweet_spot)
	
	var meter_fill := ColorRect.new()
	meter_fill.name = "MeterFill"
	meter_fill.color = Color(1, 0.8, 0.2, 0.8)
	meter_fill.size = Vector2(0, 20)  # Start at 0 width
	meter_fill.position = Vector2(10, 30)
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(meter_fill)
	
	var value_label := Label.new()
	value_label.name = "PowerValue"
	value_label.text = "0%"  # Start at 0%
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.add_theme_constant_override("outline_size", 1)
	value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	value_label.position = Vector2(320, 30)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(value_label)
	
	var min_label := Label.new()
	min_label.text = "0%"
	min_label.add_theme_font_size_override("font_size", 10)
	min_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	min_label.position = Vector2(10, 55)
	min_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(min_label)
	
	var max_label := Label.new()
	max_label.text = "100%"
	max_label.add_theme_font_size_override("font_size", 10)
	max_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	max_label.position = Vector2(280, 55)
	max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(max_label)
	
	power_meter.set_meta("max_power_for_bar", max_power_for_bar)
	power_meter.set_meta("power_for_target", power_for_target)

func hide_power_meter():
	if power_meter:
		power_meter.queue_free()
		power_meter = null

func show_height_meter():
	if height_meter:
		height_meter.queue_free()
	
	height_meter = Control.new()
	height_meter.name = "HeightMeter"
	height_meter.size = Vector2(80, 350)
	height_meter.position = Vector2(get_viewport_rect().size.x - 130, get_viewport_rect().size.y - 400)
	$UILayer.add_child(height_meter)
	height_meter.z_index = 200
	
	var background := ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1, 0.8)
	background.size = height_meter.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(background)
	
	var border := ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.size = Vector2(height_meter.size.x + 4, height_meter.size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(border)
	border.z_index = -1
	
	var title_label := Label.new()
	title_label.text = "HEIGHT"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(5, 5)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(title_label)
	
	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.2, 0.2, 0.2, 0.9)
	meter_bg.size = Vector2(20, 300)
	meter_bg.position = Vector2(30, 30)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(meter_bg)
	
	var sweet_spot := ColorRect.new()
	sweet_spot.name = "SweetSpot"
	sweet_spot.color = Color(0, 0.8, 0, 0.3)
	sweet_spot.size = Vector2(20, 60)  # 20% of 300
	sweet_spot.position = Vector2(30, 120)  # Center of the meter
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(sweet_spot)
	
	var meter_fill := ColorRect.new()
	meter_fill.name = "MeterFill"
	meter_fill.color = Color(1, 0.8, 0.2, 0.8)
	meter_fill.size = Vector2(20, 100)
	meter_fill.position = Vector2(30, 230)  # Start from bottom
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(meter_fill)
	
	var value_label := Label.new()
	value_label.name = "HeightValue"
	value_label.text = "400"
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.add_theme_constant_override("outline_size", 1)
	value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	value_label.position = Vector2(55, 30)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(value_label)
	
	var max_label := Label.new()
	max_label.text = "MAX"
	max_label.add_theme_font_size_override("font_size", 10)
	max_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	max_label.position = Vector2(55, 30)
	max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(max_label)
	
	var min_label := Label.new()
	min_label.text = "MIN"
	min_label.add_theme_font_size_override("font_size", 10)
	min_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	min_label.position = Vector2(55, 320)
	min_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(min_label)

func hide_height_meter():
	if height_meter:
		height_meter.queue_free()
		height_meter = null

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
	var mouse_pos = get_global_mouse_position()
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
	# Check if scramble effect is active
	if card_effect_handler and card_effect_handler.is_scramble_active():
		# Clear any existing golf ball before launching scramble balls
		if golf_ball and is_instance_valid(golf_ball):
			golf_ball.queue_free()
			golf_ball = null
		
		# Calculate final power for scramble balls
		var time_percent = charge_time / max_charge_time
		time_percent = clamp(time_percent, 0.0, 1.0)
		var actual_power = 0.0
		
		if chosen_landing_spot != Vector2.ZERO:
			var player_sprite = player_node.get_node_or_null("Sprite2D")
			var player_size = player_sprite.texture.get_size() * player_sprite.scale if player_sprite and player_sprite.texture else Vector2(cell_size, cell_size)
			var player_center = player_node.global_position + player_size / 2
			var distance_to_target = player_center.distance_to(chosen_landing_spot)
			var reference_distance = 1200.0
			var distance_factor = distance_to_target / reference_distance
			var ball_physics_factor = 0.8 + (distance_factor * 0.4)
			var base_power_per_distance = 0.6 + (distance_factor * 0.2)
			var base_power_for_target = distance_to_target * base_power_per_distance * ball_physics_factor
			
			var club_efficiency = 1.0
			if selected_club in club_data:
				var club_max = club_data[selected_club]["max_distance"]
				var efficiency_factor = 1200.0 / club_max
				club_efficiency = sqrt(efficiency_factor)
				club_efficiency = clamp(club_efficiency, 0.7, 1.5)
			
			var power_for_target = base_power_for_target * club_efficiency
			
			if is_putting:
				var base_putter_power = 300.0
				actual_power = time_percent * base_putter_power
			elif time_percent <= 0.75:
				actual_power = (time_percent / 0.75) * power_for_target
				var trailoff_forgiveness = club_data[selected_club].get("trailoff_forgiveness", 0.5) if selected_club in club_data else 0.5
				var undercharge_factor = 1.0 - (time_percent / 0.75)
				var trailoff_penalty = undercharge_factor * (1.0 - trailoff_forgiveness)
				actual_power = actual_power * (1.0 - trailoff_penalty)
			else:
				var overcharge_bonus = ((time_percent - 0.75) / 0.25) * (0.25 * max_shot_distance)
				actual_power = power_for_target + overcharge_bonus
		else:
			actual_power = time_percent * MAX_LAUNCH_POWER
		
		var height_percentage = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
		height_percentage = clamp(height_percentage, 0.0, 1.0)
		var height_resistance_multiplier = 1.0
		if height_percentage > HEIGHT_SWEET_SPOT_MAX:
			var excess_height = height_percentage - HEIGHT_SWEET_SPOT_MAX
			var max_excess = 1.0 - HEIGHT_SWEET_SPOT_MAX
			var resistance_factor = excess_height / max_excess
			height_resistance_multiplier = 1.0 - (resistance_factor * 0.5)
		
		var final_power = actual_power * height_resistance_multiplier
		var strength_modifier = player_stats.get("strength", 0)
		if strength_modifier != 0:
			var strength_multiplier = 1.0 + (strength_modifier * 0.1)
			final_power *= strength_multiplier
		
		card_effect_handler.launch_scramble_balls(direction, final_power, height, launch_spin)
		hide_power_meter()
		if not is_putting:
			hide_height_meter()
		game_phase = "ball_flying"
		return
	
	var player_sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = player_sprite.texture.get_size() * player_sprite.scale if player_sprite and player_sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2

	var launch_direction = (chosen_landing_spot - player_center).normalized() if chosen_landing_spot != Vector2.ZERO else Vector2.ZERO

	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	var actual_power = 0.0
	if chosen_landing_spot != Vector2.ZERO:
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
		var reference_distance = 1200.0  # Driver's max distance as reference
		var distance_factor = distance_to_target / reference_distance
		var ball_physics_factor = 0.8 + (distance_factor * 0.4)  # Reduced from 1.2 to 0.4 (0.8 to 1.2)
		var base_power_per_distance = 0.6 + (distance_factor * 0.2)  # Reduced from 0.8 to 0.2 (0.6 to 0.8)
		
		var base_power_for_target = distance_to_target * base_power_per_distance * ball_physics_factor
		
		var club_efficiency = 1.0
		if selected_club in club_data:
			var club_max = club_data[selected_club]["max_distance"]
			var efficiency_factor = 1200.0 / club_max
			club_efficiency = sqrt(efficiency_factor)
			club_efficiency = clamp(club_efficiency, 0.7, 1.5)
		
		var power_for_target = base_power_for_target * club_efficiency
		
		if is_putting:
			var base_putter_power = 300.0  # Base power for putters
			actual_power = time_percent * base_putter_power
		elif time_percent <= 0.75:
			actual_power = (time_percent / 0.75) * power_for_target
			var trailoff_forgiveness = club_data[selected_club].get("trailoff_forgiveness", 0.5) if selected_club in club_data else 0.5
			var undercharge_factor = 1.0 - (time_percent / 0.75)  # 0.0 to 1.0
			var trailoff_penalty = undercharge_factor * (1.0 - trailoff_forgiveness)
			actual_power = actual_power * (1.0 - trailoff_penalty)
		else:
			var overcharge_bonus = ((time_percent - 0.75) / 0.25) * (0.25 * max_shot_distance)
			actual_power = power_for_target + overcharge_bonus
	else:
		actual_power = time_percent * MAX_LAUNCH_POWER
	shot_start_grid_pos = player_grid_pos
	hole_score += 1
	update_deck_display()
	var aim_deviation = current_charge_mouse_pos - original_aim_mouse_pos
	var launch_dir_perp = Vector2(-launch_direction.y, launch_direction.x) # Perpendicular to launch direction
	var spin_strength = aim_deviation.dot(launch_dir_perp)
	launch_spin = clamp(spin_strength * 1.0, -800, 800)  # Increased from 0.1 to 1.0 and max from 200 to 800
	var spin_abs = abs(spin_strength)
	var spin_strength_category = 0  # 0=green, 1=yellow, 2=red
	if spin_abs > 120:
		spin_strength_category = 2  # Red - high spin
	elif spin_abs > 48:
		spin_strength_category = 1  # Yellow - medium spin
	else:
		spin_strength_category = 0  # Green - low spin

	var height_percentage = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
	height_percentage = clamp(height_percentage, 0.0, 1.0)

	var height_resistance_multiplier = 1.0
	if height_percentage > HEIGHT_SWEET_SPOT_MAX:  # Above 60% height
		var excess_height = height_percentage - HEIGHT_SWEET_SPOT_MAX
		var max_excess = 1.0 - HEIGHT_SWEET_SPOT_MAX  # 0.4 (from 60% to 100%)
		var resistance_factor = excess_height / max_excess  # 0.0 to 1.0
		height_resistance_multiplier = 1.0 - (resistance_factor * 0.5)  # Reduce power by up to 50%

	var final_power = actual_power * height_resistance_multiplier
	
	var strength_modifier = player_stats.get("strength", 0)
	if strength_modifier != 0:
		var strength_multiplier = 1.0 + (strength_modifier * 0.1)
		final_power *= strength_multiplier
		print("Character strength modifier applied: +", strength_modifier, " (", (strength_modifier * 10), "% power)")

	print("=== POWER DEBUG ===")
	var debug_distance = 0.0
	if chosen_landing_spot != Vector2.ZERO:
		debug_distance = player_center.distance_to(chosen_landing_spot)
	print("Distance to target:", debug_distance)
	print("Time percent:", time_percent)
	print("Actual power:", actual_power)
	print("Final power:", final_power)
	print("=== END POWER DEBUG ===")

	if golf_ball:
		golf_ball.queue_free()
	golf_ball = preload("res://GolfBall.tscn").instantiate()
	var ball_area = golf_ball.get_node_or_null("Area2D")
	if ball_area:
		ball_area.collision_layer = 1
		ball_area.collision_mask = 1  # Collide with layer 1 (trees)
	
	var ball_setup_player_sprite = player_node.get_node_or_null("Sprite2D")
	var ball_setup_player_size = ball_setup_player_sprite.texture.get_size() * ball_setup_player_sprite.scale if ball_setup_player_sprite and ball_setup_player_sprite.texture else Vector2(cell_size, cell_size)
	var ball_setup_player_center = player_node.global_position + ball_setup_player_size / 2

	var ball_position_offset = Vector2(0, -cell_size * 0.5)
	ball_setup_player_center += ball_position_offset

	var ball_local_position = ball_setup_player_center - camera_container.global_position
	golf_ball.position = ball_local_position
	golf_ball.cell_size = cell_size
	golf_ball.map_manager = map_manager  # Pass map manager reference for tile-based friction
	camera_container.add_child(golf_ball)  # Add to camera container instead of main scene
	golf_ball.add_to_group("balls")  # Add to group for collision detection
	print("Golf ball added to scene at position:", golf_ball.position)
	print("Golf ball node z_index:", golf_ball.z_index)
	print("Golf ball visible:", golf_ball.visible)
	print("Golf ball global position:", golf_ball.global_position)
	
	update_ball_y_sort(golf_ball)
	var shadow = golf_ball.get_node_or_null("Shadow")
	var ball_sprite = golf_ball.get_node_or_null("Sprite2D")
	play_swing_sound(final_power)  # Use final_power for sound
	golf_ball.chosen_landing_spot = chosen_landing_spot
	golf_ball.club_info = club_data[selected_club] if selected_club in club_data else {}
	golf_ball.is_putting = is_putting
	golf_ball.time_percentage = time_percent
	if sticky_shot_active and next_shot_modifier == "sticky_shot":
		golf_ball.sticky_shot_active = true
		sticky_shot_active = false
		next_shot_modifier = ""
	
	if bouncey_shot_active and next_shot_modifier == "bouncey_shot":
		golf_ball.bouncey_shot_active = true
		bouncey_shot_active = false
		next_shot_modifier = ""
	golf_ball.launch(launch_direction, final_power, height, launch_spin, spin_strength_category)  # Pass spin strength category
	golf_ball.landed.connect(_on_golf_ball_landed)
	golf_ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)  # Connect out of bounds signal
	golf_ball.sand_landing.connect(_on_golf_ball_sand_landing)  # Connect sand landing signal
	camera_following_ball = true
	
func _on_golf_ball_landed(tile: Vector2i):
	hole_score += 1
	camera_following_ball = false
	ball_landing_tile = tile
	ball_landing_position = golf_ball.global_position if golf_ball else Vector2.ZERO
	waiting_for_player_to_reach_ball = true
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var player_start_pos = player_center
	var ball_landing_pos = golf_ball.global_position if golf_ball else player_start_pos
	drive_distance = player_start_pos.distance_to(ball_landing_pos)
	var dialog_timer = get_tree().create_timer(0.5)  # Reduced from 1.5 to 0.5 second delay
	dialog_timer.timeout.connect(func():
		show_drive_distance_dialog()
	)
	game_phase = "move"
	
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

	if waiting_for_player_to_reach_ball and player_grid_pos == ball_landing_tile:
		if golf_ball and is_instance_valid(golf_ball) and golf_ball.has_method("remove_landing_highlight"):
			golf_ball.remove_landing_highlight()
		
		enter_draw_cards_phase()  # Start with club selection phase
	else:
		draw_cards_for_shot(3)
		create_movement_buttons()
		draw_cards_button.visible = false

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
	var power_percentage = (power - MIN_LAUNCH_POWER) / (MAX_LAUNCH_POWER - MIN_LAUNCH_POWER)
	power_percentage = clamp(power_percentage, 0.0, 1.0)
	
	if power_percentage >= 0.7:  # Strong swing (70%+ power)
		swing_strong_sound.play()
	elif power_percentage >= 0.4:  # Medium swing (40-70% power)
		swing_med_sound.play()
	else:  # Soft swing (0-40% power)
		swing_soft_sound.play()

func start_next_shot_from_ball() -> void:
	if golf_ball and is_instance_valid(golf_ball):
		golf_ball.queue_free()
		golf_ball = null
	
	waiting_for_player_to_reach_ball = false
	update_player_position()
	enter_draw_cards_phase()
	

func _on_golf_ball_out_of_bounds():
	
	if water_plunk_sound and water_plunk_sound.stream:
		water_plunk_sound.play()
	camera_following_ball = false
	
	hole_score += 1
	if golf_ball:
		golf_ball.queue_free()
		golf_ball = null
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
	game_phase = "launch"
	remove_ghost_ball()
	charge_time = 0.0
	original_aim_mouse_pos = get_global_mouse_position()
	show_power_meter()
	if not is_putting:
		show_height_meter()
		launch_height = MIN_LAUNCH_HEIGHT
	else:
		launch_height = 0.0
	
	var scaled_min_power = power_meter.get_meta("scaled_min_power", MIN_LAUNCH_POWER)
	launch_power = scaled_min_power
	
	if chosen_landing_spot != Vector2.ZERO:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if not is_putting:
		if not spin_indicator:
			spin_indicator = Line2D.new()
			spin_indicator.width = 12 # Make it thick for testing
			spin_indicator.default_color = Color(1, 1, 0, 1) # Bright yellow for testing
			spin_indicator.z_index = 999
			camera_container.add_child(spin_indicator)
		spin_indicator.z_index = 999
		spin_indicator.visible = true
		update_spin_indicator()
	else:
		if spin_indicator:
			spin_indicator.visible = false
	
func enter_aiming_phase() -> void:
	game_phase = "aiming"
	is_aiming_phase = true
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
	if is_putting:
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
	if golf_ball and map_manager:
		var final_tile = Vector2i(floor(golf_ball.position.x / cell_size), floor(golf_ball.position.y / cell_size))
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
	$UILayer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
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
	build_map_from_layout_with_randomization(map_manager.level_layout)
	hole_score = 0
	game_phase = "tee_select"
	is_putting = false
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
	if not spin_indicator:
		return
	
	var screen_center = Vector2(get_viewport().size.x, get_viewport().size.y) / 2
	var debug_pos = screen_center - camera_container.position  # Convert to camera container coordinates
	spin_indicator.clear_points()
	spin_indicator.add_point(debug_pos)
	spin_indicator.add_point(debug_pos + Vector2(100, 0))  # 100 pixel line to the right
	spin_indicator.default_color = Color(1, 0, 0, 1)  # Bright red
	spin_indicator.width = 20  # Very thick
	var current_mouse_pos = get_global_mouse_position()
	var mouse_deviation = current_mouse_pos - original_aim_mouse_pos
	
	var launch_dir = Vector2.ZERO
	if chosen_landing_spot != Vector2.ZERO and player_node:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		launch_dir = (chosen_landing_spot - player_center).normalized()
	else:
		launch_dir = Vector2(1, 0)  # Default direction
	
	var spin_dir = Vector2(-launch_dir.y, launch_dir.x)  # Perpendicular to launch direction
	var spin_strength = mouse_deviation.dot(spin_dir)
	
	var spin_scale = 2.0  # Reduced from 6.0 to keep indicator on screen
	var max_spin_threshold = 120.0  # Increased from 60.0 to require greater mouse movement
	var visual_length = clamp(spin_strength * spin_scale, -max_spin_threshold * spin_scale, max_spin_threshold * spin_scale)
	
	var indicator_pos = Vector2.ZERO
	if player_node:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		indicator_pos = player_center - camera_container.position
	else:
		var fallback_center = Vector2(get_viewport().size.x, get_viewport().size.y) / 2
		indicator_pos = fallback_center - camera_container.position
	
	spin_indicator.clear_points()
	spin_indicator.add_point(indicator_pos)
	spin_indicator.add_point(indicator_pos + spin_dir * visual_length)
	
	var spin_abs = abs(spin_strength)
	if spin_abs > 120:  # Increased from 60 to 120 for high spin
		spin_indicator.default_color = Color(1, 0, 0, 1)  # Red for high spin
	elif spin_abs > 48:  # Increased from 24 to 48 for medium spin
		spin_indicator.default_color = Color(1, 1, 0, 1)  # Yellow for medium spin
	else:
		spin_indicator.default_color = Color(0, 1, 0, 1)  # Green for low spin
	
	

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
			btn.pressed.connect(func(): handle_modify_next_card(club_card))
		elif club_card.effect_type == "ModifyNextCard":
			btn.pressed.connect(func(): handle_modify_next_card_card(club_card))
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
	is_putting = club_info.get("is_putter", false)
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
	exit_movement_mode()

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
	Global.saved_ball_position = golf_ball.global_position if golf_ball else Vector2.ZERO
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
	Global.saved_ball_exists = (golf_ball != null and is_instance_valid(golf_ball))
	
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
		player_grid_pos = Global.saved_player_grid_pos
		update_player_position()
		if player_node:
			player_node.visible = true
		is_placing_player = false
		ball_landing_tile = Global.saved_ball_landing_tile
		ball_landing_position = Global.saved_ball_landing_position
		waiting_for_player_to_reach_ball = Global.saved_waiting_for_player_to_reach_ball
		if Global.saved_ball_exists and Global.saved_ball_position != Vector2.ZERO:
			if golf_ball and is_instance_valid(golf_ball):
				golf_ball.queue_free()
			golf_ball = preload("res://GolfBall.tscn").instantiate()
			var ball_area = golf_ball.get_node_or_null("Area2D")
			if ball_area:
				ball_area.collision_layer = 1
				ball_area.collision_mask = 1  # Collide with layer 1 (trees)
			golf_ball.collision_layer = 1
			golf_ball.collision_mask = 1  # Collide with layer 1 (trees)
			var ball_local_position = Global.saved_ball_position - camera_container.global_position
			golf_ball.position = ball_local_position
			golf_ball.cell_size = cell_size
			golf_ball.map_manager = map_manager
			camera_container.add_child(golf_ball)
			golf_ball.add_to_group("balls")  # Add to group for collision detection
		else:
			if golf_ball and is_instance_valid(golf_ball):
				golf_ball.queue_free()
				golf_ball = null
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
	ghost_ball.set_putting_mode(is_putting)
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
	build_map_from_layout_base(layout, false)
	
	# Create object positions dictionary from saved data
	var object_positions = {
		"trees": Global.saved_tree_positions.duplicate(),
		"shop": Global.saved_shop_position  # Use the saved shop position
	}
	print("[DEBUG] About to place trees at positions:", object_positions.trees)
	
	# Place objects at saved positions
	place_objects_at_positions(object_positions, layout)
	
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
				pin.hole_in_one.connect(_on_hole_in_one)
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

func _on_hole_in_one(score: int):
	"""Handle hole completion when ball goes in the hole"""
	print("Hole in one! Score:", score)
	show_hole_completion_dialog()

func _on_pin_flag_hit(ball: Node2D):
	"""Handle pin flag hit - ball velocity has already been reduced by the pin"""
	print("Pin flag hit detected for ball:", ball)

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

func handle_modify_next_card_card(card: CardData) -> void:
	if card.name == "Dub":
		next_card_doubled = true
		if deck_manager.hand.has(card):
			deck_manager.discard(card)
			card_stack_display.animate_card_discard(card.name)
			update_deck_display()
			create_movement_buttons()  # Refresh the card display
		else:
			print("Error: Dub card not found in hand")
	

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
