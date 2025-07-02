extends Node

# Global variables
var selected_character = 1  # Default to character 1
var putt_putt_mode = false  # Flag for putt putt mode (only putters)
var starting_back_9 = false  # Flag for starting back 9 holes
var final_18_hole_score = 0  # Final score for 18-hole game
var front_9_score = 0  # Score from front 9 holes

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
	print("Applied equipment buffs for character", selected_character, ":", base_stats)

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
		print("Reset health for character %d to %d HP" % [selected_character, max_hp])

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
	Special Y-sort handling for ball sprites
	Uses the ball's Shadow/YSortPoint position for Y-sorting
	"""
	if not ball_node or not is_instance_valid(ball_node):
		return

	var ball_sprite = ball_node.get_node_or_null("Sprite2D")
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
