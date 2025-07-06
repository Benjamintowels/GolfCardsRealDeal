extends Node2D

# Only handles visual z_index and sprite offset for top/bottom rows

func _ready():
	_configure_visuals()

func _configure_visuals():
	# Get the wall's grid position from metadata
	var wall_grid_pos = get_meta("grid_position") if has_meta("grid_position") else Vector2i.ZERO
	var is_bottom_row = wall_grid_pos.y == 49
	
	if is_bottom_row:
		z_index = 500
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			var original_y = sprite.position.y
			sprite.position.y -= 37.0
			print("✓ Bottom row wall - sprite Y: ", original_y, " -> ", sprite.position.y)
		else:
			print("✗ ERROR: Sprite2D not found for bottom row wall!")
		print("✓ Bottom row wall - z_index = 500, sprite offset = -37.0")
	elif wall_grid_pos.y == 0:
		z_index = -10
		print("✓ Top row wall - z_index = -10")
	else:
		# Middle walls (if any) can have default z_index
		print("Middle row wall - default z_index")

# Returns the Y-sorting reference point (base of wall)
func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("Sprite2D/YSortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func get_collision_radius() -> float:
	"""
	Get the collision radius for this stone wall.
	Used by the rolling collision system to determine when ball has entered collision area.
	"""
	return 80.0  # Stone wall collision radius (smaller than shop since walls are thinner) 
