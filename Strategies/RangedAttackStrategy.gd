extends Node
class_name RangedAttackStrategy

# Constants
const PI = 3.14159265359

# use for attacks with a range of 4+ tiles that don't move the player. IE: meteor, attackdog

# References needed for ranged attacks
var card_effect_handler: Node
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary
var player_node: Node2D

# Meteor attack properties
var meteor_damage := 35

# Attack dog properties  
var ash_dog_damage := 50

# FiragaCard attack properties
var firaga_damage := 50

# IceSpearCard attack properties
var ice_spear_damage := 30

# Signals
signal npc_attacked(npc: Node, damage: int)
signal ash_dog_attack_performed
signal attack_completed

func setup(
	card_effect_handler_ref: Node,
	grid_tiles_ref: Array,
	grid_size_ref: Vector2i,
	cell_size_ref: int,
	obstacle_map_ref: Dictionary,
	player_grid_pos_ref: Vector2i,
	player_stats_ref: Dictionary,
	player_node_ref: Node2D
):
	card_effect_handler = card_effect_handler_ref
	grid_tiles = grid_tiles_ref
	grid_size = grid_size_ref
	cell_size = cell_size_ref
	obstacle_map = obstacle_map_ref
	player_grid_pos = player_grid_pos_ref
	player_stats = player_stats_ref
	player_node = player_node_ref

func perform_meteor_attack(target_pos: Vector2i) -> void:
	"""Perform Meteor AOE attack at the specified position"""
	print("=== PERFORMING METEOR AOE ATTACK ===")
	print("Target position:", target_pos)
	
	# Calculate the 3x2 area positions
	var aoe_positions = []
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var pos = target_pos + Vector2i(x_offset, y_offset)
			aoe_positions.append(pos)
	
	print("AOE positions:", aoe_positions)
	
	# Create and animate the meteor
	create_and_animate_meteor(target_pos, aoe_positions)

func create_and_animate_meteor(target_pos: Vector2i, aoe_positions: Array) -> void:
	"""Create and animate the meteor falling to the target position"""
	print("Creating meteor at target position:", target_pos)
	
	# Load the meteor scene
	var meteor_scene = load("res://Particles/Meteor.tscn")
	if not meteor_scene:
		print("✗ ERROR: Could not load Meteor.tscn")
		emit_signal("attack_completed")
		return
	
	# Create meteor instance
	var meteor = meteor_scene.instantiate()
	if not meteor:
		print("✗ ERROR: Could not instantiate meteor")
		emit_signal("attack_completed")
		return
	
	# Add meteor to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(meteor)
	else:
		add_child(meteor)
	
	# Calculate world position for the meteor target (center of the 3x2 area)
	var world_target_x = (target_pos.x + 1.5) * cell_size  # Center of 3-tile width
	var world_target_y = (target_pos.y + 0.5) * cell_size  # Center of 2-tile height
	var world_target_pos = Vector2(world_target_x, world_target_y)
	
	# Add camera container offset to get correct world position
	if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_node("CameraContainer"):
		var camera_container = card_effect_handler.course.get_node("CameraContainer")
		world_target_pos += camera_container.global_position
		print("✓ Added camera container offset:", camera_container.global_position, "to meteor target position")
	else:
		print("⚠ No camera container found for meteor positioning")
	
	# Position meteor much further up and to the left for dramatic effect
	var meteor_start_pos = Vector2(world_target_x - 300, -400)  # Start much higher and to the left
	# Add camera container offset to meteor start position
	if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_node("CameraContainer"):
		var camera_container = card_effect_handler.course.get_node("CameraContainer")
		meteor_start_pos += camera_container.global_position
		print("✓ Added camera container offset to meteor start position")
	meteor.global_position = meteor_start_pos
	
	# Set initial opacity to 0 and large scale for the meteor
	var meteor_sprite = meteor.get_node_or_null("MeteorSprite")
	if meteor_sprite:
		meteor_sprite.modulate = Color(1, 1, 1, 0)  # Start with 0 opacity
		meteor_sprite.scale = Vector2(3.0, 3.0)  # Start 3x larger
		print("✓ Set meteor to 0 opacity initial state and 3x scale")
	
	# Focus camera on meteor during animation
	focus_camera_on_meteor(meteor, world_target_pos)
	
	# Play meteor start sound
	var meteor_start_sound = meteor.get_node_or_null("MeteorStart")
	if meteor_start_sound:
		meteor_start_sound.play()
	
	# Animate meteor falling
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	
	# Meteor falls to target over 1.5 seconds
	tween.tween_property(meteor, "global_position", world_target_pos, 1.5)
	
	# Animate scale from 3x to 1x over the fall duration
	if meteor_sprite:
		tween.parallel().tween_property(meteor_sprite, "scale", Vector2(1.0, 1.0), 1.5)
	
	# Animate opacity fade in from 0 to 1
	if meteor_sprite:
		# Fade in from 0 to full opacity over 1.5 seconds
		tween.parallel().tween_property(meteor_sprite, "modulate:a", 1.0, 1.5)
	
	# Update YSort during meteor fall animation
	tween.parallel().tween_method(func(progress: float):
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
	, 0.0, 1.0, 1.5)
	tween.tween_callback(func():
		# Meteor has landed - update YSort for final position
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
		
		# Play crash and land sounds
		var meteor_crash_sound = meteor.get_node_or_null("MeteorCrash")
		var meteor_land_sound = meteor.get_node_or_null("MeteorLand")
		
		if meteor_crash_sound:
			meteor_crash_sound.play()
		if meteor_land_sound:
			meteor_land_sound.play()
		
		# Start crater animation sequence
		start_crater_animation(meteor, aoe_positions)
	)

func start_crater_animation(meteor: Node, aoe_positions: Array) -> void:
	"""Start the crater animation sequence"""
	print("Starting crater animation for AOE positions:", aoe_positions)
	
	# Get the crater sprites
	var meteor_sprite = meteor.get_node_or_null("MeteorSprite")
	var crater_explosion1 = meteor.get_node_or_null("CraterExplosion1")
	var crater_explosion2 = meteor.get_node_or_null("CraterExplosion2")
	var crater_sprite = meteor.get_node_or_null("CraterSprite")
	
	if not meteor_sprite or not crater_explosion1 or not crater_explosion2 or not crater_sprite:
		print("✗ ERROR: Missing crater sprites in meteor scene")
		complete_meteor_attack(meteor, aoe_positions)
		return
	
	# Stop meteor tracking and start crash sequence
	stop_meteor_camera_tracking(meteor)
	start_crash_camera_sequence(meteor)
	
	# Hide meteor sprite and show first explosion
	meteor_sprite.visible = false
	crater_explosion1.visible = true
	
	# Animate through the crater sequence
	var tween = create_tween()
	
	# Show first explosion for 0.3 seconds and apply damage immediately
	tween.tween_callback(func():
		# Apply damage when the explosion happens
		apply_meteor_damage(aoe_positions)
		
		crater_explosion1.visible = false
		crater_explosion2.visible = true
		# Update YSort for explosion sprites
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
	).set_delay(0.3)
	
	# Show second explosion for 0.3 seconds
	tween.tween_callback(func():
		crater_explosion2.visible = false
		crater_sprite.visible = true
		# Update YSort for crater sprite
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
	).set_delay(0.3)
	
	# Show final crater for 0.5 seconds then complete attack
	tween.tween_callback(func():
		# Create persistent crater before completing attack
		create_persistent_crater(meteor, aoe_positions)
		complete_meteor_attack(meteor, aoe_positions)
	).set_delay(0.5)

func apply_meteor_damage(aoe_positions: Array) -> int:
	"""Apply meteor damage to NPCs and destructible objects in the AOE area and return total damage dealt"""
	print("Applying meteor damage for AOE positions:", aoe_positions)
	
	var total_damage_dealt = 0
	
	# Deal damage to all NPCs and destructible objects in the AOE area
	for pos in aoe_positions:
		# First check for NPCs
		var npc = get_npc_at_position(pos)
		if npc:
			print("Dealing meteor damage to NPC at position:", pos)
			
			# Check if NPC is dead
			var is_dead = false
			if npc.has_method("get_is_dead"):
				is_dead = npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_dead = npc.is_dead()
			elif "is_dead" in npc:
				is_dead = npc.is_dead
			
			if not is_dead:
				# Deal damage to the NPC
				if npc.has_method("take_damage"):
					npc.take_damage(meteor_damage)
					total_damage_dealt += meteor_damage
					print("Dealt", meteor_damage, "damage to NPC:", npc.name)
				else:
					print("NPC does not have take_damage method:", npc.name)
			else:
				print("NPC is already dead, skipping damage:", npc.name)
		
		# Then check for destructible objects
		var destructible = get_destructible_at_position(pos)
		if destructible:
			print("Dealing meteor damage to destructible object at position:", pos)
			
			# Check if destructible is already destroyed
			var is_destroyed = false
			if destructible.has_method("get_is_destroyed"):
				is_destroyed = destructible.get_is_destroyed()
			elif "is_destroyed" in destructible:
				is_destroyed = destructible.is_destroyed
			
			if not is_destroyed:
				# Deal damage to the destructible object
				if destructible.has_method("take_damage"):
					# Check if this is a Tree and pass the attack type
					if destructible.get_script() and destructible.get_script().resource_path.ends_with("Tree.gd"):
						destructible.take_damage(meteor_damage, "meteor")
					else:
						destructible.take_damage(meteor_damage)
					total_damage_dealt += meteor_damage
					print("Dealt", meteor_damage, "damage to destructible object:", destructible.name)
				else:
					print("Destructible object does not have take_damage method:", destructible.name)
			else:
				print("Destructible object is already destroyed, skipping damage:", destructible.name)
	
	print("Meteor damage applied - total damage dealt:", total_damage_dealt)
	
	# Emit signal for damage dealt
	emit_signal("npc_attacked", null, total_damage_dealt)
	
	return total_damage_dealt

func complete_meteor_attack(meteor: Node, aoe_positions: Array) -> void:
	"""Complete the meteor attack sequence (damage already applied during explosion)"""
	print("Completing meteor attack sequence for AOE positions:", aoe_positions)
	
	# Camera return is now handled by the crash sequence
	# Clean up meteor from scene after a short delay
	call_deferred("_cleanup_meteor", meteor)
	
	# Emit signal for attack completion
	emit_signal("attack_completed")

func _cleanup_meteor(meteor: Node):
	"""Clean up the specific meteor from the scene after the attack is complete"""
	if is_instance_valid(meteor):
		meteor.queue_free()
		print("Cleaned up meteor from scene")

func focus_camera_on_meteor(meteor: Node, target_pos: Vector2) -> void:
	"""Focus camera on the meteor during its animation and return to player when done"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for camera focus")
		return
	
	var course = card_effect_handler.course
	if not course.has_method("create_camera_tween") or not course.has_method("transition_camera_to_player"):
		print("✗ ERROR: Course missing camera methods")
		return
	
	print("=== FOCUSING CAMERA ON METEOR ===")
	
	# Store player position for return
	var player_pos = Vector2.ZERO
	if course.player_manager and course.player_manager.get_player_node():
		var sprite = course.player_manager.get_player_node().get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(48, 48)
		player_pos = course.player_manager.get_player_node().global_position + player_size / 2
	
	# Store references for meteor tracking
	meteor.set_meta("camera_return_to_player", true)
	meteor.set_meta("player_position", player_pos)
	meteor.set_meta("course_reference", course)
	meteor.set_meta("target_position", target_pos)
	
	# Store current zoom to restore later
	if course.camera and course.camera.has_method("set_zoom_level"):
		if not meteor.has_meta("pre_meteor_zoom"):
			meteor.set_meta("pre_meteor_zoom", course.camera.get_current_zoom())
	
	# Start meteor tracking immediately
	start_meteor_camera_tracking(meteor)

func start_meteor_camera_tracking(meteor: Node) -> void:
	"""Start tracking the meteor with the camera during its fall animation"""
	if not meteor.has_meta("course_reference"):
		print("✗ ERROR: Meteor missing course reference for tracking")
		return
	
	var course = meteor.get_meta("course_reference")
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for meteor tracking")
		return
	
	print("=== STARTING METEOR CAMERA TRACKING ===")
	
	# Immediately focus camera on the meteor's current position (in the air)
	var meteor_start_pos = meteor.global_position
	course.create_camera_tween(meteor_start_pos, 0.5)
	print("✓ Camera focused on meteor in air at:", meteor_start_pos)
	
	# Zoom in for close-up meteor tracking (but respect range display zoom if it exists)
	if course.camera and course.camera.has_method("set_zoom_level"):
		var tracking_zoom = 1.2  # Zoom in to 120% for close tracking
		
		# Check if we're currently showing meteor range (zoomed out)
		if course.has_meta("pre_meteor_zoom"):
			# We're in range display mode, use a more moderate zoom for tracking
			tracking_zoom = 0.8  # Keep some zoom out for better meteor visibility
			print("✓ Using moderate zoom for meteor tracking (range display mode):", tracking_zoom)
		else:
			# Normal meteor tracking zoom
			print("✓ Camera zoomed in for meteor tracking to", tracking_zoom)
		
		course.camera.set_zoom_level(tracking_zoom)
	
	# Set up continuous tracking during meteor fall
	meteor.set_meta("is_being_tracked", true)
	meteor.set_meta("last_tracked_position", meteor.global_position)
	
	# Start a timer to continuously update camera position
	var tracking_timer = get_tree().create_timer(0.1)  # Update every 0.1 seconds
	tracking_timer.timeout.connect(func():
		update_meteor_camera_tracking(meteor)
	)
	
	# Store the timer reference for cleanup
	meteor.set_meta("tracking_timer", tracking_timer)

func update_meteor_camera_tracking(meteor: Node) -> void:
	"""Update camera tracking for the meteor during its fall animation"""
	if not is_instance_valid(meteor) or not meteor.has_meta("is_being_tracked") or not meteor.get_meta("is_being_tracked"):
		return
	
	var last_pos = meteor.get_meta("last_tracked_position", Vector2.ZERO)
	var current_pos = meteor.global_position
	
	# Only update camera if meteor has moved significantly
	if current_pos.distance_to(last_pos) > 5.0:  # 5 pixel threshold
		if meteor.has_meta("course_reference"):
			var course = meteor.get_meta("course_reference")
			if course and is_instance_valid(course) and course.has_method("create_camera_tween"):
				# Use a very short tween for smooth following
				course.create_camera_tween(current_pos, 0.1)
		
		# Update last tracked position
		meteor.set_meta("last_tracked_position", current_pos)
	
	# Continue tracking if meteor is still being tracked
	if meteor.has_meta("is_being_tracked") and meteor.get_meta("is_being_tracked"):
		var tracking_timer = get_tree().create_timer(0.1)
		tracking_timer.timeout.connect(func():
			update_meteor_camera_tracking(meteor)
		)
		meteor.set_meta("tracking_timer", tracking_timer)

func stop_meteor_camera_tracking(meteor: Node) -> void:
	"""Stop tracking the meteor and clean up tracking resources"""
	if not meteor.has_meta("is_being_tracked"):
		return
	
	meteor.set_meta("is_being_tracked", false)
	
	# Clean up tracking timer if it exists
	if meteor.has_meta("tracking_timer"):
		var timer = meteor.get_meta("tracking_timer")
		if timer and is_instance_valid(timer):
			# Timer will be automatically cleaned up when it times out
			# No need to manually disconnect signals in Godot 4
			pass
		meteor.remove_meta("tracking_timer")
	
	# Clean up tracking metadata
	meteor.remove_meta("last_tracked_position")
	
	print("✓ Stopped meteor camera tracking")

func start_crash_camera_sequence(meteor: Node) -> void:
	"""Start the camera sequence for the meteor crash - zoom out and return to player"""
	if not meteor.has_meta("course_reference"):
		print("✗ ERROR: Meteor missing course reference for crash sequence")
		return
	
	var course = meteor.get_meta("course_reference")
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for crash sequence")
		return
	
	print("=== STARTING METEOR CRASH CAMERA SEQUENCE ===")
	
	# Get target position for crash focus
	var target_pos = meteor.get_meta("target_position", meteor.global_position)
	
	# Focus camera on crash position
	course.create_camera_tween(target_pos, 0.5)
	print("✓ Camera focused on crash position")
	
	# Start smooth zoom out effect
	if course.camera and course.camera.has_method("set_zoom_level"):
		var crash_zoom = 0.6  # Zoom out to 60% for dramatic crash effect
		
		# Check if we're coming from range display mode
		if course.has_meta("pre_meteor_zoom"):
			# We're already zoomed out for range display, use a more dramatic crash zoom
			crash_zoom = 0.4  # Even more zoom out for dramatic effect
			print("✓ Camera zoomed out for dramatic crash effect (from range display):", crash_zoom)
		else:
			# Normal crash zoom
			print("✓ Camera zoomed out for crash effect to", crash_zoom)
		
		course.camera.set_zoom_level(crash_zoom)
	
	# Set up delayed return to player
	var return_timer = get_tree().create_timer(1.5)  # Wait 1.5 seconds after crash starts
	return_timer.timeout.connect(func():
		# Capture necessary data before meteor might be cleaned up
		if is_instance_valid(meteor):
			return_camera_to_player(meteor)
		else:
			# Fallback: return camera to player without meteor reference
			_fallback_return_camera_to_player(course)
	)

func create_persistent_crater(meteor: Node, aoe_positions: Array) -> void:
	"""Create a persistent crater that stays in the scene after the meteor is cleaned up"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for persistent crater")
		return
	
	var course = card_effect_handler.course
	
	# Get the crater sprite from the meteor
	var crater_sprite = meteor.get_node_or_null("CraterSprite")
	if not crater_sprite:
		print("✗ ERROR: No crater sprite found in meteor")
		return
	
	# Create a new persistent crater node
	var persistent_crater = Node2D.new()
	persistent_crater.name = "PersistentCrater"
	
	# Copy the crater sprite to the persistent crater
	var new_crater_sprite = Sprite2D.new()
	new_crater_sprite.texture = crater_sprite.texture
	new_crater_sprite.position = crater_sprite.position
	new_crater_sprite.scale = crater_sprite.scale
	new_crater_sprite.modulate = crater_sprite.modulate
	new_crater_sprite.visible = true
	new_crater_sprite.z_index = crater_sprite.z_index
	
	# Add the crater sprite to the persistent crater
	persistent_crater.add_child(new_crater_sprite)
	
	# Position the persistent crater at the meteor's position
	persistent_crater.global_position = meteor.global_position
	
	# Add to groups for YSort system
	persistent_crater.add_to_group("craters")
	persistent_crater.add_to_group("ysort_objects")
	
	# Add the persistent crater to the course
	course.add_child(persistent_crater)
	
	# Update YSort for the persistent crater
	if persistent_crater.has_method("update_ysort"):
		persistent_crater.update_ysort()
	else:
		# Add YSort method to persistent crater
		persistent_crater.set_script(load("res://Particles/meteor.gd"))
		persistent_crater.update_ysort()
	
	print("✓ Created persistent crater at position:", persistent_crater.global_position)
	print("✓ Crater added to course and YSort system")
	
	# Store crater reference for potential cleanup later
	if not course.has_meta("meteor_craters"):
		course.set_meta("meteor_craters", [])
	
	var craters = course.get_meta("meteor_craters")
	craters.append(persistent_crater)
	course.set_meta("meteor_craters", craters)

func cleanup_all_meteor_craters() -> void:
	"""Clean up all persistent meteor craters from the scene"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for crater cleanup")
		return
	
	var course = card_effect_handler.course
	
	if not course.has_meta("meteor_craters"):
		print("✓ No meteor craters to clean up")
		return
	
	var craters = course.get_meta("meteor_craters")
	var craters_cleaned = 0
	
	for crater in craters:
		if is_instance_valid(crater):
			crater.queue_free()
			craters_cleaned += 1
	
	# Clear the craters list
	course.set_meta("meteor_craters", [])
	
	print("✓ Cleaned up", craters_cleaned, "meteor craters")

func return_camera_to_player(meteor: Node) -> void:
	"""Return camera to player after meteor attack completes"""
	# Check if meteor is valid first
	if not meteor or not is_instance_valid(meteor):
		print("✗ ERROR: Meteor is null or invalid for camera return")
		return
	
	if not meteor.has_meta("camera_return_to_player") or not meteor.has_meta("course_reference"):
		print("✗ ERROR: Meteor missing camera return metadata")
		return
	
	var course = meteor.get_meta("course_reference")
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for camera return")
		return
	
	print("=== RETURNING CAMERA TO PLAYER ===")
	
	# Get player position
	var player_pos = meteor.get_meta("player_position", Vector2.ZERO)
	
	# Smoothly tween camera back to player
	if course.has_method("create_camera_tween"):
		course.create_camera_tween(player_pos, 1.5)
		print("✓ Camera tweening back to player")
	
	# Restore zoom to previous level with a smooth tween
	if course.camera and course.camera.has_method("set_zoom_level"):
		if meteor.has_meta("pre_meteor_zoom"):
			var pre_zoom = meteor.get_meta("pre_meteor_zoom")
			# Create a smooth zoom tween back to original level
			var zoom_tween = get_tree().create_tween()
			zoom_tween.set_trans(Tween.TRANS_SINE)
			zoom_tween.set_ease(Tween.EASE_IN_OUT)
			zoom_tween.tween_method(func(zoom_level: float):
				course.camera.set_zoom_level(zoom_level)
			, course.camera.get_current_zoom(), pre_zoom, 1.5)
			print("✓ Camera zoom smoothly restored to", pre_zoom)

func _fallback_return_camera_to_player(course: Node) -> void:
	"""Fallback function to return camera to player when meteor is no longer valid"""
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for fallback camera return")
		return
	
	print("=== FALLBACK RETURNING CAMERA TO PLAYER ===")
	
	# Get player position from course
	var player_pos = Vector2.ZERO
	if course.player_manager and course.player_manager.get_player_node():
		var sprite = course.player_manager.get_player_node().get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(48, 48)
		player_pos = course.player_manager.get_player_node().global_position + player_size / 2
	
	# Smoothly tween camera back to player
	if course.has_method("create_camera_tween"):
		course.create_camera_tween(player_pos, 1.5)
		print("✓ Camera tweening back to player (fallback)")
	
	# Restore zoom to default level
	if course.camera and course.camera.has_method("set_zoom_level"):
		var default_zoom = 1.0  # Default zoom level
		# Create a smooth zoom tween back to default level
		var zoom_tween = get_tree().create_tween()
		zoom_tween.set_trans(Tween.TRANS_SINE)
		zoom_tween.set_ease(Tween.EASE_IN_OUT)
		zoom_tween.tween_method(func(zoom_level: float):
			course.camera.set_zoom_level(zoom_level)
		, course.camera.get_current_zoom(), default_zoom, 1.5)
		print("✓ Camera zoom smoothly restored to default (fallback)")

# Helper function to get NPC at position
func get_npc_at_position(pos: Vector2i) -> Node:
	"""Get the NPC at the given grid position, or null if none"""
	print("=== GETTING NPC AT POSITION (RangedStrategy) ===")
	print("Position:", pos)
	print("Card effect handler:", card_effect_handler != null)
	
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ No card_effect_handler or course found")
		return null
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("✗ No Entities node found")
		return null
	
	print("✓ Entities found")
	var npcs = entities.get_npcs()
	print("Total NPCs found:", npcs.size())
	
	for npc in npcs:
		print("=== CHECKING NPC ===")
		print("NPC reference:", npc)
		print("Is instance valid:", is_instance_valid(npc))
		
		if is_instance_valid(npc):
			print("NPC name:", npc.name)
			print("NPC class:", npc.get_class())
			print("NPC script:", npc.get_script().resource_path if npc.get_script() else "No script")
			print("NPC global position:", npc.global_position)
			
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(calculated from world position)")
			
			if npc_pos == pos:
				print("✓ Found NPC at position:", pos, "NPC:", npc.name)
				return npc
		else:
			print("✗ NPC is invalid - reference:", npc)
			if npc != null:
				print("  - NPC name (if available):", npc.name if "name" in npc else "No name property")
				print("  - NPC class (if available):", npc.get_class() if "get_class" in npc else "No get_class method")
		
		print("=== END CHECKING NPC ===")
	
	print("✗ No NPC found at position:", pos)
	return null

func perform_attackdog_attack(target_pos: Vector2i) -> void:
	"""Perform AttackDog summon attack at the specified position"""
	print("=== PERFORMING ATTACKDOG SUMMON ATTACK ===")
	print("Target position:", target_pos)
	
	# Get NPC at target position
	var npc = get_npc_at_position(target_pos)
	if npc:
		print("Found NPC at target position:", npc.name)
		perform_attackdog_attack_on_npc(npc, target_pos)
	else:
		# Check for destructible object at target position
		var destructible = get_destructible_at_position(target_pos)
		if destructible:
			print("Found destructible object at target position:", destructible.name)
			perform_attackdog_attack_on_destructible(destructible, target_pos)
		else:
			print("No NPC or destructible found at target position:", target_pos)
			# Check if there's an item at the target position
			var item = get_item_at_position(target_pos)
			if item:
				print("Found item at target position:", item.name)
				perform_attackdog_attack_on_item(item, target_pos)
			else:
				print("No NPC, destructible, or item found at target position:", target_pos)
				# Still perform the attack animation even if no target
				perform_attackdog_attack_on_empty_tile(target_pos)

func perform_attackdog_attack_on_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Perform AttackDog attack on destructible object with Ash dog animation"""
	print("=== PERFORMING ATTACKDOG ATTACK ON DESTRUCTIBLE ===")
	print("Destructible:", destructible.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Emit ash dog attack signal for animation
	emit_signal("ash_dog_attack_performed")
	
	# Create and animate Ash dog
	create_and_animate_ash_dog_for_destructible(destructible, target_pos)

func create_and_animate_ash_dog_for_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Create Ash dog and animate it to attack the destructible object with full visual effects"""
	# Load Ash scene
	var ash_scene = preload("res://NPC/Animals/Ash/Ash.tscn")
	if not ash_scene:
		print("Error: Failed to load Ash scene")
		complete_attackdog_attack_for_destructible(destructible, target_pos)
		return
	
	var ash = ash_scene.instantiate()
	if not ash:
		print("Error: Failed to instantiate Ash")
		complete_attackdog_attack_for_destructible(destructible, target_pos)
		return
	
	# Add Ash as child of the player character (BennyChar, LaylaChar, etc.)
	var character_node = null
	if player_node:
		# Find the character node (BennyChar, LaylaChar, etc.)
		for child in player_node.get_children():
			if child.name.ends_with("Char"):
				character_node = child
				break
		
		if character_node:
			character_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of", character_node.name, "at position:", ash.global_position)
		else:
			# Fallback: add to player node directly
			player_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of player node at position:", ash.global_position)
	else:
		print("Error: No player node found")
		ash.queue_free()
		complete_attackdog_attack_for_destructible(destructible, target_pos)
		return
	
	# Play Ash bark sound
	var ash_bark = ash.get_node_or_null("AshBark")
	if ash_bark:
		ash_bark.play()
		print("Playing Ash bark sound")
	
	# Get target world position
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	if card_effect_handler and card_effect_handler.course:
		var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
		if camera_container:
			target_world_pos += camera_container.global_position
	
	# Calculate direction for sprite orientation
	var direction = target_world_pos - ash.global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	var is_up = direction.y < 0
	
	# Set up Ash sprites
	var default_sprite = ash.get_node_or_null("AshDefaultSprite")
	var attack_sprite = ash.get_node_or_null("AshAttackSprite")
	
	if not default_sprite or not attack_sprite:
		print("Error: Ash sprites not found")
		ash.queue_free()
		complete_attackdog_attack_for_destructible(destructible, target_pos)
		return
	
	# Hide default sprite, show attack sprite
	default_sprite.visible = false
	attack_sprite.visible = true
	
	# Set appropriate attack sprite based on direction
	if is_horizontal:
		# Use AshAttackLeftRight for horizontal movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = direction.x < 0  # Flip if moving left
	else:
		# Use AshAttackLeftRight for vertical movement too (no separate up/down sprite)
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = false  # No flip for vertical
	
	print("Ash dog attacking destructible in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", attack_sprite.flip_h)
	
	# Animate Ash to target position
	var tween = get_tree().create_tween()
	tween.tween_property(ash, "global_position", target_world_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		# Flash effect at target
		create_flash_effect(target_world_pos)
		
		# Switch to default sprite
		attack_sprite.visible = false
		default_sprite.visible = true
		
		# Set appropriate default sprite based on direction
		if is_horizontal:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = direction.x < 0  # Flip if moving left
		else:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultUp.png")
			default_sprite.flip_h = false  # No flip for vertical
		
		# Flip the sprite to face the opposite direction for return journey
		if is_horizontal:
			default_sprite.flip_h = direction.x >= 0  # Flip to face opposite direction
		# For vertical movement, we don't need to flip since it's the same sprite
		
		# Animate back to player
		var return_tween = get_tree().create_tween()
		return_tween.tween_property(ash, "global_position", player_node.global_position, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return_tween.tween_callback(func():
			# Remove Ash and complete attack
			ash.queue_free()
			complete_attackdog_attack_for_destructible(destructible, target_pos)
		)
	)

func create_flash_effect(position: Vector2) -> void:
	"""Create a flash effect at the specified position"""
	# Create a simple flash effect using a ColorRect
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.size = Vector2(48, 48)  # Same size as a tile
	flash.global_position = position - flash.size / 2
	flash.z_index = 1000  # Very high z-index to appear on top
	
	# Add to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(flash)
	else:
		add_child(flash)
	
	# Animate flash
	var flash_tween = get_tree().create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)

func complete_attackdog_attack_for_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Complete the AttackDog attack by dealing damage to destructible object"""
	print("Completing AttackDog attack on destructible object:", destructible.name)
	
	# Deal 50 damage to the destructible object
	var damage = ash_dog_damage
	
	# Check if destructible is destroyed
	var is_destroyed = false
	if destructible.has_method("get_is_destroyed"):
		is_destroyed = destructible.get_is_destroyed()
	elif destructible.has_method("is_destroyed"):
		is_destroyed = destructible.is_destroyed()
	elif "is_destroyed" in destructible:
		is_destroyed = destructible.is_destroyed
	
	if is_destroyed:
		print("Attacking destroyed destructible object - no damage dealt")
		damage = 0
	else:
		# Deal damage to the destructible object
		if destructible.has_method("take_damage"):
			destructible.take_damage(damage)
			print("Dealt", damage, "damage to destructible object:", destructible.name)
		else:
			print("Destructible object does not have take_damage method")
	
	# Emit signal
	emit_signal("npc_attacked", destructible, damage)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END ATTACKDOG ATTACK ON DESTRUCTIBLE ===")

func perform_attackdog_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AttackDog attack on NPC with Ash dog animation"""
	print("=== PERFORMING ATTACKDOG ATTACK ON NPC ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Emit ash dog attack signal for animation
	emit_signal("ash_dog_attack_performed")
	
	# Create and animate Ash dog
	create_and_animate_ash_dog(npc, target_pos)

func create_and_animate_ash_dog(npc: Node, target_pos: Vector2i) -> void:
	"""Create Ash dog and animate it to attack the target"""
	# Load Ash scene
	var ash_scene = preload("res://NPC/Animals/Ash/Ash.tscn")
	if not ash_scene:
		print("Error: Failed to load Ash scene")
		complete_attackdog_attack(npc, target_pos)
		return
	
	var ash = ash_scene.instantiate()
	if not ash:
		print("Error: Failed to instantiate Ash")
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Add Ash as child of the player character (BennyChar, LaylaChar, etc.)
	var character_node = null
	if player_node:
		# Find the character node (BennyChar, LaylaChar, etc.)
		for child in player_node.get_children():
			if child.name.ends_with("Char"):
				character_node = child
				break
		
		if character_node:
			character_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of", character_node.name, "at position:", ash.global_position)
		else:
			# Fallback: add to player node directly
			player_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of player node at position:", ash.global_position)
	else:
		print("Error: No player node found")
		ash.queue_free()
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Play Ash bark sound
	var ash_bark = ash.get_node_or_null("AshBark")
	if ash_bark:
		ash_bark.play()
		print("Playing Ash bark sound")
	
	# Get target world position
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	if card_effect_handler and card_effect_handler.course:
		var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
		if camera_container:
			target_world_pos += camera_container.global_position
	
	# Calculate direction for sprite orientation
	var direction = target_world_pos - ash.global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	var is_up = direction.y < 0
	
	# Set up Ash sprites
	var default_sprite = ash.get_node_or_null("AshDefaultSprite")
	var attack_sprite = ash.get_node_or_null("AshAttackSprite")
	
	if not default_sprite or not attack_sprite:
		print("Error: Ash sprites not found")
		ash.queue_free()
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Hide default sprite, show attack sprite
	default_sprite.visible = false
	attack_sprite.visible = true
	
	# Set appropriate attack sprite based on direction
	if is_horizontal:
		# Use AshAttackLeftRight for horizontal movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = direction.x < 0  # Flip if moving left
	else:
		# Use AshAttackLeftRight for vertical movement too (no separate up/down sprite)
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = false  # No flip for vertical
	
	print("Ash dog attacking in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", attack_sprite.flip_h)
	
	# Animate Ash to target position
	var tween = get_tree().create_tween()
	tween.tween_property(ash, "global_position", target_world_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		# Flash effect at target
		create_flash_effect(target_world_pos)
		
		# Switch to default sprite
		attack_sprite.visible = false
		default_sprite.visible = true
		
		# Set appropriate default sprite based on direction
		if is_horizontal:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = direction.x < 0  # Flip if moving left
		else:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultUp.png")
			default_sprite.flip_h = false  # No flip for vertical
		
		# Flip the sprite to face the opposite direction for return journey
		if is_horizontal:
			default_sprite.flip_h = direction.x >= 0  # Flip to face opposite direction
		# For vertical movement, we don't need to flip since it's the same sprite
		
		# Animate back to player
		var return_tween = get_tree().create_tween()
		return_tween.tween_property(ash, "global_position", player_node.global_position, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return_tween.tween_callback(func():
			# Remove Ash and complete attack
			ash.queue_free()
			complete_attackdog_attack(npc, target_pos)
		)
	)

func create_and_animate_ash_dog_for_item(item: Node, target_pos: Vector2i) -> void:
	"""Create Ash dog and animate it to pick up the item"""
	# Load Ash scene
	var ash_scene = preload("res://NPC/Animals/Ash/Ash.tscn")
	if not ash_scene:
		print("Error: Failed to load Ash scene")
		complete_attackdog_attack_for_item(item, target_pos)
		return
	
	var ash = ash_scene.instantiate()
	if not ash:
		print("Error: Failed to instantiate Ash")
		complete_attackdog_attack_for_item(item, target_pos)
		return
	
	# Add Ash as child of the player character (BennyChar, LaylaChar, etc.)
	var character_node = null
	if player_node:
		# Find the character node (BennyChar, LaylaChar, etc.)
		for child in player_node.get_children():
			if child.name.ends_with("Char"):
				character_node = child
				break
		
		if character_node:
			character_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of", character_node.name, "at position:", ash.global_position)
		else:
			# Fallback: add to player node directly
			player_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of player node at position:", ash.global_position)
	else:
		print("Error: No player node found")
		ash.queue_free()
		complete_attackdog_attack_for_item(item, target_pos)
		return
	
	# Connect to item pickup signal
	if not ash.item_pickup_triggered.is_connected(_on_ash_item_pickup):
		ash.item_pickup_triggered.connect(_on_ash_item_pickup)
	
	# Play Ash bark sound
	var ash_bark = ash.get_node_or_null("AshBark")
	if ash_bark:
		ash_bark.play()
		print("Playing Ash bark sound")
	
	# Get target world position
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	if card_effect_handler and card_effect_handler.course:
		var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
		if camera_container:
			target_world_pos += camera_container.global_position
	
	# Calculate direction for sprite orientation
	var direction = target_world_pos - ash.global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	var is_up = direction.y < 0
	
	# Set up Ash sprites
	var default_sprite = ash.get_node_or_null("AshDefaultSprite")
	var attack_sprite = ash.get_node_or_null("AshAttackSprite")
	
	if not default_sprite or not attack_sprite:
		print("Error: Ash sprites not found")
		ash.queue_free()
		complete_attackdog_attack_for_item(item, target_pos)
		return
	
	# Hide default sprite, show attack sprite
	default_sprite.visible = false
	attack_sprite.visible = true
	
	# Set appropriate attack sprite based on direction
	if is_horizontal:
		# Use AshAttackLeftRight for horizontal movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = direction.x < 0  # Flip if moving left
	else:
		# Use AshAttackLeftRight for vertical movement too (no separate up/down sprite)
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = false  # No flip for vertical
	
	print("Ash dog moving to item in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", attack_sprite.flip_h)
	
	# Animate Ash to target position
	var tween = get_tree().create_tween()
	tween.tween_property(ash, "global_position", target_world_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		# Flash effect at target
		create_flash_effect(target_world_pos)
		
		# Switch to default sprite
		attack_sprite.visible = false
		default_sprite.visible = true
		
		# Set appropriate default sprite based on direction
		if is_horizontal:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = direction.x < 0  # Flip if moving left
		else:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = false  # No flip for vertical
		
		# Flip the sprite to face the opposite direction for return journey
		if is_horizontal:
			default_sprite.flip_h = direction.x >= 0  # Flip to face opposite direction
		# For vertical movement, we don't need to flip since it's the same sprite
		
		# Animate back to player
		var return_tween = get_tree().create_tween()
		return_tween.tween_property(ash, "global_position", player_node.global_position, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return_tween.tween_callback(func():
			# Remove Ash and complete attack
			ash.queue_free()
			complete_attackdog_attack_for_item(item, target_pos)
		)
	)

func create_and_animate_ash_dog_to_empty_tile(target_pos: Vector2i) -> void:
	"""Create Ash dog and animate it to an empty tile"""
	# Load Ash scene
	var ash_scene = preload("res://NPC/Animals/Ash/Ash.tscn")
	if not ash_scene:
		print("Error: Failed to load Ash scene")
		complete_attackdog_attack_on_empty_tile(target_pos)
		return
	
	var ash = ash_scene.instantiate()
	if not ash:
		print("Error: Failed to instantiate Ash")
		complete_attackdog_attack_on_empty_tile(target_pos)
		return
	
	# Add Ash as child of the player character (BennyChar, LaylaChar, etc.)
	var character_node = null
	if player_node:
		# Find the character node (BennyChar, LaylaChar, etc.)
		for child in player_node.get_children():
			if child.name.ends_with("Char"):
				character_node = child
				break
		
		if character_node:
			character_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of", character_node.name, "at position:", ash.global_position)
		else:
			# Fallback: add to player node directly
			player_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of player node at position:", ash.global_position)
	else:
		print("Error: No player node found")
		ash.queue_free()
		complete_attackdog_attack_on_empty_tile(target_pos)
		return
	
	# Play Ash bark sound
	var ash_bark = ash.get_node_or_null("AshBark")
	if ash_bark:
		ash_bark.play()
		print("Playing Ash bark sound")
	
	# Get target world position
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	if card_effect_handler and card_effect_handler.course:
		var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
		if camera_container:
			target_world_pos += camera_container.global_position
	
	# Calculate direction for sprite orientation
	var direction = target_world_pos - ash.global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	var is_up = direction.y < 0
	
	# Set up Ash sprites
	var default_sprite = ash.get_node_or_null("AshDefaultSprite")
	var attack_sprite = ash.get_node_or_null("AshAttackSprite")
	
	if not default_sprite or not attack_sprite:
		print("Error: Ash sprites not found")
		ash.queue_free()
		complete_attackdog_attack_on_empty_tile(target_pos)
		return
	
	# Hide default sprite, show attack sprite
	default_sprite.visible = false
	attack_sprite.visible = true
	
	# Set appropriate attack sprite based on direction
	if is_horizontal:
		# Use AshAttackLeftRight for horizontal movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = direction.x < 0  # Flip if moving left
	else:
		# Use AshAttackLeftRight for vertical movement too (no separate up/down sprite)
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = false  # No flip for vertical
	
	print("Ash dog moving to empty tile in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", attack_sprite.flip_h)
	
	# Animate Ash to target position
	var tween = get_tree().create_tween()
	tween.tween_property(ash, "global_position", target_world_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		# Flash effect at target
		create_flash_effect(target_world_pos)
		
		# Switch to default sprite
		attack_sprite.visible = false
		default_sprite.visible = true
		
		# Set appropriate default sprite based on direction
		if is_horizontal:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = direction.x < 0  # Flip if moving left
		else:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = false  # No flip for vertical
		
		# Flip the sprite to face the opposite direction for return journey
		if is_horizontal:
			default_sprite.flip_h = direction.x >= 0  # Flip to face opposite direction
		# For vertical movement, we don't need to flip since it's the same sprite
		
		# Animate back to player
		var return_tween = get_tree().create_tween()
		return_tween.tween_property(ash, "global_position", player_node.global_position, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return_tween.tween_callback(func():
			# Remove Ash and complete attack
			ash.queue_free()
			complete_attackdog_attack_on_empty_tile(target_pos)
		)
	)

func _on_ash_item_pickup(item: Node):
	"""Handle when Ash picks up an item"""
	print("🗝️ ASH ITEM PICKUP: Ash picked up item:", item.name)
	# The actual pickup logic is handled by the Ash script and course
	# This is just for logging and any additional effects

func complete_attackdog_attack_for_item(item: Node, target_pos: Vector2i) -> void:
	"""Complete the AttackDog attack for item pickup"""
	print("Completing AttackDog attack for item:", item.name)
	
	# No damage dealt for item pickup
	var damage = 0
	
	# Emit signal
	emit_signal("npc_attacked", null, damage)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END ATTACKDOG ITEM PICKUP ===")

func complete_attackdog_attack_on_empty_tile(target_pos: Vector2i) -> void:
	"""Complete the AttackDog attack on empty tile"""
	print("Completing AttackDog attack on empty tile at:", target_pos)
	
	# No damage dealt for empty tile
	var damage = 0
	
	# Emit signal
	emit_signal("npc_attacked", null, damage)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END ATTACKDOG EMPTY TILE ATTACK ===")

func apply_knockback(npc: Node, target_pos: Vector2i) -> void:
	"""Apply knockback to the NPC, pushing them 1 tile away from the player"""
	
	# Calculate direction from player to NPC
	var direction = target_pos - player_grid_pos
	# For grid-based movement, we need to handle direction differently
	var knockback_pos = target_pos
	
	# Check if this is a GangMember and if it's frozen
	var actual_knockback_distance = 1  # AttackDog has 1 tile knockback
	if npc.has_method("is_frozen_state") and npc.is_frozen_state():
		actual_knockback_distance = 3  # Triple knockback for frozen GangMembers
		print("GangMember is frozen - applying triple knockback distance:", actual_knockback_distance)
	
	if direction.x > 0:
		knockback_pos.x += actual_knockback_distance
	elif direction.x < 0:
		knockback_pos.x -= actual_knockback_distance
	elif direction.y > 0:
		knockback_pos.y += actual_knockback_distance
	elif direction.y < 0:
		knockback_pos.y -= actual_knockback_distance
	
	# Check if knockback position is valid
	if is_position_valid_for_knockback(knockback_pos):
		# Use animated pushback if the NPC supports it
		if npc.has_method("push_back"):
			npc.push_back(knockback_pos)
			print("Applied animated pushback to NPC (distance:", actual_knockback_distance, ")")
		elif npc.has_method("set_grid_position"):
			# Fallback to instant position change
			npc.set_grid_position(knockback_pos)
			
			# Update Y-sorting
			if npc.has_method("update_z_index_for_ysort"):
				npc.update_z_index_for_ysort()
			print("Applied instant pushback to NPC (distance:", actual_knockback_distance, ", no animation support)")
		else:
			print("NPC does not have push_back or set_grid_position method, skipping knockback")
	else:
		print("Knockback position is not valid, skipping knockback")

func is_position_valid_for_knockback(pos: Vector2i) -> bool:
	"""Check if a position is valid for NPC knockback"""
	var is_valid = true
	
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		is_valid = false
	
	# Check if the position is occupied by an obstacle
	elif obstacle_map.has(pos):
		var obstacle = obstacle_map[pos]
		if obstacle.has_method("blocks") and obstacle.blocks():
			is_valid = false
	
	# Check if the position is occupied by another NPC
	elif card_effect_handler and card_effect_handler.course:
		var entities = card_effect_handler.course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if is_instance_valid(npc):
					var npc_pos = Vector2i.ZERO
					
					# Try to get grid position using different methods
					if npc.has_method("get_grid_position"):
						npc_pos = npc.get_grid_position()
					elif "grid_position" in npc:
						npc_pos = npc.grid_position
					elif "grid_pos" in npc:
						npc_pos = npc.grid_pos
					else:
						# Fallback: calculate grid position from world position
						var world_pos = npc.global_position
						var cell_size_used = cell_size if "cell_size" in npc else 48
						npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
					
					if npc_pos == pos:
						is_valid = false
						break
	
	# Check if the position is occupied by the player
	elif pos == player_grid_pos:
		is_valid = false
	
	return is_valid

func get_item_at_position(pos: Vector2i) -> Node:
	"""Get the item at the given grid position, or null if none"""
	print("=== GETTING ITEM AT POSITION (RangedStrategy) ===")
	print("Position:", pos)
	print("Card effect handler:", card_effect_handler != null)
	
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ No card_effect_handler or course found")
		return null
	
	# Look for items in the scene (keys, etc.)
	var items = get_tree().get_nodes_in_group("fight_room_keys")
	for item in items:
		if is_instance_valid(item):
			print("=== CHECKING ITEM ===")
			print("Item reference:", item)
			print("Item name:", item.name)
			print("Item class:", item.get_class())
			print("Item global position:", item.global_position)
			
			# Calculate grid position from world position (more reliable)
			var world_pos = item.global_position
			var cell_size_used = cell_size if "cell_size" in item else 48
			var item_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
			print("Checking item:", item.name, "at position:", item_pos, "(calculated from world position)")
			
			if item_pos == pos:
				print("✓ Found item at position:", pos, "Item:", item.name)
				return item
		else:
			print("✗ Item is invalid - reference:", item)
		
		print("=== END CHECKING ITEM ===")
	
	print("✗ No item found at position:", pos)
	return null

func get_destructible_at_position(pos: Vector2i) -> Node:
	"""Get destructible object at the specified grid position"""
	print("=== GETTING DESTRUCTIBLE AT POSITION (RangedStrategy) ===")
	print("Position:", pos)
	
	# Look for destructible objects in the destructible_objects group
	var destructibles = get_tree().get_nodes_in_group("destructible_objects")
	
	for destructible in destructibles:
		print("=== CHECKING DESTRUCTIBLE ===")
		print("Destructible reference:", destructible)
		print("Is instance valid:", is_instance_valid(destructible))
		
		if is_instance_valid(destructible):
			print("Destructible name:", destructible.name)
			print("Destructible class:", destructible.get_class())
			print("Destructible script:", destructible.get_script().resource_path if destructible.get_script() else "No script")
			print("Destructible global position:", destructible.global_position)
			
			var destructible_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if destructible.has_method("get_grid_position"):
				destructible_pos = destructible.get_grid_position()
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(using get_grid_position)")
			elif "grid_position" in destructible:
				destructible_pos = destructible.grid_position
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(using grid_position property)")
			elif "grid_pos" in destructible:
				destructible_pos = destructible.grid_pos
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = destructible.global_position
				var cell_size_used = cell_size if "cell_size" in destructible else 48
				destructible_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(calculated from world position)")
			
			if destructible_pos == pos:
				print("✓ Found destructible at position:", pos, "Destructible:", destructible.name)
				return destructible
		else:
			print("✗ Destructible is invalid - reference:", destructible)
			if destructible != null:
				print("  - Destructible name (if available):", destructible.name if "name" in destructible else "No name property")
				print("  - Destructible class (if available):", destructible.get_class() if "get_class" in destructible else "No get_class method")
		
		print("=== END CHECKING DESTRUCTIBLE ===")
	
	print("✗ No destructible found at position:", pos)
	return null

func perform_attackdog_attack_on_item(item: Node, target_pos: Vector2i) -> void:
	"""Perform AttackDog attack on item with Ash dog animation"""
	print("=== PERFORMING ATTACKDOG ATTACK ON ITEM ===")
	print("Item:", item.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Emit ash dog attack signal for animation
	emit_signal("ash_dog_attack_performed")
	
	# Create and animate Ash dog
	create_and_animate_ash_dog_for_item(item, target_pos)

func perform_attackdog_attack_on_empty_tile(target_pos: Vector2i) -> void:
	"""Perform AttackDog attack on empty tile - just animation, no target"""
	print("=== PERFORMING ATTACKDOG ATTACK ON EMPTY TILE ===")
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Emit ash dog attack signal for animation
	emit_signal("ash_dog_attack_performed")
	
	# Create and animate Ash dog to empty tile
	create_and_animate_ash_dog_to_empty_tile(target_pos)

func update_player_position(new_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	player_grid_pos = new_pos

func perform_firaga_attack(target_pos: Vector2i) -> void:
	"""Perform FiragaCard fireball attack at the specified position"""
	print("=== PERFORMING FIRAGA FIREBALL ATTACK ===")
	print("Target position:", target_pos)
	
	# Get NPC at target position
	var npc = get_npc_at_position(target_pos)
	if npc:
		print("Found NPC at target position:", npc.name)
		perform_firaga_attack_on_npc(npc, target_pos)
	else:
		# Check for destructible object at target position
		var destructible = get_destructible_at_position(target_pos)
		if destructible:
			print("Found destructible object at target position:", destructible.name)
			perform_firaga_attack_on_destructible(destructible, target_pos)
		else:
			print("No NPC or destructible found at target position:", target_pos)
			# Still perform the fireball animation even if no target
			create_and_animate_fireball(target_pos, null)
			emit_signal("attack_completed")

func perform_firaga_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform FiragaCard attack on NPC with fireball animation"""
	print("=== PERFORMING FIRAGA ATTACK ON NPC ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Create and animate fireball
	create_and_animate_fireball(target_pos, npc)

func create_and_animate_fireball(target_pos: Vector2i, npc: Node) -> void:
	"""Create fireball and animate it to attack the target"""
	print("=== CREATING AND ANIMATING FIREBALL ===")
	print("Target position:", target_pos)
	print("NPC:", npc.name if npc else "No NPC")
	
	# Load FireBallAttack scene
	var fireball_scene = load("res://Particles/FireBallAttack.tscn")
	if not fireball_scene:
		print("Error: Failed to load FireBallAttack scene")
		complete_firaga_attack(npc, target_pos)
		return
	
	print("✓ FireBallAttack scene loaded successfully")
	
	var fireball = fireball_scene.instantiate()
	if not fireball:
		print("Error: Failed to instantiate fireball")
		complete_firaga_attack(npc, target_pos)
		return
	
	print("✓ FireBallAttack instantiated successfully")
	
	# Add fireball to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(fireball)
		print("✓ FireBallAttack added to course")
	else:
		add_child(fireball)
		print("✓ FireBallAttack added to self")
	
	# Calculate world positions
	var player_world_pos = Vector2(player_grid_pos.x * cell_size + cell_size/2, player_grid_pos.y * cell_size + cell_size/2)
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	
	# Add camera container offset if available
	if card_effect_handler and card_effect_handler.course:
		var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
		if camera_container:
			player_world_pos += camera_container.global_position
			target_world_pos += camera_container.global_position
	
	print("✓ Player world position:", player_world_pos)
	print("✓ Target world position:", target_world_pos)
	
	# Setup and launch the fireball using its own script
	fireball.setup_and_launch(
		player_world_pos, 
		target_world_pos, 
		1.0, 
		func(): create_fire_explosion(target_world_pos, npc)
	)

func create_fire_explosion(target_world_pos: Vector2, npc: Node) -> void:
	"""Create and play the FireExplode animation at the target position"""
	print("Creating FireExplode animation at position:", target_world_pos)
	
	# Load FireExplode scene
	var fire_explode_scene = load("res://Particles/FireExplode.tscn")
	if not fire_explode_scene:
		print("Error: Failed to load FireExplode scene")
		complete_firaga_attack(npc, Vector2i(target_world_pos.x / cell_size, target_world_pos.y / cell_size))
		return
	
	var fire_explode = fire_explode_scene.instantiate()
	if not fire_explode:
		print("Error: Failed to instantiate FireExplode")
		complete_firaga_attack(npc, Vector2i(target_world_pos.x / cell_size, target_world_pos.y / cell_size))
		return
	
	# Add FireExplode to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(fire_explode)
	else:
		add_child(fire_explode)
	
	# Setup and play the explosion using its own script
	fire_explode.setup_and_play(
		target_world_pos,
		1.0,
		func(): complete_firaga_attack(npc, Vector2i(target_world_pos.x / cell_size, target_world_pos.y / cell_size))
	)

func complete_firaga_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Complete the FiragaCard attack by dealing damage"""
	print("Completing FiragaCard attack on NPC:", npc.name if npc else "No NPC")
	
	if npc:
		# Deal 50 damage to the NPC
		var damage = firaga_damage
		
		# Check if NPC is dead
		var is_dead = false
		if npc.has_method("get_is_dead"):
			is_dead = npc.get_is_dead()
		elif npc.has_method("is_dead"):
			is_dead = npc.is_dead()
		elif "is_dead" in npc:
			is_dead = npc.is_dead
		
		if is_dead:
			print("Attacking dead NPC - no damage dealt")
			damage = 0
		else:
			# Deal damage to the NPC
			if npc.has_method("take_damage"):
				npc.take_damage(damage)
				print("Dealt", damage, "damage to NPC:", npc.name)
			else:
				print("NPC does not have take_damage method")
		
		# Emit signal
		emit_signal("npc_attacked", npc, damage)
	else:
		print("No NPC at target position - no damage dealt")
		emit_signal("npc_attacked", null, 0)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END FIRAGA ATTACK ===")

func perform_icespear_attack(target_pos: Vector2i) -> void:
	"""Perform IceSpearCard ice spear attack at the specified position"""
	print("=== PERFORMING ICESPEAR ICE SPEAR ATTACK ===")
	print("Target position:", target_pos)
	
	# Get NPC at target position
	var npc = get_npc_at_position(target_pos)
	if npc:
		print("Found NPC at target position:", npc.name)
		perform_icespear_attack_on_npc(npc, target_pos)
	else:
		# Check for destructible object at target position
		var destructible = get_destructible_at_position(target_pos)
		if destructible:
			print("Found destructible object at target position:", destructible.name)
			perform_icespear_attack_on_destructible(destructible, target_pos)
		else:
			print("No NPC or destructible found at target position:", target_pos)
			# Still perform the ice spear animation even if no target
			create_and_animate_ice_spear(target_pos, null)
			emit_signal("attack_completed")

func perform_icespear_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform IceSpearCard attack on NPC with ice spear animation"""
	print("=== PERFORMING ICESPEAR ATTACK ON NPC ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Create and animate ice spear
	create_and_animate_ice_spear(target_pos, npc)

func create_and_animate_ice_spear(target_pos: Vector2i, npc: Node) -> void:
	"""Create ice spear and animate it to attack the target"""
	print("=== CREATING AND ANIMATING ICE SPEAR ===")
	print("Target position:", target_pos)
	print("NPC:", npc.name if npc else "No NPC")
	
	# Load IceSpear scene
	var ice_spear_scene = load("res://Particles/IceSpear.tscn")
	if not ice_spear_scene:
		print("Error: Failed to load IceSpear scene")
		complete_icespear_attack(npc, target_pos)
		return
	
	print("✓ IceSpear scene loaded successfully")
	
	var ice_spear = ice_spear_scene.instantiate()
	if not ice_spear:
		print("Error: Failed to instantiate ice spear")
		complete_icespear_attack(npc, target_pos)
		return
	
	print("✓ IceSpear instantiated successfully")
	
	# Add ice spear to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(ice_spear)
		print("✓ IceSpear added to course")
	else:
		add_child(ice_spear)
		print("✓ IceSpear added to self")
	
	# Calculate world positions
	var player_world_pos = Vector2(player_grid_pos.x * cell_size + cell_size/2, player_grid_pos.y * cell_size + cell_size/2)
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	
	# Add camera container offset if available
	if card_effect_handler and card_effect_handler.course:
		var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
		if camera_container:
			player_world_pos += camera_container.global_position
			target_world_pos += camera_container.global_position
	
	print("✓ Player world position:", player_world_pos)
	print("✓ Target world position:", target_world_pos)
	
	# Play IceWhoosh sound
	play_ice_whoosh_sound()
	
	# Setup and launch the ice spear using its own script
	if ice_spear.has_method("setup_and_launch"):
		ice_spear.setup_and_launch(
			player_world_pos, 
			target_world_pos, 
			1.0, 
			func(): create_ice_impact(target_world_pos, npc)
		)
	else:
		# Fallback: manually animate the ice spear
		manual_ice_spear_animation(ice_spear, player_world_pos, target_world_pos, npc)

func play_ice_whoosh_sound() -> void:
	"""Play the IceWhoosh sound effect when IceSpear is created"""
	# Find the player node to get access to the course
	var player = player_node if player_node else null
	if player:
		# Create a temporary node to play the sound
		var temp_sound_node = Node2D.new()
		if card_effect_handler and card_effect_handler.course:
			card_effect_handler.course.add_child(temp_sound_node)
		else:
			add_child(temp_sound_node)
		
		# Create audio player for the sound
		var ice_whoosh_sound = AudioStreamPlayer2D.new()
		temp_sound_node.add_child(ice_whoosh_sound)
		
		# Load and play the Whoosh2 sound (closest to IceWhoosh)
		var whoosh_sound = load("res://Sounds/Whoosh2.mp3")
		if whoosh_sound:
			ice_whoosh_sound.stream = whoosh_sound
			ice_whoosh_sound.play()
			print("✓ Playing IceWhoosh sound effect")
		else:
			print("Warning: Whoosh2 sound not found")
		
		# Remove the temporary sound node after a short delay
		await get_tree().create_timer(0.1).timeout
		temp_sound_node.queue_free()

func manual_ice_spear_animation(ice_spear: Node, start_pos: Vector2, end_pos: Vector2, npc: Node) -> void:
	"""Manually animate the ice spear if it doesn't have a setup_and_launch method"""
	print("Using manual ice spear animation")
	
	# Position at start with chest offset
	var chest_offset = Vector2(0, -40)  # Offset to appear from chest area
	ice_spear.global_position = start_pos + chest_offset
	
	# Set proper z-index to appear above ground but below UI
	ice_spear.z_index = 100
	
	# Calculate direction for sprite orientation
	var direction = end_pos - ice_spear.global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	
	# Set appropriate sprite orientation based on direction
	if is_horizontal:
		# For horizontal movement, flip the sprite if moving left
		ice_spear.flip_h = direction.x < 0
	else:
		# For vertical movement, rotate the sprite
		if direction.y < 0:
			# For upward movement, rotate 90 degrees counterclockwise
			ice_spear.rotation = -PI/2
		else:
			# For downward movement, rotate 90 degrees clockwise
			ice_spear.rotation = PI/2
	
	print("Ice spear attacking in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", ice_spear.flip_h, "rotation:", ice_spear.rotation)
	
	# Animate ice spear to target position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ice_spear, "global_position", end_pos, 1.0)
	tween.tween_callback(func():
		create_ice_impact(end_pos, npc)
	)

func create_ice_impact(target_world_pos: Vector2, npc: Node) -> void:
	"""Create and play the ice impact effect at the target position"""
	print("Creating ice impact effect at position:", target_world_pos)
	
	# Create a simple ice impact effect using a ColorRect
	var ice_impact = ColorRect.new()
	ice_impact.color = Color(0.8, 0.9, 1.0, 0.8)  # Light blue with transparency
	ice_impact.size = Vector2(48, 48)  # Same size as a tile
	ice_impact.global_position = target_world_pos - ice_impact.size / 2
	ice_impact.z_index = 1000  # Very high z-index to appear on top
	
	# Add to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(ice_impact)
	else:
		add_child(ice_impact)
	
	# Animate ice impact
	var impact_tween = create_tween()
	impact_tween.tween_property(ice_impact, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	impact_tween.tween_callback(func():
		ice_impact.queue_free()
		complete_icespear_attack(npc, Vector2i(target_world_pos.x / cell_size, target_world_pos.y / cell_size))
	)

func complete_icespear_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Complete the IceSpearCard attack by dealing damage"""
	print("Completing IceSpearCard attack on NPC:", npc.name if npc else "No NPC")
	
	if npc:
		# Deal 30 damage to the NPC
		var damage = ice_spear_damage
		
		# Check if NPC is dead
		var is_dead = false
		if npc.has_method("get_is_dead"):
			is_dead = npc.get_is_dead()
		elif npc.has_method("is_dead"):
			is_dead = npc.is_dead()
		elif "is_dead" in npc:
			is_dead = npc.is_dead
		
		if is_dead:
			print("Attacking dead NPC - no damage dealt")
			damage = 0
		else:
			# Deal damage to the NPC
			if npc.has_method("take_damage"):
				npc.take_damage(damage)
				print("Dealt", damage, "damage to NPC:", npc.name)
			else:
				print("NPC does not have take_damage method")
		
		# Emit signal
		emit_signal("npc_attacked", npc, damage)
	else:
		print("No NPC at target position - no damage dealt")
		emit_signal("npc_attacked", null, 0)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END ICESPEAR ATTACK ===")

func perform_firaga_attack_on_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Perform FiragaCard attack on destructible object with fireball animation"""
	print("=== PERFORMING FIRAGA ATTACK ON DESTRUCTIBLE ===")
	print("Destructible:", destructible.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Create and animate fireball
	create_and_animate_fireball(target_pos, destructible)

func complete_firaga_attack_for_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Complete the FiragaCard attack by dealing damage to destructible object"""
	print("Completing FiragaCard attack on destructible object:", destructible.name if destructible else "No destructible")
	
	if destructible:
		# Deal 50 damage to the destructible object
		var damage = firaga_damage
		
		# Check if destructible is destroyed
		var is_destroyed = false
		if destructible.has_method("get_is_destroyed"):
			is_destroyed = destructible.get_is_destroyed()
		elif destructible.has_method("is_destroyed"):
			is_destroyed = destructible.is_destroyed()
		elif "is_destroyed" in destructible:
			is_destroyed = destructible.is_destroyed
		
		if is_destroyed:
			print("Attacking destroyed destructible object - no damage dealt")
			damage = 0
		else:
			# Deal damage to the destructible object
			if destructible.has_method("take_damage"):
				destructible.take_damage(damage)
				print("Dealt", damage, "damage to destructible object:", destructible.name)
			else:
				print("Destructible object does not have take_damage method")
		
		# Emit signal
		emit_signal("npc_attacked", destructible, damage)
	else:
		print("No destructible at target position - no damage dealt")
		emit_signal("npc_attacked", null, 0)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END FIRAGA ATTACK ON DESTRUCTIBLE ===")

func perform_icespear_attack_on_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Perform IceSpearCard attack on destructible object with ice spear animation"""
	print("=== PERFORMING ICESPEAR ATTACK ON DESTRUCTIBLE ===")
	print("Destructible:", destructible.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Create and animate ice spear
	create_and_animate_ice_spear(target_pos, destructible)

func complete_icespear_attack_for_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Complete the IceSpearCard attack by dealing damage to destructible object"""
	print("Completing IceSpearCard attack on destructible object:", destructible.name if destructible else "No destructible")
	
	if destructible:
		# Deal 40 damage to the destructible object
		var damage = ice_spear_damage
		
		# Check if destructible is destroyed
		var is_destroyed = false
		if destructible.has_method("get_is_destroyed"):
			is_destroyed = destructible.get_is_destroyed()
		elif destructible.has_method("is_destroyed"):
			is_destroyed = destructible.is_destroyed()
		elif "is_destroyed" in destructible:
			is_destroyed = destructible.is_destroyed
		
		if is_destroyed:
			print("Attacking destroyed destructible object - no damage dealt")
			damage = 0
		else:
			# Deal damage to the destructible object
			if destructible.has_method("take_damage"):
				destructible.take_damage(damage)
				print("Dealt", damage, "damage to destructible object:", destructible.name)
			else:
				print("Destructible object does not have take_damage method")
		
		# Emit signal
		emit_signal("npc_attacked", destructible, damage)
	else:
		print("No destructible at target position - no damage dealt")
		emit_signal("npc_attacked", null, 0)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END ICESPEAR ATTACK ON DESTRUCTIBLE ===")

func complete_attackdog_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Complete the AttackDog attack by dealing damage"""
	print("Completing AttackDog attack on NPC:", npc.name)
	
	# Deal 50 damage to the NPC
	var damage = ash_dog_damage
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("Attacking dead NPC - pushing corpse")
		damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, damage)
	
	# Exit attack mode
	emit_signal("attack_completed")
	
	print("=== END ATTACKDOG ATTACK ===")
