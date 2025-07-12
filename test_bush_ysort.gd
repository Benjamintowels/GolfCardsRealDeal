extends Node2D

# Test script for Bush Ysorting

func _ready():
	print("=== BUSH YSORT TEST ===")
	
	# Test bush scene loading
	var bush_scene = preload("res://Obstacles/Bush.tscn")
	if bush_scene:
		print("✓ Bush scene loaded successfully")
		
		# Test bush instantiation
		var bush = bush_scene.instantiate()
		if bush:
			print("✓ Bush instantiated successfully")
			
			# Test YsortPoint
			var ysort_point = bush.get_node_or_null("YsortPoint")
			if ysort_point:
				print("✓ Bush YsortPoint found at:", ysort_point.position)
				print("✓ Bush YsortPoint global position:", ysort_point.global_position)
			else:
				print("✗ Bush YsortPoint not found")
			
			# Test get_y_sort_point method
			if bush.has_method("get_y_sort_point"):
				var y_sort_value = bush.get_y_sort_point()
				print("✓ Bush get_y_sort_point() returns:", y_sort_value)
			else:
				print("✗ Bush missing get_y_sort_point method")
			
			# Test sprite position
			var sprite = bush.get_node_or_null("BushSprite")
			if sprite:
				print("✓ Bush sprite position:", sprite.position)
				print("✓ Bush sprite global position:", sprite.global_position)
			else:
				print("✗ Bush sprite not found")
			
			# Test global Ysort system
			if bush.has_method("_update_ysort"):
				bush._update_ysort()
				print("✓ Bush _update_ysort() called")
			else:
				print("✗ Bush missing _update_ysort method")
			
			bush.queue_free()
		else:
			print("✗ Bush instantiation failed")
	else:
		print("✗ Bush scene loading failed")
	
	print("=== END BUSH YSORT TEST ===") 