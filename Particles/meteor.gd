extends Node2D

#Meteor can be used even if no NPC's are detected, it can be placed on a 3x2 tile chunk anywhere up to 10 tiles away from the player

func _ready():
	# Add meteor to groups for YSort system
	add_to_group("meteors")
	add_to_group("ysort_objects")
	
	# Add meteor to YSort system when created
	update_ysort()

func get_y_sort_point() -> float:
	"""Get the Y-sort point for the meteor using the YSortPoint marker"""
	var ysort_point = get_node_or_null("YSortPoint")
	if ysort_point:
		return ysort_point.global_position.y
	else:
		# Fallback to global position if no YSortPoint marker
		return global_position.y

func update_ysort():
	"""Update the meteor's Y-sort using the global system"""
	Global.update_object_y_sort(self, "objects")
