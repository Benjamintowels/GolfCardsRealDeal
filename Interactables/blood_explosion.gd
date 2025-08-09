extends Node2D

# Basic red particle explosion to simulate blood on NPC/Player death

var particles: GPUParticles2D

func _ready() -> void:
	particles = get_node_or_null("GPUParticles2D")
	visible = false
	if particles:
		_setup_particles()

func _setup_particles() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 10.0
	pm.gravity = Vector3(0, 0, 0)
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 180.0
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	pm.color = Color(0.75, 0.0, 0.0, 1.0) # deep red
	particles.process_material = pm
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 28
	particles.emitting = false

func trigger() -> void:
	visible = true
	if particles:
		particles.emitting = true
	# Cleanup after a short delay
	var t := Timer.new()
	t.wait_time = 1.8
	t.one_shot = true
	t.timeout.connect(queue_free)
	add_child(t)
	t.start()
