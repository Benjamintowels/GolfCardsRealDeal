extends Node2D

# Explosion effect that can be reused for various objects
# Handles scaling animation, sound effects, and particle systems

# Animation variables
var explosion_sprite: Sprite2D
var explosion_sound: AudioStreamPlayer2D
var particle_system: GPUParticles2D
var animation_tween: Tween

# Animation settings
const EXPLOSION_DURATION: float = 1.5  # Total duration of explosion effect
const SCALE_UP_TIME: float = 0.3       # Time to scale up
const FADE_OUT_TIME: float = 1.2       # Time to fade out
const MAX_SCALE: float = 2.5           # Maximum scale of explosion sprite
const PARTICLE_DURATION: float = 2.0   # Duration of particle effects

# Particle settings
const PARTICLE_COUNT: int = 15         # Number of fire particles
const PARTICLE_SPEED: float = 150.0    # Speed of particles
const PARTICLE_GRAVITY: float = 300.0  # Gravity effect on particles

func _ready():
	print("=== EXPLOSION _READY CALLED ===")
	
	# Get references to nodes
	explosion_sprite = get_node_or_null("ExplosionSprite")
	explosion_sound = get_node_or_null("ExplosionSound")
	particle_system = get_node_or_null("FireParticles")
	
	print("Explosion sprite found:", explosion_sprite != null)
	print("Explosion sound found:", explosion_sound != null)
	print("Particle system found:", particle_system != null)
	
	# Start the explosion animation
	start_explosion_animation()
	
	print("=== EXPLOSION _READY COMPLETE ===")

func start_explosion_animation():
	"""Start the explosion animation sequence"""
	print("=== STARTING EXPLOSION ANIMATION ===")
	
	# Play explosion sound
	if explosion_sound:
		explosion_sound.play()
		print("✓ Playing explosion sound")
	else:
		print("✗ No explosion sound found")
	
	# Start particle system
	if particle_system:
		particle_system.emitting = true
		print("✓ Started fire particle system")
	else:
		print("✗ No particle system found")
	
	# Create tween for animation
	animation_tween = create_tween()
	animation_tween.set_parallel(true)
	
	# Scale up animation
	if explosion_sprite:
		# Start at small scale (but not zero so it's visible)
		explosion_sprite.scale = Vector2.ONE * 0.1
		explosion_sprite.modulate.a = 1.0
		
		print("Explosion sprite initial scale:", explosion_sprite.scale)
		
		# Scale up quickly
		animation_tween.tween_property(explosion_sprite, "scale", Vector2.ONE * MAX_SCALE, SCALE_UP_TIME)
		animation_tween.tween_callback(_on_scale_up_complete).set_delay(SCALE_UP_TIME)
		
		# Fade out over time
		animation_tween.tween_property(explosion_sprite, "modulate:a", 0.0, FADE_OUT_TIME).set_delay(SCALE_UP_TIME)
		# Add a callback to track fade out progress
		animation_tween.tween_callback(func(): print("Explosion fade out started")).set_delay(SCALE_UP_TIME)
		
		print("✓ Started explosion sprite animation")
	else:
		print("✗ No explosion sprite found")
	
	# Clean up after animation completes
	animation_tween.tween_callback(_on_explosion_complete).set_delay(EXPLOSION_DURATION)
	
	print("=== EXPLOSION ANIMATION STARTED ===")

func _on_scale_up_complete():
	"""Called when the explosion sprite has finished scaling up"""
	print("Explosion scale up complete - sprite at maximum scale")
	print("Explosion sprite current alpha:", explosion_sprite.modulate.a if explosion_sprite else "No sprite")
	print("Explosion sprite current scale:", explosion_sprite.scale if explosion_sprite else "No sprite")

func _on_explosion_complete():
	"""Called when the entire explosion animation is complete"""
	print("=== EXPLOSION ANIMATION COMPLETE ===")
	print("Explosion position:", global_position)
	print("Explosion parent:", get_parent().name if get_parent() else "No parent")
	
	# Stop particle system
	if particle_system:
		particle_system.emitting = false
		print("✓ Stopped fire particle system")
	
	# Remove the explosion from the scene
	queue_free()
	print("✓ Explosion removed from scene")

# These functions are no longer needed since we create everything programmatically
# The particle system is now configured in the static create_explosion_at_position method

# Static method to create explosion at a specific position
static func create_explosion_at_position(position: Vector2, parent: Node) -> Node2D:
	"""Create and instance an explosion at the specified position"""
	print("=== CREATING EXPLOSION ===")
	print("Position:", position)
	print("Parent:", parent.name if parent else "No parent")
	
	# Load and instance the explosion scene
	var explosion_scene = load("res://Particles/Explosion.tscn")
	if not explosion_scene:
		print("✗ ERROR: Could not load Explosion.tscn")
		return null
	
	var explosion = explosion_scene.instantiate()
	print("✓ Explosion scene loaded and instantiated")
	
	# Add explosion to parent
	parent.add_child(explosion)
	
	# Set the position AFTER adding to parent to account for parent's transform
	explosion.global_position = position
	
	# Set the explosion's z_index to be visible above other objects
	# Use a high positive z_index to ensure it appears on top
	explosion.z_index = 1000
	
	print("✓ Created explosion at position:", position)
	print("Explosion added to parent:", parent.name)
	print("Explosion z_index set to:", explosion.z_index)
	print("Explosion final global position after parent transform:", explosion.global_position)
	
	return explosion 
