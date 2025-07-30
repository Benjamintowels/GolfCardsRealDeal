extends Node2D

# Visual effect for shooting guns
# Handles bullet trajectory animation

@onready var bullet_sprite: Sprite2D = $Sprite2D
@onready var collision_area: Area2D = $Area2D

var speed: float = 1600.0  # Pixels per second (doubled from 800)
var max_distance: float = 1000.0  # Maximum distance bullet can travel
var start_position: Vector2
var target_position: Vector2
var direction: Vector2
var distance_traveled: float = 0.0
var is_moving: bool = false
var shooter: Node = null  # Reference to the police that fired the bullet

signal bullet_hit(target: Node)
signal bullet_missed

func _ready():
	# Hide bullet initially
	visible = false
	
	# Connect Area2D signals
	if collision_area:
		collision_area.area_entered.connect(_on_area_entered)
		collision_area.body_entered.connect(_on_body_entered)
		print("✓ Bullet Area2D signals connected")
	else:
		print("✗ ERROR: Bullet Area2D not found!")

func fire(from_position: Vector2, to_position: Vector2, shooter_ref: Node = null) -> void:
	"""Fire the bullet from one position to another"""
	print("=== BULLET FIRED ===")
	print("From:", from_position, "To:", to_position)
	
	# Store shooter reference
	shooter = shooter_ref
	
	# Set positions and direction
	start_position = from_position
	target_position = to_position
	global_position = from_position
	
	# Calculate direction and distance
	direction = (to_position - from_position).normalized()
	var total_distance = from_position.distance_to(to_position)
	
	# Limit distance if too far
	if total_distance > max_distance:
		target_position = from_position + (direction * max_distance)
		total_distance = max_distance
	
	print("Direction:", direction, "Distance:", total_distance)
	
	# Rotate bullet sprite to face the direction
	_rotate_bullet_to_direction()
	
	# Reset and start movement
	distance_traveled = 0.0
	is_moving = true
	visible = true
	
	# Start movement animation
	_animate_bullet_movement(total_distance)

func _rotate_bullet_to_direction() -> void:
	"""Rotate the bullet sprite to face the movement direction"""
	if not bullet_sprite:
		return
	
	# Calculate angle from direction vector
	var angle = direction.angle()
	
	# Convert to degrees and adjust for bullet's default upward orientation
	# Since bullet sprite faces up by default, we need to subtract 90 degrees
	var rotation_degrees = rad_to_deg(angle) - 90
	
	# Apply rotation to both sprite and collision area
	bullet_sprite.rotation_degrees = rotation_degrees
	if collision_area:
		collision_area.rotation_degrees = rotation_degrees
	
	print("Bullet rotated to:", rotation_degrees, "degrees")

func _animate_bullet_movement(total_distance: float) -> void:
	"""Animate the bullet's movement along its trajectory"""
	if not is_moving:
		return
	
	# Calculate how long the movement should take
	var travel_time = total_distance / speed
	
	print("Bullet travel time:", travel_time, "seconds")
	
	# Create tween for smooth movement
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Animate position
	tween.tween_property(self, "global_position", target_position, travel_time)
	
	# When movement completes
	tween.tween_callback(_on_bullet_movement_completed)

func _on_area_entered(area: Area2D) -> void:
	"""Called when bullet enters an Area2D"""
	if not is_moving:
		return
	
	# Check if damage has already been applied by raytrace
	if has_meta("damage_applied") and get_meta("damage_applied"):
		print("=== BULLET AREA ENTERED (DAMAGE ALREADY APPLIED) ===")
		print("Hit area:", area.name, "- ignoring collision (damage already applied)")
		return
	
	print("=== BULLET AREA ENTERED ===")
	print("Hit area:", area.name)
	
	# Check if this is a HitBox
	if area.name == "HitBox":
		var parent = area.get_parent()
		print("HitBox parent:", parent.name if parent else "None")
		
		# Check if this is our own HitBox - if so, ignore it
		if parent and shooter and parent == shooter:
			print("✗ Hit our own HitBox - ignoring")
			return
		
		print("✓ Hit valid target:", parent.name if parent else "None")
		print("Target has take_damage:", parent.has_method("take_damage") if parent else "No parent")
		
		if parent and parent.has_method("take_damage"):
			print("✓ HitBox parent has take_damage method - dealing damage")
			_handle_bullet_hit(parent)
		else:
			print("✗ HitBox parent doesn't have take_damage method")
			print("Parent class:", parent.get_class() if parent else "No parent")
			print("Parent methods:", parent.get_method_list() if parent else "No parent")
	else:
		# Check if this is a character's collision area (Area2D)
		var parent = area.get_parent()
		if parent and parent.has_method("take_damage"):
			# Check if this is our own collision area - if so, ignore it
			if parent == shooter:
				print("✗ Hit our own collision area - ignoring")
				return
			
			print("✓ Hit character collision area:", parent.name)
			_handle_bullet_hit(parent)
		else:
			print("✗ Bullet hit non-HitBox area:", area.name)

func _on_body_entered(body: Node2D) -> void:
	"""Called when bullet enters a body (for completeness)"""
	if not is_moving:
		return
	
	print("=== BULLET BODY ENTERED ===")
	print("Hit body:", body.name)
	
	# Handle body collision if needed
	if body.has_method("take_damage"):
		_handle_bullet_hit(body)

func _handle_bullet_hit(target: Node) -> void:
	"""Handle when bullet hits something"""
	print("=== BULLET HIT ===")
	print("Hit target:", target.name)
	
	# Stop movement
	is_moving = false
	
	# Emit bullet_hit signal to notify the shooter
	bullet_hit.emit(target)
	
	# Hide bullet
	visible = false
	
	# Clean up after a short delay
	var cleanup_timer = get_tree().create_timer(0.1)
	cleanup_timer.timeout.connect(_cleanup_bullet)

func _on_bullet_movement_completed() -> void:
	"""Called when bullet movement animation completes"""
	print("Bullet movement completed")
	
	if is_moving:
		# Bullet reached target without hitting anything
		is_moving = false
		bullet_missed.emit()
		print("✓ Bullet missed signal emitted")
		
		# Hide bullet
		visible = false
		
		# Clean up after a short delay
		var cleanup_timer = get_tree().create_timer(0.1)
		cleanup_timer.timeout.connect(_cleanup_bullet)

func _cleanup_bullet() -> void:
	"""Clean up the bullet node"""
	print("Cleaning up bullet")
	queue_free()

func stop_movement() -> void:
	"""Stop bullet movement immediately"""
	is_moving = false
	visible = false
