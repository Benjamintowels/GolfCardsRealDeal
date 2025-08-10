extends Node2D

# use for placing in game fences to connect rows together

func _ready():
	add_to_group("collision_objects")
	# Setup Area2D for ball collisions
	var area2d: Area2D = get_node_or_null("Area2D")
	if area2d:
		area2d.collision_layer = 1
		area2d.collision_mask = 1
		area2d.area_entered.connect(_on_area_entered)
		area2d.area_exited.connect(_on_area_exited)

func get_collision_radius() -> float:
	# Approximate half-width for proximity checks
	return 60.0

func get_height() -> float:
	# Use TopHeight marker height
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D) -> void:
	var projectile = area.get_parent()
	if projectile == null:
		return
	var fence_height = get_height()
	var proj_height := 0.0
	if projectile.has_method("get_height"):
		proj_height = projectile.get_height()
	elif "z" in projectile:
		proj_height = projectile.z
	# If ball above fence, set ground level to allow roof bounce; otherwise reflect
	if projectile.has_method("_set_ground_level") and proj_height > fence_height:
		projectile._set_ground_level(fence_height)
	else:
		# Reflect off fence
		if projectile.has_method("_reflect_off_object"):
			_play_trunk_thunk_sound()
			projectile._reflect_off_object(self)

func _on_area_exited(area: Area2D) -> void:
	var projectile = area.get_parent()
	if projectile and projectile.has_method("_reset_ground_level"):
		projectile._reset_ground_level()

func _play_trunk_thunk_sound():
	var thunk = get_node_or_null("TrunkThunk")
	if thunk:
		thunk.play()
