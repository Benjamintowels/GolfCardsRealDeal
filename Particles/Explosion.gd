extends Node2D

# Explosion effect that can be reused for various objects
# Handles scaling animation, sound effects, particle systems, and radius damage

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

# Explosion radius settings
const EXPLOSION_RADIUS: float = 150.0  # Radius of explosion effect in pixels
const EXPLOSION_DAMAGE: int = 50       # Base damage for GangMembers in radius
const RAGDOLL_DELAY: float = 0.1       # Delay before starting ragdoll animation

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
	
	# Apply explosion radius effects after a short delay
	call_deferred("_apply_explosion_radius_effects")
	
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

func _apply_explosion_radius_effects():
	"""Apply explosion effects to all GangMembers within the explosion radius"""
	print("=== APPLYING EXPLOSION RADIUS EFFECTS ===")
	print("Explosion position:", global_position)
	print("Explosion radius:", EXPLOSION_RADIUS)
	
	# Find all GangMembers in the scene
	var gang_members = _find_all_gang_members()
	print("Found", gang_members.size(), "GangMembers in scene")
	
	var affected_count = 0
	
	for gang_member in gang_members:
		if not is_instance_valid(gang_member):
			continue
		
		var distance = global_position.distance_to(gang_member.global_position)
		print("GangMember", gang_member.name, "distance:", distance)
		
		if distance <= EXPLOSION_RADIUS:
			print("✓ GangMember", gang_member.name, "is within explosion radius!")
			_affect_gang_member_with_explosion(gang_member, distance)
			affected_count += 1
		else:
			print("✗ GangMember", gang_member.name, "is outside explosion radius")
	
	print("=== EXPLOSION RADIUS EFFECTS COMPLETE ===")
	print("Affected", affected_count, "GangMembers")

func _find_all_gang_members() -> Array:
	"""Find all GangMember nodes in the scene"""
	var gang_members: Array = []
	
	# Method 1: Try to get from Entities system
	var course = _find_course_script()
	if course and course.has_node("Entities"):
		var entities = course.get_node("Entities")
		if entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if npc.get_script() and npc.get_script().resource_path.ends_with("GangMember.gd"):
					gang_members.append(npc)
			print("Found", gang_members.size(), "GangMembers via Entities system")
			return gang_members
	
	# Method 2: Search scene tree for GangMember nodes
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		if node.get_script() and node.get_script().resource_path.ends_with("GangMember.gd"):
			gang_members.append(node)
	
	print("Found", gang_members.size(), "GangMembers via scene tree search")
	return gang_members

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			return current_node
		current_node = current_node.get_parent()
	return null

func _affect_gang_member_with_explosion(gang_member: Node, distance: float):
	"""Apply explosion effects to a specific GangMember"""
	print("=== AFFECTING GANGMEMBER WITH EXPLOSION ===")
	print("GangMember:", gang_member.name)
	print("Distance from explosion:", distance)
	
	# Calculate damage based on distance (closer = more damage)
	var damage_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var damage = int(EXPLOSION_DAMAGE * damage_factor)
	
	print("Damage factor:", damage_factor)
	print("Calculated damage:", damage)
	
	# Apply damage to the GangMember
	if gang_member.has_method("take_damage"):
		gang_member.take_damage(damage)
		print("✓ Applied", damage, "damage to GangMember")
	else:
		print("✗ GangMember doesn't have take_damage method")
	
	# Start ragdoll animation after a short delay
	var ragdoll_timer = Timer.new()
	ragdoll_timer.wait_time = RAGDOLL_DELAY
	ragdoll_timer.one_shot = true
	ragdoll_timer.timeout.connect(func(): _start_gang_member_ragdoll(gang_member, distance))
	add_child(ragdoll_timer)
	ragdoll_timer.start()
	
	print("✓ Scheduled ragdoll animation for GangMember")

func _start_gang_member_ragdoll(gang_member: Node, distance: float):
	"""Start the ragdoll animation for a GangMember"""
	if not is_instance_valid(gang_member):
		print("✗ GangMember is no longer valid for ragdoll")
		return
	
	print("=== STARTING GANGMEMBER RAGDOLL ===")
	print("GangMember:", gang_member.name)
	
	# Calculate ragdoll force based on distance (closer = more force)
	var force_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var ragdoll_force = 300.0 * force_factor  # Base force of 300 pixels
	
	print("Force factor:", force_factor)
	print("Ragdoll force:", ragdoll_force)
	
	# Calculate direction from explosion to GangMember
	var direction = (gang_member.global_position - global_position).normalized()
	
	# Add some randomness to the direction
	var random_angle = randf_range(-0.3, 0.3)  # ±0.3 radians of randomness
	var randomized_direction = direction.rotated(random_angle)
	
	print("Direction from explosion:", direction)
	print("Randomized direction:", randomized_direction)
	
	# Start the ragdoll animation
	if gang_member.has_method("start_ragdoll_animation"):
		gang_member.start_ragdoll_animation(randomized_direction, ragdoll_force)
		print("✓ Started ragdoll animation via method")
	else:
		print("✗ GangMember doesn't have start_ragdoll_animation method")
		# Fallback: just kill the GangMember
		if gang_member.has_method("die"):
			gang_member.die()
			print("✓ Applied fallback death to GangMember")

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
