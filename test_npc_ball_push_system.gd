extends Node2D

# Test script for NPC Ball Push System
# This demonstrates how NPCs can push balls while moving during their turns

@onready var gang_member: Node2D
@onready var police: Node2D
@onready var golf_ball: Node2D
@onready var entities_manager: Node

func _ready():
	print("=== NPC BALL PUSH SYSTEM TEST ===")
	
	# Find the Entities manager
	entities_manager = get_node_or_null("Entities")
	if not entities_manager:
		print("✗ ERROR: Entities manager not found!")
		return
	
	# Find NPCs and ball
	gang_member = get_node_or_null("GangMember")
	police = get_node_or_null("Police")
	golf_ball = get_node_or_null("GolfBall")
	
	if not gang_member:
		print("✗ ERROR: GangMember not found!")
	if not police:
		print("✗ ERROR: Police not found!")
	if not golf_ball:
		print("✗ ERROR: GolfBall not found!")
	
	print("✓ Test setup complete")
	print("=== TEST INSTRUCTIONS ===")
	print("1. Start NPC turns to see them move")
	print("2. Launch a ball to collide with moving NPCs")
	print("3. Observe how balls get pushed by NPC movement direction")
	print("4. GangMembers push harder (400 velocity) than Police (250 velocity)")
	print("5. Test with landed/stationary balls - they should 'wake up' when pushed")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_npc_movement_detection()
	elif event.is_action_pressed("ui_select"):
		_test_ball_state_detection()

func _test_npc_movement_detection():
	"""Test the movement detection system"""
	print("=== TESTING MOVEMENT DETECTION ===")
	
	if gang_member:
		var is_moving = entities_manager._is_npc_moving_during_turn(gang_member)
		var movement_dir = entities_manager._get_npc_movement_direction(gang_member)
		var push_vel = entities_manager._get_npc_push_velocity(gang_member)
		
		print("GangMember - Moving:", is_moving, "Direction:", movement_dir, "Push Velocity:", push_vel)
	
	if police:
		var is_moving = entities_manager._is_npc_moving_during_turn(police)
		var movement_dir = entities_manager._get_npc_movement_direction(police)
		var push_vel = entities_manager._get_npc_push_velocity(police)
		
		print("Police - Moving:", is_moving, "Direction:", movement_dir, "Push Velocity:", push_vel)

func _on_ball_launched():
	"""Called when a ball is launched - useful for testing"""
	print("=== BALL LAUNCHED - READY FOR NPC COLLISION TEST ===")
	print("Move NPCs and watch how they push the ball!")

func _on_npc_turn_started(npc: Node):
	"""Called when an NPC starts their turn"""
	print("NPC turn started:", npc.name)
	if npc == gang_member:
		print("GangMember will push balls with 400 velocity when moving")
	elif npc == police:
		print("Police will push balls with 250 velocity when moving")

func _on_npc_turn_ended(npc: Node):
	"""Called when an NPC ends their turn"""
	print("NPC turn ended:", npc.name) 

func _test_ball_state_detection():
	"""Test the ball state detection system"""
	print("=== TESTING BALL STATE DETECTION ===")
	
	if golf_ball:
		var is_in_flight = false
		var is_landed = false
		var is_rolling = false
		var velocity_length = 0.0
		
		if golf_ball.has_method("is_in_flight"):
			is_in_flight = golf_ball.is_in_flight()
		if "landed_flag" in golf_ball:
			is_landed = golf_ball.landed_flag
		if "is_rolling" in golf_ball:
			is_rolling = golf_ball.is_rolling
		if golf_ball.has_method("get_velocity"):
			velocity_length = golf_ball.get_velocity().length()
		elif "velocity" in golf_ball:
			velocity_length = golf_ball.velocity.length()
		
		print("Ball State - In Flight:", is_in_flight, "Landed:", is_landed, "Rolling:", is_rolling, "Velocity:", velocity_length)
		
		# Test the helper methods
		if golf_ball.has_method("set_rolling_state"):
			print("✓ Ball has set_rolling_state method")
		if golf_ball.has_method("set_landed_flag"):
			print("✓ Ball has set_landed_flag method")
		if golf_ball.has_method("is_in_flight"):
			print("✓ Ball has is_in_flight method") 