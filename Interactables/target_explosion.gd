extends Node2D

# TargetExplosion - Basic particle explosion effect with rainbow colors and lots of particles
# Similar to CrateExplosion but without reward placement

# Particle system for rainbow explosion
var particles: GPUParticles2D

# Rainbow colors for particles
var rainbow_colors = [
	Color(1.0, 0.0, 0.0, 1.0),  # Red
	Color(1.0, 0.5, 0.0, 1.0),  # Orange
	Color(1.0, 1.0, 0.0, 1.0),  # Yellow
	Color(0.0, 1.0, 0.0, 1.0),  # Green
	Color(0.0, 0.0, 1.0, 1.0),  # Blue
	Color(0.5, 0.0, 1.0, 1.0),  # Indigo
	Color(1.0, 0.0, 1.0, 1.0)   # Violet
]

func _ready():
	# Get reference to particle system
	particles = get_node_or_null("GPUParticles2D")
	
	# Initially hide the explosion
	visible = false
	
	# Set up particle system if it exists
	if particles:
		_setup_rainbow_particle_system()

func _setup_rainbow_particle_system():
	"""Set up the rainbow particle explosion effect"""
	if not particles:
		return
	
	# Create a particle process material for the rainbow explosion
	var process_material = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 15.0
	process_material.gravity = Vector3(0, 0, 0)  # No gravity for explosion
	process_material.initial_velocity_min = 80.0
	process_material.initial_velocity_max = 200.0
	process_material.scale_min = 3.0
	process_material.scale_max = 6.0
	
	# Set up rainbow color gradient
	var gradient = Gradient.new()
	for i in range(rainbow_colors.size()):
		var t = float(i) / (rainbow_colors.size() - 1)
		gradient.add_point(t, rainbow_colors[i])
	
	process_material.color_ramp = gradient
	
	# Apply the material to the particle system
	particles.process_material = process_material
	
	# Configure particle system properties
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 30  # More particles for rainbow effect

func trigger_explosion():
	"""Trigger the target explosion effect"""
	print("=== TARGET EXPLOSION TRIGGERED ===")
	
	# Make the explosion visible
	visible = true
	
	# Start particle emission
	if particles:
		particles.emitting = true
		print("✓ Rainbow particle explosion started")
	
	# Set up cleanup timer
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 3.0  # Clean up after 3 seconds
	cleanup_timer.one_shot = true
	cleanup_timer.connect("timeout", _cleanup_explosion)
	add_child(cleanup_timer)
	cleanup_timer.start()

func _cleanup_explosion():
	"""Clean up the explosion after it's finished"""
	print("=== CLEANING UP TARGET EXPLOSION ===")
	
	# Stop particles
	if particles:
		particles.emitting = false
	
	# Hide the explosion
	visible = false
	
	# Remove this node after a delay
	var final_cleanup = Timer.new()
	final_cleanup.wait_time = 1.0
	final_cleanup.one_shot = true
	final_cleanup.connect("timeout", queue_free)
	add_child(final_cleanup)
	final_cleanup.start()
