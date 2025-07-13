extends Node2D

var stall_time := 0.05
var is_dropping := false
var fade_time := 2.0  # Increased from 0.3 to 2.0 seconds for longer visibility
var fade_timer := 0.0
var sprite: Sprite2D = null

# Explosion properties
var explosion_velocity: Vector2 = Vector2.ZERO
var has_explosion_velocity: bool = false
var explosion_drag: float = 0.95  # How quickly explosion velocity decays

# Gravity and ground properties
var gravity: float = 300.0  # Reduced gravity for more controlled movement
var ground_level: float = 0.0  # Will be set relative to spawn position
var max_fall_distance: float = 30.0  # Maximum distance coins can fall from spawn
var spawn_position: Vector2 = Vector2.ZERO

func _ready():
	sprite = get_node_or_null("CoinParticleSprite")
	spawn_position = position
	ground_level = position.y + max_fall_distance  # Set ground level relative to spawn
	await get_tree().create_timer(stall_time).timeout
	is_dropping = true

func _process(delta):
	if is_dropping:
		# Apply explosion velocity if it exists
		if has_explosion_velocity and explosion_velocity.length() > 5.0:
			position += explosion_velocity * delta
			explosion_velocity *= explosion_drag  # Apply drag
		else:
			# Apply gentle gravity when explosion velocity is gone
			explosion_velocity.y += gravity * delta
			position += explosion_velocity * delta
			
			# Stop falling when hitting ground level
			if position.y >= ground_level:
				position.y = ground_level
				explosion_velocity.y = 0.0
				explosion_velocity.x *= 0.8  # Slow horizontal movement on ground
		
		# Keep coins within reasonable bounds of spawn area
		var distance_from_spawn = position.distance_to(spawn_position)
		if distance_from_spawn > 80.0:  # Limit how far coins can travel
			var direction_to_spawn = (spawn_position - position).normalized()
			position = spawn_position + direction_to_spawn * 80.0
			explosion_velocity *= 0.5  # Slow down when hitting boundary
		
		if sprite:
			fade_timer += delta
			var alpha = 1.0 - (fade_timer / fade_time)
			alpha = clamp(alpha, 0.0, 1.0)
			sprite.modulate.a = alpha
			if alpha <= 0.0:
				queue_free()
		else:
			# Fallback: just queue_free after fade_time
			fade_timer += delta
			if fade_timer >= fade_time:
				queue_free()

func add_explosion_velocity(velocity: Vector2) -> void:
	"""Add explosion velocity to the coin particle"""
	explosion_velocity = velocity
	has_explosion_velocity = true
