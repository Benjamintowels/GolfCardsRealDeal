extends Node

# Boss Manager - handles Boss encounters on holes 9 and 18

signal boss_encounter_started(boss_type: String, hole_number: int)
signal boss_encounter_ended(boss_type: String, hole_number: int)

# Boss encounter configuration
var boss_holes: Array[int] = [0, 8, 17]  # Holes where bosses appear (0-based indexing: 0=hole1, 8=hole9, 17=hole18)
var current_boss: Node = null
var current_hole: int = 0

# Boss types and their configurations
var boss_configs: Dictionary = {
	"wraith": {
		"scene_path": "res://NPC/Bosses/Wraith.tscn",
		"spawn_position": Vector2(0, 0),  # Will be set to green center
		"health": 200,
		"movement_range": 10
	}
}

# GangMember configuration for boss encounters
var gang_member_config: Dictionary = {
	"scene_path": "res://NPC/Gang/GangMember.tscn",
	"count": 3,  # Number of GangMembers to spawn on fairway
	"health": 30,
	"movement_range": 3
}

func _ready():
	# Connect to course events
	var course = _find_course_script()
	if course:
		print("✓ BossManager connected to course")
		# Check current hole immediately
		_check_current_hole(course.current_hole)
	else:
		print("✗ ERROR: BossManager could not find course")

func _check_current_hole(hole_number: int) -> void:
	"""Check if the current hole should have a boss encounter"""
	print("BossManager: Checking hole", hole_number, "(game hole", hole_number + 1, ")")
	print("BossManager: Boss holes array:", boss_holes)
	current_hole = hole_number
	
	# Check if this is a boss hole
	if hole_number in boss_holes:
		print("BossManager: Boss hole detected! Starting boss encounter...")
		_start_boss_encounter(hole_number)
	else:
		print("BossManager: Not a boss hole, clearing any existing boss")
		# Clear any existing boss
		_clear_boss_encounter()

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			print("Found course_1.gd script at: ", current_node.name)
			return current_node
		current_node = current_node.get_parent()
	
	print("ERROR: Could not find course_1.gd script in scene tree!")
	return null

func on_hole_changed(hole_number: int) -> void:
	"""Handle hole changes and check for boss encounters - called by course system"""
	print("BossManager: Hole changed to", hole_number)
	_check_current_hole(hole_number)

func _start_boss_encounter(hole_number: int) -> void:
	"""Start a boss encounter on the specified hole"""
	print("BossManager: Starting boss encounter on hole", hole_number)
	
	# Wait a frame to ensure the course is fully built
	await get_tree().process_frame
	
	# Determine boss type based on hole
	var boss_type = _get_boss_type_for_hole(hole_number)
	
	# Spawn the boss first
	_spawn_boss(boss_type, hole_number)
	
	# Wait a frame to ensure boss is placed
	await get_tree().process_frame
	
	# Spawn GangMembers on the fairway (avoiding boss position)
	_spawn_gang_members(hole_number)
	
	# Emit signal
	boss_encounter_started.emit(boss_type, hole_number)

func _get_boss_type_for_hole(hole_number: int) -> String:
	"""Get the boss type for a specific hole"""
	# For now, Wraith appears on holes 1, 9, and 18 (0-based indexing: 0=hole1, 8=hole9, 17=hole18)
	# This can be expanded later for different bosses
	return "wraith"

func _spawn_boss(boss_type: String, hole_number: int) -> void:
	"""Spawn a boss on the specified hole"""
	print("BossManager: Attempting to spawn boss type:", boss_type, "on hole:", hole_number)
	
	if not boss_type in boss_configs:
		print("✗ ERROR: Unknown boss type:", boss_type)
		return
	
	var config = boss_configs[boss_type]
	var boss_scene = load(config.scene_path)
	
	if not boss_scene:
		print("✗ ERROR: Could not load boss scene:", config.scene_path)
		return
	
	print("✓ Boss scene loaded successfully")
	
	# Create boss instance
	current_boss = boss_scene.instantiate()
	print("✓ Boss instance created")
	
	# Position the boss on the green
	var green_center = _get_green_center_position(hole_number)
	if green_center != Vector2.ZERO:
		current_boss.global_position = green_center
		print("✓ Boss positioned at green center:", green_center)
	else:
		# Fallback position
		current_boss.global_position = Vector2(0, 0)
		print("⚠ Using fallback position for boss")
	
	# Add boss to the scene
	var course = _find_course_script()
	if course:
		course.add_child(current_boss)
		print("✓ Boss added to scene")
		
		# Connect to boss death signal
		if current_boss.has_signal("boss_defeated"):
			current_boss.boss_defeated.connect(_on_boss_defeated)
			print("✓ Boss defeated signal connected")
	else:
		print("✗ ERROR: Could not add boss to scene")

func _spawn_gang_members(hole_number: int) -> void:
	"""Spawn GangMembers on the fairway for the boss encounter"""
	print("BossManager: Spawning GangMembers on fairway")
	
	var gang_scene = load(gang_member_config.scene_path)
	if not gang_scene:
		print("✗ ERROR: Could not load GangMember scene")
		return
	
	var course = _find_course_script()
	if not course:
		print("✗ ERROR: Could not find course for GangMember spawning")
		return
	
	# Get fairway positions (avoiding boss position)
	var fairway_positions = _get_fairway_positions(hole_number)
	
	# Get boss position to avoid overlap
	var boss_position = Vector2.ZERO
	if current_boss:
		boss_position = current_boss.global_position
		print("DEBUG: Boss position to avoid:", boss_position)
	
	# Spawn GangMembers
	var spawned_count = 0
	for i in range(gang_member_config.count):
		if i < fairway_positions.size():
			var spawn_pos = fairway_positions[i]
			
			# Check if this position is too close to the boss
			if current_boss and spawn_pos.distance_to(boss_position) < 100:
				print("DEBUG: Skipping position too close to boss:", spawn_pos)
				continue
			
			var gang_member = gang_scene.instantiate()
			gang_member.global_position = spawn_pos
			
			# Set GangMember properties
			gang_member.max_health = gang_member_config.health
			gang_member.current_health = gang_member_config.health
			gang_member.movement_range = gang_member_config.movement_range
			
			course.add_child(gang_member)
			spawned_count += 1
			print("✓ GangMember spawned at:", spawn_pos)
	
	print("✓ Spawned", spawned_count, "GangMembers for boss encounter")

func _get_green_center_position(hole_number: int) -> Vector2:
	"""Get the center position of the green for the specified hole"""
	var course = _find_course_script()
	if not course:
		print("✗ ERROR: Could not find course for green position lookup")
		return Vector2.ZERO
	
	# Get the hole layout from the course
	var GolfCourseLayout = preload("res://Maps/GolfCourseLayout.gd")
	var layout = GolfCourseLayout.get_hole_layout(hole_number)
	
	if not layout or layout.size() == 0:
		print("✗ ERROR: Could not get layout for hole", hole_number)
		return Vector2.ZERO
	
	# Find all green positions in the layout
	var green_positions: Array[Vector2i] = []
	for y in range(layout.size()):
		for x in range(layout[y].size()):
			if layout[y][x] == "G":
				green_positions.append(Vector2i(x, y))
	
	print("DEBUG: Found", green_positions.size(), "green tiles in hole", hole_number)
	print("DEBUG: Green tile positions:", green_positions)
	
	if green_positions.size() == 0:
		print("✗ ERROR: No green tiles found in hole", hole_number)
		return Vector2.ZERO
	
	# Calculate the center of all green tiles
	var center_x = 0
	var center_y = 0
	for pos in green_positions:
		center_x += pos.x
		center_y += pos.y
	
	center_x = center_x / green_positions.size()
	center_y = center_y / green_positions.size()
	
	print("DEBUG: Calculated center - X:", center_x, "Y:", center_y)
	
	# Get the actual cell size from the course
	var cell_size = 48  # Default cell size
	if course and "cell_size" in course:
		cell_size = course.cell_size
		print("DEBUG: Using cell size from course:", cell_size)
	else:
		print("DEBUG: Using default cell size:", cell_size)
	
	var world_pos = Vector2(center_x * cell_size, center_y * cell_size)
	
	# Add half cell size to center the boss on the tile
	world_pos += Vector2(cell_size / 2, cell_size / 2)
	
	# Get the obstacle layer position to adjust for camera offset
	var obstacle_layer = course.get_node_or_null("CameraContainer/ObstacleLayer")
	if obstacle_layer:
		world_pos += obstacle_layer.global_position
		print("DEBUG: Adjusted for obstacle layer position:", obstacle_layer.global_position)
	
	print("✓ Found green center for hole", hole_number, "at world position:", world_pos)
	return world_pos

func _get_fairway_positions(hole_number: int) -> Array[Vector2]:
	"""Get positions on the fairway for GangMembers"""
	var course = _find_course_script()
	if not course:
		print("✗ ERROR: Could not find course for fairway position lookup")
		return []
	
	# Get the hole layout from the course
	var GolfCourseLayout = preload("res://Maps/GolfCourseLayout.gd")
	var layout = GolfCourseLayout.get_hole_layout(hole_number)
	
	if not layout or layout.size() == 0:
		print("✗ ERROR: Could not get layout for hole", hole_number)
		return []
	
	# Find all fairway positions in the layout
	var fairway_positions: Array[Vector2i] = []
	for y in range(layout.size()):
		for x in range(layout[y].size()):
			if layout[y][x] == "F":  # Fairway tiles
				fairway_positions.append(Vector2i(x, y))
	
	if fairway_positions.size() == 0:
		print("✗ ERROR: No fairway tiles found in hole", hole_number)
		return []
	
	# Convert to world positions
	var cell_size = 48  # Default cell size
	var world_positions: Array[Vector2] = []
	
	# Get the obstacle layer position to adjust for camera offset
	var obstacle_layer = course.get_node_or_null("CameraContainer/ObstacleLayer")
	var layer_offset = Vector2.ZERO
	if obstacle_layer:
		layer_offset = obstacle_layer.global_position
		print("DEBUG: Fairway positions - obstacle layer offset:", layer_offset)
	
	# Take up to 3 fairway positions for GangMembers
	var max_positions = min(3, fairway_positions.size())
	for i in range(max_positions):
		var pos = fairway_positions[i]
		var world_pos = Vector2(pos.x * cell_size, pos.y * cell_size)
		world_pos += Vector2(cell_size / 2, cell_size / 2)
		world_pos += layer_offset
		world_positions.append(world_pos)
	
	print("✓ Found", world_positions.size(), "fairway positions for hole", hole_number)
	return world_positions

func _clear_boss_encounter() -> void:
	"""Clear the current boss encounter"""
	if current_boss:
		print("BossManager: Clearing boss encounter")
		current_boss.queue_free()
		current_boss = null

func _on_boss_defeated() -> void:
	"""Handle boss defeat"""
	print("BossManager: Boss defeated!")
	
	# Emit signal
	boss_encounter_ended.emit("wraith", current_hole)
	
	# Clear the boss
	_clear_boss_encounter()

func is_boss_hole(hole_number: int) -> bool:
	"""Check if a hole is a boss hole"""
	return hole_number in boss_holes

func get_current_boss() -> Node:
	"""Get the current boss instance"""
	return current_boss
