extends Node2D

# Test script to check bonfire visibility and Y-sorting

func _ready():
	print("=== BONFIRE VISIBILITY TEST ===")
	
	# Test bonfire scene loading
	var bonfire_scene = preload("res://Interactables/Bonfire.tscn")
	if bonfire_scene:
		print("✓ Bonfire scene loaded successfully")
		
		# Test bonfire instantiation
		var bonfire = bonfire_scene.instantiate()
		if bonfire:
			print("✓ Bonfire instantiated successfully")
			
			# Test YsortPoint
			var ysort_point = bonfire.get_node_or_null("YsortPoint")
			if ysort_point:
				print("✓ Bonfire YsortPoint found at:", ysort_point.position)
				print("✓ Bonfire YsortPoint global position:", ysort_point.global_position)
			else:
				print("✗ Bonfire YsortPoint not found")
			
			# Test get_y_sort_point method
			if bonfire.has_method("get_y_sort_point"):
				var y_sort_value = bonfire.get_y_sort_point()
				print("✓ Bonfire get_y_sort_point() returns:", y_sort_value)
			else:
				print("✗ Bonfire missing get_y_sort_point method")
			
			# Test sprite visibility
			var base_sprite = bonfire.get_node_or_null("BonfireBaseSprite")
			var flame_sprite = bonfire.get_node_or_null("BonfireFlame")
			
			if base_sprite:
				print("✓ Bonfire base sprite found")
				print("✓ Bonfire base sprite visible:", base_sprite.visible)
				print("✓ Bonfire base sprite position:", base_sprite.position)
				print("✓ Bonfire base sprite global position:", base_sprite.global_position)
				print("✓ Bonfire base sprite z_index:", base_sprite.z_index)
			else:
				print("✗ Bonfire base sprite not found")
			
			if flame_sprite:
				print("✓ Bonfire flame sprite found")
				print("✓ Bonfire flame sprite visible:", flame_sprite.visible)
				print("✓ Bonfire flame sprite position:", flame_sprite.position)
				print("✓ Bonfire flame sprite global position:", flame_sprite.global_position)
				print("✓ Bonfire flame sprite z_index:", flame_sprite.z_index)
			else:
				print("✗ Bonfire flame sprite not found")
			
			# Test global Ysort system
			if bonfire.has_method("_update_ysort"):
				bonfire._update_ysort()
				print("✓ Bonfire _update_ysort() called")
				print("✓ Bonfire z_index after update:", bonfire.z_index)
			else:
				print("✗ Bonfire missing _update_ysort method")
			
			# Add to scene for visual testing
			add_child(bonfire)
			bonfire.position = Vector2(100, 100)
			print("✓ Bonfire added to scene at position:", bonfire.position)
			
		else:
			print("✗ Bonfire instantiation failed")
	else:
		print("✗ Bonfire scene loading failed")
	
	print("=== END BONFIRE VISIBILITY TEST ===")

func _process(delta):
	# Update Y-sorting every few seconds
	if Time.get_ticks_msec() % 3000 < 16:  # Every 3 seconds
		var bonfires = get_tree().get_nodes_in_group("ysort_objects")
		for bonfire in bonfires:
			if is_instance_valid(bonfire) and bonfire.has_method("_update_ysort"):
				bonfire._update_ysort()
				print("Updated bonfire z_index:", bonfire.z_index) 