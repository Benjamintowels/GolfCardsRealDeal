extends Node

# Global variables
var selected_character = 1  # Default to character 1
var putt_putt_mode = false  # Flag for putt putt mode (only putters)
var starting_back_9 = false  # Flag for starting back 9 holes
var final_18_hole_score = 0  # Final score for 18-hole game
var front_9_score = 0  # Score from front 9 holes

var CHARACTER_STATS = {
	1: { "name": "Layla", "base_mobility": 3, "strength": -1, "card_draw": -1 },
	2: { "name": "Benny", "base_mobility": 2, "strength": 0, "card_draw": 0 },
	3: { "name": "Clark", "base_mobility": 1, "strength": 2, "card_draw": 1 }
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

func _ready():
	print("Global script loaded, selected_character = ", selected_character)

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
