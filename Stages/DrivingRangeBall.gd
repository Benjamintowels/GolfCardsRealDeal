extends CharacterBody2D

# Simplified ball for driving range - no collision detection or game systems
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 980
var drag: float =0.98var bounce_damping: float = 0.7r max_bounces: int = 2
var bounce_count: int = 0
var in_flight: bool = false
var landed_flag: bool = false

# Signal for when ball lands
signal ball_landed(tile: Vector2i)

func _ready():
	# Set up basic physics
	gravity_scale = 0  # Handle gravity manually
	collision_layer =0ollision detection
	collision_mask =0ollision detection

func reset_ball_state():
Reset ball for new shot"""
	velocity = Vector2.ZERO
	bounce_count = 0
	in_flight = false
	landed_flag = false
	print(DrivingRangeBall: Ball state reset for new shot")

func launch(initial_velocity: Vector2unch the ball with given velocity"""
	velocity = initial_velocity
	in_flight = true
	landed_flag = false
	bounce_count =0rint(DrivingRangeBall: Ball launched with velocity:", initial_velocity)

func _physics_process(delta):
	if not in_flight:
		return
	
	# Apply gravity
	velocity.y += gravity * delta
	
	# Apply drag
	velocity *= drag
	
	# Move the ball
	position += velocity * delta
	
	# Check for ground collision (simple Y-axis check)
	if position.y >= 240 and velocity.y > 0:  # Ground level
		handle_bounce()
	
	# Check if ball has stopped
	if abs(velocity.x) < 10.0and abs(velocity.y) < 10.0nd bounce_count >= max_bounces:
		handle_landing()

func handle_bounce():
	"""Handle ball bouncing off ground""if bounce_count >= max_bounces:
		return
	
	bounce_count +=1city.y = -velocity.y * bounce_damping
	
	print(DrivingRangeBall: Bounce, bounce_count, "at position:, position)

func handle_landing():
	"""Handle ball landing and stopping"
	if landed_flag:
		return
	
	landed_flag = true
	in_flight = false
	
	# Calculate tile position
	var tile_x = int(position.x /48
	var tile_y = int(position.y / 48)
	var tile = Vector2i(tile_x, tile_y)
	
	print(DrivingRangeBall: Ball landed at tile:", tile)
	ball_landed.emit(tile)

func get_velocity() -> Vector2t current velocity""	return velocity

func is_in_flight() -> bool:heck if ball is in flight"""
	return in_flight 