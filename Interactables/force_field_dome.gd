extends Node2D

# ForceFieldDome - acts as a barrier around the pin area
# Reflects all balls like a boulder while active
# Deactivates when the miniboss dies

signal miniboss_defeated

@onready var sprite: Sprite2D = $ForceFieldDomeSprite
@onready var area2d: Area2D = $Area2D
@onready var force_field_bounce_sound: AudioStreamPlayer2D = $ForceFieldBounce
@onready var powered_down_sound: AudioStreamPlayer2D = $PoweredDown

var is_active: bool = true
var miniboss_reference: Node2D = null

func _ready():
	# Add to groups for collision detection and optimization
	add_to_group("collision_objects")
	add_to_group("force_field_dome")
	
	# Set up collision detection
	if area2d:
		# Set collision layer to 1 so golf balls can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		area2d.collision_mask = 1
		
		# Connect to area entered and exited signals for collision detection
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)
	
	# Initial Y-sort update
	call_deferred("update_z_index_for_ysort")

func _process(delta):
	# Update Y-sort for proper layering
	update_z_index_for_ysort()
	
	# Check if miniboss is still alive
	if miniboss_reference and not miniboss_reference.is_alive and is_active:
		deactivate_dome()

func update_z_index_for_ysort():
	"""Update the ForceFieldDome's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func set_miniboss_reference(miniboss: Node2D):
	"""Set the reference to the miniboss for death detection"""
	miniboss_reference = miniboss
	print("ForceFieldDome: Miniboss reference set to:", miniboss.name if miniboss else "null")

func _on_area_entered(area: Area2D):
	"""Handle when a golf ball enters the force field area"""
	if not is_active:
		return
	
	var projectile = area.get_parent()
	if not projectile:
		return
	
	# Check if this is a golf ball
	var is_golf_ball = projectile.has_method("get_height")
	
	if is_golf_ball:
		print("=== FORCE FIELD DOME BALL REFLECTION ===")
		print("Ball entered force field area - reflecting ball")
		
		# Play force field bounce sound
		if force_field_bounce_sound and force_field_bounce_sound.stream:
			force_field_bounce_sound.play()
			print("Force field bounce sound played")
		
		# Reflect the ball like a boulder would
		_reflect_ball(projectile)

func _on_area_exited(area: Area2D):
	"""Handle when a projectile exits the force field area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0

func _reflect_ball(ball: Node2D):
	"""Reflect the ball off the force field dome"""
	if not ball or not ball.has_method("get_velocity"):
		return
	
	var ball_velocity = ball.get_velocity()
	if ball_velocity == Vector2.ZERO:
		return
	
	# Calculate reflection direction (simple bounce off circular dome)
	var ball_pos = ball.global_position
	var dome_center = global_position
	
	# Calculate direction from dome center to ball
	var direction_to_ball = (ball_pos - dome_center).normalized()
	
	# Reflect the velocity (bounce off the dome surface)
	var reflected_velocity = ball_velocity.bounce(direction_to_ball)
	
	# Apply the reflected velocity
	if ball.has_method("set_velocity"):
		ball.set_velocity(reflected_velocity)
		print("Ball reflected with velocity:", reflected_velocity)
	
	# Add some visual feedback (optional)
	_add_reflection_effect()

func _add_reflection_effect():
	"""Add visual feedback for the reflection"""
	# Create a brief flash effect
	var flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func deactivate_dome():
	"""Deactivate the force field dome when miniboss dies"""
	print("=== FORCE FIELD DOME DEACTIVATION ===")
	print("Miniboss defeated - deactivating force field dome")
	
	is_active = false
	
	# Play powered down sound
	if powered_down_sound and powered_down_sound.stream:
		powered_down_sound.play()
		print("Powered down sound played")
	
	# Animate the dome fading away
	var fade_tween = create_tween()
	fade_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	fade_tween.tween_callback(func():
		print("Force field dome deactivated and hidden")
		# Emit signal for any systems that need to know
		miniboss_defeated.emit()
		# Hide the dome completely
		visible = false
	)
	
	# Disable collision detection
	if area2d:
		area2d.collision_layer = 0
		area2d.collision_mask = 0
		print("Force field dome collision disabled")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this force field dome.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 170.0  # Approximate radius based on the collision shape scale
