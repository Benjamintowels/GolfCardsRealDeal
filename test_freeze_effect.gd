extends Node2D

# Test scene for freeze effect system
# Press SPACE to launch an ice ball at a gang member

var gang_member_created: bool = false
var ball_created: bool = false

func _ready():
	print("=== FREEZE EFFECT TEST SCENE ===")
	print("Press SPACE to launch ice ball at gang member")
	print("GangMember should be frozen for 2 turns when hit")
	print("GangMember should switch to ice sprite and collision")
	
	# Create test entities automatically
	_create_test_gang_member()
	_create_test_ball()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("=== LAUNCHING ICE BALL ===")
		_launch_ice_ball()

func _launch_ice_ball():
	"""Launch an ice ball at the gang member"""
	print("Launching ice ball at gang member")
	
	# Get the gang member
	var gang_member = get_node_or_null("TestGangMember")
	if not gang_member:
		print("✗ No gang member found")
		return
	
	# Get the ball
	var ball = get_node_or_null("TestBall")
	if not ball:
		print("✗ No ball found")
		return
	
	# Set ball position and velocity to hit gang member
	var ball_pos = Vector2(100, 300)  # Start position
	var gang_member_pos = gang_member.global_position
	var direction = (gang_member_pos - ball_pos).normalized()
	var velocity = direction * 500.0  # Fast enough to deal damage
	
	ball.global_position = ball_pos
	ball.velocity = velocity
	
	# Apply ice element to the ball
	var ice_element = preload("res://Elements/Ice.tres")
	ball.set_element(ice_element)
	
	print("✓ Ice ball launched with velocity:", velocity)
	print("Ball has ice element:", ball.get_element().name if ball.get_element() else "None")
	print("Expected: GangMember should switch to ice sprite and be frozen for 2 turns")

func _create_test_gang_member():
	"""Create a test GangMember"""
	print("=== CREATING TEST GANGMEMBER ===")
	
	# Load the GangMember scene
	var gang_member_scene = load("res://NPC/Gang/GangMember.tscn")
	if not gang_member_scene:
		print("✗ ERROR: Could not load GangMember.tscn")
		return
	
	# Create GangMember at center
	var gang_member = gang_member_scene.instantiate()
	gang_member.name = "TestGangMember"
	add_child(gang_member)
	gang_member.global_position = Vector2(400, 300)
	
	# Setup the GangMember
	if gang_member.has_method("setup"):
		# Convert world position to grid position
		var cell_size = 48
		var grid_x = floor((400 - cell_size / 2) / cell_size)
		var grid_y = floor((300 - cell_size / 2) / cell_size)
		gang_member.setup("default", Vector2i(grid_x, grid_y))
	
	print("✓ Created GangMember at position:", gang_member.global_position)
	gang_member_created = true
	print("=== TEST GANGMEMBER CREATED ===")

func _create_test_ball():
	"""Create a test golf ball"""
	print("=== CREATING TEST BALL ===")
	
	# Load the golf ball scene
	var ball_scene = load("res://GolfBall.tscn")
	if not ball_scene:
		print("✗ ERROR: Could not load GolfBall.tscn")
		return
	
	# Create ball
	var ball = ball_scene.instantiate()
	ball.name = "TestBall"
	add_child(ball)
	ball.global_position = Vector2(100, 300)
	
	print("✓ Created ball at position:", ball.global_position)
	ball_created = true
	print("=== TEST BALL CREATED ===") 