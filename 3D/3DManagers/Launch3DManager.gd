extends Node
class_name Launch3DManager

# Launch3DManager - Handles 3D ball physics and launching
# Optimized for 3D space with realistic ball physics

signal ball_launched(ball: Node3D)
signal ball_landed(ball: Node3D)
signal ball_in_hole(ball: Node3D)

# Manager references
var player_manager: Node = null
var camera_manager: Node = null
var world_container: Node3D = null
var cell_size: int = 48

# Ball properties
var ball_node: Node3D = null
var ball_sprite: Sprite3D = null
var ball_rigid_body: RigidBody3D = null
var ball_collision: CollisionShape3D = null

# Physics settings
var ball_mass: float = 1.0
var ball_friction: float = 0.8
var ball_bounce: float = 0.3
var launch_power_multiplier: float = 10.0

# Launch state
var is_ball_active: bool = false
var launch_tween: Tween = null

func setup(player_mgr: Node, camera_mgr: Node, world_container_param: Node3D, cell_size_param: int):
	"""Initialize the 3D launch system"""
	player_manager = player_mgr
	camera_manager = camera_mgr
	world_container = world_container_param
	cell_size = cell_size_param
	
	print("✓ Launch3DManager setup complete")

func launch_ball(power: float, direction: Vector3):
	"""Launch the ball with specified power and direction"""
	
	if is_ball_active:
		print("⚠ Ball already active")
		return
	
	# Create ball if it doesn't exist
	if not ball_node:
		_create_ball()
	
	# Position ball at player location
	var player_pos = player_manager.get_player_position()
	ball_node.global_position = player_pos
	ball_node.global_position.y = 5.0  # Slightly above ground
	
	# Calculate launch velocity
	var launch_velocity = direction.normalized() * power * launch_power_multiplier
	launch_velocity.y = power * 2.0  # Add upward component
	
	# Apply impulse to ball
	ball_rigid_body.apply_central_impulse(launch_velocity)
	
	# Set ball as active
	is_ball_active = true
	
	# Connect to ball collision
	ball_rigid_body.body_entered.connect(_on_ball_collision)
	
	# Emit launch signal
	ball_launched.emit(ball_node)
	
	print("✓ Ball launched with power:", power, "direction:", direction)

func _create_ball():
	"""Create the 3D ball with physics"""
	
	# Create ball node
	ball_node = Node3D.new()
	ball_node.name = "GolfBall3D"
	
	# Create rigid body for physics
	ball_rigid_body = RigidBody3D.new()
	ball_rigid_body.name = "BallRigidBody"
	ball_rigid_body.mass = ball_mass
	ball_rigid_body.friction = ball_friction
	ball_rigid_body.bounce = ball_bounce
	ball_rigid_body.gravity_scale = 1.0
	
	# Create collision shape
	ball_collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 2.0  # Small ball radius
	ball_collision.shape = sphere_shape
	
	# Create ball sprite
	ball_sprite = Sprite3D.new()
	ball_sprite.name = "BallSprite3D"
	
	# Load ball texture
	var ball_texture = load("res://GolfBall.png")
	if ball_texture:
		ball_sprite.texture = ball_texture
	else:
		# Create fallback texture
		ball_sprite.texture = _create_ball_fallback_texture()
	
	# Setup sprite properties
	ball_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ball_sprite.pixel_size = 0.05  # Small ball size
	ball_sprite.position.y = 0
	
	# Assemble ball
	ball_rigid_body.add_child(ball_collision)
	ball_rigid_body.add_child(ball_sprite)
	ball_node.add_child(ball_rigid_body)
	
	# Add to world
	world_container.add_child(ball_node)
	
	print("✓ 3D Ball created with physics")

func _create_ball_fallback_texture() -> Texture2D:
	"""Create a fallback texture for the ball"""
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	
	# Draw a simple ball shape
	for x in range(32):
		for y in range(32):
			var center = Vector2(16, 16)
			var pos = Vector2(x, y)
			var distance = center.distance_to(pos)
			if distance <= 14:
				image.set_pixel(x, y, Color.WHITE)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	return ImageTexture.create_from_image(image)

func _on_ball_collision(body: Node3D):
	"""Handle ball collision with ground or obstacles"""
	
	if not is_ball_active:
		return
	
	# Check if ball has stopped moving
	if ball_rigid_body.linear_velocity.length() < 0.1:
		_on_ball_stopped()

func _on_ball_stopped():
	"""Handle ball stopping"""
	
	if not is_ball_active:
		return
	
	is_ball_active = false
	
	# Emit landed signal
	ball_landed.emit(ball_node)
	
	print("✓ Ball landed at:", ball_node.global_position)

func reset_ball():
	"""Reset ball to initial state"""
	
	if ball_node:
		# Stop any movement
		ball_rigid_body.linear_velocity = Vector3.ZERO
		ball_rigid_body.angular_velocity = Vector3.ZERO
		
		# Position at player
		var player_pos = player_manager.get_player_position()
		ball_node.global_position = player_pos
		ball_node.global_position.y = 5.0
		
		is_ball_active = false
	
	print("✓ Ball reset")

func destroy_ball():
	"""Destroy the ball"""
	
	if ball_node:
		ball_node.queue_free()
		ball_node = null
		ball_rigid_body = null
		ball_sprite = null
		ball_collision = null
		is_ball_active = false
	
	print("✓ Ball destroyed")

func get_ball_position() -> Vector3:
	"""Get current ball position"""
	if ball_node:
		return ball_node.global_position
	return Vector3.ZERO

func is_ball_flying() -> bool:
	"""Check if ball is currently flying"""
	return is_ball_active

func update(delta: float):
	"""Update ball physics (called by main manager)"""
	
	if is_ball_active and ball_rigid_body:
		# Check if ball has fallen below ground
		if ball_rigid_body.global_position.y < -10:
			_on_ball_stopped()
		
		# Check if ball has stopped moving
		if ball_rigid_body.linear_velocity.length() < 0.1:
			_on_ball_stopped()

# Public API
func get_ball_node() -> Node3D:
	"""Get the ball node"""
	return ball_node

func set_ball_properties(mass: float, friction: float, bounce: float):
	"""Set ball physics properties"""
	ball_mass = mass
	ball_friction = friction
	ball_bounce = bounce
	
	if ball_rigid_body:
		ball_rigid_body.mass = mass
		ball_rigid_body.friction = friction
		ball_rigid_body.bounce = bounce

func get_ball_info() -> Dictionary:
	"""Get current ball information"""
	return {
		"position": get_ball_position(),
		"is_flying": is_ball_flying(),
		"velocity": ball_rigid_body.linear_velocity if ball_rigid_body else Vector3.ZERO,
		"mass": ball_mass,
		"friction": ball_friction,
		"bounce": ball_bounce
	} 