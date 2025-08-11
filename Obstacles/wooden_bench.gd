extends Node2D

# WoodenBench destructible object with health and GolfBall collision behavior similar to Crate

# Health system
var max_health: int = 110
var current_health: int = 110
var is_destroyed: bool = false

# Damage calculation constants
const MIN_VELOCITY := 25.0
const MAX_VELOCITY := 1200.0

# Ball connection tracking
var connected_balls: Array = []
var ball_check_timer: Timer

# Collision areas
var collision_area: Area2D

# Health bar
var health_bar
var health_bar_container: Control

func _ready():
	add_to_group("interactables")
	add_to_group("collision_objects")
	add_to_group("destructible_objects")
	add_to_group("boulders")

	_setup_collision_areas()
	call_deferred("_update_ysort")
	_connect_to_ball_landed_signals()
	_setup_ball_check_timer()

func _setup_collision_areas():
	# Prefer CrateArea2D (so GolfBall logic allows collisions), fallback to generic Area2D
	collision_area = get_node_or_null("CrateArea2D")
	if collision_area == null:
		collision_area = get_node_or_null("Area2D")
	if collision_area:
		collision_area.collision_layer = 1
		collision_area.collision_mask = 1
		collision_area.connect("area_entered", _on_area_entered)
		collision_area.connect("area_exited", _on_area_exited)

	var hitbox: Area2D = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.collision_layer = 2
		hitbox.collision_mask = 0
		hitbox.add_to_group("hitboxes")

func _create_health_bar():
	# WoodenBench: intentionally no health bar
	health_bar = null
	health_bar_container = null

func _connect_to_ball_landed_signals():
	if Global.has_signal("ball_landed"):
		Global.connect("ball_landed", _on_ball_landed)
	var course = get_node_or_null("/root/Course1")
	if course and course.has_signal("ball_landed"):
		course.connect("ball_landed", _on_ball_landed)

func _setup_ball_check_timer():
	ball_check_timer = Timer.new()
	ball_check_timer.wait_time = 0.1
	ball_check_timer.connect("timeout", _check_for_new_balls)
	add_child(ball_check_timer)
	ball_check_timer.start()

func _check_for_new_balls():
	var balls = get_tree().get_nodes_in_group("golf_balls")
	for ball in balls:
		if ball not in connected_balls:
			connected_balls.append(ball)
			if ball.has_signal("ball_landed"):
				ball.connect("ball_landed", _on_ball_landed)

func _on_ball_landed():
	if not is_destroyed:
		current_health = max_health
		# No health bar on benches

func take_damage(amount: int) -> void:
	_play_thunk()
	current_health = max(0, current_health - amount)
	# No health bar on benches
	if current_health <= 0:
		is_destroyed = true
		_destroy_self()
	else:
		_flash_damage()

func _flash_damage():
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _destroy_self():
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false
	if collision_area:
		collision_area.collision_layer = 0
		collision_area.collision_mask = 0
		collision_area.monitoring = false
		collision_area.monitorable = false
	var hitbox: Area2D = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.collision_layer = 0
		hitbox.collision_mask = 0
		hitbox.monitoring = false
		hitbox.monitorable = false
	if health_bar_container:
		health_bar_container.visible = false
	_play_break_sound()
	_trigger_explosion()

func _trigger_explosion():
	var explosion = get_node_or_null("CrateExplosion")
	if explosion:
		explosion.visible = true
		if explosion.has_method("trigger_explosion"):
			explosion.trigger_explosion()

func _on_area_entered(area: Area2D):
	var projectile = area.get_parent()
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	# GolfBall handles calling _handle_ball_collision directly when appropriate

func _on_area_exited(_area: Area2D):
	pass

func _handle_area_collision(projectile: Node2D):
	var projectile_velocity := Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	var damage := _calculate_velocity_damage(projectile_velocity.length())
	take_damage(damage)

func _handle_ball_collision(ball: Node2D) -> void:
	# Height gate: allow pass-through if ball is above bench top
	var ball_height := 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	var bench_height := Global.get_object_height_from_marker(self)
	if ball_height > bench_height:
		return
	_apply_ball_collision_effect(ball)

func _apply_ball_collision_effect(ball: Node2D) -> void:
	var ball_velocity := Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity

	var damage := _calculate_velocity_damage(ball_velocity.length())
	var will_destroy := damage >= current_health
	if will_destroy:
		var overkill_damage := damage - current_health
		take_damage(damage)
		var dampened_velocity := _calculate_kill_dampening(ball_velocity, overkill_damage)
		if ball.has_method("set_velocity"):
			ball.set_velocity(dampened_velocity)
		elif "velocity" in ball:
			ball.velocity = dampened_velocity
	else:
		take_damage(damage)
		var reflected_velocity := _calculate_circular_reflection(ball, ball_velocity)
		if ball.has_method("set_velocity"):
			ball.set_velocity(reflected_velocity)
		elif "velocity" in ball:
			ball.velocity = reflected_velocity

func _calculate_circular_reflection(ball: Node2D, ball_velocity: Vector2) -> Vector2:
	var to_ball := ball.global_position - global_position
	var normal := to_ball.normalized()
	var reflected := ball_velocity.bounce(normal)
	reflected *= 0.8
	return reflected

func _calculate_kill_dampening(ball_velocity: Vector2, _overkill_damage: int) -> Vector2:
	var dampening_factor := 0.3
	return ball_velocity * dampening_factor

func _calculate_velocity_damage(velocity: float) -> int:
	if velocity < MIN_VELOCITY:
		return 0
	elif velocity > MAX_VELOCITY:
		return 88
	var damage_ratio := (velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
	return int(damage_ratio * 87) + 1

func _play_thunk():
	var thunk = get_node_or_null("TrunkThunk")
	if thunk:
		# Throttle rapid repeats
		var now := Time.get_ticks_msec() / 1000.0
		if has_meta("last_thunk_time") and get_meta("last_thunk_time") + 0.1 > now:
			return
		thunk.play()
		set_meta("last_thunk_time", now)

func _play_break_sound():
	var break_sound = get_node_or_null("BoxBreak")
	if break_sound:
		break_sound.play()

func get_collision_radius() -> float:
	return 32.0

func get_height() -> float:
	return Global.get_object_height_from_marker(self)

func _update_ysort():
	Global.update_object_y_sort(self, "objects")

func get_grid_position() -> Vector2i:
	if has_meta("grid_position"):
		return get_meta("grid_position")
	elif get("grid_position") != null:
		return get("grid_position")
	var world_pos: Vector2 = global_position
	var cell_size: int = 48
	var grid_x: int = int(floor((world_pos.x - float(cell_size) / 2.0) / float(cell_size)))
	var grid_y: int = int(floor((world_pos.y - float(cell_size) / 2.0) / float(cell_size)))
	return Vector2i(grid_x, grid_y)

func blocks() -> bool:
	return true
