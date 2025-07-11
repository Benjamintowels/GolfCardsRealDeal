extends Node2D

# Test script to verify NPC push landing highlight fix
# This test simulates an NPC pushing a landed ball and verifies that
# the ball can create a new landing highlight when it stops again

@onready var golf_ball: Node2D
@onready var entities_manager: Node

func _ready():
	print("=== NPC PUSH LANDING HIGHLIGHT TEST ===")
	
	# Find the Entities manager
	entities_manager = get_node_or_null("Entities")
	if not entities_manager:
		print("✗ ERROR: Entities manager not found!")
		return
	
	# Find golf ball
	golf_ball = get_node_or_null("GolfBall")
	if not golf_ball:
		print("✗ ERROR: GolfBall not found!")
		return
	
	print("✓ Test setup complete")
	print("=== TEST INSTRUCTIONS ===")
	print("1. Launch a ball and let it land (should create landing highlight)")
	print("2. Have an NPC push the ball during their turn")
	print("3. Let the ball stop again (should create NEW landing highlight)")
	print("4. Verify that the landing highlight system works correctly")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_landing_highlight_reset()
	elif event.is_action_pressed("ui_select"):
		_test_npc_push_simulation()

func _test_landing_highlight_reset():
	"""Test that landing highlight variables are properly reset"""
	print("=== TESTING LANDING HIGHLIGHT RESET ===")
	
	if not golf_ball:
		print("✗ No golf ball found for testing")
		return
	
	# Simulate the ball being in a landed state
	golf_ball.landed_flag = true
	golf_ball.has_emitted_landed_signal = true
	golf_ball.final_landing_tile = Vector2i(10, 10)
	
	print("Before reset:")
	print("  landed_flag:", golf_ball.landed_flag)
	print("  has_emitted_landed_signal:", golf_ball.has_emitted_landed_signal)
	print("  final_landing_tile:", golf_ball.final_landing_tile)
	
	# Simulate NPC push by calling set_landed_flag(false)
	golf_ball.set_landed_flag(false)
	
	print("After NPC push reset:")
	print("  landed_flag:", golf_ball.landed_flag)
	print("  has_emitted_landed_signal:", golf_ball.has_emitted_landed_signal)
	print("  final_landing_tile:", golf_ball.final_landing_tile)
	
	# Verify that the landing highlight system is reset
	if not golf_ball.landed_flag and not golf_ball.has_emitted_landed_signal and golf_ball.final_landing_tile == Vector2i.ZERO:
		print("✓ SUCCESS: Landing highlight system properly reset by NPC push")
	else:
		print("✗ FAILURE: Landing highlight system not properly reset")

func _test_npc_push_simulation():
	"""Simulate a complete NPC push scenario"""
	print("=== TESTING NPC PUSH SIMULATION ===")
	
	if not golf_ball or not entities_manager:
		print("✗ Required components not found for testing")
		return
	
	# Create a mock NPC for testing
	var mock_npc = Node2D.new()
	mock_npc.name = "MockNPC"
	
	# Simulate ball in landed state
	golf_ball.landed_flag = true
	golf_ball.velocity = Vector2.ZERO
	golf_ball.has_emitted_landed_signal = true
	golf_ball.final_landing_tile = Vector2i(5, 5)
	
	print("Ball state before NPC push:")
	print("  landed_flag:", golf_ball.landed_flag)
	print("  velocity:", golf_ball.velocity)
	print("  has_emitted_landed_signal:", golf_ball.has_emitted_landed_signal)
	
	# Simulate NPC push force
	var push_force = Vector2(300, 0)  # Push to the right
	entities_manager._apply_ball_push_force(golf_ball, push_force)
	
	print("Ball state after NPC push:")
	print("  landed_flag:", golf_ball.landed_flag)
	print("  velocity:", golf_ball.velocity)
	print("  has_emitted_landed_signal:", golf_ball.has_emitted_landed_signal)
	
	# Verify that the ball was properly "woken up"
	if not golf_ball.landed_flag and golf_ball.velocity.length() > 0 and not golf_ball.has_emitted_landed_signal:
		print("✓ SUCCESS: Ball properly awakened by NPC push")
		print("✓ SUCCESS: Landing highlight system reset for new landing")
	else:
		print("✗ FAILURE: Ball not properly awakened by NPC push")
	
	# Clean up mock NPC
	mock_npc.queue_free()

func _on_ball_landed(tile: Vector2i):
	"""Called when a ball lands - useful for testing"""
	print("=== BALL LANDED ===")
	print("Landing tile:", tile)
	print("has_emitted_landed_signal:", golf_ball.has_emitted_landed_signal)
	print("final_landing_tile:", golf_ball.final_landing_tile) 