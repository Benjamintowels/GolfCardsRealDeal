extends Node2D

# Test script for Meteor YSort system

func _ready():
	print("=== METEOR YSORT TEST ===")
	
	# Test meteor scene loading
	var meteor_scene = preload("res://Particles/Meteor.tscn")
	if meteor_scene:
		print("✓ Meteor scene loaded successfully")
		
		# Test meteor instantiation
		var meteor = meteor_scene.instantiate()
		if meteor:
			print("✓ Meteor instantiated successfully")
			
			# Test YSortPoint
			var ysort_point = meteor.get_node_or_null("YSortPoint")
			if ysort_point:
				print("✓ Meteor YSortPoint found at:", ysort_point.position)
				print("✓ Meteor YSortPoint global position:", ysort_point.global_position)
			else:
				print("✗ Meteor YSortPoint not found")
			
			# Test get_y_sort_point method
			if meteor.has_method("get_y_sort_point"):
				var y_sort_value = meteor.get_y_sort_point()
				print("✓ Meteor get_y_sort_point() returns:", y_sort_value)
			else:
				print("✗ Meteor missing get_y_sort_point method")
			
			# Test update_ysort method
			if meteor.has_method("update_ysort"):
				meteor.update_ysort()
				print("✓ Meteor update_ysort() called")
			else:
				print("✗ Meteor missing update_ysort method")
			
			# Test groups
			if meteor.is_in_group("meteors"):
				print("✓ Meteor added to 'meteors' group")
			else:
				print("✗ Meteor not in 'meteors' group")
			
			if meteor.is_in_group("ysort_objects"):
				print("✓ Meteor added to 'ysort_objects' group")
			else:
				print("✗ Meteor not in 'ysort_objects' group")
			
			# Test sprite visibility
			var meteor_sprite = meteor.get_node_or_null("MeteorSprite")
			if meteor_sprite:
				print("✓ Meteor sprite found, visible:", meteor_sprite.visible)
				print("✓ Meteor sprite position:", meteor_sprite.position)
				print("✓ Meteor sprite global position:", meteor_sprite.global_position)
			else:
				print("✗ Meteor sprite not found")
			
			meteor.queue_free()
		else:
			print("✗ Meteor instantiation failed")
	else:
		print("✗ Meteor scene loading failed")
	
	print("=== END METEOR YSORT TEST ===") 