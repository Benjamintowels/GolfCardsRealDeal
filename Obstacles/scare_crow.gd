extends BaseObstacle

# ScareCrow: Boulder-like circular obstacle with roof-bounce collisions

func _ready():
	# Groups for collision detection and optimization
	add_to_group("collision_objects")
	add_to_group("scarecrows")

	# Configure Area2D for ball/knife detection
	var area2d: Area2D = get_node_or_null("Area2D")
	if area2d:
		area2d.collision_layer = 1
		area2d.collision_mask = 1
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)

func _process(_delta: float) -> void:
	_update_ysort()

func _update_ysort() -> void:
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	# Collision radius used by generic obstacle checks
	return 50.0

func get_height() -> float:
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D) -> void:
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	var projectile: Node = area.get_parent()
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# Balls handle their collision and will call our roof-bounce handler
		pass

func _on_area_exited(area: Area2D) -> void:
	var projectile: Node = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		elif "current_ground_level" in projectile:
			projectile.current_ground_level = 0.0

func _handle_area_collision(projectile: Node2D) -> void:
	if not projectile:
		return
	_handle_roof_bounce_collision(projectile)

# Expose a boulder-compatible hook so GolfBall uses the same branch
func _handle_boulder_collision(projectile: Node2D) -> void:
	_handle_roof_bounce_collision(projectile)

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	if not projectile:
		return

	var projectile_height: float = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z

	var scarecrow_height: float = get_height()

	if projectile_height > scarecrow_height:
		# Projectile above the scarecrow: set ground level to allow roof bounce
		if projectile.has_method("set_ground_level"):
			projectile.set_ground_level(scarecrow_height)
	else:
		_reflect_off_scarecrow(projectile)

func _reflect_off_scarecrow(projectile: Node2D) -> void:
	if not projectile:
		return

	var projectile_velocity: Vector2 = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity

	var obstacle_center: Vector2 = global_position
	var projectile_pos: Vector2 = projectile.global_position
	var to_projectile: Vector2 = (projectile_pos - obstacle_center).normalized()

	var reflected_velocity: Vector2 = projectile_velocity - 2.0 * projectile_velocity.dot(to_projectile) * to_projectile
	reflected_velocity *= 0.8
	var random_angle: float = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)

	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity

	_play_shake_and_thud()

func _play_shake_and_thud() -> void:
	var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
	if anim:
		anim.play("shake")
	var thud: AudioStreamPlayer2D = get_node_or_null("Thud")
	if thud and thud.stream:
		thud.play()
