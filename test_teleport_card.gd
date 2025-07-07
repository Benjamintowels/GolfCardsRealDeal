extends Node2D

# Test scene for teleport card functionality
# Press SPACE to test teleport effect

var player_created: bool = false
var ball_created: bool = false
var card_effect_handler: Node = null

func _ready():
	print("=== TELEPORT CARD TEST SCENE ===")
	print("Press SPACE to test teleport effect")
	print("Player should teleport to ball position with portal effect")
	
	# Create test entities automatically
	_create_test_player()
	_create_test_ball()
	_setup_card_effect_handler()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("=== TESTING TELEPORT EFFECT ===")
		_test_teleport_effect()

func _setup_card_effect_handler():
	"""Setup the card effect handler for testing"""
	print("=== SETTING UP CARD EFFECT HANDLER ===")
	
	# Create a mock course node
	var course = Node.new()
	course.name = "MockCourse"
	add_child(course)
	
	# Create card effect handler
	var effect_handler_script = load("res://CardEffectHandler.gd")
	card_effect_handler = effect_handler_script.new()
	add_child(card_effect_handler)
	card_effect_handler.set_course_reference(course)
	
	# Setup mock course properties
	course.player_node = get_node_or_null("TestPlayer")
	course.cell_size = 48
	course.player_grid_pos = Vector2i(5, 5)
	course.ysort_objects = []
	
	# Mock deck manager
	course.deck_manager = Node.new()
	course.deck_manager.hand = []
	
	# Mock card stack display
	course.card_stack_display = Node.new()
	course.card_stack_display.animate_card_discard = func(card_name): print("Card discarded:", card_name)
	
	# Mock movement buttons container
	course.movement_buttons_container = Node.new()
	course.movement_buttons = []
	
	# Mock launch manager with ball
	course.launch_manager = Node.new()
	course.launch_manager.golf_ball = get_node_or_null("TestBall")
	
	# Mock camera container
	course.camera_container = Node.new()
	course.camera_container.global_position = Vector2.ZERO
	
	print("✓ Card effect handler setup complete")

func _create_test_player():
	"""Create a test player at a specific position"""
	print("=== CREATING TEST PLAYER ===")
	
	# Load the player scene
	var player_scene = load("res://Characters/Player1.tscn")
	if not player_scene:
		print("✗ ERROR: Could not load Player1.tscn")
		return
	
	# Create player at position (240, 240) - grid position (5, 5)
	var player_pos = Vector2(240, 240)
	var player = player_scene.instantiate()
	player.name = "TestPlayer"
	add_child(player)
	player.global_position = player_pos
	
	# Convert world position to grid position
	var cell_size = 48
	var grid_x = floor((player_pos.x - cell_size / 2) / cell_size)
	var grid_y = floor((player_pos.y - cell_size / 2) / cell_size)
	
	# Setup the player
	if player.has_method("setup"):
		player.setup(Vector2i(20, 20), cell_size, 0, {})  # grid_size, cell_size, base_mobility, obstacle_map
		player.set_grid_position(Vector2i(grid_x, grid_y))
		print("✓ Player setup complete at grid position:", Vector2i(grid_x, grid_y))
	else:
		print("✗ ERROR: Player doesn't have setup method")
	
	# Enable animations for the player
	if player.has_method("enable_animations"):
		player.enable_animations()
		print("✓ Player animations enabled")
	
	print("✓ Test player created at world position:", player_pos, "grid position:", Vector2i(grid_x, grid_y))
	player_created = true
	print("=== TEST PLAYER CREATED ===")

func _create_test_ball():
	"""Create a test ball at a different position"""
	print("=== CREATING TEST BALL ===")
	
	# Load the ball scene
	var ball_scene = load("res://GolfBall.tscn")
	if not ball_scene:
		print("✗ ERROR: Could not load GolfBall.tscn")
		return
	
	# Create ball at position (720, 720) - grid position (15, 15)
	var ball_pos = Vector2(720, 720)
	var ball = ball_scene.instantiate()
	ball.name = "TestBall"
	add_child(ball)
	ball.global_position = ball_pos
	ball.add_to_group("balls")
	
	# Setup the ball
	ball.cell_size = 48
	ball.map_manager = null  # No map manager needed for this test
	
	print("✓ Test ball created at world position:", ball_pos, "grid position:", Vector2i(15, 15))
	ball_created = true
	print("=== TEST BALL CREATED ===")

func _test_teleport_effect():
	"""Test the teleport effect"""
	print("=== TESTING TELEPORT EFFECT ===")
	
	if not card_effect_handler:
		print("✗ ERROR: Card effect handler not setup")
		return
	
	# Test ball position detection first
	print("=== TESTING BALL POSITION DETECTION ===")
	var ball_pos = card_effect_handler.get_ball_position()
	print("Ball position detected:", ball_pos)
	
	# Create a teleport card
	var teleport_card = CardData.new()
	teleport_card.name = "TeleportCard"
	teleport_card.effect_type = "Teleport"
	teleport_card.effect_strength = 1
	
	# Add card to hand
	var course = card_effect_handler.course
	course.deck_manager.hand.append(teleport_card)
	
	print("✓ Teleport card created and added to hand")
	print("Player position before teleport:", course.player_node.global_position)
	print("Ball position:", get_node_or_null("TestBall").global_position)
	
	# Test the teleport effect
	card_effect_handler.handle_teleport_effect(teleport_card)
	
	# Wait a moment for the effect to complete
	await get_tree().create_timer(2.0).timeout
	
	print("Player position after teleport:", course.player_node.global_position)
	print("✓ Teleport effect test complete")

# Import CardData class
const CardData = preload("res://Cards/CardData.gd") 