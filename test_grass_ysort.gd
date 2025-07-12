extends Node2D

# Test script to verify grass Y-sorting with ball
# This will help debug the Y-sorting issue

func _ready():
	print("=== GRASS Y-SORT TEST ===")
	
	# Find grass elements
	var grass_elements = get_tree().get_nodes_in_group("grass_elements")
	print("Found", grass_elements.size(), "grass elements")
	
	# Find golf balls
	var golf_balls = get_tree().get_nodes_in_group("golf_balls")
	print("Found", golf_balls.size(), "golf balls")
	
	# Check Y-sorting for each grass element
	for grass in grass_elements:
		if is_instance_valid(grass):
			var grass_pos = grass.global_position
			var grass_z_index = grass.z_index
			var grass_ysort_point = grass.get_y_sort_point() if grass.has_method("get_y_sort_point") else grass_pos.y
			
			print("Grass at", grass_pos, "z_index:", grass_z_index, "ysort_point:", grass_ysort_point)
	
	# Check Y-sorting for each golf ball
	for ball in golf_balls:
		if is_instance_valid(ball):
			var ball_pos = ball.global_position
			var ball_z_index = ball.z_index
			var ball_sprite = ball.get_node_or_null("Sprite2D")
			var ball_shadow = ball.get_node_or_null("Shadow")
			
			print("Ball at", ball_pos, "z_index:", ball_z_index)
			if ball_sprite:
				print("  Ball sprite z_index:", ball_sprite.z_index)
			if ball_shadow:
				print("  Ball shadow z_index:", ball_shadow.z_index)
	
	print("=== END GRASS Y-SORT TEST ===")

func _process(delta):
	# Update Y-sorting for all grass elements every few seconds
	if Time.get_ticks_msec() % 3000 < 16:  # Every 3 seconds
		var grass_elements = get_tree().get_nodes_in_group("grass_elements")
		for grass in grass_elements:
			if is_instance_valid(grass) and grass.has_method("_update_ysort"):
				grass._update_ysort()
		
		# Update Y-sorting for golf balls
		var golf_balls = get_tree().get_nodes_in_group("golf_balls")
		for ball in golf_balls:
			if is_instance_valid(ball) and ball.has_method("update_y_sort"):
				ball.update_y_sort() 