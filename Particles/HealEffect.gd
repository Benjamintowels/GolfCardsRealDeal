extends Node2D

# Particle effect of green HealthParticles floating upwards and fading away

@onready var particle_texture: Texture2D = preload("res://Particles/HealthParticle.png")

var particle_count: int = 15  # Number of particles to spawn
var particle_lifetime: float = 2.0  # How long each particle lives
var spawn_radius: float = 20.0  # Radius around the center to spawn particles
var float_speed: float = 50.0  # Speed particles float upwards
var fade_duration: float = 1.5  # How long particles take to fade out

func _ready():
	# Start the particle effect
	start_heal_effect()

func start_heal_effect():
	"""Start the healing particle effect"""
	print("=== STARTING HEAL EFFECT ===")
	
	# Spawn particles over a short duration
	for i in range(particle_count):
		# Stagger particle spawning
		var spawn_delay = (i * 0.1)  # 0.1 seconds between each particle
		call_deferred("spawn_particle", spawn_delay)
	
	# Clean up after all particles are done
	var cleanup_timer = get_tree().create_timer(particle_lifetime + 1.0)
	cleanup_timer.timeout.connect(_on_effect_complete)

func spawn_particle(delay: float):
	"""Spawn a single healing particle"""
	# Wait for the delay
	await get_tree().create_timer(delay).timeout
	
	# Create particle sprite
	var particle = Sprite2D.new()
	particle.texture = particle_texture
	particle.modulate = Color(0.2, 1.0, 0.3, 1.0)  # Green color
	particle.z_index = 1000  # Ensure particles appear on top
	
	# Random position within spawn radius
	var random_angle = randf() * TAU
	var random_distance = randf_range(0, spawn_radius)
	var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	particle.position = spawn_offset
	
	add_child(particle)
	
	# Animate the particle
	_animate_particle(particle)

func _animate_particle(particle: Sprite2D):
	"""Animate a single particle floating upwards and fading"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move particle upwards
	var target_y = particle.position.y - 100.0  # Move up 100 pixels
	tween.tween_property(particle, "position:y", target_y, particle_lifetime)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	# Add some horizontal movement
	var horizontal_movement = randf_range(-20.0, 20.0)
	tween.tween_property(particle, "position:x", particle.position.x + horizontal_movement, particle_lifetime)
	
	# Fade out the particle
	tween.tween_property(particle, "modulate:a", 0.0, fade_duration).set_delay(particle_lifetime - fade_duration)
	
	# Scale the particle slightly
	var scale_variation = randf_range(0.8, 1.2)
	tween.tween_property(particle, "scale", Vector2(scale_variation, scale_variation), particle_lifetime)
	
	# Remove particle when animation completes
	tween.tween_callback(particle.queue_free).set_delay(particle_lifetime)

func _on_effect_complete():
	"""Called when the entire effect is complete"""
	print("=== HEAL EFFECT COMPLETE ===")
	queue_free()
