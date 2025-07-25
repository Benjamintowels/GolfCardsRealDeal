extends Node2D

var stall_time := 0.02  # Brief pause before starting to fall
var is_falling := false
var fade_time := 3.0  # Total lifetime of leaf particle
var fade_timer := 0.0
var sprite: Sprite2D = null

# Explosion properties
var explosion_velocity: Vector2 = Vector2.ZERO
var has_explosion_velocity: bool = false
var explosion_drag: float = 0.98  # Slower drag for leaves (more air resistance)

# Gravity and ground properties
var gravity: float = 100.0  # Lighter gravity for leaves
var ground_level: float = 0.0
var max_fall_distance: float = 60.0  # Leaves can fall further
var spawn_position: Vector2 = Vector2.ZERO

# Leaf-specific properties
var initial_scale: float = 1.0
var min_scale: float = 0.3  # How small leaves get when they hit the ground
var rotation_speed: float = 0.0  # Random rotation as they fall
var sway_amplitude: float = 20.0  # How much leaves sway side to side
var sway_frequency: float = 2.0  # How fast they sway

func _ready():
	sprite = get_node_or_null("LeafSprite")
	spawn_position = position
	ground_level = position.y + max_fall_distance
	
	# Set high z_index to ensure leaves appear on top of everything
	z_index = 1000
	if sprite:
		sprite.z_index = 1000
	
	# Set random rotation speed and initial rotation
	rotation_speed = randf_range(-2.0, 2.0)
	rotation = randf_range(0, TAU)
	
	# Store initial scale
	if sprite:
		initial_scale = sprite.scale.x
	
	# Brief stall before falling
	await get_tree().create_timer(stall_time).timeout
	is_falling = true

func _process(delta):
	if is_falling:
		# Apply explosion velocity with drag
		if has_explosion_velocity and explosion_velocity.length() > 10.0:
			position += explosion_velocity * delta
			explosion_velocity *= explosion_drag
		
		# Apply gravity
		explosion_velocity.y += gravity * delta
		
		# Add gentle swaying motion
		var sway_offset = sin(fade_timer * sway_frequency) * sway_amplitude * delta
		explosion_velocity.x += sway_offset
		
		# Apply velocity
		position += explosion_velocity * delta
		
		# Apply rotation
		rotation += rotation_speed * delta
		
		# Stop falling when hitting ground
		if position.y >= ground_level:
			position.y = ground_level
			explosion_velocity.y = 0.0
			explosion_velocity.x *= 0.9  # Slow horizontal movement on ground
			rotation_speed *= 0.8  # Slow rotation on ground
		
		# Scale down as Y increases (gets smaller as it falls)
		if sprite:
			var fall_progress = (position.y - spawn_position.y) / max_fall_distance
			fall_progress = clamp(fall_progress, 0.0, 1.0)
			var current_scale = lerp(initial_scale, min_scale, fall_progress)
			sprite.scale = Vector2(current_scale, current_scale)
		
		# Keep leaves within reasonable bounds
		var distance_from_spawn = position.distance_to(spawn_position)
		if distance_from_spawn > 100.0:
			var direction_to_spawn = (spawn_position - position).normalized()
			position = spawn_position + direction_to_spawn * 100.0
			explosion_velocity *= 0.7
		
		# Fade out over time
		if sprite:
			fade_timer += delta
			var alpha = 1.0 - (fade_timer / fade_time)
			alpha = clamp(alpha, 0.0, 1.0)
			sprite.modulate.a = alpha
			if alpha <= 0.0:
				queue_free()
		else:
			# Fallback cleanup
			fade_timer += delta
			if fade_timer >= fade_time:
				queue_free()

func add_explosion_velocity(velocity: Vector2) -> void:
	"""Add initial explosion velocity to the leaf particle"""
	explosion_velocity = velocity
	has_explosion_velocity = true

func set_leaf_texture(texture: Texture2D) -> void:
	"""Set the texture for this leaf particle"""
	if sprite:
		sprite.texture = texture 
