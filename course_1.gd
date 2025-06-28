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
const GolfCourseLayout := preload("res://Maps/GolfCourseLayout.gd")

var is_placing_player := true

var obstacle_map: Dictionary = {}  # Vector2i -> BaseObstacle

var turn_count: int = 1
var selected_card: CardData = null

var grid_size := Vector2i(50, 50)
var cell_size: int = 48 # This will be set by the main script
var grid_tiles = []
var grid_container: Control
var camera_container: Control

var player_node: Node2D
var player_grid_pos := Vector2i(25, 25)

var movement_buttons := []
var active_button: TextureButton = null

var is_movement_mode := false
var movement_range := 2
var valid_movement_tiles := []

var is_panning := false
var pan_start_pos := Vector2.ZERO
var camera_offset := Vector2.ZERO
var camera_snap_back_pos := Vector2.ZERO

var flashlight_radius := 150.0
var mouse_world_pos := Vector2.ZERO
var player_flashlight_center := Vector2.ZERO
var tree_scene = preload("res://Obstacles/Tree.tscn")
var water_scene = preload("res://Obstacles/WaterHazard.tscn")

var selected_card_label: String = ""

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
	random_seed_value = current_hole * 1000 + randi()
	seed(random_seed_value)
	print("Random seed for hole", current_hole + 1, ":", random_seed_value)
	
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
	return positions

func build_map_from_layout_with_randomization(layout: Array) -> void:
	"""Build map with randomized object placement"""
	print("=== BUILD MAP WITH RANDOMIZATION DEBUG ===")
	print("Building map with randomization for hole", current_hole + 1)
	print("Current hole variable:", current_hole)
	print("Layout size:", layout.size(), "x", layout[0].size() if layout.size() > 0 else "empty")
	
	# Clear existing objects first
	print("About to clear existing objects...")
	clear_existing_objects()
	print("Existing objects cleared")
	
	# Build the base map (tiles only)
	print("About to call build_map_from_layout_base...")
	build_map_from_layout_base(layout)
	print("build_map_from_layout_base completed")
	
	# Generate random positions for objects
	print("About to generate random positions for objects...")
	var object_positions = get_random_positions_for_objects(layout, 8, true)
	print("Random positions generated")
	
	# Place objects at random positions
	print("About to place objects at positions...")
	place_objects_at_positions(object_positions, layout)
	print("Objects placed")
	
	# Position camera on pin immediately after map is built
	print("About to position camera on pin...")
	position_camera_on_pin()
	print("Camera positioned on pin")
	print("=== END BUILD MAP WITH RANDOMIZATION DEBUG ===")

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
				if pin.has_meta("grid_position") or "grid_position" in pin:
					pin.set("grid_position", pin_pos)
				
				obstacle_layer.add_child(pin)
				
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
		tree.z_index = int(tree.position.y)
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
				
				# Set grid_position if the property exists
				if shop.has_meta("grid_position") or "grid_position" in shop:
					shop.set("grid_position", object_positions.shop)
				else:
					push_warning("⚠️ Shop missing 'grid_position'. Type: %s" % shop.get_class())
				
				# Track for Y-sorting
				ysort_objects.append({"node": shop, "grid_pos": object_positions.shop})
				obstacle_layer.add_child(shop)
				
				# Update shop grid position for interaction
				shop_grid_pos = object_positions.shop
				
				# Place invisible blocker to the right of Shop
				var right_of_shop_pos = object_positions.shop + Vector2i(1, 0)
				var blocker_scene = preload("res://Obstacles/InvisibleBlocker.tscn")
				var blocker = blocker_scene.instantiate()
				var blocker_world_pos = Vector2(right_of_shop_pos.x, right_of_shop_pos.y) * cell_size
				blocker.position = blocker_world_pos + Vector2(cell_size / 2, cell_size / 2)
				obstacle_layer.add_child(blocker)
				obstacle_map[right_of_shop_pos] = blocker
				
				print("Random shop placed at grid position:", object_positions.shop)
				print("Invisible blocker placed at:", right_of_shop_pos)
	
	print("Object placement complete. Total ysort objects:", ysort_objects.size())
	
	# Update z-indices for all objects after placement
	update_all_ysort_z_indices()

# Move this function above focus_camera_on_tee
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
	# Handle power charging during launch phase
	if is_charging and game_phase == "launch":
		# Calculate max charge time based on target distance
		max_charge_time = 3.0  # Default for close shots
		if chosen_landing_spot != Vector2.ZERO:
			var sprite = player_node.get_node_or_null("Sprite2D")
			var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
			var player_center = player_node.global_position + player_size / 2
			var distance_to_target = player_center.distance_to(chosen_landing_spot)
			var distance_factor = distance_to_target / max_shot_distance
			# Far shots = less time (1 second), close shots = more time (3 seconds)
			max_charge_time = 3.0 - (distance_factor * 2.0)  # 3.0 to 1.0 seconds
			max_charge_time = clamp(max_charge_time, 1.0, 3.0)
		
		# Charge time at a constant rate
		charge_time = min(charge_time + delta, max_charge_time)
		
		# UI update - show time as percentage
		if power_meter:
			var meter_fill = power_meter.get_node_or_null("MeterFill")
			var value_label = power_meter.get_node_or_null("PowerValue")
			var time_percent = charge_time / max_charge_time
			time_percent = clamp(time_percent, 0.0, 1.0)
			
			if meter_fill:
				meter_fill.size.x = 300 * time_percent
				# Sweet spot is always 65-75%
				if time_percent >= 0.65 and time_percent <= 0.75:
					meter_fill.color = Color(0, 1, 0, 0.8)
					# Show player highlight when in sweet spot
					if player_node and player_node.has_method("show_highlight"):
						player_node.show_highlight()
				else:
					meter_fill.color = Color(1, 0.8, 0.2, 0.8)
					# Hide player highlight when not in sweet spot
					if player_node and player_node.has_method("hide_highlight"):
						player_node.hide_highlight()
			if value_label:
				value_label.text = str(int(time_percent * 100)) + "%"
	
	# Handle height charging during launch phase
	if is_charging_height and game_phase == "launch":
		# Charge height
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
			
			# Change color based on sweet spot
			var height_percentage = (launch_height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
			if meter_fill:
				if height_percentage >= HEIGHT_SWEET_SPOT_MIN and height_percentage <= HEIGHT_SWEET_SPOT_MAX:
					meter_fill.color = Color(0, 1, 0, 0.8)  # Green for sweet spot
				else:
					meter_fill.color = Color(1, 0.8, 0.2, 0.8)  # Yellow for other areas
	
	# Track mouse position during charging for spin
	if game_phase == "launch" and (is_charging or is_charging_height):
		current_charge_mouse_pos = get_global_mouse_position()
	
	# Handle camera following the ball
	if camera_following_ball and golf_ball and is_instance_valid(golf_ball):
		var ball_center = golf_ball.global_position
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", ball_center, 0.1).set_trans(Tween.TRANS_LINEAR)
	
	# Handle UI layer fixes
	if card_hand_anchor and card_hand_anchor.z_index != 100:
		card_hand_anchor.z_index = 100
		card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(false)  # stop checking after setting
	
	# Update aiming circle during aiming phase
	if is_aiming_phase and aiming_circle:
		update_aiming_circle()
	
	# Update spin indicator during launch phase before charging
	if game_phase == "launch" and not is_charging and not is_charging_height and spin_indicator and spin_indicator.visible:
		update_spin_indicator()
	# Hide spin indicator when charging starts
	if (is_charging or is_charging_height) and spin_indicator and spin_indicator.visible:
		spin_indicator.visible = false

func _ready() -> void:
	# Add this course to a group so other nodes can find it
	add_to_group("course")
	
	# Debug output for putt putt mode
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
	
	call_deferred("fix_ui_layers")
	display_selected_character()
	if end_round_button:
		end_round_button.pressed.connect(_on_end_round_pressed)

	create_grid()
	create_player()

	# Reparent the obstacle layer to align with the grid
	if obstacle_layer.get_parent():
		obstacle_layer.get_parent().remove_child(obstacle_layer)
	camera_container.add_child(obstacle_layer)

	# Load map data first - use LEVEL_LAYOUT instead of the non-existent LAYOUT
	map_manager.load_map_data(GolfCourseLayout.LEVEL_LAYOUT)
	# Remove this redundant call - we'll load the specific hole layout below
	# build_map_from_layout_with_randomization(map_manager.level_layout)

	deck_manager = DeckManager.new()
	add_child(deck_manager)
	deck_manager.deck_updated.connect(update_deck_display)
	deck_manager.discard_recycled.connect(card_stack_display.animate_card_recycle)

	var hud := $UILayer/HUD

	update_deck_display()
	set_process_input(true)

	# Set up swing sound effects
	setup_swing_sounds()

	# Ensure the UI gets drawn on top and intercepts input
	# Bring CardHandAnchor to front
	card_hand_anchor.z_index = 100
	card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
	card_hand_anchor.get_parent().move_child(card_hand_anchor, card_hand_anchor.get_parent().get_child_count() - 1)

	# Bring HUD to front too (if needed)
	hud.z_index = 101
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.get_parent().move_child(hud, hud.get_parent().get_child_count() - 1)
	# Move CardHandAnchor & HUD to the top of their parent's draw order
	var parent := card_hand_anchor.get_parent()
	parent.move_child(card_hand_anchor, parent.get_child_count() - 1)
	parent.move_child(hud,             parent.get_child_count() - 1)

	# Large z-index so they render over the grid
	card_hand_anchor.z_index = 100
	hud.z_index             = 101
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	end_turn_button.z_index = 102
	end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	end_turn_button.get_parent().move_child(end_turn_button, end_turn_button.get_parent().get_child_count() - 1)

	# Prevent the grid from stealing UI clicks
	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	draw_cards_button.visible = false
	draw_cards_button.pressed.connect(_on_draw_cards_pressed)
	
	# Connect ModShotRoom button
	mod_shot_room_button = $UILayer/ModShotRoom
	mod_shot_room_button.pressed.connect(_on_mod_shot_room_pressed)
	mod_shot_room_button.visible = false  # Start hidden
	print("ModShotRoom button connected successfully")

	# Set up bag and inventory system
	setup_bag_and_inventory()

	# Check if returning from shop FIRST
	if Global.saved_game_state == "shop_entrance":
		restore_game_state()
		return  # Skip tee selection/setup when returning from shop

	# Check if starting back 9
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

	# Only do tee selection if NOT returning from shop
	# Start in tee selection mode
	is_placing_player = true
	highlight_tee_tiles()

	# Load map data for the starting hole
	print("=== INITIALIZATION DEBUG ===")
	print("Loading map data for hole:", current_hole + 1)
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
	print("Map data loaded, building map...")
	build_map_from_layout_with_randomization(map_manager.level_layout)
	print("Map built, camera should be positioned on pin")
	print("=== END INITIALIZATION DEBUG ===")

	update_hole_and_score_display()

	# Show instruction to player
	show_tee_selection_instruction()

	# Add Complete Hole test button
	var complete_hole_btn := Button.new()
	complete_hole_btn.name = "CompleteHoleButton"
	complete_hole_btn.text = "Complete Hole"
	complete_hole_btn.position = Vector2(400, 50)
	complete_hole_btn.z_index = 999
	$UILayer.add_child(complete_hole_btn)
	complete_hole_btn.pressed.connect(_on_complete_hole_pressed)

	# Add Randomization Test button
	var test_random_btn := Button.new()
	test_random_btn.name = "TestRandomButton"
	test_random_btn.text = "Test Randomization"
	test_random_btn.position = Vector2(400, 100)
	test_random_btn.z_index = 999
	$UILayer.add_child(test_random_btn)
	test_random_btn.pressed.connect(test_randomization)

	# Add Pin-to-Tee Test button
	var test_pin_tee_btn := Button.new()
	test_pin_tee_btn.name = "TestPinTeeButton"
	test_pin_tee_btn.text = "Test Pin-to-Tee"
	test_pin_tee_btn.position = Vector2(400, 150)
	test_pin_tee_btn.z_index = 999
	$UILayer.add_child(test_pin_tee_btn)
	test_pin_tee_btn.pressed.connect(start_hole_with_pin_transition)

func _on_complete_hole_pressed():
	show_hole_completion_dialog()

func _input(event: InputEvent) -> void:
	if game_phase == "aiming":
		# Aiming phase - player moves red circle to set landing spot
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				# Confirm the landing spot and enter launch phase
				print("Landing spot confirmed at:", chosen_landing_spot)
				is_aiming_phase = false
				hide_aiming_circle()
				hide_aiming_instruction()
				enter_launch_phase()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				# Cancel aiming and return to previous phase
				print("Aiming cancelled")
				is_aiming_phase = false
				hide_aiming_circle()
				hide_aiming_instruction()
				game_phase = "move"  # Return to move phase
	elif game_phase == "launch":
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed and not is_charging and not is_charging_height:
					# Start charging power
					is_charging = true
					charge_time = 0.0  # Reset charge time
					
					# Force reset highlight state when starting to charge
					if player_node and player_node.has_method("force_reset_highlight"):
						print("Force resetting highlight state for new charge")
						player_node.force_reset_highlight()
					
					# Direction: from player to chosen landing spot
					var input_start_sprite = player_node.get_node_or_null("Sprite2D")
					var input_start_player_size = input_start_sprite.texture.get_size() * input_start_sprite.scale if input_start_sprite and input_start_sprite.texture else Vector2(cell_size, cell_size)
					var input_start_player_center = player_node.global_position + input_start_player_size / 2
					launch_direction = (chosen_landing_spot - input_start_player_center).normalized()
				elif not event.pressed and is_charging:
					# Stop charging power
					is_charging = false
					
					# Hide player highlight when charging stops
					if player_node and player_node.has_method("hide_highlight"):
						player_node.hide_highlight()
					
					# For putters, go directly to launch (no height charging)
					if is_putting:
						print("Putter: Skipping height charge, launching directly")
						launch_golf_ball(launch_direction, 0.0, launch_height)  # Pass 0.0 since we calculate power from charge_time
						hide_power_meter()
						game_phase = "ball_flying"
					else:
						# For non-putter clubs, start charging height
						is_charging_height = true
						launch_height = MIN_LAUNCH_HEIGHT
				elif not event.pressed and is_charging_height:
					# Launch! (only for non-putter clubs)
					is_charging_height = false
					launch_golf_ball(launch_direction, 0.0, launch_height)  # Pass 0.0 since we calculate power from charge_time
					hide_power_meter()
					hide_height_meter()
					game_phase = "ball_flying"
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				# Right click to cancel charging
				if is_charging or is_charging_height:
					is_charging = false
					is_charging_height = false
					charge_time = 0.0  # Reset charge time
					
					# Hide player highlight when charging is cancelled
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
		# Ball is flying - disable most input until it lands
		# Only allow camera panning during ball flight
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			if is_panning:
				pan_start_pos = event.position
			else:
				# Snap camera back to the current target position
				var tween := get_tree().create_tween()
				tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		elif event is InputEventMouseMotion and is_panning:
			var delta: Vector2 = event.position - pan_start_pos
			camera.position -= delta
			pan_start_pos = event.position
		return  # Don't process other input during ball flight

	# Track hovered nodes if needed
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var node = get_viewport().gui_get_hovered_control()
		# (print removed)

	# Start or stop panning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_panning = event.pressed
		if is_panning:
			pan_start_pos = event.position
		else:
			# Snap camera back to the current target position
			var tween := get_tree().create_tween()
			tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Pan while moving mouse
	elif event is InputEventMouseMotion and is_panning:
		var delta: Vector2 = event.position - pan_start_pos
		camera.position -= delta
		pan_start_pos = event.position

	# Update flashlight tracking (optional)
	if player_node:
		player_flashlight_center = get_flashlight_center()

	# Redraw tiles to reflect flashlight
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
	tile.add_child(red)

	var green := ColorRect.new()
	green.name = "MovementHighlight"
	green.size = tile.size
	green.color = Color(0, 1, 0, 0.4)
	green.visible = false
	green.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# Set player_stats from Global.CHARACTER_STATS before creating the player
	player_stats = Global.CHARACTER_STATS.get(Global.selected_character, {})
	# Reuse existing player if it exists and is valid
	if player_node and is_instance_valid(player_node):
		print("Reusing existing player")
		# Just update the player's position and make it visible
		player_node.position = Vector2(player_grid_pos.x, player_grid_pos.y) * cell_size + Vector2(2, 2)
		player_node.set_grid_position(player_grid_pos)
		player_node.visible = true
		update_player_position()
		return

	# Create new player only if one doesn't exist
	print("Creating new player")
	var player_scene = preload("res://Characters/Player1.tscn")
	player_node = player_scene.instantiate()
	player_node.name = "Player"
	player_node.position = Vector2(player_grid_pos.x, player_grid_pos.y) * cell_size + Vector2(2, 2)
	# Removed: player_node.mouse_filter (Node2D does not have this property)
	grid_container.add_child(player_node)

	# Instance the selected character as a child of the player node
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

	# Setup the player with grid and movement info
	var base_mobility = player_stats.get("base_mobility", 0)
	player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
	
	# Set the player's initial grid position
	player_node.set_grid_position(player_grid_pos)

	# Connect signals
	player_node.player_clicked.connect(_on_player_input)
	player_node.moved_to_tile.connect(_on_player_moved_to_tile)

	update_player_position()
	if player_node:
		player_node.visible = false

func update_player_stats_from_equipment() -> void:
	"""Update player stats to reflect equipment buffs"""
	# Get updated stats from Global (which includes equipment buffs)
	player_stats = Global.CHARACTER_STATS.get(Global.selected_character, {})
	
	# Update player mobility if player exists
	if player_node and is_instance_valid(player_node):
		var base_mobility = player_stats.get("base_mobility", 0)
		player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
		print("Updated player stats with equipment buffs:", player_stats)

func _on_player_input(event: InputEvent) -> void:
	# (print removed)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# If we're in move phase (after ball lands), start aiming phase
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
	# Get the Sprite2D node and its size
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)

	player_node.position = Vector2(player_grid_pos.x, player_grid_pos.y) * cell_size + Vector2(2, 2)

	# Update the player's grid position in the Player.gd script
	player_node.set_grid_position(player_grid_pos, ysort_objects)
	
	# --- Y-SORT LOGIC FIXED FOR TREE OFFSETS ---
	# (debug prints removed)
	# --- END Y-SORT LOGIC FIXED ---
	var player_center: Vector2 = player_node.global_position + player_size / 2
	camera_snap_back_pos = player_center
	
	# Don't move camera during pin-to-tee transition (when we're in tee selection phase)
	if not is_placing_player:
		print("=== CAMERA MOVEMENT DEBUG ===")
		print("update_player_position moving camera from", camera.position, "to", player_center)
		print("player_node.visible:", player_node.visible, "is_placing_player:", is_placing_player)
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "position", player_center, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		print("=== END CAMERA MOVEMENT DEBUG ===")

func create_movement_buttons() -> void:
	# 1. Clear old buttons
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()

	# 2. Build new buttons
	for i in deck_manager.hand.size():
		var card := deck_manager.hand[i]

		var btn := TextureButton.new()
		btn.name = "CardButton%d" % i
		btn.texture_normal = card.image
		btn.custom_minimum_size = Vector2(100, 140)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		# Input behaviour
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.z_index = 10

		# Hover overlay
		var overlay := ColorRect.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(1, 0.84, 0, 0.25)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		btn.add_child(overlay)

		btn.mouse_entered.connect(func(): overlay.visible = true)
		btn.mouse_exited.connect(func(): overlay.visible = false)

		btn.pressed.connect(func(): _on_movement_card_pressed(card, btn))

		movement_buttons_container.add_child(btn)
		movement_buttons.append(btn)
	
	# Update ModShotRoom button visibility when cards are available
	update_mod_shot_room_visibility()

func _on_movement_card_pressed(card: CardData, button: TextureButton) -> void:
	if selected_card == card:
		return
	card_click_sound.play()
	hide_all_movement_highlights()
	valid_movement_tiles.clear()

	# Handle different effect types
	if card.effect_type == "ModifyNext":
		# Handle StickyShot and other modification cards
		handle_modify_next_card(card)
		return
	
	# Default movement card handling
	is_movement_mode = true
	active_button = button
	selected_card = card
	selected_card_label = card.name
	movement_range = card.effect_strength

	print("Card selected:", card.name, "Range:", movement_range)

	# Use player_node to start movement mode (this will calculate valid tiles)
	player_node.start_movement_mode(card, movement_range)
	
	# Get the valid tiles from the player node
	valid_movement_tiles = player_node.valid_movement_tiles.duplicate()
	show_movement_highlights()

func handle_modify_next_card(card: CardData) -> void:
	"""Handle cards with ModifyNext effect type"""
	print("Handling ModifyNext card:", card.name)
	
	if card.name == "Sticky Shot":
		# Apply StickyShot effect to next shot
		sticky_shot_active = true
		next_shot_modifier = "sticky_shot"
		print("StickyShot effect applied to next shot")
		
		# Discard the card after use
		if deck_manager.hand.has(card):
			deck_manager.discard(card)
			card_stack_display.animate_card_discard(card.name)
			update_deck_display()
			create_movement_buttons()  # Refresh the card display
		else:
			print("Error: StickyShot card not found in hand")
	
	elif card.name == "Bouncey":
		# Apply Bouncey effect to next shot
		bouncey_shot_active = true
		next_shot_modifier = "bouncey_shot"
		print("Bouncey effect applied to next shot")
		
		# Discard the card after use
		if deck_manager.hand.has(card):
			deck_manager.discard(card)
			card_stack_display.animate_card_discard(card.name)
			update_deck_display()
			create_movement_buttons()  # Refresh the card display
		else:
			print("Error: Bouncey card not found in hand")
	
	# Add more ModifyNext card types here as needed

func calculate_valid_movement_tiles() -> void:
	valid_movement_tiles.clear()

	var base_mobility = player_stats.get("base_mobility", 0)
	var total_range = movement_range + base_mobility

	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)

			if calculate_grid_distance(player_grid_pos, pos) <= total_range and pos != player_grid_pos:
				if obstacle_map.has(pos):
					var obstacle = obstacle_map[pos]

					# Check if the obstacle blocks movement via method
					if obstacle.has_method("blocks") and obstacle.blocks():
						continue

				valid_movement_tiles.append(pos)

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func show_movement_highlights() -> void:
	hide_all_movement_highlights()
	for pos in valid_movement_tiles:
		grid_tiles[pos.y][pos.x].get_node("MovementHighlight").visible = true

func hide_all_movement_highlights() -> void:
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("MovementHighlight").visible = false

func _on_tile_mouse_entered(x: int, y: int) -> void:
	if not is_panning and is_movement_mode:
		var tile: Control = grid_tiles[y][x]
		var clicked := Vector2i(x, y)
		
		# Only show red highlight if it's not a valid movement tile
		if not Vector2i(x, y) in valid_movement_tiles:
			tile.get_node("Highlight").visible = true

func _on_tile_mouse_exited(x: int, y: int) -> void:
	if not is_panning:
		grid_tiles[y][x].get_node("Highlight").visible = false

func _on_tile_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed and not is_panning and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := Vector2i(x, y)
		if is_placing_player:
			if map_manager.get_tile_type(x, y) == "Tee":
				player_grid_pos = clicked
				create_player()  # This will reuse existing player or create new one
				is_placing_player = false
				var sprite = player_node.get_node_or_null("Sprite2D")
				var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
				var player_center = player_node.global_position + player_size / 2
				camera_snap_back_pos = player_center
				# Play SandThunk sound when player is placed on tee
				if sand_thunk_sound and sand_thunk_sound.stream:
					sand_thunk_sound.play()
				start_round_after_tee_selection()
			else:
				pass # Please select a Tee Box to start your round.
		else:
			# Use player_node to move
			print("=== MOVEMENT DEBUG ===")
			print("is_movement_mode:", is_movement_mode)
			print("clicked tile:", clicked)
			print("valid_movement_tiles:", valid_movement_tiles)
			print("clicked in valid tiles:", clicked in valid_movement_tiles)
			if player_node.has_method("can_move_to"):
				print("player_node.can_move_to(clicked):", player_node.can_move_to(clicked))
			else:
				print("player_node does not have can_move_to method")
			print("=== END MOVEMENT DEBUG ===")
			
			if is_movement_mode and clicked in valid_movement_tiles:
				print("=== MOVEMENT ATTEMPT DEBUG ===")
				print("Calling player_node.move_to_grid with:", clicked)
				player_node.move_to_grid(clicked)
				print("player_node.move_to_grid call completed")
				card_play_sound.play()
				print("Card play sound played")
				# exit_movement_mode() will be called from moved_to_tile signal
				print("=== END MOVEMENT ATTEMPT DEBUG ===")
			else:
				print("Invalid movement tile or not in movement mode")

func start_round_after_tee_selection() -> void:
	# Remove tee selection instruction
	var instruction_label = $UILayer.get_node_or_null("TeeInstructionLabel")
	if instruction_label:
		instruction_label.queue_free()
	
	# Clear tee highlights
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("Highlight").visible = false
	
	# Get player stats from Global
	player_stats = Global.CHARACTER_STATS.get(Global.selected_character, {})
	
	# Initialize the deck
	deck_manager.initialize_deck(deck_manager.starter_deck)
	print("Deck initialized with", deck_manager.draw_pile.size(), "cards")

	has_started = true
	
	# Set up for first shot - start with club selection phase
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
	
	# Create a container for the power meter
	power_meter = Control.new()
	power_meter.name = "PowerMeter"
	power_meter.size = Vector2(350, 80)
	power_meter.position = Vector2(50, get_viewport_rect().size.y - 120)
	$UILayer.add_child(power_meter)
	power_meter.z_index = 200
	
	# Background panel
	var background := ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1, 0.8)
	background.size = power_meter.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(background)
	
	# Border
	var border := ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.size = Vector2(power_meter.size.x + 4, power_meter.size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(border)
	border.z_index = -1
	
	# Title label
	var title_label := Label.new()
	title_label.text = "CHARGE TIME (0-100%)"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(10, 5)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(title_label)
	
	# Meter background
	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.2, 0.2, 0.2, 0.9)
	meter_bg.size = Vector2(300, 20)
	meter_bg.position = Vector2(10, 30)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(meter_bg)
	
	# Sweet spot indicator (green zone for 65-75%)
	var sweet_spot := ColorRect.new()
	sweet_spot.name = "SweetSpot"
	sweet_spot.color = Color(0, 0.8, 0, 0.3)  # Green with transparency
	sweet_spot.size = Vector2(30, 20)  # 10% of 300 (65-75% = 10% range)
	sweet_spot.position = Vector2(195, 30)  # 65% of 300 = 195
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(sweet_spot)
	
	# Meter fill (this will be updated in _process)
	var meter_fill := ColorRect.new()
	meter_fill.name = "MeterFill"
	meter_fill.color = Color(1, 0.8, 0.2, 0.8)
	meter_fill.size = Vector2(0, 20)  # Start at 0 width
	meter_fill.position = Vector2(10, 30)
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(meter_fill)
	
	# Power value label (shows percentage)
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
	
	# Min/Max labels
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
	
	# Store for use in _process
	power_meter.set_meta("max_power_for_bar", max_power_for_bar)
	power_meter.set_meta("power_for_target", power_for_target)

func hide_power_meter():
	if power_meter:
		power_meter.queue_free()
		power_meter = null

func show_height_meter():
	if height_meter:
		height_meter.queue_free()
	
	# Create a container for the height meter
	height_meter = Control.new()
	height_meter.name = "HeightMeter"
	height_meter.size = Vector2(80, 350)
	height_meter.position = Vector2(get_viewport_rect().size.x - 130, get_viewport_rect().size.y - 400)
	$UILayer.add_child(height_meter)
	height_meter.z_index = 200
	
	# Background panel
	var background := ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1, 0.8)
	background.size = height_meter.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(background)
	
	# Border
	var border := ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.size = Vector2(height_meter.size.x + 4, height_meter.size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(border)
	border.z_index = -1
	
	# Title label
	var title_label := Label.new()
	title_label.text = "HEIGHT"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(5, 5)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(title_label)
	
	# Meter background
	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.2, 0.2, 0.2, 0.9)
	meter_bg.size = Vector2(20, 300)
	meter_bg.position = Vector2(30, 30)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(meter_bg)
	
	# Sweet spot indicator (green zone)
	var sweet_spot := ColorRect.new()
	sweet_spot.name = "SweetSpot"
	sweet_spot.color = Color(0, 0.8, 0, 0.3)
	sweet_spot.size = Vector2(20, 60)  # 20% of 300
	sweet_spot.position = Vector2(30, 120)  # Center of the meter
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(sweet_spot)
	
	# Meter fill (this will be updated in _process)
	var meter_fill := ColorRect.new()
	meter_fill.name = "MeterFill"
	meter_fill.color = Color(1, 0.8, 0.2, 0.8)
	meter_fill.size = Vector2(20, 100)
	meter_fill.position = Vector2(30, 230)  # Start from bottom
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(meter_fill)
	
	# Height value label
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
	
	# Min/Max labels
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
	
	# Calculate circle size based on character strength modifier
	var base_circle_size = 50.0
	var strength_modifier = player_stats.get("strength", 0)
	var strength_multiplier = 1.0 + (strength_modifier * 0.15)  # +15% size per strength point
	var adjusted_circle_size = base_circle_size * strength_multiplier
	
	# Create a container for the aiming circle
	aiming_circle = Control.new()
	aiming_circle.name = "AimingCircle"
	aiming_circle.size = Vector2(adjusted_circle_size, adjusted_circle_size)
	aiming_circle.z_index = 150  # Above the player but below UI
	camera_container.add_child(aiming_circle)
	
	# Create the red circle visual
	var circle = ColorRect.new()
	circle.name = "CircleVisual"
	circle.size = Vector2(adjusted_circle_size, adjusted_circle_size)
	circle.color = Color(1, 0, 0, 0.6)  # Red with transparency
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(circle)
	
	# Make it circular by using a custom draw function
	circle.draw.connect(_draw_circle.bind(circle))
	
	# Add distance indicator label
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
	# Draw a red circle
	var center = circle.size / 2
	var radius = min(circle.size.x, circle.size.y) / 2
	circle.draw_circle(center, radius, Color(1, 0, 0, 0.8))
	circle.draw_arc(center, radius, 0, 2 * PI, 32, Color(1, 0, 0, 1.0), 2.0)

func hide_aiming_circle():
	if aiming_circle:
		aiming_circle.queue_free()
		aiming_circle = null
	
	# Remove ghost ball when hiding aiming circle
	remove_ghost_ball()

func update_aiming_circle():
	if not aiming_circle or not player_node:
		return
	
	# Get player center position
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	# Get mouse position
	var mouse_pos = get_global_mouse_position()
	# Calculate direction and distance
	var direction = (mouse_pos - player_center).normalized()
	var distance = player_center.distance_to(mouse_pos)
	
	# Clamp the distance to the maximum shot distance
	var clamped_distance = min(distance, max_shot_distance)
	var clamped_position = player_center + direction * clamped_distance
	
	# Position the circle at the clamped position
	aiming_circle.global_position = clamped_position - aiming_circle.size / 2
	
	# Store the chosen landing spot
	chosen_landing_spot = clamped_position
	
	# Update ghost ball with new landing spot
	update_ghost_ball()
	
	# Change circle color based on distance vs min distance
	var circle = aiming_circle.get_node_or_null("CircleVisual")
	if circle and selected_club in club_data:
		var min_distance = club_data[selected_club]["min_distance"]
		if clamped_distance >= min_distance:
			# Safe range - green circle
			circle.color = Color(0, 1, 0, 0.8)  # Green
		else:
			# Penalty range - red circle
			circle.color = Color(1, 0, 0, 0.8)  # Red
	
	# Make camera follow the red circle smoothly
	var target_camera_pos = clamped_position
	var current_camera_pos = camera.position
	var camera_speed = 5.0  # Adjust for faster/slower camera movement
	
	# Smoothly move camera toward the red circle
	var new_camera_pos = current_camera_pos.lerp(target_camera_pos, camera_speed * get_process_delta_time())
	camera.position = new_camera_pos
	
	
	# Update distance label
	var distance_label = aiming_circle.get_node_or_null("DistanceLabel")
	if distance_label:
		distance_label.text = str(int(clamped_distance)) + "px"

func launch_golf_ball(direction: Vector2, charged_power: float, height: float):
	# (debug prints removed)
	# Get player center using new system
	var player_sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = player_sprite.texture.get_size() * player_sprite.scale if player_sprite and player_sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	print("Player global position at launch:", player_node.global_position)
	print("Player size at launch:", player_size)
	print("Player center at launch:", player_center)

	# Calculate direction from player center to chosen landing spot
	var launch_direction = (chosen_landing_spot - player_center).normalized() if chosen_landing_spot != Vector2.ZERO else Vector2.ZERO
	print("Calculated launch direction:", launch_direction)

	# Calculate power from charge time instead of charged_power
	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)

	# Calculate actual power based on time percentage and target distance
	var actual_power = 0.0
	if chosen_landing_spot != Vector2.ZERO:
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
		# Use distance-based scaling for physics factors
		var reference_distance = 1200.0  # Driver's max distance as reference
		var distance_factor = distance_to_target / reference_distance
		var ball_physics_factor = 0.8 + (distance_factor * 0.4)  # Reduced from 1.2 to 0.4 (0.8 to 1.2)
		var base_power_per_distance = 0.6 + (distance_factor * 0.2)  # Reduced from 0.8 to 0.2 (0.6 to 0.8)
		
		# Calculate base power needed for the distance
		var base_power_for_target = distance_to_target * base_power_per_distance * ball_physics_factor
		
		# Apply club-specific power scaling based on club efficiency
		# Lower power clubs need more power to reach the same distance
		var club_efficiency = 1.0
		if selected_club in club_data:
			var club_max = club_data[selected_club]["max_distance"]
			# Calculate efficiency: Driver (1200) = 1.0, lower clubs need more power
			# Use a more gradual scaling to keep clubs closer in power
			var efficiency_factor = 1200.0 / club_max
			# Apply a square root to make the differences more gradual
			# This reduces the extreme differences between clubs
			club_efficiency = sqrt(efficiency_factor)
			# Clamp efficiency to reasonable range (0.7 to 1.5)
			club_efficiency = clamp(club_efficiency, 0.7, 1.5)
		
		var power_for_target = base_power_for_target * club_efficiency
		
		print("Club power calculation - club:", selected_club, "efficiency:", club_efficiency, "base_power:", base_power_for_target, "final_power:", power_for_target)
		
		# Calculate power based on time percentage
		if is_putting:
			# For putters: simple linear power based on charge time, no penalties
			var base_putter_power = 300.0  # Base power for putters
			actual_power = time_percent * base_putter_power
			print("Putter power calculation - time_percent:", time_percent, "final_power:", actual_power)
		elif time_percent <= 0.75:
			# 0-75% time = 0-100% of target power (for non-putters)
			actual_power = (time_percent / 0.75) * power_for_target
			
			# Apply trailoff effects for undercharged shots
			var trailoff_forgiveness = club_data[selected_club].get("trailoff_forgiveness", 0.5) if selected_club in club_data else 0.5
			
			# Calculate how much undercharged the shot is (0.0 = sweet spot, 1.0 = minimum charge)
			var undercharge_factor = 1.0 - (time_percent / 0.75)  # 0.0 to 1.0
			
			# Apply trailoff penalty based on forgiveness
			# Lower forgiveness = more severe penalty for undercharging
			var trailoff_penalty = undercharge_factor * (1.0 - trailoff_forgiveness)
			actual_power = actual_power * (1.0 - trailoff_penalty)
			
			print("Trailoff calculation - time_percent:", time_percent, "undercharge_factor:", undercharge_factor, "trailoff_forgiveness:", trailoff_forgiveness, "trailoff_penalty:", trailoff_penalty, "final_power:", actual_power)
		else:
			# 75-100% time = target power + overcharge bonus (for non-putters)
			var overcharge_bonus = ((time_percent - 0.75) / 0.25) * (0.25 * max_shot_distance)
			actual_power = power_for_target + overcharge_bonus
	else:
		# No target - use time percentage of max power
		actual_power = time_percent * MAX_LAUNCH_POWER

	print("Time percent:", time_percent, "Actual power for launch:", actual_power)
	
	# Debug the final power calculation
	print("=== FINAL POWER CALCULATION DEBUG ===")
	print("Selected club:", selected_club)
	print("Is putting:", is_putting)
	print("Time percent:", time_percent)
	print("Target power needed:", power_for_target)
	print("Final actual power:", actual_power)
	print("=== END FINAL POWER CALCULATION DEBUG ===")
	
	# Store the shot start position for out of bounds handling
	shot_start_grid_pos = player_grid_pos

	# Increment shot score and update HUD immediately
	hole_score += 1
	update_deck_display()

	# Calculate spin based on mouse deviation from original aim
	var aim_deviation = current_charge_mouse_pos - original_aim_mouse_pos
	var launch_dir_perp = Vector2(-launch_direction.y, launch_direction.x) # Perpendicular to launch direction
	var spin_strength = aim_deviation.dot(launch_dir_perp)
	# Scale spin (dramatically increased for more noticeable curve effects)
	launch_spin = clamp(spin_strength * 1.0, -800, 800)  # Increased from 0.1 to 1.0 and max from 200 to 800

	# Calculate spin strength for scaling (same logic as spin indicator)
	var spin_abs = abs(spin_strength)
	var spin_strength_category = 0  # 0=green, 1=yellow, 2=red
	if spin_abs > 120:
		spin_strength_category = 2  # Red - high spin
	elif spin_abs > 48:
		spin_strength_category = 1  # Yellow - medium spin
	else:
		spin_strength_category = 0  # Green - low spin

	# Apply height resistance to the final launch power
	var height_percentage = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
	height_percentage = clamp(height_percentage, 0.0, 1.0)

	var height_resistance_multiplier = 1.0
	if height_percentage > HEIGHT_SWEET_SPOT_MAX:  # Above 60% height
		# Calculate how much above the sweet spot we are
		var excess_height = height_percentage - HEIGHT_SWEET_SPOT_MAX
		var max_excess = 1.0 - HEIGHT_SWEET_SPOT_MAX  # 0.4 (from 60% to 100%)
		# Progressive resistance: more excess height = more power reduction
		var resistance_factor = excess_height / max_excess  # 0.0 to 1.0
		height_resistance_multiplier = 1.0 - (resistance_factor * 0.5)  # Reduce power by up to 50%

	# Apply height resistance to final power
	var final_power = actual_power * height_resistance_multiplier
	
	# Apply character strength modifier
	var strength_modifier = player_stats.get("strength", 0)
	if strength_modifier != 0:
		# Strength modifier affects power by a percentage
		# +1 strength = +10% power, -1 strength = -10% power
		var strength_multiplier = 1.0 + (strength_modifier * 0.1)
		final_power *= strength_multiplier
		print("Character strength modifier applied: +", strength_modifier, " (", (strength_modifier * 10), "% power)")

	# Focused debug print for power calculation
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
	
	# Ensure collision properties are set correctly
	var ball_area = golf_ball.get_node_or_null("Area2D")
	if ball_area:
		ball_area.collision_layer = 1
		ball_area.collision_mask = 1  # Collide with layer 1 (trees)
	
	# Note: Using Area2D for all collision detection
	
	# Calculate ball position relative to camera container
	var ball_setup_player_sprite = player_node.get_node_or_null("Sprite2D")
	var ball_setup_player_size = ball_setup_player_sprite.texture.get_size() * ball_setup_player_sprite.scale if ball_setup_player_sprite and ball_setup_player_sprite.texture else Vector2(cell_size, cell_size)
	var ball_setup_player_center = player_node.global_position + ball_setup_player_size / 2

	# Add vertical offset for all shots to make ball appear from middle of tile
	var ball_position_offset = Vector2(0, -cell_size * 0.5)
	ball_setup_player_center += ball_position_offset

	# Convert global position to camera container local position
	var ball_local_position = ball_setup_player_center - camera_container.global_position
	golf_ball.position = ball_local_position
	# (debug prints removed)
	
	golf_ball.cell_size = cell_size
	golf_ball.map_manager = map_manager  # Pass map manager reference for tile-based friction
	
	# Don't set z_index here - let individual sprites control their own layering
	camera_container.add_child(golf_ball)  # Add to camera container instead of main scene
	golf_ball.add_to_group("balls")  # Add to group for collision detection
	print("Golf ball added to scene at position:", golf_ball.position)
	print("Golf ball node z_index:", golf_ball.z_index)
	print("Golf ball visible:", golf_ball.visible)
	print("Golf ball global position:", golf_ball.global_position)
	
	# Update Y-sorting for the ball
	update_ball_y_sort(golf_ball)
	
	# Debug: Check child z_index values
	var shadow = golf_ball.get_node_or_null("Shadow")
	var ball_sprite = golf_ball.get_node_or_null("Sprite2D")
	# (debug prints removed)
	
	play_swing_sound(final_power)  # Use final_power for sound
	
	# Pass the chosen landing spot to the ball for trajectory calculation
	golf_ball.chosen_landing_spot = chosen_landing_spot
	# Pass the club information to the ball for progressive overcharge system
	golf_ball.club_info = club_data[selected_club] if selected_club in club_data else {}
	# Set the putting mode flag on the ball
	golf_ball.is_putting = is_putting
	print("=== PUTTING DEBUG ===")
	print("Selected club:", selected_club)
	print("Is putting mode:", is_putting)
	print("Club info:", club_data[selected_club] if selected_club in club_data else "No club data")
	print("Ball is_putting set to:", golf_ball.is_putting)
	print("=== END PUTTING DEBUG ===")
	# Pass the time percentage information for proper sweet spot detection
	golf_ball.time_percentage = time_percent
	
	# Apply StickyShot effect if active
	if sticky_shot_active and next_shot_modifier == "sticky_shot":
		print("Applying StickyShot effect to ball")
		golf_ball.sticky_shot_active = true
		# Clear the effect after applying it
		sticky_shot_active = false
		next_shot_modifier = ""
		print("StickyShot effect cleared after application")
	
	# Apply Bouncey effect if active
	if bouncey_shot_active and next_shot_modifier == "bouncey_shot":
		print("Applying Bouncey effect to ball")
		golf_ball.bouncey_shot_active = true
		# Clear the effect after applying it
		bouncey_shot_active = false
		next_shot_modifier = ""
		print("Bouncey effect cleared after application")
	
	# Pass the spin value to the ball
	golf_ball.launch(launch_direction, final_power, height, launch_spin, spin_strength_category)  # Pass spin strength category
	golf_ball.landed.connect(_on_golf_ball_landed)
	golf_ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)  # Connect out of bounds signal
	golf_ball.sand_landing.connect(_on_golf_ball_sand_landing)  # Connect sand landing signal
	# (debug prints removed)
	
	# Start camera following the ball
	camera_following_ball = true
	print("Camera following ball started")

func _on_golf_ball_landed(tile: Vector2i):
	hole_score += 1
	# (debug prints removed)
	# Stop camera following
	camera_following_ball = false
	print("Golf ball landed on tile:", tile, "Shots so far:", hole_score)
	print("Ball final position:", golf_ball.position if golf_ball else "No ball")
	print("Ball final global position:", golf_ball.global_position if golf_ball else "No ball")
	print("Transitioning from ball_flying to move phase")
	
	# Store ball landing information for multi-shot golf
	ball_landing_tile = tile
	ball_landing_position = golf_ball.global_position if golf_ball else Vector2.ZERO
	waiting_for_player_to_reach_ball = true
	
	# Calculate drive distance (distance from player to ball landing position)
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var player_start_pos = player_center
	var ball_landing_pos = golf_ball.global_position if golf_ball else player_start_pos
	drive_distance = player_start_pos.distance_to(ball_landing_pos)
	
	# Add a delay before showing the dialog so player can appreciate their shot
	var dialog_timer = get_tree().create_timer(0.5)  # Reduced from 1.5 to 0.5 second delay
	dialog_timer.timeout.connect(func():
		show_drive_distance_dialog()
	)
	
	# Keep the ball visible on the screen - don't remove it!
	# The ball will stay until the player reaches its tile
	print("Ball will remain visible until player reaches tile:", tile)
	
	# Set player target tile for next move phase, or check for pin, etc.
	# For now, just transition to movement phase
	game_phase = "move"
	print("Game phase set to:", game_phase)
	
	# Update ModShotRoom button visibility
	update_mod_shot_room_visibility()
	
	# Don't draw cards here - they will be drawn when starting the next shot
	# print("Drawing cards from deck...")
	# deck_manager.draw_cards()
	# print("Cards drawn. Hand size:", deck_manager.hand.size())
	
	# Don't create movement buttons here - there are no cards yet
	# Movement buttons will be created when cards are drawn for the next shot
	# print("Creating movement buttons...")
	# create_movement_buttons()
	# print("Movement phase ready!")

func highlight_tee_tiles():
	# Clear any existing highlights first
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("Highlight").visible = false
	
	# Highlight all tee tiles
	for y in grid_size.y:
		for x in grid_size.x:
			if map_manager.get_tile_type(x, y) == "Tee":
				grid_tiles[y][x].get_node("Highlight").visible = true
				# Change highlight color to blue for tee tiles
				var highlight = grid_tiles[y][x].get_node("Highlight")
				highlight.color = Color(0, 0.5, 1, 0.6)  # Blue with transparency

func exit_movement_mode() -> void:
	is_movement_mode = false
	hide_all_movement_highlights()
	valid_movement_tiles.clear()

	if active_button and active_button.is_inside_tree():
		if selected_card:
			var card_discarded := false

			if deck_manager.hand.has(selected_card):
				print("Discarding selected card:", selected_card.name)
				deck_manager.discard(selected_card)
				card_discarded = true
			else:
				print("Card not in hand:", selected_card.name)

			card_stack_display.animate_card_discard(selected_card.name)
			update_deck_display()

		if movement_buttons_container and movement_buttons_container.has_node(NodePath(active_button.name)):
			movement_buttons_container.remove_child(active_button)

		active_button.queue_free()
		movement_buttons.erase(active_button)
		active_button = null

	selected_card_label = ""
	selected_card = null
	print("Exited movement mode")

func _on_end_turn_pressed() -> void:
	if is_movement_mode:
		exit_movement_mode()

	# Check if there are cards in hand to discard
	var cards_to_discard = deck_manager.hand.size()
	
	# Always discard all cards and clear movement buttons
	for card in deck_manager.hand:
		deck_manager.discard(card)
	deck_manager.hand.clear()
	hide_all_movement_highlights()
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	selected_card_label = ""
	selected_card = null
	active_button = null
	is_movement_mode = false
	turn_count += 1
	update_deck_display()
	
	# Play discard sound if there were cards in hand
	if cards_to_discard > 0:
		if card_stack_display.has_node("Discard"):
			var discard_sound = card_stack_display.get_node("Discard")
			if discard_sound and discard_sound.stream:
				discard_sound.play()
				print("Playing discard sound for", cards_to_discard, "cards")
	# Play DiscardEmpty sound if there were no cards in hand
	elif cards_to_discard == 0:
		if card_stack_display.has_node("DiscardEmpty"):
			var discard_empty_sound = card_stack_display.get_node("DiscardEmpty")
			if discard_empty_sound and discard_empty_sound.stream:
				discard_empty_sound.play()
				print("Playing DiscardEmpty sound (no cards to discard)")

	# Only start the next shot if player is on the ball tile
	if waiting_for_player_to_reach_ball and player_grid_pos == ball_landing_tile:
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
	print("Selected character: ", Global.selected_character)
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
				# Don't change scale or position - keep original
			3: 
				character_image.texture = load("res://character3.png")
				# Don't change scale or position - keep original
	
	# Set the bag character to match the selected character
	if bag and bag.has_method("set_character"):
		bag.set_character(character_name)
		print("Bag character set to:", character_name)

func _on_end_round_pressed() -> void:
	if is_movement_mode:
		exit_movement_mode()
	call_deferred("_change_to_main")

func _change_to_main() -> void:
	# Reset putt putt mode when returning to main menu
	Global.putt_putt_mode = false
	# Use FadeManager for smooth transition
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5)

func show_tee_selection_instruction() -> void:
	# Create a temporary instruction label
	var instruction_label := Label.new()
	instruction_label.name = "TeeInstructionLabel"
	instruction_label.text = "Click on a Tee Box to start your round!"
	instruction_label.add_theme_font_size_override("font_size", 24)
	instruction_label.add_theme_color_override("font_color", Color.YELLOW)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Position it in the center of the screen
	instruction_label.position = Vector2(400, 200)
	instruction_label.z_index = 200
	
	# Add to UI layer
	$UILayer.add_child(instruction_label)

func show_drive_distance_dialog() -> void:
	if drive_distance_dialog:
		drive_distance_dialog.queue_free()
	
	drive_distance_dialog = Control.new()
	drive_distance_dialog.name = "DriveDistanceDialog"
	drive_distance_dialog.size = get_viewport_rect().size
	drive_distance_dialog.z_index = 500  # Very high z-index to appear on top
	drive_distance_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Semi-transparent background
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = drive_distance_dialog.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP  # Make sure it can receive input
	drive_distance_dialog.add_child(background)
	
	# Connect input to the background
	background.gui_input.connect(_on_drive_distance_dialog_input)
	
	# Dialog box
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.9)
	dialog_box.size = Vector2(400, 200)
	dialog_box.position = (drive_distance_dialog.size - dialog_box.size) / 2  # Center the dialog
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drive_distance_dialog.add_child(dialog_box)
	
	# Title label
	var title_label := Label.new()
	title_label.text = "Drive Distance"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(150, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	# Distance label
	var distance_label := Label.new()
	distance_label.text = "%d pixels" % drive_distance
	distance_label.add_theme_font_size_override("font_size", 36)
	distance_label.add_theme_color_override("font_color", Color.WHITE)
	distance_label.add_theme_constant_override("outline_size", 2)
	distance_label.add_theme_color_override("font_outline_color", Color.BLACK)
	distance_label.position = Vector2(150, 80)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(distance_label)
	
	# Click instruction
	var instruction_label := Label.new()
	instruction_label.text = "Click anywhere to continue"
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	instruction_label.position = Vector2(120, 150)
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(instruction_label)
	
	$UILayer.add_child(drive_distance_dialog)
	print("Drive distance dialog created and input connected")

func _on_drive_distance_dialog_input(event: InputEvent) -> void:
	print("Dialog input received:", event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Dialog clicked - dismissing")
		# Dismiss dialog
		if drive_distance_dialog:
			drive_distance_dialog.queue_free()
			drive_distance_dialog = null
		
		# Go to move phase so player can move to the ball
		print("Going to move phase after drive distance dialog")
		game_phase = "move"
		
		# Update ModShotRoom button visibility
		update_mod_shot_room_visibility()
		
		# Show the draw cards button for movement cards
		draw_cards_button.visible = true
		draw_cards_button.text = "Draw Cards"
		print("Draw cards button made visible for movement phase")
		
		# Return camera to player
		var dialog_player_sprite = player_node.get_node_or_null("Sprite2D")
		var dialog_player_size = dialog_player_sprite.texture.get_size() * dialog_player_sprite.scale if dialog_player_sprite and dialog_player_sprite.texture else Vector2(cell_size, cell_size)
		var player_center: Vector2 = player_node.global_position + dialog_player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		print("Camera returned to player")

func setup_swing_sounds() -> void:
	# Get references to the existing audio players in the scene
	swing_strong_sound = $SwingStrong
	swing_med_sound = $SwingMed
	swing_soft_sound = $SwingSoft
	water_plunk_sound = $WaterPlunk
	sand_thunk_sound = $SandThunk
	
	print("Swing sounds setup complete")

func play_swing_sound(power: float) -> void:
	# Calculate power percentage (0.0 to 1.0)
	var power_percentage = (power - MIN_LAUNCH_POWER) / (MAX_LAUNCH_POWER - MIN_LAUNCH_POWER)
	power_percentage = clamp(power_percentage, 0.0, 1.0)
	
	print("Power percentage:", power_percentage)
	
	# Play different sounds based on power level
	if power_percentage >= 0.7:  # Strong swing (70%+ power)
		print("Playing strong swing sound")
		swing_strong_sound.play()
	elif power_percentage >= 0.4:  # Medium swing (40-70% power)
		print("Playing medium swing sound")
		swing_med_sound.play()
	else:  # Soft swing (0-40% power)
		print("Playing soft swing sound")
		swing_soft_sound.play()

func start_next_shot_from_ball() -> void:
	# Remove the old ball since we're taking a new shot from its position
	if golf_ball and is_instance_valid(golf_ball):
		golf_ball.queue_free()
		golf_ball = null
	
	# Reset the waiting flag since we're taking the next shot
	waiting_for_player_to_reach_ball = false
	
	# Move the player to the ball's position (they're already there, but update visuals)
	update_player_position()
	
	# Start with club selection phase
	enter_draw_cards_phase()
	
	print("Ready for next shot from position:", player_grid_pos)

func _on_golf_ball_out_of_bounds():
	print("Golf ball went out of bounds!")
	
	# Play water plunk sound if available
	if water_plunk_sound and water_plunk_sound.stream:
		water_plunk_sound.play()
	
	# Stop camera following
	camera_following_ball = false
	
	# Add penalty stroke
	hole_score += 1
	print("Out of bounds penalty! Shots so far:", hole_score)
	
	# Remove the ball from the scene
	if golf_ball:
		golf_ball.queue_free()
		golf_ball = null
	
	# Show out of bounds dialog
	show_out_of_bounds_dialog()
	
	# Return ball to the shot start position (not tee box)
	ball_landing_tile = shot_start_grid_pos
	ball_landing_position = Vector2(shot_start_grid_pos.x * cell_size + cell_size/2, shot_start_grid_pos.y * cell_size + cell_size/2)
	waiting_for_player_to_reach_ball = true
	
	# Move player to the shot start position
	player_grid_pos = shot_start_grid_pos
	update_player_position()
	
	# Set game phase to draw_cards for club selection since player is at ball position
	game_phase = "draw_cards"
	print("Game phase set to:", game_phase)
	print("Ball returned to shot start position:", shot_start_grid_pos)
	print("Player moved to shot start position:", player_grid_pos)
	print("Ready for club selection for penalty shot")

func show_out_of_bounds_dialog():
	# Create a dialog to inform the player
	var dialog = AcceptDialog.new()
	dialog.title = "Out of Bounds!"
	dialog.dialog_text = "Your ball went out of bounds!\n\nPenalty: +1 stroke\nYour ball has been returned to where you took the shot from.\n\nClick to select your club for the penalty shot."
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.RED)
	
	# Position the dialog in the center of the screen
	dialog.position = Vector2(400, 300)
	# Remove z_index setting as AcceptDialog doesn't support it
	
	# Add to UI layer
	$UILayer.add_child(dialog)
	
	# Show the dialog
	dialog.popup_centered()
	
	# Connect the confirmed signal to remove the dialog and enter club selection
	dialog.confirmed.connect(func():
		dialog.queue_free()
		print("Out of bounds dialog dismissed")
		enter_draw_cards_phase()  # Go directly to club selection
		print("Entering club selection phase for penalty shot")
	)

func reset_player_to_tee():
	# Find the first tee box and place the player there
	for y in map_manager.level_layout.size():
		for x in map_manager.level_layout[y].size():
			if map_manager.get_tile_type(x, y) == "Tee":
				player_grid_pos = Vector2i(x, y)
				update_player_position()
				print("Player reset to tee box at:", player_grid_pos)
				return
	
	# If no tee box found, use a default position
	player_grid_pos = Vector2i(25, 25)
	update_player_position()
	print("Player reset to default position:", player_grid_pos)

func enter_launch_phase() -> void:
	"""Enter the launch phase for taking a shot"""
	game_phase = "launch"
	print("Entered launch phase - ready to take shot")
	print("Putting mode:", is_putting)
	
	# Remove ghost ball when entering launch phase
	remove_ghost_ball()
	
	# Reset charge time
	charge_time = 0.0
	
	# Store the original aiming mouse position
	original_aim_mouse_pos = get_global_mouse_position()
	print("Original aim mouse position:", original_aim_mouse_pos)
	
	# Show power meter (always show for all clubs)
	show_power_meter()
	
	# Only show height meter for non-putter clubs
	if not is_putting:
		show_height_meter()
		# Initialize height to minimum for non-putter clubs
		launch_height = MIN_LAUNCH_HEIGHT
	else:
		# For putters, set height to 0 (no arc, just rolling)
		launch_height = 0.0
		# print("Putter selected - height set to 0 for rolling only")
	
	# Initialize power to the scaled minimum
	var scaled_min_power = power_meter.get_meta("scaled_min_power", MIN_LAUNCH_POWER)
	launch_power = scaled_min_power
	
	print("=== LAUNCH PHASE INITIALIZATION ===")
	print("Initial power:", launch_power)
	print("Initial height:", launch_height)
	print("Scaled min power:", scaled_min_power)
	print("Chosen landing spot:", chosen_landing_spot)
	if chosen_landing_spot != Vector2.ZERO:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
		print("Distance to target:", distance_to_target)
	print("=== END LAUNCH PHASE INITIALIZATION ===")
	
	# Don't draw cards here - they will be drawn after the drive distance dialog
	# Cards should only be drawn when the player clicks on themselves after the dialog
	
	# Center camera on player
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Create or show spin indicator (only for non-putter clubs)
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
		# Hide spin indicator for putters
		if spin_indicator:
			spin_indicator.visible = false
	
	print("Launch phase ready!")

func enter_aiming_phase() -> void:
	"""Enter the aiming phase where player sets the landing spot"""
	game_phase = "aiming"
	is_aiming_phase = true
	print("Entered aiming phase - move mouse to set landing spot")
	
	# Update ModShotRoom button visibility
	update_mod_shot_room_visibility()
	
	# Show the aiming circle
	show_aiming_circle()
	
	# Create ghost ball for aiming preview
	create_ghost_ball()
	
	# Show instruction label
	show_aiming_instruction()
	
	# Center camera on player
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	print("Aiming phase ready! Left click to confirm landing spot, right click to cancel")

func show_aiming_instruction() -> void:
	# Remove any existing instruction
	var existing_instruction = $UILayer.get_node_or_null("AimingInstructionLabel")
	if existing_instruction:
		existing_instruction.queue_free()
	
	# Create instruction label
	var instruction_label := Label.new()
	instruction_label.name = "AimingInstructionLabel"
	
	# Different instructions for putters vs other clubs
	if is_putting:
		instruction_label.text = "Move mouse to set landing spot\nLeft click to confirm, Right click to cancel\n(Putter: Power only, no height)"
	else:
		instruction_label.text = "Move mouse to set landing spot\nLeft click to confirm, Right click to cancel"
	
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.YELLOW)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Position it at the top of the screen
	instruction_label.position = Vector2(400, 50)
	instruction_label.z_index = 200
	
	# Add to UI layer
	$UILayer.add_child(instruction_label)

func hide_aiming_instruction() -> void:
	var instruction_label = $UILayer.get_node_or_null("AimingInstructionLabel")
	if instruction_label:
		instruction_label.queue_free()

func draw_cards_for_shot(card_count: int = 3) -> void:
	"""Draw cards for the current shot"""
	# Apply character card draw modifier
	var card_draw_modifier = player_stats.get("card_draw", 0)
	var final_card_count = card_count + card_draw_modifier
	# Ensure we don't draw negative cards
	final_card_count = max(1, final_card_count)
	
	print("Drawing", final_card_count, "cards for shot... (base:", card_count, "modifier:", card_draw_modifier, ")")
	deck_manager.draw_cards(final_card_count)
	print("Cards drawn. Hand size:", deck_manager.hand.size())

func start_shot_sequence() -> void:
	"""Start a complete shot sequence - enter aiming phase first"""
	enter_aiming_phase()

func draw_cards_for_next_shot() -> void:
	"""Draw cards for the next shot without entering launch phase"""
	print("Drawing cards for next shot...")
	# Play CardDraw sound when drawing the 3 cards
	if card_stack_display.has_node("CardDraw"):
		var card_draw_sound = card_stack_display.get_node("CardDraw")
		if card_draw_sound and card_draw_sound.stream:
			card_draw_sound.play()
	draw_cards_for_shot(3)  # This now includes character modifiers
	create_movement_buttons()
	print("Cards drawn and movement buttons created for next shot")

func _on_golf_ball_sand_landing():
	print("Golf ball landed in sand trap!")
	
	# Play sand thunk sound if available
	if sand_thunk_sound and sand_thunk_sound.stream:
		sand_thunk_sound.play()
	
	# Stop camera following
	camera_following_ball = false
	
	# Get the final tile position where the ball landed
	if golf_ball and map_manager:
		var final_tile = Vector2i(floor(golf_ball.position.x / cell_size), floor(golf_ball.position.y / cell_size))
		print("Ball landed in sand at tile:", final_tile)
		
		# Handle exactly like a normal landing (this will remove the ball)
		_on_golf_ball_landed(final_tile)

func show_sand_landing_dialog():
	# Create a dialog to inform the player
	var dialog = AcceptDialog.new()
	dialog.title = "Sand Trap!"
	dialog.dialog_text = "Your ball landed in a sand trap!\n\nThis is a valid shot - no penalty.\nYou'll take your next shot from here."
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.ORANGE)
	
	# Position the dialog in the center of the screen
	dialog.position = Vector2(400, 300)
	
	# Add to UI layer
	$UILayer.add_child(dialog)
	
	# Show the dialog
	dialog.popup_centered()
	
	# Connect the confirmed signal to remove the dialog only
	dialog.confirmed.connect(func():
		dialog.queue_free()
		print("Sand landing dialog dismissed")
		print("Move your character to the ball position to take your next shot!")
	)

func show_hole_completion_dialog():
	"""Show dialog when the ball goes in the hole"""
	# Store the hole score in round_scores array
	round_scores.append(hole_score)
	
	# Calculate par for this hole
	var hole_par = GolfCourseLayout.get_hole_par(current_hole)
	var score_vs_par = hole_score - hole_par
	
	# Create score text with par information
	var score_text = "Hole %d Complete!\n\n" % (current_hole + 1)
	score_text += "Hole Score: %d strokes\n" % hole_score
	score_text += "Par: %d\n" % hole_par
	
	# Add par-based score display
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
	
	# Show round progress
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
	
	# Check if this is the last hole of the current round
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
	"""Reset the game state for the next hole"""
	print("Resetting for next hole...")
	print("Current hole before increment:", current_hole)
	current_hole += 1
	print("Current hole after increment:", current_hole)
	
	# Check if we've completed the current round (front 9 or back 9)
	var round_end_hole = 0
	if is_back_9_mode:
		round_end_hole = back_9_start_hole + NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		round_end_hole = NUM_HOLES - 1  # Hole 9 (index 8)
	
	if current_hole > round_end_hole:
		print("Current hole > round end hole, returning early")
		return
	
	# Hide existing player instead of removing it
	if player_node and is_instance_valid(player_node):
		player_node.visible = false
		print("Hidden existing player for new hole")
	
	# Load the next hole layout
	print("Loading map data for hole:", current_hole + 1)
	map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
	print("About to call build_map_from_layout_with_randomization for hole:", current_hole + 1)
	build_map_from_layout_with_randomization(map_manager.level_layout)
	print("build_map_from_layout_with_randomization completed for hole:", current_hole + 1)
	
	# Reset hole score
	hole_score = 0
	game_phase = "tee_select"
	is_putting = false
	chosen_landing_spot = Vector2.ZERO
	selected_club = ""
	update_hole_and_score_display()
	if hud:
		hud.get_node("ShotLabel").text = "Shots: %d" % hole_score
	
	# Start tee placement phase for new hole
	is_placing_player = true
	highlight_tee_tiles()
	show_tee_selection_instruction()
	print("Reset complete. Ready for next hole!")

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
	"""Show final round score dialog for front 9 completion"""
	var total_round_score = 0
	for score in round_scores:
		total_round_score += score
	
	var total_par = GolfCourseLayout.get_front_nine_par()
	var round_vs_par = total_round_score - total_par
	
	# Create detailed score breakdown
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
	
	# Final score vs par
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
	
	# Check if this is the 18th hole (hole 18, index 17)
	if current_hole == 17:  # 18th hole completed
		# For now, we'll use the back 9 score as the total score
		# In a full implementation, this would include front 9 score
		var total_18_hole_score = total_round_score
		
		# Store the final score in Global
		Global.final_18_hole_score = total_18_hole_score
		
		# Transition to end scene
		FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://EndScene.tscn"), 0.5)
		return
	
	# Create detailed score breakdown for back 9 only
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
	
	# Final score vs par
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
		
		# Calculate current round score
		var current_round_score = 0
		for score in round_scores:
			current_round_score += score
		current_round_score += hole_score  # Include current hole score
		
		# Calculate vs par based on mode
		var total_par_so_far = 0
		if is_back_9_mode:
			# For back 9, calculate par from hole 10 onwards
			for i in range(back_9_start_hole, current_hole + 1):
				total_par_so_far += GolfCourseLayout.get_hole_par(i)
		else:
			# For front 9, calculate par from hole 1 onwards
			for i in range(current_hole + 1):
				total_par_so_far += GolfCourseLayout.get_hole_par(i)
		var round_vs_par = current_round_score - total_par_so_far
		
		label.text = "Hole: %d/%d    Round: %d (%+d)" % [current_hole+1, NUM_HOLES, current_round_score, round_vs_par]
		label.position = Vector2(10, 10)
		label.z_index = 200

func _on_draw_cards_pressed() -> void:
	if game_phase == "draw_cards":
		# Club selection phase - draw club cards
		print("Drawing club cards for selection...")
		# Play CardDraw sound
		if card_stack_display.has_node("CardDraw"):
			var card_draw_sound = card_stack_display.get_node("CardDraw")
			if card_draw_sound and card_draw_sound.stream:
				card_draw_sound.play()
		draw_club_cards()
	else:
		# Normal movement phase - draw movement cards
		# Play CardDraw sound
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
	
	# DEBUG: Force it to be visible at a fixed position in camera container coordinates
	var screen_center = Vector2(get_viewport().size.x, get_viewport().size.y) / 2
	var debug_pos = screen_center - camera_container.position  # Convert to camera container coordinates
	spin_indicator.clear_points()
	spin_indicator.add_point(debug_pos)
	spin_indicator.add_point(debug_pos + Vector2(100, 0))  # 100 pixel line to the right
	spin_indicator.default_color = Color(1, 0, 0, 1)  # Bright red
	spin_indicator.width = 20  # Very thick
	# Get current mouse position and calculate spin
	var current_mouse_pos = get_global_mouse_position()
	var mouse_deviation = current_mouse_pos - original_aim_mouse_pos
	
	# Calculate spin direction (perpendicular to launch direction)
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
	
	# Scale the spin for visual display
	var spin_scale = 2.0  # Reduced from 6.0 to keep indicator on screen
	var max_spin_threshold = 120.0  # Increased from 60.0 to require greater mouse movement
	var visual_length = clamp(spin_strength * spin_scale, -max_spin_threshold * spin_scale, max_spin_threshold * spin_scale)
	
	# Position the indicator at the player's position in camera container coordinates
	var indicator_pos = Vector2.ZERO
	if player_node:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		indicator_pos = player_center - camera_container.position
	else:
		var fallback_center = Vector2(get_viewport().size.x, get_viewport().size.y) / 2
		indicator_pos = fallback_center - camera_container.position
	
	# Clear and redraw the indicator
	spin_indicator.clear_points()
	spin_indicator.add_point(indicator_pos)
	spin_indicator.add_point(indicator_pos + spin_dir * visual_length)
	
	# Change color based on spin strength
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
	
	# Show the draw cards button
	draw_cards_button.visible = true
	draw_cards_button.text = "Draw Club Cards"
	
	# Update ModShotRoom button visibility
	update_mod_shot_room_visibility()
	
	# Center camera on player
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	print("Draw cards phase ready! Click 'Draw Club Cards' to select your club")

func draw_club_cards() -> void:
	"""Draw club cards for selection (Driver, Iron, Putter) and allow bonus cards like StickyShot to appear as extras."""
	print("Drawing club cards from bag pile...")
	
	# Clear any existing movement buttons
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	
	# Create a copy of the bag pile to draw from
	var available_clubs = bag_pile.duplicate()
	
	# Check for putt putt mode - only use putters
	if Global.putt_putt_mode:
		print("Putt Putt mode enabled - filtering for putters only")
		available_clubs = available_clubs.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		)
		print("Available putters:", available_clubs.map(func(card): return card.name))
	
	# Apply character card draw modifier to club selection
	var base_club_count = 2  # Default number of clubs to show
	var card_draw_modifier = player_stats.get("card_draw", 0)
	var final_club_count = base_club_count + card_draw_modifier
	# Ensure we don't show negative clubs and cap at available clubs
	final_club_count = max(1, min(final_club_count, available_clubs.size()))
	
	print("Selecting", final_club_count, "clubs for selection... (base:", base_club_count, "modifier:", card_draw_modifier, ")")
	
	var selected_clubs: Array[CardData] = []
	var bonus_cards: Array[CardData] = []
	
	# First, ensure we always get at least one putter (unless in putt putt mode where all are putters)
	if not Global.putt_putt_mode:
		# Find all putters in available clubs
		var putters = available_clubs.filter(func(card): 
			var club_info = club_data.get(card.name, {})
			return club_info.get("is_putter", false)
		)
		
		if putters.size() > 0:
			# Randomly select one putter
			var random_putter_index = randi() % putters.size()
			var selected_putter = putters[random_putter_index]
			selected_clubs.append(selected_putter)
			
			# Remove the selected putter from available clubs
			available_clubs.erase(selected_putter)
			print("Guaranteed putter selected:", selected_putter.name)
			
			# Adjust final club count since we already selected one
			final_club_count -= 1
	
	# Randomly select remaining clubs from the available clubs, skipping ModifyNext cards
	var club_candidates = available_clubs.filter(func(card): return card.effect_type != "ModifyNext")
	for i in range(final_club_count):
		if club_candidates.size() > 0:
			var random_index = randi() % club_candidates.size()
			selected_clubs.append(club_candidates[random_index])
			club_candidates.remove_at(random_index)
	
	# Now, check for any ModifyNext (e.g., StickyShot) cards in the bag pile and randomly add one as a bonus (with a chance)
	var modify_next_candidates = available_clubs.filter(func(card): return card.effect_type == "ModifyNext")
	if force_stickyshot_bonus:
		# Always add StickyShot as a bonus if forced
		for card in modify_next_candidates:
			if card.name == "Sticky Shot":
				bonus_cards.append(card)
				print("StickyShot forced as bonus card")
				break
		force_stickyshot_bonus = false
	elif modify_next_candidates.size() > 0:
		# 50% chance to add a bonus ModifyNext card (or always, if you want)
		if randi() % 2 == 0:
			var random_index = randi() % modify_next_candidates.size()
			bonus_cards.append(modify_next_candidates[random_index])
			print("Bonus card added:", modify_next_candidates[random_index].name)
	
	print("Selected clubs to draw:", selected_clubs.map(func(card): return card.name))
	if bonus_cards.size() > 0:
		print("Bonus cards:", bonus_cards.map(func(card): return card.name))
	
	# Create club card buttons using actual card data
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
		
		# Input behaviour
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.z_index = 10
		
		# Hover overlay
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
		else:
			btn.pressed.connect(func(): _on_club_card_pressed(club_name, club_info, btn))
		
		movement_buttons_container.add_child(btn)
		movement_buttons.append(btn)
	
	# Hide the draw cards button
	draw_cards_button.visible = false
	
	print("Club cards created from bag pile. Select your club!")

func _on_club_card_pressed(club_name: String, club_info: Dictionary, button: TextureButton) -> void:
	"""Handle club card selection"""
	print("Club selected:", club_name, "Club info:", club_info)
	
	# Store the selected club and its data
	selected_club = club_name
	
	# Apply character strength modifier to max shot distance
	var base_max_distance = club_info["max_distance"]
	var strength_modifier = player_stats.get("strength", 0)
	var strength_multiplier = 1.0 + (strength_modifier * 0.1)  # Same multiplier as power calculation
	max_shot_distance = base_max_distance * strength_multiplier
	
	print("Max distance calculation - base:", base_max_distance, "strength modifier:", strength_modifier, "final:", max_shot_distance)
	
	# Set putting flag if this is a putter
	is_putting = club_info.get("is_putter", false)
	print("Putting mode:", is_putting)
	
	# Play card click sound
	card_click_sound.play()
	
	# Clear club card buttons
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	
	# Transition to aiming phase
	enter_aiming_phase()
	
	print("Club selection complete. Entering aiming phase with", club_name, "max distance:", max_shot_distance, "putting:", is_putting)

func _on_player_moved_to_tile(new_grid_pos: Vector2i) -> void:
	print("=== PLAYER MOVED DEBUG ===")
	print("Player moved to new grid position:", new_grid_pos)
	print("Old player_grid_pos:", player_grid_pos)
	
	# Update the main script's grid position
	player_grid_pos = new_grid_pos
	print("Updated player_grid_pos to:", player_grid_pos)
	
	# Check if player moved to shop position
	if player_grid_pos == shop_grid_pos and not shop_entrance_detected:
		shop_entrance_detected = true
		show_shop_entrance_dialog()
		return  # Don't exit movement mode yet
	elif player_grid_pos != shop_grid_pos:
		# Reset shop entrance detection if player moved away
		shop_entrance_detected = false
	
	# Update the player's visual position
	update_player_position()
	
	# Exit movement mode (this will discard the card)
	exit_movement_mode()
	
	print("=== END PLAYER MOVED DEBUG ===")

func show_shop_entrance_dialog():
	"""Show dialog asking if player wants to enter the shop"""
	if shop_dialog:
		shop_dialog.queue_free()
	
	shop_dialog = Control.new()
	shop_dialog.name = "ShopEntranceDialog"
	shop_dialog.size = get_viewport_rect().size
	shop_dialog.z_index = 500
	shop_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Semi-transparent background
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = shop_dialog.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_dialog.add_child(background)
	
	# Dialog box
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.9)
	dialog_box.size = Vector2(400, 200)
	dialog_box.position = (shop_dialog.size - dialog_box.size) / 2  # Center the dialog
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_dialog.add_child(dialog_box)
	
	# Title label
	var title_label := Label.new()
	title_label.text = "Golf Shop"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(150, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	# Question label
	var question_label := Label.new()
	question_label.text = "Would you like to enter the shop?"
	question_label.add_theme_font_size_override("font_size", 18)
	question_label.add_theme_color_override("font_color", Color.WHITE)
	question_label.position = Vector2(100, 80)
	question_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(question_label)
	
	# Yes button
	var yes_button := Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.position = Vector2(120, 140)
	yes_button.pressed.connect(_on_shop_enter_yes)
	dialog_box.add_child(yes_button)
	
	# No button
	var no_button := Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.position = Vector2(220, 140)
	no_button.pressed.connect(_on_shop_enter_no)
	dialog_box.add_child(no_button)
	
	$UILayer.add_child(shop_dialog)
	print("Shop entrance dialog created")

func _on_shop_enter_yes():
	"""Player chose to enter the shop"""
	print("Player chose to enter shop")
	
	# Save current game state
	save_game_state()
	
	# Use FadeManager for smooth transition
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Shop/ShopInterior.tscn"), 0.5)

func _on_shop_enter_no():
	"""Player chose not to enter the shop"""
	print("Player chose not to enter shop")
	
	# Dismiss dialog
	if shop_dialog:
		shop_dialog.queue_free()
		shop_dialog = null
	
	# Reset shop entrance detection
	shop_entrance_detected = false
	
	# Exit movement mode normally
	exit_movement_mode()

func show_shop_under_construction_dialog():
	"""Show shop under construction dialog"""
	if shop_dialog:
		shop_dialog.queue_free()
	
	shop_dialog = Control.new()
	shop_dialog.name = "ShopUnderConstructionDialog"
	shop_dialog.size = get_viewport_rect().size
	shop_dialog.z_index = 500
	shop_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Semi-transparent background
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = shop_dialog.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_dialog.add_child(background)
	
	# Dialog box
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.9)
	dialog_box.size = Vector2(400, 200)
	dialog_box.position = Vector2(400, 200)
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_dialog.add_child(dialog_box)
	
	# Title label
	var title_label := Label.new()
	title_label.text = "Shop Under Construction"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.ORANGE)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(100, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	# Message label
	var message_label := Label.new()
	message_label.text = "Shop under construction, brb!\n\nClick to return to the course."
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.position = Vector2(100, 80)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(message_label)
	
	# Click instruction
	var instruction_label := Label.new()
	instruction_label.text = "Click anywhere to continue"
	instruction_label.add_theme_font_size_override("font_size", 14)
	instruction_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	instruction_label.position = Vector2(120, 150)
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(instruction_label)
	
	# Connect input to background
	background.gui_input.connect(_on_shop_under_construction_input)
	
	$UILayer.add_child(shop_dialog)
	print("Shop under construction dialog created")

func _on_shop_under_construction_input(event: InputEvent):
	"""Handle input for shop under construction dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Shop under construction dialog clicked - returning to course")
		
		# Dismiss dialog
		if shop_dialog:
			shop_dialog.queue_free()
			shop_dialog = null
		
		# Restore game state
		restore_game_state()
		
		# Reset shop entrance detection
		shop_entrance_detected = false
		
		# Exit movement mode
		exit_movement_mode()

func save_game_state():
	"""Save important game state before entering shop"""
	print("Saving game state before entering shop")
	
	# Save important game state to Global
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
	
	# Save ball-related state
	Global.saved_ball_landing_tile = ball_landing_tile
	Global.saved_ball_landing_position = ball_landing_position
	Global.saved_waiting_for_player_to_reach_ball = waiting_for_player_to_reach_ball
	Global.saved_ball_exists = (golf_ball != null and is_instance_valid(golf_ball))
	
	# Save tree, pin, and shop positions
	Global.saved_tree_positions.clear()
	Global.saved_pin_position = Vector2i.ZERO
	Global.saved_shop_position = Vector2i.ZERO
	
	# Debug: Print all ysort_objects to see what we have
	print("[DEBUG] ysort_objects at save time (size:", ysort_objects.size(), "):")
	for i in range(ysort_objects.size()):
		var obj_data = ysort_objects[i]
		var node = obj_data.node
		var grid_pos = obj_data.grid_pos
		print("[DEBUG] Object", i, ":", node, "name:", node.name, "class:", node.get_class(), "at pos:", grid_pos)
	
	# Collect tree, pin, and shop positions from ysort_objects
	for obj_data in ysort_objects:
		var node = obj_data.node
		var grid_pos = obj_data.grid_pos
		
		# Check if this is a tree - improved detection
		var is_tree = false
		if node.name == "Tree":
			is_tree = true
			print("[DEBUG] Found tree by name at:", grid_pos)
		elif node.has_method("blocks") and node.blocks():
			is_tree = true
			print("[DEBUG] Found tree by blocks() method at:", grid_pos)
		elif node.get_script() and node.get_script().get_path().find("Tree.gd") != -1:
			is_tree = true
			print("[DEBUG] Found tree by script path at:", grid_pos)
		
		if is_tree:
			Global.saved_tree_positions.append(grid_pos)
			print("Saved tree position:", grid_pos)
		
		# Check if this is a pin
		if node.name == "Pin" or (node.has_method("get_class") and node.get_class() == "Pin"):
			Global.saved_pin_position = grid_pos
			print("Saved pin position:", grid_pos)
		
		# Check if this is a shop
		if node.name == "Shop" or (node.has_method("get_class") and node.get_class() == "Shop"):
			Global.saved_shop_position = grid_pos
			print("Saved shop position:", grid_pos)
	
	# Also save the current shop_grid_pos as a fallback
	if Global.saved_shop_position == Vector2i.ZERO:
		Global.saved_shop_position = shop_grid_pos
		print("Saved shop position from shop_grid_pos:", shop_grid_pos)

	print("[DEBUG] Final saved tree positions:", Global.saved_tree_positions)
	print("Game state saved to Global - game phase:", game_phase, "ball exists:", Global.saved_ball_exists)
	print("Saved", Global.saved_tree_positions.size(), "trees, pin at", Global.saved_pin_position, "and shop at", Global.saved_shop_position)

func restore_game_state():
	"""Restore game state after returning from shop"""
	print("Restoring game state after returning from shop")
	
	# Check if we have saved state
	if Global.saved_game_state == "shop_entrance":
		# Load map data and rebuild with saved positions
		print("Loading map data for hole:", current_hole + 1)
		map_manager.load_map_data(GolfCourseLayout.get_hole_layout(current_hole))
		print("Map data loaded, building map with saved positions...")
		build_map_from_layout_with_saved_positions(map_manager.level_layout)
		print("Map built with saved positions, camera should be positioned on pin")
		
		# Restore player position
		player_grid_pos = Global.saved_player_grid_pos
		update_player_position()
		
		# Make player visible (important!)
		if player_node:
			player_node.visible = true
		
		# IMPORTANT: Set is_placing_player to false so movement works
		is_placing_player = false
		
		# Restore ball-related state
		ball_landing_tile = Global.saved_ball_landing_tile
		ball_landing_position = Global.saved_ball_landing_position
		waiting_for_player_to_reach_ball = Global.saved_waiting_for_player_to_reach_ball
		
		# Restore the ball if it existed
		if Global.saved_ball_exists and Global.saved_ball_position != Vector2.ZERO:
			print("Recreating golf ball at saved position:", Global.saved_ball_position)
			# Remove any existing ball
			if golf_ball and is_instance_valid(golf_ball):
				golf_ball.queue_free()
			
			# Create new ball
			golf_ball = preload("res://GolfBall.tscn").instantiate()
			
			# Ensure collision properties are set correctly
			var ball_area = golf_ball.get_node_or_null("Area2D")
			if ball_area:
				ball_area.collision_layer = 1
				ball_area.collision_mask = 1  # Collide with layer 1 (trees)
			
			# Note: CharacterBody2D collision layers removed - using Area2D for all collision detection
			
			# Set collision layers for the CharacterBody2D (for trunk collisions)
			golf_ball.collision_layer = 1
			golf_ball.collision_mask = 1  # Collide with layer 1 (trees)
			
			# Set ball position in camera container coordinates
			var ball_local_position = Global.saved_ball_position - camera_container.global_position
			golf_ball.position = ball_local_position
			
			# Set up the ball
			golf_ball.cell_size = cell_size
			golf_ball.map_manager = map_manager
			camera_container.add_child(golf_ball)
			golf_ball.add_to_group("balls")  # Add to group for collision detection
			
			print("Golf ball restored at position:", golf_ball.global_position)
		else:
			print("No ball to restore or ball position was zero")
			if golf_ball and is_instance_valid(golf_ball):
				golf_ball.queue_free()
				golf_ball = null
		
		# Restore turn and score
		turn_count = Global.saved_current_turn
		hole_score = Global.saved_shot_score
		
		# Restore deck state
		deck_manager.restore_deck_state(Global.saved_deck_manager_state)
		deck_manager.restore_discard_state(Global.saved_discard_pile_state)
		deck_manager.restore_hand_state(Global.saved_hand_state)
		
		# Restore has_started
		has_started = Global.saved_has_started
		
		# Restore the saved game phase (instead of always setting to "move")
		if Global.get("saved_game_phase") != null:
			game_phase = Global.saved_game_phase
		else:
			game_phase = "move"
		
		# Recreate movement buttons if there are cards in hand
		if deck_manager.hand.size() > 0:
			print("Recreating movement buttons for", deck_manager.hand.size(), "cards")
			create_movement_buttons()
		
		# Update UI
		update_deck_display()
		
		# Apply equipment buffs when returning from shop
		update_player_stats_from_equipment()
		
		# Focus camera on the player at shop position
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		camera_snap_back_pos = player_center
		
		# Add camera transition to player position when returning from shop
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		print("Game state restored from Global - player at shop position, game phase:", game_phase, "is_placing_player:", is_placing_player, "ball exists:", golf_ball != null)
		print("Restored", Global.saved_tree_positions.size(), "trees, pin at", Global.saved_pin_position, "and shop at", Global.saved_shop_position)
	else:
		print("No saved game state found")

func is_player_on_shop_tile() -> bool:
	"""Check if the player is currently on the shop tile"""
	return player_grid_pos == shop_grid_pos

# Place these at the top, after variable declarations and before _ready

func build_map_from_layout(layout: Array) -> void:
	obstacle_map.clear()
	ysort_objects.clear() # Clear previous objects
	# First pass: Place all tiles (ground)
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size

			# Determine what tile to place
			var tile_code: String = code
			if object_scene_map.has(code):
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
	# Second pass: Place objects on top of tiles
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size
			# Only place objects (not tiles)
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
				# Don't scale objects - they should be Y-sorted sprites
				# Objects will handle their own scaling and positioning
				# Set grid_position if the property exists
				if object.has_meta("grid_position") or "grid_position" in object:
					object.set("grid_position", pos)
				else:
					push_warning("⚠️ Object missing 'grid_position'. Type: %s" % object.get_class())
				# Track for Y-sorting
				ysort_objects.append({"node": object, "grid_pos": pos})
				obstacle_layer.add_child(object)
				
				# Connect pin signals if this is a pin
				if object.has_signal("hole_in_one"):
					object.hole_in_one.connect(_on_hole_in_one)
				if object.has_signal("pin_flag_hit"):
					object.pin_flag_hit.connect(_on_pin_flag_hit)
				
				# If this object blocks movement, add it to obstacle_map
				if object.has_method("blocks") and object.blocks():
					obstacle_map[pos] = object
				# Debug: Print tree positions
				if code == "T":
					print("Tree created at grid position:", pos, "world position:", object.position, "global position:", object.global_position)
					# Check if this tree should be near the ball's path
					if pos.x >= 16 and pos.x <= 18 and pos.y >= 10 and pos.y <= 12:
						print("*** TREE IN BALL PATH! Grid:", pos, "World:", object.position, "Global:", object.global_position)
				
				# Special case: Place invisible blocker to the right of Shop
				if code == "SHOP":
					var right_of_shop_pos = pos + Vector2i(1, 0)
					var blocker_scene = preload("res://Obstacles/InvisibleBlocker.tscn")
					var blocker = blocker_scene.instantiate()
					var blocker_world_pos = Vector2(right_of_shop_pos.x, right_of_shop_pos.y) * cell_size
					blocker.position = blocker_world_pos + Vector2(cell_size / 2, cell_size / 2)
					obstacle_layer.add_child(blocker)
					obstacle_map[right_of_shop_pos] = blocker
					print("Placed invisible blocker to the right of Shop at:", right_of_shop_pos)
				
				# Note: We don't overwrite obstacle_map[pos] since the tile is already there
				# Objects are separate from the tile system for movement/collision
			elif not tile_scene_map.has(code):
				print("ℹ️ Skipping unmapped code '%s' at (%d,%d)" % [code, x, y])

func focus_camera_on_tee():
	var tee_center_local := _get_tee_area_center()
	var tee_center_global := camera_container.position + tee_center_local
	camera_snap_back_pos = tee_center_global
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", tee_center_global, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Ghost ball system variables
var ghost_ball: Node2D = null
var ghost_ball_active: bool = false

func create_ghost_ball() -> void:
	"""Create a ghost ball for aiming preview"""
	
	if ghost_ball and is_instance_valid(ghost_ball):
		ghost_ball.queue_free()
	
	ghost_ball = preload("res://GhostBall.tscn").instantiate()
	
	# Ensure collision properties are set correctly
	var ghost_ball_area = ghost_ball.get_node_or_null("Area2D")
	if ghost_ball_area:
		ghost_ball_area.collision_layer = 1
		ghost_ball_area.collision_mask = 1  # Collide with layer 1 (trees)
	
	# Position the ghost ball at the player's position
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	
	# Add vertical offset for all shots to match the real ball positioning
	player_center += Vector2(0, -cell_size * 0.5)

	# Convert global position to camera container local position
	var ball_local_position = player_center - camera_container.global_position
	ghost_ball.position = ball_local_position
	
	# Set up the ghost ball
	ghost_ball.cell_size = cell_size
	ghost_ball.map_manager = map_manager
	
	# Set the club information for power calculations
	if selected_club in club_data:
		ghost_ball.set_club_info(club_data[selected_club])
	
	# Set the putting flag for the ghost ball
	ghost_ball.set_putting_mode(is_putting)
	
	# Add to camera container
	camera_container.add_child(ghost_ball)
	ghost_ball.add_to_group("balls")  # Add to group for collision detection
	ghost_ball_active = true
	
	# Update Y-sorting for the ghost ball
	update_ball_y_sort(ghost_ball)
	
	# Set initial landing spot if we have one
	if chosen_landing_spot != Vector2.ZERO:
		ghost_ball.set_landing_spot(chosen_landing_spot)

func update_ghost_ball() -> void:
	"""Update the ghost ball's landing spot and launch it"""
	if not ghost_ball or not is_instance_valid(ghost_ball):
		return
	
	# Set the landing spot for the ghost ball
	ghost_ball.set_landing_spot(chosen_landing_spot)
	
	# Don't reset the ball - let it continue its trajectory
	# The ghost ball will automatically relaunch every 2 seconds

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

	# Get ball's height (z-coordinate)
	var ball_height = 0.0
	if ball_node.has_method("get_height"):
		ball_height = ball_node.get_height()
	elif "z" in ball_node:
		ball_height = ball_node.z

	var ball_sprite = ball_node.get_node_or_null("Sprite2D")
	if not ball_sprite:
		return

	# Find the closest tree (by 2D distance) for Y-sorting
	var closest_tree = null
	var closest_tree_y = 0.0
	var closest_tree_z = 0
	var min_dist = INF
	for obj in ysort_objects:
		if not obj.has("node") or not obj["node"] or not is_instance_valid(obj["node"]):
			continue
		if obj["node"].z_index == 3:
			var tree_node = obj["node"]
			var tree_y_sort_point = tree_node.global_position.y
			if tree_node.has_method("get_y_sort_point"):
				tree_y_sort_point = tree_node.get_y_sort_point()
			
			# Calculate 2D distance from ball to tree (considering both X and Y)
			var tree_pos_2d = Vector2(tree_node.global_position.x, tree_y_sort_point)
			var ball_pos_2d = Vector2(ball_ground_pos.x, ball_ground_pos.y)
			var dist = ball_pos_2d.distance_to(tree_pos_2d)
			
			if dist < min_dist:
				min_dist = dist
				closest_tree = tree_node
				closest_tree_y = tree_y_sort_point
				closest_tree_z = tree_node.z_index

	if closest_tree != null:
		# Set tree height (can be adjusted later for realism)
		var tree_height = 1500.0  # Updated from 100.0 to 1500.0 to match max ball height of 2000
		
		# Only consider trees that are close enough to affect visibility
		var max_tree_distance = 200.0  # Only consider trees within 200 pixels
		if min_dist > max_tree_distance:
			# No close trees found, use default
			ball_sprite.z_index = 100  # Default to in front
			return
		
		# Check if ball is above the tree height
		if ball_height >= tree_height:
			# Ball is above tree height - always in front
			ball_sprite.z_index = 100  # Much higher z_index to be clearly in front of tree (z_index = 3)
		else:
			# Ball is below tree height - check if it has significant height
			var significant_height_threshold = 200.0  # If ball is more than 200 pixels high, it should appear in front
			if ball_height >= significant_height_threshold:
				# Ball has significant height - appear in front of tree
				ball_sprite.z_index = 100
			else:
				# Ball is close to ground level - use Y position for sorting
				var tree_threshold = closest_tree_y + 50  # 50 pixels higher threshold
				if ball_ground_pos.y > tree_threshold:
					ball_sprite.z_index = 100  # Much higher z_index to be clearly in front of tree (z_index = 3)
				else:
					ball_sprite.z_index = 1  # Much lower z_index to be clearly behind tree (z_index = 3)
	else:
		# No tree found, use default
		ball_sprite.z_index = 100  # Default to in front

	# Shadow follows ball sprite z_index
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

# Add this function after the other randomization functions
func test_randomization() -> void:
	"""Test function to verify randomization is working"""
	print("=== TESTING RANDOMIZATION ===")
	
	# Test with a simple layout
	var test_layout = [
		["Base", "Base", "Base", "Base", "Base"],
		["Base", "F", "F", "F", "Base"],
		["Base", "F", "G", "F", "Base"],
		["Base", "F", "F", "F", "Base"],
		["Base", "Base", "Base", "Base", "Base"]
	]
	
	print("Test layout:")
	for row in test_layout:
		print(row)
	
	var positions = get_random_positions_for_objects(test_layout, 3, true)
	print("Random positions result:", positions)
	
	# Test validity of positions
	for tree_pos in positions.trees:
		var valid = is_valid_position_for_object(tree_pos, test_layout)
		print("Tree at", tree_pos, "valid:", valid)
	
	if positions.shop != Vector2i.ZERO:
		var valid = is_valid_position_for_object(positions.shop, test_layout)
		print("Shop at", positions.shop, "valid:", valid)
	
	print("=== RANDOMIZATION TEST COMPLETE ===")

# Add these functions after the existing helper functions and before _process

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

func start_hole_with_pin_transition():
	"""Start a new hole with a pin-to-tee transition"""
	print("Starting hole with pin-to-tee transition...")
	print("Current camera position:", camera.position)
	
	# Add a small delay to ensure the map is fully built
	await get_tree().process_frame
	
	# Find pin position
	var pin_position = find_pin_position()
	if pin_position == Vector2.ZERO:
		print("Warning: No pin found, skipping transition")
		focus_camera_on_tee()
		return
	
	print("Pin found at:", pin_position)
	print("Camera position before setting to pin:", camera.position)
	
	# Start with camera at pin position
	camera.position = pin_position
	camera_snap_back_pos = pin_position
	print("Camera position after setting to pin:", camera.position)
	
	# Create a sequence: show pin for 2 seconds, then tween to tee
	var tween = get_tree().create_tween()
	tween.set_parallel(false)  # Sequential tweens
	
	# Wait 2 seconds at pin
	print("Waiting 2 seconds at pin...")
	tween.tween_interval(2.0)
	
	# Tween to tee area
	var tee_center = _get_tee_area_center()
	var tee_center_global = camera_container.position + tee_center
	print("Tweening from pin at", pin_position, "to tee at", tee_center_global)
	print("Camera position before tween:", camera.position)
	tween.tween_property(camera, "position", tee_center_global, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Update camera snap back position
	tween.tween_callback(func(): 
		camera_snap_back_pos = tee_center_global
		print("Pin-to-tee transition complete")
		print("Final camera position:", camera.position)
	)

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
	print("=== START PIN TO TEE TRANSITION DEBUG ===")
	print("Starting pin-to-tee transition...")
	print("Current camera position:", camera.position)
	
	# Wait 1.5 seconds at pin (as requested)
	var tween = get_tree().create_tween()
	tween.set_parallel(false)  # Sequential tweens
	
	# Wait 1.5 seconds at pin
	print("Waiting 1.5 seconds at pin...")
	tween.tween_interval(1.5)
	
	# Tween to tee area
	var tee_center = _get_tee_area_center()
	var tee_center_global = camera_container.position + tee_center
	print("Tweening from pin to tee at", tee_center_global)
	tween.tween_property(camera, "position", tee_center_global, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Update camera snap back position
	tween.tween_callback(func(): 
		camera_snap_back_pos = tee_center_global
		print("Pin-to-tee transition complete")
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
			if pin.has_meta("grid_position") or "grid_position" in pin:
				pin.set("grid_position", Global.saved_pin_position)
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
		
		# Base z_index on Y position (lower Y = higher z_index)
		var base_z = 10 + (sorted_objects.size() - i) * 10
		
		# Special handling for different object types
		if node.name == "Pin":
			# Skip pins - they have a fixed high z_index
			continue
		elif node.name == "Shop":
			node.z_index = base_z + 3  # Shop should be higher than most objects
		else:
			node.z_index = base_z

func _on_hole_in_one(score: int):
	"""Handle hole completion when ball goes in the hole"""
	print("Hole in one! Score:", score)
	show_hole_completion_dialog()

func _on_pin_flag_hit(ball: Node2D):
	"""Handle pin flag hit - ball velocity has already been reduced by the pin"""
	print("Pin flag hit detected for ball:", ball)
	# The pin has already applied the velocity reduction
	# We could add additional effects here if needed (sound, visual feedback, etc.)

var force_stickyshot_bonus := false

func _on_mod_shot_room_pressed():
	print("ModShotRoom button pressed")
	var sticky_shot_card = preload("res://Cards/StickyShot.tres")
	pending_inventory_card = sticky_shot_card
	show_inventory_choice(sticky_shot_card)

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
	print("Inventory choice dialog should now be visible.")

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

func update_mod_shot_room_visibility() -> void:
	"""Update ModShotRoom button visibility based on game phase"""
	if mod_shot_room_button:
		# Show button during card phases (draw_cards, move when cards are available)
		var should_show = (game_phase == "draw_cards" or 
						  (game_phase == "move" and deck_manager and deck_manager.hand.size() > 0))
		mod_shot_room_button.visible = should_show
		print("ModShotRoom button visibility:", should_show, "for game phase:", game_phase, "hand size:", deck_manager.hand.size() if deck_manager else "no deck manager")
	else:
		print("ModShotRoom button not found!")

func setup_bag_and_inventory() -> void:
	# Connect bag click signal
	if bag and bag.has_signal("bag_clicked"):
		bag.bag_clicked.connect(_on_bag_clicked)
		print("Bag click signal connected")
	
	# Set up inventory dialog
	if inventory_dialog:
		# Set the callable functions for getting cards
		inventory_dialog.get_movement_cards = get_movement_cards_for_inventory
		inventory_dialog.get_club_cards = get_club_cards_for_inventory
		inventory_dialog.inventory_closed.connect(_on_inventory_closed)
		print("Inventory dialog setup complete")
	
	# Initialize bag with level 1 for the selected character
	if bag and bag.has_method("set_bag_level"):
		bag.set_bag_level(1)  # Always start with level 1
		print("Bag initialized with level 1")

func _on_bag_clicked() -> void:
	print("Bag clicked - opening inventory")
	if inventory_dialog:
		inventory_dialog.show_inventory()

func _on_inventory_closed() -> void:
	print("Inventory closed")

func get_movement_cards_for_inventory() -> Array[CardData]:
	# Return movement cards from the deck manager
	if deck_manager:
		return deck_manager.hand.filter(func(card): return card.effect_type == "movement")
	return []

func get_club_cards_for_inventory() -> Array[CardData]:
	# Return club cards from the bag pile
	return bag_pile.duplicate()
