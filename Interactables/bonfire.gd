extends Node2D

# A rest site that you activate with fire and then you can rest there

@onready var bonfire_flame: Sprite2D = $BonfireFlame
@onready var bonfire_area: Area2D = $BonfireArea2D
@onready var top_height_marker: Marker2D = $TopHeight
@onready var ysort_point: Marker2D = $YsortPoint

# Flame animation properties
var flame_frames: Array[Texture2D] = []
var current_frame_index: int = 0
var animation_timer: float = 0.0
var animation_speed: float = 0.15  # Time between frame changes
var scale_variation: float = 0.1   # How much the flame scales
var base_scale: Vector2 = Vector2(1.0, 1.0)
var opacity_variation: float = 0.2 # How much opacity changes
var base_opacity: float = 1.0

# Height properties
var bonfire_height: float = 10.0  # Height from base to top

func _ready():
	# Add to groups for Y-sorting and optimization
	add_to_group("visual_objects")
	add_to_group("ysort_objects")
	
	setup_flame_animation()
	setup_collision_detection()
	
	# Initialize Y-sorting
	_update_ysort()
	
	# Debug output
	print("=== BONFIRE READY DEBUG ===")
	print("Bonfire name:", name)
	print("Bonfire position:", global_position)
	print("Bonfire z_index:", z_index)
	var base_sprite = get_node_or_null("BonfireBaseSprite")
	print("Base sprite visible:", base_sprite.visible if base_sprite else "null")
	print("Flame sprite visible:", bonfire_flame.visible)
	print("=== END BONFIRE READY DEBUG ===")

func setup_flame_animation():
	# Load flame textures
	flame_frames = [
		preload("res://Interactables/BonfireFlame1.png"),
		preload("res://Interactables/BonfireFlame2.png"),
		preload("res://Interactables/BonfireFlame3.png")
	]
	
	# Set initial frame
	if flame_frames.size() > 0:
		bonfire_flame.texture = flame_frames[0]
		bonfire_flame.visible = true
	else:
		print("✗ Bonfire flame frames failed to load")

func setup_collision_detection():
	# Connect collision signals
	bonfire_area.body_entered.connect(_on_body_entered)
	bonfire_area.body_exited.connect(_on_body_exited)

func _process(delta):
	animate_flame(delta)

func animate_flame(delta):
	animation_timer += delta
	
	# Change frame
	if animation_timer >= animation_speed:
		animation_timer = 0.0
		current_frame_index = (current_frame_index + 1) % flame_frames.size()
		bonfire_flame.texture = flame_frames[current_frame_index]
	
	# Animate scale and opacity
	var time_factor = sin(Time.get_ticks_msec() * 0.003) * 0.5 + 0.5  # 0 to 1 oscillation
	var scale_factor = 1.0 + (time_factor * scale_variation)
	var opacity_factor = base_opacity - (time_factor * opacity_variation)
	
	bonfire_flame.scale = base_scale * scale_factor
	bonfire_flame.modulate = Color(1.0, 0.8, 0.6, opacity_factor)  # Orange-red-yellow tint

func _on_body_entered(body: Node2D):
	if body.has_method("get_ball_height") and body.has_method("get_ball_velocity"):
		handle_ball_collision(body)

func _on_body_exited(body: Node2D):
	# Handle any cleanup when ball leaves bonfire area
	pass

func handle_ball_collision(ball: Node2D):
	var ball_height = ball.get_ball_height()
	var ball_velocity = ball.get_ball_velocity()
	var ball_position = ball.global_position
	
	# Check if ball is in air (above ground level)
	if ball_height > 0:
		# Ball in air - check height against bonfire
		if ball_height < bonfire_height:
			# Ball hits bonfire wall - reflect
			reflect_ball_off_wall(ball, ball_velocity)
		else:
			# Ball passes over bonfire
			ball_passes_over(ball, ball_velocity)
	else:
		# Ball is rolling on ground
		reflect_ball_off_wall(ball, ball_velocity)

func reflect_ball_off_wall(ball: Node2D, velocity: Vector2):
	# Simple wall reflection - reverse horizontal velocity
	var reflected_velocity = Vector2(-velocity.x * 0.8, velocity.y)  # Reduce speed slightly
	ball.set_ball_velocity(reflected_velocity)

func ball_passes_over(ball: Node2D, velocity: Vector2):
	# Ball passes over bonfire - no collision, just continue
	# Could add visual effects here
	pass

# Getter methods for external access
func get_bonfire_height() -> float:
	return bonfire_height

func get_top_height_position() -> Vector2:
	return top_height_marker.global_position

func get_ysort_position() -> Vector2:
	return ysort_point.global_position

func get_y_sort_point() -> float:
	"""Get the Y-sort reference point for the bonfire"""
	# Use the YsortPoint marker for consistent Y-sorting
	if ysort_point:
		return ysort_point.global_position.y
	else:
		# Fallback to global position if no YsortPoint marker
		return global_position.y

func _update_ysort():
	"""Update the Bonfire's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")
