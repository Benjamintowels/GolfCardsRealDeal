extends Node2D

var stall_time := 0.05
var drop_speed := 200.0
var is_dropping := false
var fade_time := 0.3
var fade_timer := 0.0
var sprite: Sprite2D = null

# Explosion properties
var explosion_velocity: Vector2 = Vector2.ZERO
var has_explosion_velocity: bool = false
var explosion_drag: float = 0.95  # How quickly explosion velocity decays

func _ready():
	sprite = get_node_or_null("CoinParticleSprite")
	await get_tree().create_timer(stall_time).timeout
	is_dropping = true

func _process(delta):
	if is_dropping:
		# Apply explosion velocity if it exists
		if has_explosion_velocity and explosion_velocity.length() > 10.0:
			position += explosion_velocity * delta
			explosion_velocity *= explosion_drag  # Apply drag
		else:
			# Normal falling behavior
			if drop_speed > 0.0:
				position.y += drop_speed * delta
		
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
	print("✓ Added explosion velocity to coin particle:", velocity)
