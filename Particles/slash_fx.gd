extends AnimatedSprite2D

func update_animation_facing(direction: Vector2) -> void:
	"""Update the SlashFX orientation based on direction"""
	# Determine if the direction is primarily horizontal or vertical
	var is_horizontal = abs(direction.x) > abs(direction.y)
	
	if is_horizontal:
		# Horizontal slash - flip based on direction
		flip_h = direction.x < 0
		flip_v = false
	else:
		# Vertical slash - flip based on direction
		flip_h = false
		flip_v = direction.y < 0

func update_animation_facing_player_direction(player_facing_left: bool) -> void:
	"""Update the SlashFX orientation based on player's facing direction"""
	# Flip horizontally based on player's facing direction
	flip_h = player_facing_left
	flip_v = false  # Keep vertical flip off for player-facing orientation
