extends Node

# Global variables
var selected_character = 1  # Default to character 1
var putt_putt_mode = false  # Flag for putt putt mode (only putters)

var CHARACTER_STATS = {
	1: { "name": "Layla", "base_mobility": 3, "strength": -1, "card_draw": -1 },
	2: { "name": "Benny", "base_mobility": 2, "strength": 0, "card_draw": 0 },
	3: { "name": "Clark", "base_mobility": 1, "strength": 2, "card_draw": 1 }
}

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
