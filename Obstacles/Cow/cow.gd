extends BaseObstacle

var collision_radius := 50.0

func _ready():
	add_to_group("collision_objects")
	add_to_group("animals")
	# Setup area signals
	var area2d: Area2D = get_node_or_null("Area2D")
	if area2d:
		area2d.collision_layer = 1
		area2d.collision_mask = 1
		area2d.area_entered.connect(_on_area_entered)
		area2d.area_exited.connect(_on_area_exited)

func blocks():
	# Cows don't block world turn movement (obstacle in physics only)
	return false

func get_collision_radius() -> float:
	return collision_radius

func get_height() -> float:
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D) -> void:
	var projectile = area.get_parent()
	if projectile == null:
		return
	var cow_height = get_height()
	var proj_height := 0.0
	if projectile.has_method("get_height"):
		proj_height = projectile.get_height()
	elif "z" in projectile:
		proj_height = projectile.z
	# If ball above cow, set ground level to allow roof bounce; otherwise reflect
	if projectile.has_method("_set_ground_level") and proj_height > cow_height:
		projectile._set_ground_level(cow_height)
	else:
		if projectile.has_method("_reflect_off_object"):
			projectile._reflect_off_object(self)
	_play_moo()

func _on_area_exited(area: Area2D) -> void:
	var projectile = area.get_parent()
	if projectile and projectile.has_method("_reset_ground_level"):
		projectile._reset_ground_level()

func _play_moo():
	# Randomly play Moo1 or Moo2
	var choice = randi() % 2
	var m1 = get_node_or_null("Moo1")
	var m2 = get_node_or_null("Moo2")
	if choice == 0 and m1:
		m1.play()
	elif m2:
		m2.play()
