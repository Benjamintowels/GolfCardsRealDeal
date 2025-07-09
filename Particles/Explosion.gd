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

# Fire tile settings
const CELL_SIZE: int = 48              # Size of each tile in pixels
const CREATE_FIRE_TILE: bool = true    # Whether to create a fire tile at explosion position

func _ready():
	
	# Get references to nodes
	explosion_sprite = get_node_or_null("ExplosionSprite")
	explosion_sound = get_node_or_null("ExplosionSound")
	particle_system = get_node_or_null("FireParticles")
	
	# Start the explosion animation
	start_explosion_animation()
	
	# Apply explosion radius effects after a short delay
	call_deferred("_apply_explosion_radius_effects")

func start_explosion_animation():
	"""Start the explosion animation sequence"""
	
	# Play explosion sound
	if explosion_sound:
		explosion_sound.play()
	
	# Start particle system
	if particle_system:
		particle_system.emitting = true
	
	# Create tween for animation
	animation_tween = create_tween()
	animation_tween.set_parallel(true)
	
	# Scale up animation
	if explosion_sprite:
		# Start at small scale (but not zero so it's visible)
		explosion_sprite.scale = Vector2.ONE * 0.1
		explosion_sprite.modulate.a = 1.0
		
		# Scale up quickly
		animation_tween.tween_property(explosion_sprite, "scale", Vector2.ONE * MAX_SCALE, SCALE_UP_TIME)
		animation_tween.tween_callback(_on_scale_up_complete).set_delay(SCALE_UP_TIME)
		
		# Fade out over time
		animation_tween.tween_property(explosion_sprite, "modulate:a", 0.0, FADE_OUT_TIME).set_delay(SCALE_UP_TIME)
		# Add a callback to track fade out progress
		animation_tween.tween_callback(func(): print("Explosion fade out started")).set_delay(SCALE_UP_TIME)
		
	# Clean up after animation completes
	animation_tween.tween_callback(_on_explosion_complete).set_delay(EXPLOSION_DURATION)

func _apply_explosion_radius_effects():
	"""Apply explosion effects to all GangMembers and Player within the explosion radius"""
	
	# Find all GangMembers and Police in the scene
	var gang_members = _find_all_gang_members()
	var police_npcs = _find_all_police()
	
	# Find the player
	var player = _find_player()
	
	var affected_count = 0
	
	# Check GangMembers
	for gang_member in gang_members:
		if not is_instance_valid(gang_member):
			continue
		
		var distance = global_position.distance_to(gang_member.global_position)
		
		if distance <= EXPLOSION_RADIUS:
			_affect_gang_member_with_explosion(gang_member, distance)
			affected_count += 1
	
	# Check Police
	for police in police_npcs:
		if not is_instance_valid(police):
			continue
		
		var distance = global_position.distance_to(police.global_position)
		
		if distance <= EXPLOSION_RADIUS:
			_affect_police_with_explosion(police, distance)
			affected_count += 1
	
	# Check Player
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= EXPLOSION_RADIUS:
			_affect_player_with_explosion(player, distance)
			affected_count += 1
	
	# Create fire tile at explosion position if enabled
	if CREATE_FIRE_TILE:
		call_deferred("_create_fire_tile_at_explosion_position")

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
				# Add null check before calling get_script()
				if is_instance_valid(npc) and npc.get_script() and npc.get_script().resource_path.ends_with("GangMember.gd"):
					gang_members.append(npc)
			return gang_members
	
	# Method 2: Search scene tree for GangMember nodes
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		# Add null check before calling get_script()
		if is_instance_valid(node) and node.get_script() and node.get_script().resource_path.ends_with("GangMember.gd"):
			gang_members.append(node)
	
	return gang_members

func _find_all_police() -> Array:
	"""Find all Police nodes in the scene"""
	var police: Array = []
	
	# Method 1: Try to get from Entities system
	var course = _find_course_script()
	if course and course.has_node("Entities"):
		var entities = course.get_node("Entities")
		if entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				# Add null check before calling get_script()
				if is_instance_valid(npc) and npc.get_script() and npc.get_script().resource_path.ends_with("police.gd"):
					police.append(npc)
			return police
	
	# Method 2: Search scene tree for Police nodes
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		# Add null check before calling get_script()
		if is_instance_valid(node) and node.get_script() and node.get_script().resource_path.ends_with("police.gd"):
			police.append(node)
	
	return police

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		# Add null check before calling get_script()
		if is_instance_valid(current_node) and current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			return current_node
		current_node = current_node.get_parent()
	return null

func _find_player() -> Node:
	"""Find the player in the scene"""
	# Method 1: Try to get from course method
	var course = _find_course_script()
	if course and course.has_method("get_player_reference"):
		var player = course.get_player_reference()
		if player:
			return player
	
	# Method 2: Try to find player in course
	if course and course.has_node("Player"):
		var player = course.get_node("Player")
		if player:
			return player
	
	# Method 3: Search scene tree for player
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		# Add null check before accessing node properties
		if is_instance_valid(node) and node.name == "Player":
			return node
	
	return null

func _affect_gang_member_with_explosion(gang_member: Node, distance: float):
	"""Apply explosion effects to a specific GangMember"""
	
	# Calculate damage based on distance (closer = more damage)
	var damage_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var damage = int(EXPLOSION_DAMAGE * damage_factor)
	
	# Apply damage to the GangMember
	if gang_member.has_method("take_damage"):
		gang_member.take_damage(damage)
	
	# Start ragdoll animation after a short delay
	var ragdoll_timer = Timer.new()
	ragdoll_timer.wait_time = RAGDOLL_DELAY
	ragdoll_timer.one_shot = true
	ragdoll_timer.timeout.connect(func(): _start_gang_member_ragdoll(gang_member, distance))
	add_child(ragdoll_timer)
	ragdoll_timer.start()

func _affect_police_with_explosion(police: Node, distance: float):
	"""Apply explosion effects to a specific Police"""
	
	# Calculate damage based on distance (closer = more damage)
	var damage_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var damage = int(EXPLOSION_DAMAGE * damage_factor)
	
	# Apply damage to the Police
	if police.has_method("take_damage"):
		police.take_damage(damage)
	
	# Start ragdoll animation after a short delay
	var ragdoll_timer = Timer.new()
	ragdoll_timer.wait_time = RAGDOLL_DELAY
	ragdoll_timer.one_shot = true
	ragdoll_timer.timeout.connect(func(): _start_police_ragdoll(police, distance))
	add_child(ragdoll_timer)
	ragdoll_timer.start()

func _start_gang_member_ragdoll(gang_member: Node, distance: float):
	"""Start the ragdoll animation for a GangMember"""
	if not is_instance_valid(gang_member):
		return
	
	# Calculate ragdoll force based on distance (closer = more force)
	var force_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var ragdoll_force = 300.0 * force_factor  # Base force of 300 pixels
	
	# Calculate direction from explosion to GangMember
	var direction = (gang_member.global_position - global_position).normalized()
	
	# Add some randomness to the direction
	var random_angle = randf_range(-0.3, 0.3)  # ±0.3 radians of randomness
	var randomized_direction = direction.rotated(random_angle)
	
	# Start the ragdoll animation
	if gang_member.has_method("start_ragdoll_animation"):
		gang_member.start_ragdoll_animation(randomized_direction, ragdoll_force)
	else:
		# Fallback: just kill the GangMember
		if gang_member.has_method("die"):
			gang_member.die()

func _start_police_ragdoll(police: Node, distance: float):
	"""Start the ragdoll animation for a Police"""
	if not is_instance_valid(police):
		return
	
	# Calculate ragdoll force based on distance (closer = more force)
	var force_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var ragdoll_force = 300.0 * force_factor  # Base force of 300 pixels
	
	# Calculate direction from explosion to Police
	var direction = (police.global_position - global_position).normalized()
	
	# Add some randomness to the direction
	var random_angle = randf_range(-0.3, 0.3)  # ±0.3 radians of randomness
	var randomized_direction = direction.rotated(random_angle)
	
	# Start the ragdoll animation
	if police.has_method("start_ragdoll_animation"):
		police.start_ragdoll_animation(randomized_direction, ragdoll_force)
	else:
		# Fallback: just kill the Police
		if police.has_method("die"):
			police.die()

func _on_scale_up_complete():
	"""Called when the explosion sprite has finished scaling up"""

func _on_explosion_complete():
	"""Called when the entire explosion animation is complete"""
	
	# Stop particle system
	if particle_system:
		particle_system.emitting = false
	
	# Remove the explosion from the scene
	queue_free()

func _affect_player_with_explosion(player: Node, distance: float):
	"""Apply explosion effects to the player"""
	
	# Calculate damage based on distance (closer = more damage)
	var damage_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var damage = int(EXPLOSION_DAMAGE * damage_factor)
	
	# Check if this damage will kill the player
	var will_kill = false
	if player.has_method("take_damage") and "current_health" in player:
		will_kill = damage >= player.current_health
	
	# Apply damage to the player
	if player.has_method("take_damage"):
		player.take_damage(damage)

func _start_player_ragdoll(player: Node, distance: float):
	"""Start the ragdoll animation for the player"""
	if not is_instance_valid(player):
		return
	
	# Calculate ragdoll force based on distance (closer = more force)
	# Use higher force for players since it only affects visual animation now
	var force_factor = 1.0 - (distance / EXPLOSION_RADIUS)
	var ragdoll_force = 200.0 * force_factor  # Increased base force for players (was 100.0)
	
	# Calculate direction from explosion to player
	var direction = (player.global_position - global_position).normalized()
	
	# Add some randomness to the direction
	var random_angle = randf_range(-0.3, 0.3)  # ±0.3 radians of randomness
	var randomized_direction = direction.rotated(random_angle)
	
	# Start the ragdoll animation
	if player.has_method("start_ragdoll_animation"):
		player.start_ragdoll_animation(randomized_direction, ragdoll_force)
	else:
		# Fallback: just apply damage without ragdoll
		print("✓ Applied fallback damage to player")

# Static method to create explosion at a specific position
static func create_explosion_at_position(position: Vector2, parent: Node) -> Node2D:
	"""Create and instance an explosion at the specified position"""
	
	# Load and instance the explosion scene
	var explosion_scene = load("res://Particles/Explosion.tscn")
	if not explosion_scene:
		return null
	
	var explosion = explosion_scene.instantiate()
	
	# Add explosion to parent
	parent.add_child(explosion)
	
	# Set the position AFTER adding to parent to account for parent's transform
	explosion.global_position = position
	
	# Set the explosion's z_index to be visible above other objects
	# Use a high positive z_index to ensure it appears on top
	explosion.z_index = 1000
	
	# Trigger fire tile creation for explosions created via static method
	if explosion.CREATE_FIRE_TILE:
		explosion.call_deferred("_create_fire_tile_at_explosion_position")
	
	return explosion

func _create_fire_tile_at_explosion_position():
	"""Create a fire tile at the explosion position"""
	
	# Calculate the tile position from the explosion's world position
	var tile_pos = Vector2i(floor(global_position.x / CELL_SIZE), floor(global_position.y / CELL_SIZE))
	
	# Check if this tile is already on fire or has been scorched
	if _is_tile_on_fire_or_scorched(tile_pos):
		print("Tile already on fire/scorched at", tile_pos, "- skipping fire tile creation")
		return
	
	# Check if this is a grass tile that can catch fire
	var tile_type = _get_tile_type(tile_pos)
	if not _is_grass_tile(tile_type):
		print("Not a grass tile at", tile_pos, "(", tile_type, ") - skipping fire tile creation")
		return
	
	# Create fire tile
	print("Creating fire tile at explosion position:", tile_pos, "on tile type:", tile_type)
	
	var fire_tile_scene = preload("res://Particles/FireTile.tscn")
	var fire_tile = fire_tile_scene.instantiate()
	
	# Set the tile position
	fire_tile.set_tile_position(tile_pos)
	
	# Find the camera container to add the fire tile to (so it moves with the world)
	var camera_container = _find_camera_container()
	if not camera_container:
		print("Could not find camera container - adding fire tile to current scene")
		get_tree().current_scene.add_child(fire_tile)
	else:
		# Add to camera container so it moves with the world
		camera_container.add_child(fire_tile)
	
	# Position the fire tile at the tile center (relative to its parent)
	var tile_center = Vector2(tile_pos.x * CELL_SIZE + CELL_SIZE / 2, tile_pos.y * CELL_SIZE + CELL_SIZE / 2)
	if camera_container:
		# If added to camera container, position relative to camera container
		fire_tile.position = tile_center
	else:
		# If added to current scene, use global position
		fire_tile.global_position = tile_center
	
	# Add to fire tiles group for easy management
	fire_tile.add_to_group("fire_tiles")
	
	# Connect to completion signal
	fire_tile.fire_tile_completed.connect(_on_fire_tile_completed)
	
	print("Fire tile created successfully at:", tile_pos, "z_index:", fire_tile.z_index)

func _is_tile_on_fire_or_scorched(tile_pos: Vector2i) -> bool:
	"""Check if a tile is currently on fire or has been scorched"""
	# Check for existing fire tiles in the scene
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		# Add null check before accessing fire tile properties
		if is_instance_valid(fire_tile) and fire_tile.get_tile_position() == tile_pos:
			return true
	
	# Check if tile is scorched via map manager
	var map_manager = _find_map_manager()
	if map_manager and map_manager.has_method("is_tile_scorched"):
		return map_manager.is_tile_scorched(tile_pos.x, tile_pos.y)
	
	return false

func _is_grass_tile(tile_type: String) -> bool:
	"""Check if a tile type is considered grass (can catch fire)"""
	return tile_type in ["F", "R", "Base", "G"]  # Fairway, Rough, Base grass, Green (excludes Scorched)

func _get_tile_type(tile_pos: Vector2i) -> String:
	"""Get the tile type at the given position"""
	var map_manager = _find_map_manager()
	if map_manager and map_manager.has_method("get_tile_type"):
		return map_manager.get_tile_type(tile_pos.x, tile_pos.y)
	return "Unknown"

func _find_map_manager() -> Node:
	"""Find the map manager in the scene"""
	# Method 1: Try to get from course
	var course = _find_course_script()
	if course and course.has_node("MapManager"):
		return course.get_node("MapManager")
	
	# Method 2: Search scene tree for MapManager
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		# Add null check before calling get_script()
		if is_instance_valid(node) and node.get_script() and node.get_script().resource_path.ends_with("MapManager.gd"):
			return node
	
	return null

func _find_camera_container() -> Node:
	"""Find the camera container in the scene"""
	# Method 1: Try to get from course
	var course = _find_course_script()
	if course and course.has_node("CameraContainer"):
		return course.get_node("CameraContainer")
	
	# Method 2: Search scene tree for CameraContainer
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		# Add null check before accessing node properties
		if is_instance_valid(node) and node.name == "CameraContainer":
			return node
	
	return null

func _on_fire_tile_completed(tile_pos: Vector2i) -> void:
	"""Handle when a fire tile transitions to scorched earth"""
	# The fire tile will handle its own visual transition
	# We just need to notify the map manager that this tile is now scorched
	var map_manager = _find_map_manager()
	if map_manager and map_manager.has_method("set_tile_scorched"):
		map_manager.set_tile_scorched(tile_pos.x, tile_pos.y)
		print("Tile marked as scorched at:", tile_pos) 
