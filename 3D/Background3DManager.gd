extends Node
class_name Background3DManager

# 3D Background Manager - Replicates 2D parallax effect in 3D space
# Uses multiple planes at different depths with different movement speeds

# Background planes
var background_planes: Array = []
var camera: Camera3D = null
var last_camera_position: Vector3 = Vector3.ZERO

# Parallax settings
var parallax_factors: Array = [0.0, 0.1, 0.3, 0.5, 0.7]  # Different movement speeds
var background_depths: Array = [-500, -400, -300, -200, -100]  # Z positions
var background_colors: Array = [
	Color(0.5, 0.7, 1.0, 1.0),  # Sky blue
	Color(0.3, 0.5, 0.8, 1.0),  # Distant mountains
	Color(0.4, 0.6, 0.9, 1.0),  # Mid mountains
	Color(0.5, 0.7, 1.0, 1.0),  # Near mountains
	Color(0.6, 0.8, 1.0, 1.0)   # Hills
]

# Performance optimization
var update_threshold: float = 1.0  # Only update if camera moves more than this

func setup(camera_ref: Camera3D, background_container: Node3D):
	"""Initialize the 3D background system"""
	camera = camera_ref
	last_camera_position = camera.global_position
	
	# Create background planes
	_create_background_planes(background_container)
	
	print("Background3DManager setup complete")

func _create_background_planes(container: Node3D):
	"""Create all background planes with parallax effect"""
	
	for i in range(background_depths.size()):
		var plane_mesh = PlaneMesh.new()
		plane_mesh.size = Vector2(2000, 1000)  # Large background plane
		
		var material = StandardMaterial3D.new()
		material.albedo_color = background_colors[i]
		material.flags_unshaded = true  # No lighting for backgrounds
		
		var background_plane = MeshInstance3D.new()
		background_plane.mesh = plane_mesh
		background_plane.material_override = material
		background_plane.position = Vector3(0, 0, background_depths[i])
		
		container.add_child(background_plane)
		background_planes.append({
			"plane": background_plane,
			"parallax_factor": parallax_factors[i],
			"base_position": background_plane.position,
			"total_offset": Vector3.ZERO
		})
	
	print("✓ Created", background_planes.size(), "background planes")

func _process(delta):
	"""Update background parallax effect"""
	if not camera:
		return
	
	# Check if camera moved enough to warrant an update
	var camera_movement = camera.global_position.distance_to(last_camera_position)
	if camera_movement < update_threshold:
		return
	
	# Store previous camera position for movement calculation
	var previous_camera_position = last_camera_position
	last_camera_position = camera.global_position
	
	# Update all background planes
	_update_background_planes(previous_camera_position)

func _update_background_planes(previous_camera_position: Vector3):
	"""Update all background planes with parallax effect"""
	
	var camera_movement = camera.global_position - previous_camera_position
	
	for plane_data in background_planes:
		var plane = plane_data.plane
		var parallax_factor = plane_data.parallax_factor
		var base_position = plane_data.base_position
		
		# Calculate parallax movement (only X component for horizontal parallax)
		var parallax_movement = Vector3(camera_movement.x * parallax_factor, 0, 0)
		
		# Accumulate total offset
		plane_data.total_offset += parallax_movement
		
		# Apply parallax effect (planes move opposite to camera for depth effect)
		plane.position = base_position - plane_data.total_offset

func update_parallax():
	"""Update parallax effect (called by course manager)"""
	if not camera:
		return
	
	# Check if camera moved enough to warrant an update
	var camera_movement = camera.global_position.distance_to(last_camera_position)
	if camera_movement < update_threshold:
		return
	
	# Store previous camera position for movement calculation
	var previous_camera_position = last_camera_position
	last_camera_position = camera.global_position
	
	# Update all background planes
	_update_background_planes(previous_camera_position)

func reset_layer_offsets():
	"""Reset all background layer offsets (called when camera is repositioned)"""
	for plane_data in background_planes:
		plane_data.total_offset = Vector3.ZERO
		plane_data.plane.position = plane_data.base_position
	
	print("✓ Reset all 3D background layer offsets")

func set_camera_reference(new_camera: Camera3D):
	"""Set a new camera reference"""
	camera = new_camera
	if camera:
		last_camera_position = camera.global_position
		reset_layer_offsets()
		print("✓ 3D Background camera reference updated")

func get_background_info() -> Dictionary:
	"""Get information about background system for debugging"""
	return {
		"plane_count": background_planes.size(),
		"camera_position": camera.global_position if camera else Vector3.ZERO,
		"last_camera_position": last_camera_position
	} 