extends Control

signal reach_ball_pressed

@onready var texture_button: TextureButton = $TextureButton

func _ready():
	# Connect the button press signal
	texture_button.pressed.connect(_on_reach_ball_pressed)
	
	# Initially hide the button
	visible = false

func _on_reach_ball_pressed():
	"""Handle the reach ball button press"""
	print("ReachBallButton: Button pressed - teleporting player to ball")
	
	# Emit signal for the course to handle
	reach_ball_pressed.emit()
	
	# Hide the button after use
	visible = false

func show_button():
	"""Show the reach ball button"""
	visible = true

func hide_button():
	"""Hide the reach ball button"""
	visible = false

func should_show_button() -> bool:
	"""Check if the button should be shown based on game state"""
	var course = get_tree().current_scene
	if not course or not course.has_method("get_game_state"):
		return false
	
	# Get game state from course
	var game_phase = course.game_phase if "game_phase" in course else ""
	var waiting_for_player_to_reach_ball = course.waiting_for_player_to_reach_ball if "waiting_for_player_to_reach_ball" in course else false
	var player_grid_pos = course.player_grid_pos if "player_grid_pos" in course else Vector2i.ZERO
	var ball_landing_tile = course.ball_landing_tile if "ball_landing_tile" in course else Vector2i.ZERO
	
	# Show button if:
	# 1. It's the player's turn (game_phase is "move" or "waiting_for_draw")
	# 2. We're waiting for player to reach the ball
	# 3. Player is not currently on the ball tile
	var is_player_turn = game_phase in ["move", "waiting_for_draw", "draw_cards"]
	var player_not_on_ball = player_grid_pos != ball_landing_tile
	
	return is_player_turn and waiting_for_player_to_reach_ball and player_not_on_ball
