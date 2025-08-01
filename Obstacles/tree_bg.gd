extends Node2D

#empty performative tree to make forests on the edge of the map

@onready var sprite: Sprite2D = $Sprite2D
var original_scale: Vector2 = Vector2.ONE
var original_position: Vector2 = Vector2.ZERO

func _ready():
	original_scale = scale
	original_position = position
	add_to_group("forest_trees")

func play_pseudo3d_effect():
	"""Play pseudo3D animation for hole transition"""
	# Create a simple scale and position animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale up on Y axis (like the main pseudo3D effect)
	var target_scale = Vector2(original_scale.x, original_scale.y * 3.63)
	tween.tween_property(self, "scale", target_scale, 1.5)
	
	# Move down (simulate 3D perspective)
	var target_position = original_position + Vector2(0, 100)
	tween.tween_property(self, "position", target_position, 1.5)
	
	print("TreeBG: Playing pseudo3D effect")

func reverse_pseudo3d_effect():
	"""Reverse pseudo3D animation when switching back"""
	# Create reverse animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale back to original
	tween.tween_property(self, "scale", original_scale, 1.5)
	
	# Move back to original position
	tween.tween_property(self, "position", original_position, 1.5)
	
	print("TreeBG: Reversing pseudo3D effect")
