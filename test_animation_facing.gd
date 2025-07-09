extends Node2D

# Test scene for animation facing direction
# This scene tests that animations flip correctly based on player facing direction

@onready var player: Node2D
@onready var camera: Camera2D

func _ready():
	print("=== ANIMATION FACING TEST SCENE ===")
	
	# Find the player node
	player = get_node_or_null("Player")
	if not player:
		print("⚠ Player node not found")
		return
	
	# Find the camera
	camera = get_node_or_null("Camera2D")
	if not camera:
		print("⚠ Camera2D node not found")
		return
	
	# Set up the camera reference for the player
	if player.has_method("set_camera_reference"):
		player.set_camera_reference(camera)
		print("✓ Camera reference set for player")
	
	# Set up the game phase for mouse facing
	if player.has_method("set_game_phase"):
		player.set_game_phase("move")
		print("✓ Game phase set to 'move' for mouse facing")
	
	print("=== TEST SCENE READY ===")
	print("Move your mouse left/right to change player facing direction")
	print("Press SPACE to test swing animation")
	print("Press K to test kick animation")
	print("Press P to test punch animation")

func _input(event):
	if not player:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				print("=== TESTING SWING ANIMATION ===")
				print("Current facing direction:", player.get_current_facing_direction())
				print("Facing left:", player.is_facing_left())
				print("Facing right:", player.is_facing_right())
				player.start_swing_animation()
			
			KEY_K:
				print("=== TESTING KICK ANIMATION ===")
				print("Current facing direction:", player.get_current_facing_direction())
				print("Facing left:", player.is_facing_left())
				print("Facing right:", player.is_facing_right())
				player.start_kick_animation()
			
			KEY_P:
				print("=== TESTING PUNCH ANIMATION ===")
				print("Current facing direction:", player.get_current_facing_direction())
				print("Facing left:", player.is_facing_left())
				print("Facing right:", player.is_facing_right())
				player.start_punchb_animation()

func _process(delta):
	# Update mouse facing every frame
	if player and player.has_method("_update_mouse_facing"):
		player._update_mouse_facing() 