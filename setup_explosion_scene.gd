extends Node2D

# Temporary script to set up the Explosion.tscn scene
# Run this once to create the proper explosion scene structure

func _ready():
	print("Setting up Explosion scene structure...")
	
	# Create ExplosionSprite
	var explosion_sprite = Sprite2D.new()
	explosion_sprite.name = "ExplosionSprite"
	explosion_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	# Load explosion texture
	var explosion_texture = load("res://Particles/Explosion.png")
	if explosion_texture:
		explosion_sprite.texture = explosion_texture
		print("✓ Explosion texture loaded")
	else:
		print("✗ ERROR: Could not load explosion texture")
	
	add_child(explosion_sprite)
	
	# Create ExplosionSound
	var explosion_sound = AudioStreamPlayer2D.new()
	explosion_sound.name = "ExplosionSound"
	
	# Load explosion sound
	var explosion_audio = load("res://Sounds/Explosion.mp3")
	if explosion_audio:
		explosion_sound.stream = explosion_audio
		explosion_sound.volume_db = 0.0
		print("✓ Explosion sound loaded")
	else:
		print("✗ ERROR: Could not load explosion sound")
	
	add_child(explosion_sound)
	
	# Create FireParticles
	var fire_particles = GPUParticles2D.new()
	fire_particles.name = "FireParticles"
	fire_particles.emitting = false
	fire_particles.amount = 15
	fire_particles.lifetime = 2.0
	fire_particles.one_shot = true
	fire_particles.explosiveness = 0.8
	
	# Load fire particle texture
	var fire_particle_texture = load("res://Particles/FireParticle.png")
	if fire_particle_texture:
		fire_particles.texture = fire_particle_texture
		print("✓ Fire particle texture loaded")
	else:
		print("✗ ERROR: Could not load fire particle texture")
	
	# Create particle material
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 20.0
	particle_material.particle_flag_disable_z = true
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.gravity = Vector3(0, 300, 0)
	particle_material.initial_velocity_min = 50.0
	particle_material.initial_velocity_max = 150.0
	particle_material.angular_velocity_min = -180.0
	particle_material.angular_velocity_max = 180.0
	particle_material.scale_min = 0.5
	particle_material.scale_max = 1.5
	particle_material.lifetime_randomness = 0.3
	
	# Create color ramp for fire particles
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.8, 0.0, 1.0))    # Bright yellow-orange
	gradient.add_point(0.3, Color(1.0, 0.5, 0.0, 0.8))    # Orange
	gradient.add_point(0.7, Color(0.8, 0.2, 0.0, 0.6))    # Dark orange-red
	gradient.add_point(1.0, Color(0.5, 0.0, 0.0, 0.0))    # Transparent red
	particle_material.color_ramp = gradient
	
	fire_particles.process_material = particle_material
	add_child(fire_particles)
	
	print("✓ Explosion scene structure created!")
	print("Now save this scene as Explosion.tscn in the Particles folder")
	print("Then remove this setup script and replace it with the Explosion.gd script") 