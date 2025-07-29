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
	# The SlashFX sprite has default flip_h = true and flip_v = true
	# So we need to account for this when setting the orientation
	
	# For player-facing orientation:
	# - When player faces left: we want the slash to appear to come from the left
	# - When player faces right: we want the slash to appear to come from the right
	
	# Since the default sprite is flipped, we need to invert the logic
	flip_h = not player_facing_left  # Invert the player's facing direction
	flip_v = false  # Keep vertical flip off for player-facing orientation
	
	print("SlashFX orientation - Player facing left:", player_facing_left, "SlashFX flip_h:", flip_h, "flip_v:", flip_v)
