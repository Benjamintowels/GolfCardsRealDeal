extends Node2D

# Test script to verify explosion Y-sorting
# This will help debug the Y-sorting issue with explosions

# Import Explosion class
const Explosion = preload("res://Particles/Explosion.gd")

func _ready():
	print("=== EXPLOSION Y-SORT TEST ===")
	
	# Create an explosion at a specific position
	var explosion = Explosion.create_explosion_at_position(Vector2(300, 300), self)
	
	if explosion:
		print("✓ Explosion created successfully")
		print("Explosion position:", explosion.global_position)
		print("Explosion z_index:", explosion.z_index)
		
		# Check if explosion has YSortPoint
		var ysort_point = explosion.get_node_or_null("YSortPoint")
		if ysort_point:
			print("✓ YSortPoint found at:", ysort_point.global_position)
			print("YSortPoint Y position:", ysort_point.global_position.y)
		else:
			print("✗ ERROR: YSortPoint not found!")
		
		# Check if explosion has get_y_sort_point method
		if explosion.has_method("get_y_sort_point"):
			var ysort_value = explosion.get_y_sort_point()
			print("✓ get_y_sort_point() method found, returns:", ysort_value)
		else:
			print("✗ ERROR: get_y_sort_point() method not found!")
		
		# Check if explosion is in the explosions group
		if explosion.is_in_group("explosions"):
			print("✓ Explosion is in 'explosions' group")
		else:
			print("✗ ERROR: Explosion is not in 'explosions' group!")
		
		# Check if explosion is in the ysort_objects group
		if explosion.is_in_group("ysort_objects"):
			print("✓ Explosion is in 'ysort_objects' group")
		else:
			print("✗ ERROR: Explosion is not in 'ysort_objects' group!")
		
		# Force update Y-sort
		explosion._update_ysort()
		print("Updated explosion z_index:", explosion.z_index)
		
	else:
		print("✗ ERROR: Failed to create explosion!")
	
	print("=== END EXPLOSION Y-SORT TEST ===")

func _process(delta):
	# Update Y-sort for explosions every few seconds
	if Time.get_ticks_msec() % 2000 < 16:  # Every 2 seconds
		var explosions = get_tree().get_nodes_in_group("explosions")
		for explosion in explosions:
			if is_instance_valid(explosion) and explosion.has_method("_update_ysort"):
				explosion._update_ysort()
				print("Updated explosion Y-sort, z_index:", explosion.z_index) 