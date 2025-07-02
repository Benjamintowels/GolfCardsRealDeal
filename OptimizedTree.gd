extends Node

# Optimized Tree collision detection system
# Reduces performance impact by using spatial partitioning and update throttling

var tree_update_cooldown: float = 0.2  # Update every 0.2 seconds instead of every frame
var last_update_time: float = 0.0
var nearby_balls_cache: Array = []
var cache_valid: bool = false
var cache_cooldown: float = 0.5  # Cache is valid for 0.5 seconds

# Spatial partitioning for ball detection
var ball_spatial_grid: Dictionary = {}
var grid_cell_size: float = 200.0  # Larger cells for ball detection

func _ready():
	print("Optimized Tree collision system initialized")

func update_tree_collisions(delta: float):
	"""Update tree collision detection with throttling"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Only update if enough time has passed
	if current_time - last_update_time < tree_update_cooldown:
		return
	
	last_update_time = current_time
	
	# Update spatial grid for balls
	update_ball_spatial_grid()
	
	# Process tree collisions
	process_tree_collisions()

func update_ball_spatial_grid():
	"""Update the spatial grid with current ball positions"""
	ball_spatial_grid.clear()
	
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if ball and (ball.name == "GolfBall" or ball.name == "GhostBall"):
			var grid_pos = get_grid_position(ball.global_position)
			if not ball_spatial_grid.has(grid_pos):
				ball_spatial_grid[grid_pos] = []
			ball_spatial_grid[grid_pos].append(ball)

func get_grid_position(world_pos: Vector2) -> Vector2i:
	"""Convert world position to grid position"""
	return Vector2i(floor(world_pos.x / grid_cell_size), floor(world_pos.y / grid_cell_size))

func process_tree_collisions():
	"""Process collisions for all trees using spatial partitioning"""
	var trees = get_tree().get_nodes_in_group("trees")
	
	for tree in trees:
		if not tree or not is_instance_valid(tree):
			continue
		
		# Get nearby balls using spatial partitioning
		var nearby_balls = get_nearby_balls(tree.global_position)
		
		# Process collision for this tree
		process_single_tree_collision(tree, nearby_balls)

func get_nearby_balls(tree_position: Vector2) -> Array:
	"""Get balls near a tree using spatial partitioning"""
	var nearby_balls = []
	var tree_grid = get_grid_position(tree_position)
	
	# Check current grid cell and adjacent cells
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_grid = tree_grid + Vector2i(dx, dy)
			if ball_spatial_grid.has(check_grid):
				nearby_balls.append_array(ball_spatial_grid[check_grid])
	
	return nearby_balls

func process_single_tree_collision(tree: Node2D, nearby_balls: Array):
	"""Process collision detection for a single tree"""
	var tree_center = tree.global_position
	var trunk_radius = 120.0
	
	for ball in nearby_balls:
		if not ball or not is_instance_valid(ball):
			continue
		
		# Get ball ground position
		var ball_ground_pos = ball.global_position
		if ball.has_method("get_ground_position"):
			ball_ground_pos = ball.get_ground_position()
		
		# Check distance to tree trunk
		var distance_to_trunk = ball_ground_pos.distance_to(tree_center)
		if distance_to_trunk > trunk_radius:
			continue
		
		# Get ball height
		var ball_height = 0.0
		if ball.has_method("get_height"):
			ball_height = ball.get_height()
		elif "z" in ball:
			ball_height = ball.z
		
		var tree_height = 400.0
		var min_leaves_height = 60.0
		
		# Check if ball should trigger leaves rustle
		if ball_height > min_leaves_height and ball_height < tree_height:
			check_and_play_leaves_sound(tree, ball)

func check_and_play_leaves_sound(tree: Node2D, ball: Node2D):
	"""Check if leaves sound should be played and play it"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var ball_id = ball.get_instance_id()
	
	# Check if we haven't played the sound recently for this ball
	if not ball.has_meta("last_leaves_rustle_time") or ball.get_meta("last_leaves_rustle_time") + 0.5 < current_time:
		var rustle = tree.get_node_or_null("LeavesRustle")
		if rustle:
			rustle.play()
			print("✓ LeavesRustle sound played - ball passing through leaves near trunk")
			# Mark when we last played the sound for this ball
			ball.set_meta("last_leaves_rustle_time", current_time)

func clear_spatial_grid():
	"""Clear the spatial grid to free memory"""
	ball_spatial_grid.clear() 