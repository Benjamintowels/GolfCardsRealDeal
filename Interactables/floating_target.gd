extends Node2D

# FloatingTarget - A floating target used in Target Puzzle Type
# Handles collision with golf balls, plays sounds, triggers explosions, and manages animations

# Node references
var target_sprite: Sprite2D
var shadow_sprite: Sprite2D
var area2d: Area2D
var animation_player: AnimationPlayer
var boop_sound: AudioStreamPlayer2D
var target_explosion: Node2D

# Animation names
const FLOATING_ANIMATION = "floating_target"
const RIGHT_LEFT_ANIMATION = "right_left"
const UP_DOWN_ANIMATION = "up_down"

# State
var is_hit: bool = false
var is_cleared: bool = false

func _ready():
	# Get references to child nodes
	target_sprite = get_node_or_null("AnchorPoint/TargetSprite")
	shadow_sprite = get_node_or_null("AnchorPoint/Shadow")
	area2d = get_node_or_null("AnchorPoint/Area2D")
	animation_player = get_node_or_null("AnchorPoint/AnimationPlayer")
	boop_sound = get_node_or_null("Boop")
	target_explosion = get_node_or_null("AnchorPoint/TargetExplosion")
	
	# Set up collision detection
	if area2d:
		# Set collision layer to 1 so golf balls can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		area2d.collision_mask = 1
		
		# Connect to area entered signal for collision detection
		area2d.connect("area_entered", _on_area_entered)
	
	# Add to groups for optimization
	add_to_group("interactables")
	add_to_group("collision_objects")
	add_to_group("floating_targets")
	
	# Start the floating animation
	if animation_player:
		animation_player.play(FLOATING_ANIMATION)
		print("✓ FloatingTarget: Started floating animation")

func _process(delta):
	# Update Y-sort for proper layering
	_update_ysort()

func _update_ysort():
	"""Update the FloatingTarget's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func set_animation_based_on_layout(is_horizontal_layout: bool):
	"""
	Set the appropriate movement animation based on layout direction
	
	Args:
		is_horizontal_layout: True if the course layout is horizontal (use up_down animation)
							 False if the course layout is vertical (use right_left animation)
	"""
	if not animation_player:
		return
	
	# Stop current floating animation
	animation_player.stop()
	
	# Set the appropriate movement animation
	if is_horizontal_layout:
		# For horizontal layouts, use up_down animation (target faces left)
		animation_player.play(UP_DOWN_ANIMATION)
		print("✓ FloatingTarget: Set to up_down animation (horizontal layout)")
	else:
		# For vertical layouts, use right_left animation (target faces down)
		animation_player.play(RIGHT_LEFT_ANIMATION)
		print("✓ FloatingTarget: Set to right_left animation (vertical layout)")
	
	# Start the floating animation in parallel
	animation_player.queue(FLOATING_ANIMATION)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the floating target area"""
	if is_hit or is_cleared:
		return  # Already hit or cleared
	
	var projectile = area.get_parent()
	
	# Only process if this is a valid projectile (golf ball or ghost ball)
	if not projectile:
		return
	
	# Check if this is a golf ball or ghost ball by checking for velocity method/property
	var is_golf_ball = projectile.has_method("get_velocity") or "velocity" in projectile
	
	# Only process golf balls and ghost balls - ignore other objects
	if not is_golf_ball:
		print("=== FLOATING TARGET: Ignoring non-projectile collision ===")
		print("Colliding object:", projectile.name if projectile else "Unknown")
		return
	
	print("=== FLOATING TARGET HIT ===")
	print("Target position:", global_position)
	print("Ball position:", projectile.global_position)
	
	# Mark as hit to prevent multiple collisions
	is_hit = true
	
	# Play Boop sound
	_play_boop_sound()
	
	# Make target and shadow invisible
	_make_target_invisible()
	
	# Trigger target explosion
	_trigger_target_explosion()
	
	# Clear the floating target after a short delay
	_clear_floating_target()

func _play_boop_sound():
	"""Play the Boop sound when target is hit"""
	if boop_sound and boop_sound.stream:
		boop_sound.play()
		print("✓ FloatingTarget: Boop sound played")

func _make_target_invisible():
	"""Make the target sprite and shadow invisible"""
	if target_sprite:
		target_sprite.visible = false
		print("✓ FloatingTarget: Target sprite hidden")
	
	if shadow_sprite:
		shadow_sprite.visible = false
		print("✓ FloatingTarget: Shadow sprite hidden")
	
	# Disable collision detection
	if area2d:
		area2d.collision_layer = 0
		area2d.collision_mask = 0
		print("✓ FloatingTarget: Collision detection disabled")

func _trigger_target_explosion():
	"""Trigger the target explosion effect"""
	if target_explosion:
		# Make explosion visible and trigger it
		target_explosion.visible = true
		
		# If the explosion has a trigger method, call it
		if target_explosion.has_method("trigger_explosion"):
			target_explosion.trigger_explosion()
		elif target_explosion.has_method("start_explosion"):
			target_explosion.start_explosion()
		
		print("✓ FloatingTarget: Target explosion triggered")
	else:
		print("⚠ FloatingTarget: No target explosion found")

func _clear_floating_target():
	"""Clear the floating target from the scene"""
	is_cleared = true
	
	# Set up cleanup timer
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 3.0  # Clean up after 3 seconds
	cleanup_timer.one_shot = true
	cleanup_timer.connect("timeout", _cleanup_target)
	add_child(cleanup_timer)
	cleanup_timer.start()
	
	print("✓ FloatingTarget: Cleanup timer started")

func _cleanup_target():
	"""Clean up the floating target after explosion"""
	print("=== CLEANING UP FLOATING TARGET ===")
	
	# Remove from groups
	remove_from_group("interactables")
	remove_from_group("collision_objects")
	remove_from_group("floating_targets")
	
	# Remove from ysort objects if present
	if "ysort_objects" in get_parent():
		var ysort_objects = get_parent().ysort_objects
		for i in range(ysort_objects.size()):
			if ysort_objects[i].node == self:
				ysort_objects.remove_at(i)
				break
	
	# Queue free the target
	queue_free()
	print("✓ FloatingTarget: Removed from scene")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this floating target.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 29.0  # Same as the CircleShape2D radius

func get_height() -> float:
	"""Get the height of this floating target for collision detection"""
	return Global.get_object_height_from_marker(self)
