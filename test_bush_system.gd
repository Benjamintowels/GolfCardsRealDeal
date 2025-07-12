extends Node2D

# Test script for Bush system

func _ready():
	print("=== BUSH SYSTEM TEST ===")
	
	# Test bush scene loading
	var bush_scene = preload("res://Obstacles/Bush.tscn")
	if bush_scene:
		print("✓ Bush scene loaded successfully")
		
		# Test bush instantiation
		var bush = bush_scene.instantiate()
		if bush:
			print("✓ Bush instantiated successfully")
			print("✓ Bush name:", bush.name)
			
			# Test bush script
			if bush.has_method("_handle_bush_collision"):
				print("✓ Bush has _handle_bush_collision method")
			else:
				print("✗ Bush missing _handle_bush_collision method")
			
			if bush.has_method("_handle_bush_velocity_damping"):
				print("✓ Bush has _handle_bush_velocity_damping method")
			else:
				print("✗ Bush missing _handle_bush_velocity_damping method")
			
			if bush.has_method("_play_leaves_rustle"):
				print("✓ Bush has _play_leaves_rustle method")
			else:
				print("✗ Bush missing _play_leaves_rustle method")
			
			# Test bush groups
			bush.add_to_group("bushes")
			bush.add_to_group("collision_objects")
			print("✓ Bush added to groups")
			
			# Test bush Area2D
			var area2d = bush.get_node_or_null("Area2D")
			if area2d:
				print("✓ Bush Area2D found")
				print("✓ Area2D collision layer:", area2d.collision_layer)
				print("✓ Area2D collision mask:", area2d.collision_mask)
			else:
				print("✗ Bush Area2D not found")
			
			# Test bush sprite
			var sprite = bush.get_node_or_null("BushSprite")
			if sprite:
				print("✓ Bush sprite found")
				if sprite.texture:
					print("✓ Bush texture loaded")
				else:
					print("✗ Bush texture not loaded")
			else:
				print("✗ Bush sprite not found")
			
			# Test bush sound
			var leaves_sound = bush.get_node_or_null("LeavesRustle")
			if leaves_sound:
				print("✓ Bush leaves rustle sound found")
				if leaves_sound.stream:
					print("✓ Bush sound stream loaded")
				else:
					print("✗ Bush sound stream not loaded")
			else:
				print("✗ Bush leaves rustle sound not found")
			
			# Test bush height marker
			var top_height = bush.get_node_or_null("TopHeight")
			if top_height:
				print("✓ Bush TopHeight marker found at:", top_height.position)
			else:
				print("✗ Bush TopHeight marker not found")
			
			# Test bush Ysort point
			var ysort_point = bush.get_node_or_null("YsortPoint")
			if ysort_point:
				print("✓ Bush YsortPoint found at:", ysort_point.position)
			else:
				print("✗ Bush YsortPoint not found")
			
			bush.queue_free()
		else:
			print("✗ Bush instantiation failed")
	else:
		print("✗ Bush scene loading failed")
	
	print("=== END BUSH SYSTEM TEST ===") 