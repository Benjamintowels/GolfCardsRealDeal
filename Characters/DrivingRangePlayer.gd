extends CharacterBody2D

signal player_clicked
signal moved_to_tile(new_grid_pos: Vector2i)

var grid_pos: Vector2i
var movement_range: int = 1
var base_mobility: int = 0
var valid_movement_tiles: Array = []
var is_movement_mode: bool = false
var selected_card = null
var obstacle_map = {}
var grid_size: Vector2i
var cell_size: int = 48

# Highlight effect variables
var character_sprite: Sprite2D = null
var highlight_tween: Tween = null

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3  # Duration of movement animation in seconds
var animations_enabled: bool = false  # Only enable animations after player is placed on tee

# Mouse facing system
var game_phase: String = "move"  # Will be updated by parent
var is_charging: bool = false  # Will be updated by parent
var is_charging_height: bool = false  # Will be updated by parent
var camera: Camera2D = null  # Will be set by parent
var is_in_launch_mode: bool = false  # Track if we're in launch mode (ball flying)

# Player facing direction tracking
var current_facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right (1, 0) = right, (-1, 0) = left

# Swing sound references
var swing_strong_sound: AudioStreamPlayer2D
var swing_med_sound: AudioStreamPlayer2D
var swing_soft_sound: AudioStreamPlayer2D

func _ready():
	print("=== DRIVING RANGE PLAYER _READY FUNCTION CALLED ===")
	print("Player name:", name)
	print("Player scene path:", scene_file_path)
	
	# Look for the character sprite (it's added as a direct child by the course script)
	for child in get_children():
		if child is Sprite2D:
			character_sprite = child
			print("[DrivingRangePlayer.gd] Found character sprite for highlight:", character_sprite, "Initial modulate:", character_sprite.modulate)
			break
		elif child is Node2D:
			# Also check Node2D children in case the structure changes
			for grandchild in child.get_children():
				if grandchild is Sprite2D:
					character_sprite = grandchild
					print("[DrivingRangePlayer.gd] Found character sprite for highlight:", character_sprite, "Initial modulate:", character_sprite.modulate)
					break
	
	# Setup swing sound references
	setup_swing_sounds()
	
	print("[DrivingRangePlayer.gd] Player ready")

func setup_swing_sounds():
	"""Setup swing sound references"""
	swing_strong_sound = get_node_or_null("SwingStrong")
	swing_med_sound = get_node_or_null("SwingMed")
	swing_soft_sound = get_node_or_null("SwingSoft")
	
	if swing_strong_sound and swing_med_sound and swing_soft_sound:
		print("✓ DrivingRangePlayer swing sounds setup complete")
	else:
		print("⚠ Some swing sounds not found in DrivingRangePlayer")

func play_swing_sound(power: float) -> void:
	"""Play swing sound based on power level - same logic as main course"""
	if not swing_strong_sound or not swing_med_sound or not swing_soft_sound:
		print("⚠ Swing sounds not available in DrivingRangePlayer")
		return
	
	var power_percentage = (power - 300.0) / (1200.0 - 300.0)  # Using hardcoded values since constants are removed
	power_percentage = clamp(power_percentage, 0.0, 1.0)
	
	if power_percentage >= 0.7:  # Strong swing (70%+ power)
		swing_strong_sound.play()
		print("Playing strong swing sound from DrivingRangePlayer")
	elif power_percentage >= 0.4:  # Medium swing (40-70% power)
		swing_med_sound.play()
		print("Playing medium swing sound from DrivingRangePlayer")
	else:  # Soft swing (0-40% power)
		swing_soft_sound.play()
		print("Playing soft swing sound from DrivingRangePlayer")

func setup(grid_size_param: Vector2i, cell_size_param: int, base_mobility_param: int, obstacle_map_param: Dictionary):
	"""Setup the player with grid parameters"""
	grid_size = grid_size_param
	cell_size = cell_size_param
	base_mobility = base_mobility_param
	obstacle_map = obstacle_map_param
	movement_range = base_mobility + 1
	print("Player setup complete - Grid:", grid_size, "Cell:", cell_size, "Mobility:", base_mobility)

func set_grid_position(pos: Vector2i, ysort_objects: Array = [], shop_grid_pos: Vector2i = Vector2i.ZERO):
	"""Set the player's grid position"""
	grid_pos = pos
	var world_pos = Vector2(pos.x * cell_size + cell_size/2, pos.y * cell_size + cell_size/2)
	global_position = world_pos
	print("Player grid position set to:", pos, "World position:", world_pos)

func set_game_phase(phase: String):
	"""Set the current game phase"""
	game_phase = phase

func set_launch_state(charging: bool, charging_height: bool, selecting_height: bool):
	"""Set the launch state"""
	is_charging = charging
	is_charging_height = charging_height

func set_launch_mode(launch_mode: bool):
	"""Set the launch mode state"""
	is_in_launch_mode = launch_mode

func set_camera_reference(camera_ref: Camera2D):
	"""Set the camera reference for mouse facing"""
	camera = camera_ref

func get_character_sprite() -> Sprite2D:
	"""Get the character sprite"""
	return character_sprite

func _input(event):
	"""Handle input events"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is on the player
		var mouse_pos = get_global_mouse_position()
		var player_rect = Rect2(global_position - Vector2(cell_size/2, cell_size/2), Vector2(cell_size, cell_size))
		
		if player_rect.has_point(mouse_pos):
			print("Player clicked!")
			emit_signal("player_clicked")

func _update_mouse_facing() -> void:
	"""Update player sprite to face the mouse direction when appropriate"""
	var sprite = get_character_sprite()
	if not sprite:
		return
	
	# Only face mouse when it's player's turn and not in launch charge mode or ball flying mode
	var should_face_mouse = (
		game_phase == "move" or 
		game_phase == "aiming" or 
		game_phase == "draw_cards" or
		game_phase == "ball_tile_choice"
	) and not is_charging and not is_charging_height and not is_in_launch_mode
	
	if not should_face_mouse:
		return
	
	# Get mouse position in world space
	if not camera:
		return
	
	var mouse_world_pos = camera.get_global_mouse_position()
	var player_world_pos = global_position
	
	# Calculate direction from player to mouse
	var direction = mouse_world_pos - player_world_pos
	
	# Only update if mouse is not too close to player (to prevent jittering)
	if direction.length() < 10.0:
		return
	
	# Determine if mouse is to the left or right of player
	var mouse_is_left = direction.x < 0
	
	# Update current facing direction
	current_facing_direction = Vector2i(-1, 0) if mouse_is_left else Vector2i(1, 0)
	
	# Flip the sprite horizontally based on mouse position
	# Assuming the default sprite faces right, so we flip when mouse is on the left
	sprite.flip_h = mouse_is_left

func get_current_facing_direction() -> Vector2i:
	"""Get the current facing direction of the player"""
	return current_facing_direction

func is_facing_left() -> bool:
	"""Check if the player is currently facing left"""
	return current_facing_direction.x < 0

func is_facing_right() -> bool:
	"""Check if the player is currently facing right"""
	return current_facing_direction.x > 0

func _process(delta):
	"""Process function for continuous updates"""
	_update_mouse_facing() 
