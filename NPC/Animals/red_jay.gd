extends Node2D

# RedJay states
enum State { FLYING_TO_BALL, PUSHING_BALL, FLYING_AWAY, CLEANUP }

var current_state: State = State.FLYING_TO_BALL
var target_ball: Node2D = null
var pin_position: Vector2 = Vector2.ZERO
var flight_speed: float = 800.0
var push_force: float = 400.0

# Animation sprites
@onready var animated_sprite: AnimatedSprite2D = $RedJaySprite
@onready var swoop_sound: AudioStreamPlayer2D = $Swoop

# Animation frames
var bird_flight_left_right: Texture2D
var bird_flight_up: Texture2D
var bird_flight_down: Texture2D
var bird_left_right: Texture2D
var bird_up: Texture2D
var bird_down: Texture2D

func _ready():
	# Load bird textures
	bird_flight_left_right = load("res://NPC/Animals/BirdFlightLeftRight.png")
	bird_flight_up = load("res://NPC/Animals/BirdFlightUp.png")
	bird_flight_down = load("res://NPC/Animals/BirdFlightDown.png")
	bird_left_right = load("res://NPC/Animals/BirdLeftRight.png")
	bird_up = load("res://NPC/Animals/BirdUp.png")
	bird_down = load("res://NPC/Animals/BirdDown.png")
	
	# Check if textures loaded successfully
	if not bird_flight_left_right or not bird_flight_up or not bird_flight_down or not bird_left_right or not bird_up or not bird_down:
		print("Warning: Failed to load some bird textures")
		queue_free()
		return
	
	# Set up animated sprite
	if animated_sprite:
		animated_sprite.sprite_frames = SpriteFrames.new()
		animated_sprite.sprite_frames.add_animation("flight_left_right")
		animated_sprite.sprite_frames.add_frame("flight_left_right", bird_flight_left_right, 0)
		animated_sprite.sprite_frames.add_animation("flight_up")
		animated_sprite.sprite_frames.add_frame("flight_up", bird_flight_up, 0)
		animated_sprite.sprite_frames.add_animation("flight_down")
		animated_sprite.sprite_frames.add_frame("flight_down", bird_flight_down, 0)
		animated_sprite.sprite_frames.add_animation("left_right")
		animated_sprite.sprite_frames.add_frame("left_right", bird_left_right, 0)
		animated_sprite.sprite_frames.add_animation("up")
		animated_sprite.sprite_frames.add_frame("up", bird_up, 0)
		animated_sprite.sprite_frames.add_animation("down")
		animated_sprite.sprite_frames.add_frame("down", bird_down, 0)
		
		# Start with flight animation
		animated_sprite.play("flight_left_right")
	else:
		print("Warning: AnimatedSprite2D not found")
		queue_free()

func start_red_jay_effect(ball: Node2D, pin_pos: Vector2):
	"""Start the RedJay effect - fly to ball, push it toward pin, then fly away"""
	target_ball = ball
	pin_position = pin_pos
	
	# Play swoop sound
	if swoop_sound:
		swoop_sound.play()
	
	# Start flying to the ball
	current_state = State.FLYING_TO_BALL
	_fly_to_ball()

func _fly_to_ball():
	"""Fly toward the ball"""
	if not target_ball or not is_instance_valid(target_ball):
		_cleanup()
		return
	
	var ball_pos = target_ball.global_position
	var direction = (ball_pos - global_position).normalized()
	
	# Update sprite based on flight direction
	_update_flight_sprite(direction)
	
	# Move toward ball
	var tween = create_tween()
	tween.tween_method(_move_toward_target, global_position, ball_pos, global_position.distance_to(ball_pos) / flight_speed)
	tween.tween_callback(_on_reached_ball)

func _move_toward_target(current_pos: Vector2):
	"""Move toward target position"""
	global_position = current_pos

func _on_reached_ball():
	"""Called when RedJay reaches the ball"""
	current_state = State.PUSHING_BALL
	_push_ball()

func _push_ball():
	"""Push the ball toward the pin"""
	if not target_ball or not is_instance_valid(target_ball):
		_cleanup()
		return
	
	print("=== REDJAY PUSHING BALL ===")
	print("Ball position:", target_ball.global_position)
	print("Pin position:", pin_position)
	print("Ball has set_velocity method:", target_ball.has_method("set_velocity"))
	print("Ball has velocity property:", "velocity" in target_ball)
	print("Ball has set_landed_flag method:", target_ball.has_method("set_landed_flag"))
	print("Ball has set_rolling_state method:", target_ball.has_method("set_rolling_state"))
	
	# Calculate direction from ball to pin
	var ball_pos = target_ball.global_position
	var direction_to_pin = (pin_position - ball_pos).normalized()
	
	# Update sprite to show pushing animation (non-flight sprite)
	_update_push_sprite(direction_to_pin)
	
	# Visual feedback - scale up slightly when pushing
	var original_scale = scale
	var push_scale = scale * 1.2
	var tween = create_tween()
	tween.tween_property(self, "scale", push_scale, 0.1)
	tween.tween_property(self, "scale", original_scale, 0.1)
	
	# Apply push force to the ball with proper awakening
	var push_velocity = direction_to_pin * push_force
	print("RedJay pushing ball with velocity:", push_velocity)
	
	# Try multiple methods to ensure the ball moves
	var ball_moved = false
	
	# Method 1: Use set_velocity if available
	if target_ball.has_method("set_velocity"):
		target_ball.set_velocity(push_velocity)
		print("RedJay used set_velocity method")
		ball_moved = true
	
	# Method 2: Direct velocity assignment
	if "velocity" in target_ball:
		target_ball.velocity = push_velocity
		print("RedJay used direct velocity assignment")
		ball_moved = true
	
	# Method 3: Wake up the ball if it's in landed state
	if target_ball.has_method("set_landed_flag"):
		target_ball.set_landed_flag(false)
		print("RedJay awakened ball from landed state")
		ball_moved = true
	
	# Method 4: Enable rolling state if available
	if target_ball.has_method("set_rolling_state"):
		target_ball.set_rolling_state(true)
		print("RedJay enabled ball rolling state")
		ball_moved = true
	
	# Method 5: Force ball to move using position change (fallback)
	if not ball_moved:
		print("RedJay using fallback position change method")
		var new_position = ball_pos + (direction_to_pin * 50.0)  # Move 50 pixels
		target_ball.global_position = new_position
	
	# Wait a moment then fly away
	await get_tree().create_timer(0.5).timeout
	current_state = State.FLYING_AWAY
	_fly_away()

func _fly_away():
	"""Fly away from the ball"""
	# Calculate a random direction away from the ball
	var ball_pos = target_ball.global_position if target_ball and is_instance_valid(target_ball) else global_position
	var away_direction = (global_position - ball_pos).normalized()
	
	# Add some randomness to the flight path
	away_direction += Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	away_direction = away_direction.normalized()
	
	# Update sprite for flight
	_update_flight_sprite(away_direction)
	
	# Fly away to a point off screen
	var fly_away_distance = 800.0  # Distance to fly off screen
	var target_pos = global_position + (away_direction * fly_away_distance)
	
	var tween = create_tween()
	tween.tween_method(_move_toward_target, global_position, target_pos, fly_away_distance / flight_speed)
	tween.tween_callback(_cleanup)

func _update_flight_sprite(direction: Vector2):
	"""Update the sprite to show flight animation based on direction"""
	if not animated_sprite:
		return
	
	# Determine primary direction
	var abs_x = abs(direction.x)
	var abs_y = abs(direction.y)
	
	if abs_x > abs_y:
		# Flying left or right
		animated_sprite.play("flight_left_right")
		animated_sprite.flip_h = direction.x < 0
	else:
		# Flying up or down
		if direction.y < 0:
			animated_sprite.play("flight_up")
		else:
			animated_sprite.play("flight_down")

func _update_push_sprite(direction: Vector2):
	"""Update the sprite to show pushing animation (non-flight sprite)"""
	if not animated_sprite:
		return
	
	# Determine primary direction
	var abs_x = abs(direction.x)
	var abs_y = abs(direction.y)
	
	if abs_x > abs_y:
		# Pushing left or right
		animated_sprite.play("left_right")
		animated_sprite.flip_h = direction.x < 0
	else:
		# Pushing up or down
		if direction.y < 0:
			animated_sprite.play("up")
		else:
			animated_sprite.play("down")

func _cleanup():
	"""Clean up the RedJay effect"""
	current_state = State.CLEANUP
	queue_free()
