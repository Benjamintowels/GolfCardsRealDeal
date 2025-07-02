extends Node

# Optimized Y-sort system that reduces performance impact
# Only updates objects when they actually move or when camera moves significantly

var last_camera_position: Vector2 = Vector2.ZERO
var camera_movement_threshold: float = 10.0  # Only update if camera moves more than this
var object_update_cooldown: float = 0.1  # Minimum time between updates for same object
var last_update_times: Dictionary = {}

# Spatial partitioning for better performance
var spatial_grid: Dictionary = {}
var grid_cell_size: float = 100.0  # Size of each grid cell

func _ready():
	# Initialize the optimized Y-sort system
	print("Optimized Y-sort system initialized")

func update_camera_position(camera_pos: Vector2):
	"""Update camera position and trigger Y-sort updates if needed"""
	var camera_moved = camera_pos.distance_to(last_camera_position) > camera_movement_threshold
	if camera_moved:
		last_camera_position = camera_pos
		# Update all objects when camera moves significantly
		update_all_objects_optimized()
		print("Camera moved significantly - updating all Y-sorts")

func update_object_y_sort_optimized(node: Node2D, object_type: String = "objects"):
	"""Update a single object's Y-sort with cooldown and optimization"""
	if not node or not is_instance_valid(node):
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var node_id = node.get_instance_id()
	
	# Check if enough time has passed since last update
	if last_update_times.has(node_id):
		if current_time - last_update_times[node_id] < object_update_cooldown:
			return
	
	# Update the Y-sort
	Global.update_object_y_sort(node, object_type)
	last_update_times[node_id] = current_time

func update_all_objects_optimized():
	"""Update all objects using the optimized system"""
	# Get all objects that need Y-sort updates
	var objects_to_update = get_all_ysort_objects()
	
	for obj in objects_to_update:
		if not obj.has("node") or not obj["node"] or not is_instance_valid(obj["node"]):
			continue
		
		var node = obj["node"]
		var object_type = determine_object_type(node)
		update_object_y_sort_optimized(node, object_type)

func get_all_ysort_objects() -> Array:
	"""Get all objects that need Y-sorting - this should be called from course_1.gd"""
	# This function should be implemented in course_1.gd to return the ysort_objects array
	# For now, return empty array - will be overridden
	return []

func determine_object_type(node: Node2D) -> String:
	"""Determine the object type for Y-sorting"""
	if node.name == "Tree" or (node.get_script() and "Tree.gd" in str(node.get_script().get_path())):
		return "objects"
	elif node.name == "Pin":
		return "objects"
	elif node.name == "Shop":
		return "objects"
	elif "Player" in node.name or "GangMember" in node.name:
		return "characters"
	elif "GolfBall" in node.name or "GhostBall" in node.name:
		return "balls"
	else:
		return "objects"

func clear_update_times():
	"""Clear the update times dictionary to free memory"""
	last_update_times.clear()

func set_ysort_objects_reference(ysort_objects_array: Array):
	"""Set the reference to the ysort_objects array from course_1.gd"""
	# This will be called from course_1.gd to provide access to the objects
	pass 