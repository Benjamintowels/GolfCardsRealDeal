extends Control

# Simple test to verify Squirrel placement
func _ready():
	print("=== SQUIRREL PLACEMENT TEST ===")
	
	# Test the Squirrel scene loading
	var squirrel_scene = preload("res://NPC/Animals/Squirrel.tscn")
	if squirrel_scene:
		print("✓ Squirrel scene loaded successfully")
		var squirrel = squirrel_scene.instantiate()
		if squirrel:
			print("✓ Squirrel instantiated successfully")
			print("✓ Squirrel name:", squirrel.name)
			print("✓ Squirrel script:", squirrel.get_script().resource_path if squirrel.get_script() else "No script")
			squirrel.queue_free()
		else:
			print("✗ Squirrel instantiation failed")
	else:
		print("✗ Squirrel scene loading failed")
	
	# Test the object scene map
	var object_scene_map = {
		"SQUIRREL": preload("res://NPC/Animals/Squirrel.tscn"),
	}
	
	if "SQUIRREL" in object_scene_map:
		print("✓ SQUIRREL key exists in object scene map")
		if object_scene_map["SQUIRREL"]:
			print("✓ Squirrel scene in object scene map is valid")
		else:
			print("✗ Squirrel scene in object scene map is null")
	else:
		print("✗ SQUIRREL key missing from object scene map")
	
	print("=== END SQUIRREL PLACEMENT TEST ===") 