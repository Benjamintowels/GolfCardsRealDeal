extends Node

# Global variables
var selected_character = 1  # Default to character 1
var putt_putt_mode = false  # Flag for putt putt mode (only putters)
var starting_back_9 = false  # Flag for starting back 9 holes
var final_18_hole_score = 0  # Final score for 18-hole game
var front_9_score = 0  # Score from front 9 holes

# Turn-based spawning system
var global_turn_count: int = 1  # Global turn counter across all holes

var CHARACTER_STATS = {
	1: { "name": "Layla", "base_mobility": 3, "strength": -1, "card_draw": -1, "max_hp": 125, "current_hp": 125 },
	2: { "name": "Benny", "base_mobility": 2, "strength": 0, "card_draw": 0, "max_hp": 150, "current_hp": 150 },
	3: { "name": "Clark", "base_mobility": 1, "strength": 2, "card_draw": 1, "max_hp": 200, "current_hp": 200 }
}

# Equipment inventory and buffs
var equipped_items: Array[EquipmentData] = []

# Shop state saving variables
var saved_player_grid_pos := Vector2i.ZERO
var saved_ball_position := Vector2.ZERO
var saved_current_turn := 1
var saved_shot_score := 0
var saved_global_turn_count := 1
var saved_deck_manager_state := {}
var saved_discard_pile_state := {}
var saved_hand_state := {}
var saved_game_state := ""
var saved_has_started := false
var saved_game_phase := ""

# Ball-related state variables
var saved_ball_landing_tile := Vector2i.ZERO
var saved_ball_landing_position := Vector2.ZERO
var saved_waiting_for_player_to_reach_ball := false
var saved_ball_exists := false

# Course object positions (trees, pin, and shop)
var saved_tree_positions := []
var saved_pin_position := Vector2i.ZERO
var saved_shop_position := Vector2i.ZERO

# Global Y-sort system - simple and effective
# Uses Godot's built-in Y-sorting with manual z_index offsets for different object types

# Z-index offsets for different object types (to ensure proper layering)
const Z_INDEX_OFFSETS = {
	"background": -100,  # Behind everything
	"ground": -50,       # Behind objects
	"objects": 0,        # Trees, pins, etc.
	"characters": 0,     # Player, NPCs (same as objects for true Y-sort)
	"balls": 0,          # Balls (same as objects/characters for true Y-sort)
	"ui": 200           # UI elements (in front of everything)
}

# Standardized Height System
# This system provides consistent visual scaling and collision detection for all objects with height variables
# The goal is to have a 1:1 correlation between sprite visual height and the height variable

# Height System Constants
const HEIGHT_VISUAL_SCALE_FACTOR = 0.5  # How much to scale sprite size per unit of height (reduced for pixel perfect system)
const HEIGHT_VERTICAL_OFFSET_FACTOR = 1.0  # How much to move sprite up per unit of height
const HEIGHT_SHADOW_SCALE_FACTOR = 0.5  # How much to scale shadow per unit of height (reduced for pixel perfect system)

# Pixel Perfect Height System - no scaling needed since all heights are in the same coordinate system
# Ball launch heights and object TopHeight markers now use the same scale (pixels)

# Standard height values for common objects (in pixels)
# These values represent the actual visual height of sprites in the game world

func _ready():
	print("Global script loaded, selected_character = ", selected_character)
	# Global Y-sort system initialized - using Godot's built-in Y-sorting

# Equipment functions
func add_equipment(equipment: EquipmentData) -> void:
	"""Add equipment to inventory and apply buffs"""
	if not equipped_items.has(equipment):
		equipped_items.append(equipment)
		print("Added equipment:", equipment.name, "to inventory")
		apply_equipment_buffs()

func remove_equipment(equipment: EquipmentData) -> void:
	"""Remove equipment from inventory"""
	if equipped_items.has(equipment):
		equipped_items.erase(equipment)
		print("Removed equipment:", equipment.name, "from inventory")
		apply_equipment_buffs()

func apply_equipment_buffs() -> void:
	"""Apply all equipment buffs to character stats"""
	# Reset character stats to base values
	var base_stats = CHARACTER_STATS[selected_character].duplicate()
	
	# Apply equipment buffs
	for equipment in equipped_items:
		match equipment.buff_type:
			"mobility":
				base_stats.base_mobility += equipment.buff_value
			"strength":
				base_stats.strength += equipment.buff_value
			"card_draw":
				base_stats.card_draw += equipment.buff_value
	
	# Update character stats
	CHARACTER_STATS[selected_character] = base_stats

func get_equipment_buff(stat_type: String) -> int:
	"""Get total buff value for a specific stat type"""
	var total_buff = 0
	for equipment in equipped_items:
		if equipment.buff_type == stat_type:
			total_buff += equipment.buff_value
	return total_buff

func reset_character_health() -> void:
	"""Reset character health to maximum for new round"""
	if CHARACTER_STATS.has(selected_character):
		var max_hp = CHARACTER_STATS[selected_character].get("max_hp", 100)
		CHARACTER_STATS[selected_character]["current_hp"] = max_hp

func get_character_health() -> Dictionary:
	"""Get current character health info"""
	if CHARACTER_STATS.has(selected_character):
		var stats = CHARACTER_STATS[selected_character]
		return {
			"current_hp": stats.get("current_hp", 100),
			"max_hp": stats.get("max_hp", 100),
			"is_alive": stats.get("current_hp", 100) > 0
		}
	return {"current_hp": 0, "max_hp": 0, "is_alive": false}

func update_screen_height():
	"""Update screen height (call when viewport changes)"""
	# No longer needed with simplified Y-sort system
	pass

# Store last debug output to avoid spam
var _last_debug_output = {}

func get_y_sort_z_index(world_position: Vector2, object_type: String = "objects") -> int:
	"""
	Simple Y-sort: just use the Y position as the z_index with an offset
	Higher Y position = higher z_index (appears in front)
	"""
	# Simple approach: use Y position directly as z_index base
	# Add 1000 to ensure all game objects have positive z_index values
	var base_z_index = int(world_position.y) + 1000
	
	# Add offset based on object type
	var offset = Z_INDEX_OFFSETS.get(object_type, 0)
	var z_index = base_z_index + offset
	
	# Debug output for significant changes only
	if object_type == "characters" or object_type == "balls":
		var debug_key = str(world_position) + "_" + object_type
		var current_debug = str(z_index)
		
		# Only print if this is a new position or significant change
		if not _last_debug_output.has(debug_key) or _last_debug_output[debug_key] != current_debug:
			# Y-sort update - pos: world_position, z_index: z_index, type: object_type
			_last_debug_output[debug_key] = current_debug
	
	return z_index

func update_object_y_sort(node: Node2D, object_type: String = "objects"):
	"""
	Update a node's z_index based on its world position
	"""
	if not node or not is_instance_valid(node):
		return
	
	# Use custom Y-sort point for trees
	var world_position = node.global_position
	if node.has_method("get_y_sort_point"):
		world_position.y = node.get_y_sort_point()
	
	var z_index = get_y_sort_z_index(world_position, object_type)
	node.z_index = z_index

func update_ball_y_sort(ball_node: Node2D):
	"""
	Special Y-sort handling for ball sprites and throwing knives
	Uses the ball's Shadow/YSortPoint position for Y-sorting
	"""
	if not ball_node or not is_instance_valid(ball_node):
		return

	# Check for different sprite node names (Sprite2D for golf balls, ThrowingKnife for knives)
	var ball_sprite = ball_node.get_node_or_null("Sprite2D")
	if not ball_sprite:
		ball_sprite = ball_node.get_node_or_null("ThrowingKnife")
	
	var ysort_point = ball_node.get_node_or_null("Shadow/YSortPoint")
	var ball_shadow = ball_node.get_node_or_null("Shadow")

	if not ball_sprite:
		return

	# Use YSortPoint if available, then Shadow, then global_position
	var ground_y = ball_node.global_position.y
	if ysort_point:
		ground_y = ysort_point.global_position.y
	elif ball_shadow:
		ground_y = ball_shadow.global_position.y

	var ground_position = ball_node.global_position
	ground_position.y = ground_y

	# Get z_index based on ground position
	var z_index = get_y_sort_z_index(ground_position, "balls")

	# Set shadow z_index
	if ball_shadow:
		ball_shadow.z_index = z_index
	# Set ball sprite z_index to always be 1 higher than the shadow
	ball_sprite.z_index = z_index + 1

func update_all_objects_y_sort(ysort_objects: Array):
	"""
	Update Y-sort for all objects in the ysort_objects array
	"""
	for obj in ysort_objects:
		if not obj.has("node") or not obj["node"] or not is_instance_valid(obj["node"]):
			continue
		
		var node = obj["node"]
		var object_type = "objects"  # Default
		
		# Determine object type based on node name or script
		if node.name == "Tree" or (node.get_script() and "Tree.gd" in str(node.get_script().get_path())):
			object_type = "objects"
		elif node.name == "Pin":
			object_type = "objects"
		elif node.name == "Shop":
			object_type = "objects"
		elif "Player" in node.name or "GangMember" in node.name:
			object_type = "characters"
		
		update_object_y_sort(node, object_type)

# Height System Functions
func apply_standard_height_visual_effects(sprite: Sprite2D, shadow: Sprite2D, z: float, base_scale: Vector2 = Vector2.ONE) -> void:
	"""
	Apply standardized visual effects for height-based objects.
	
	Parameters:
	- sprite: The sprite to apply effects to
	- shadow: The shadow sprite (can be null)
	- z: Current height value
	- base_scale: Base scale of the sprite before height effects
	"""
	if not sprite:
		return
	
	# Scale the sprite based on height (bigger when higher)
	var height_scale = 1.0 + (z * HEIGHT_VISUAL_SCALE_FACTOR / 500.0)  # Scale per 500 units of height for pixel perfect system
	height_scale = clamp(height_scale, 0.8, 2.0)  # Keep scaling reasonable
	
	sprite.scale = base_scale * height_scale
	
	# Move the sprite up based on height (1:1 ratio)
	var sprite_y_offset = -(z * HEIGHT_VERTICAL_OFFSET_FACTOR)
	sprite.position.y = sprite_y_offset
	
	# Update shadow if provided
	if shadow:
		# Keep shadow at ground level (Vector2.ZERO) - never move it up with the sprite
		shadow.position = Vector2.ZERO
		
		# Shadow gets smaller when sprite is higher
		var shadow_scale = 1.0 - (z * HEIGHT_SHADOW_SCALE_FACTOR / 500.0)  # Scale per 500 units for pixel perfect system
		shadow_scale = clamp(shadow_scale, 0.1, 1.0)
		
		shadow.scale = base_scale * shadow_scale
		
		# Shadow opacity also changes with height
		var shadow_alpha = 0.3 - (z / 500.0)  # Opacity change per 500 units for pixel perfect system
		shadow_alpha = clamp(shadow_alpha, 0.05, 0.3)
		
		shadow.modulate = Color(0, 0, 0, shadow_alpha)
		
		# Ensure shadow is always behind the sprite
		shadow.z_index = sprite.z_index - 1
		if shadow.z_index <= -5:
			shadow.z_index = 1

# Enhanced Height System using TopHeight Marker2D
func get_object_height_from_marker(object_node: Node2D) -> float:
	"""
	Get the height of an object using its TopHeight Marker2D.
	This provides more accurate height values than hardcoded standards.
	
	Parameters:
	- object_node: The node to get height for
	
	Returns:
	- Height value in pixels, or fallback to standard height
	"""
	if not object_node or not is_instance_valid(object_node):
		return 100.0
	
	# Special handling for dead GangMembers - check for DeadGangTopHeight marker first
	if object_node.has_method("get_is_dead") and object_node.get_is_dead():
		var dead_gang_top_height_marker = object_node.get_node_or_null("Dead/DeadGangTopHeight")
		if dead_gang_top_height_marker:
			# The marker's Y position represents the height from the object's base to its top
			# Since the marker is positioned at the top of the dead sprite, we take the absolute value
			var height_from_marker = abs(dead_gang_top_height_marker.position.y)
			print("Using DeadGangTopHeight marker for dead", object_node.name, "- height:", height_from_marker)
			return height_from_marker
	
	# Look for regular TopHeight Marker2D
	var top_height_marker = object_node.get_node_or_null("TopHeight")
	if top_height_marker:
		# The marker's Y position represents the height from the object's base to its top
		# Since the marker is positioned at the top of the sprite, we take the absolute value
		var height_from_marker = abs(top_height_marker.position.y)
		print("Using TopHeight marker for", object_node.name, "- height:", height_from_marker)
		return height_from_marker
	
	# Fallback to standard height based on object type
	var object_type = _get_object_type_from_node(object_node)
	var fallback_height = _get_standard_height_for_type(object_type)
	print("Using fallback height for", object_node.name, "- type:", object_type, "- height:", fallback_height)
	return fallback_height

func _get_object_type_from_node(object_node: Node2D) -> String:
	"""
	Determine the object type from the node for fallback height calculation.
	
	Parameters:
	- object_node: The node to analyze
	
	Returns:
	- Object type string for height lookup
	"""
	if not object_node:
		return "unknown"
	
	var node_name = object_node.name.to_lower()
	var script_path = ""
	if object_node.get_script():
		script_path = str(object_node.get_script().get_path()).to_lower()
	
	# Check for specific object types
	if "player" in node_name or "Player" in object_node.get_class():
		return "player"
	elif "gang" in node_name or "GangMember" in script_path or "GangMember" in object_node.get_class():
		return "gang_member"
	elif "tree" in node_name or "Tree" in script_path or "Tree" in object_node.get_class():
		return "tree"
	elif "pin" in node_name or "Pin" in script_path or "Pin" in object_node.get_class():
		return "pin"
	elif "shop" in node_name or "Shop" in script_path or "Shop" in object_node.get_class():
		return "shop"
	elif "ball" in node_name or "GolfBall" in script_path or "GolfBall" in object_node.get_class():
		return "golf_ball"
	elif "knife" in node_name or "ThrowingKnife" in script_path or "ThrowingKnife" in object_node.get_class():
		return "throwing_knife"
	else:
		return "unknown"

func _get_standard_height_for_type(object_type: String) -> float:
	"""
	Get standard height values for different object types.
	
	Parameters:
	- object_type: The type of object
	
	Returns:
	- Standard height value in pixels
	"""
	match object_type:
		"player":
			return 80.0
		"gang_member":
			return 80.0
		"tree":
			return 200.0
		"pin":
			return 150.0
		"shop":
			return 120.0
		"golf_ball":
			return 10.0
		"throwing_knife":
			return 5.0
		_:
			return 100.0  # Default fallback height

func is_object_above_height(object_height: float, obstacle_height: float) -> bool:
	"""
	Check if an object is above an obstacle's height.
	
	Parameters:
	- object_height: The height of the moving object (ball, knife, etc.)
	- obstacle_height: The height of the obstacle (NPC, tree, etc.)
	
	Returns:
	- true if object is above obstacle entirely
	- false if object is within or below obstacle height
	"""
	return object_height > obstacle_height

func is_object_above_obstacle(object_node: Node2D, obstacle_node: Node2D) -> bool:
	"""
	Enhanced collision check using TopHeight markers for more accurate detection.
	
	Parameters:
	- object_node: The moving object (ball, knife, etc.)
	- obstacle_node: The obstacle to check against (NPC, tree, etc.)
	
	Returns:
	- true if object is above obstacle entirely
	- false if object is within or below obstacle height
	"""
	if not object_node or not obstacle_node:
		return false
	
	# Get object height
	var object_height = 0.0
	if object_node.has_method("get_height"):
		object_height = object_node.get_height()
	elif "z" in object_node:
		object_height = object_node.z
	
	# Get obstacle height using TopHeight marker
	var obstacle_height = get_object_height_from_marker(obstacle_node)
	
	# Check if object is above obstacle
	var is_above = is_object_above_height(object_height, obstacle_height)
	
	return is_above

func get_obstacle_collision_height(obstacle_node: Node2D) -> float:
	"""
	Get the collision height for an obstacle, prioritizing TopHeight marker.
	
	Parameters:
	- obstacle_node: The obstacle node
	
	Returns:
	- Height value for collision detection
	"""
	return get_object_height_from_marker(obstacle_node)

func calculate_height_percentage(current_height: float, min_height: float, max_height: float) -> float:
	"""
	Calculate height percentage for sweet spot detection.
	
	Parameters:
	- current_height: Current height value
	- min_height: Minimum height in the range
	- max_height: Maximum height in the range
	
	Returns:
	- Height percentage (0.0 to 1.0)
	"""
	var height_percentage = (current_height - min_height) / (max_height - min_height)
	return clamp(height_percentage, 0.0, 1.0)

func get_turn_based_gang_member_count() -> int:
	"""Calculate number of gang members to spawn based on current turn"""
	var base_count = 1
	var turn_increment = 5  # Every 5 turns
	
	# Calculate additional gang members based on turn milestones
	var additional_count = (global_turn_count - 1) / turn_increment
	
	# Cap at reasonable maximum (e.g., 5 gang members max)
	var max_count = 5
	return min(base_count + additional_count, max_count)

func get_turn_based_oil_drum_count() -> int:
	"""Calculate number of oil drums to spawn based on current turn"""
	var base_count = 3
	var turn_increment = 5  # Every 5 turns
	
	# Calculate additional oil drums based on turn milestones
	var additional_count = (global_turn_count - 1) / turn_increment
	
	# Cap at reasonable maximum (e.g., 8 oil drums max)
	var max_count = 8
	return min(base_count + additional_count, max_count)

func increment_global_turn() -> void:
	"""Increment the global turn counter"""
	global_turn_count += 1
	print("Global turn incremented to: ", global_turn_count)

func reset_global_turn() -> void:
	"""Reset the global turn counter (for new games)"""
	global_turn_count = 1
	print("Global turn reset to: ", global_turn_count)

func clear_shop_state():
	"""Clear global state to prevent dictionary conflicts when returning from shop"""
	print("=== CLEARING GLOBAL SHOP STATE ===")
	
	# Clear any debug output cache that might cause issues
	_last_debug_output.clear()
	
	# Clear any saved game state that might cause conflicts
	saved_game_state = ""
	saved_player_grid_pos = Vector2i.ZERO
	saved_ball_position = Vector2.ZERO
	saved_current_turn = 1
	saved_shot_score = 0
	saved_global_turn_count = 1
	saved_deck_manager_state.clear()
	saved_discard_pile_state.clear()
	saved_hand_state.clear()
	saved_has_started = false
	saved_game_phase = ""
	
	# Clear ball-related state
	saved_ball_landing_tile = Vector2i.ZERO
	saved_ball_landing_position = Vector2.ZERO
	saved_waiting_for_player_to_reach_ball = false
	saved_ball_exists = false
	
	# Clear course object positions
	saved_tree_positions.clear()
	saved_pin_position = Vector2i.ZERO
	saved_shop_position = Vector2i.ZERO
	
	print("=== GLOBAL SHOP STATE CLEARED ===")
