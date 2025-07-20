extends Node
class_name Course3DManager

# Course3DManager - Main orchestrator for 3D golf course
# Optimized, modular architecture based on 2D lessons learned

signal course_initialized
signal game_phase_changed(new_phase: String)
signal player_moved(new_position: Vector3)
signal ball_launched(ball: Node3D)

# Core 3D managers
var grid_3d_manager: Node = null
var player_3d_manager: Node = null
var camera_3d_manager: Node = null
var map_3d_manager: Node = null
var background_3d_manager: Node = null
var ui_3d_manager: Node = null
var launch_3d_manager: Node = null
var game_state_3d_manager: Node = null
var sound_3d_manager: Node = null

# 3D scene references
var camera_3d: Camera3D = null
var world_container: Node3D = null
var obstacle_container: Node3D = null
var ui_layer: Control = null

# Game settings
var grid_size := Vector2i(50, 50)
var cell_size: int = 48
var current_game_phase: String = "initializing"

# Performance optimization
var frame_count: int = 0
var update_frequency: int = 2  # Update every N frames

func _ready():
	print("🔧 Course3DManager initializing...")
	add_to_group("course_3d")
	
	# Initialize all 3D managers
	_initialize_3d_managers()
	
	# Setup 3D world
	_setup_3d_world()
	
	# Connect signals
	_connect_manager_signals()
	
	# Start game flow
	_start_game_flow()
	
	print("✓ Course3DManager initialized successfully")

func _initialize_3d_managers():
	"""Initialize all 3D managers in optimal order"""
	
	# 1. Game State Manager (needed by others)
	game_state_3d_manager = preload("res://3D/3DManagers/GameState3DManager.gd").new()
	add_child(game_state_3d_manager)
	
	# 2. Sound Manager
	sound_3d_manager = preload("res://3D/3DManagers/Sound3DManager.gd").new()
	add_child(sound_3d_manager)
	
	# 3. Map Manager (provides layout data)
	map_3d_manager = preload("res://3D/3DManagers/Map3DManager.gd").new()
	add_child(map_3d_manager)
	
	# 4. Grid Manager (creates 3D grid floor)
	grid_3d_manager = preload("res://3D/3DManagers/Grid3DManager.gd").new()
	add_child(grid_3d_manager)
	
	# 5. Background Manager (3D parallax system)
	background_3d_manager = preload("res://3D/Background3DManager.gd").new()
	add_child(background_3d_manager)
	
	# 6. Camera Manager (3D camera system)
	camera_3d_manager = preload("res://3D/Camera3DManager.gd").new()
	add_child(camera_3d_manager)
	
	# 7. Player Manager (3D player system)
	player_3d_manager = preload("res://3D/3DManagers/Player3DManager.gd").new()
	add_child(player_3d_manager)
	
	# 8. Launch Manager (3D ball physics)
	launch_3d_manager = preload("res://3D/3DManagers/Launch3DManager.gd").new()
	add_child(launch_3d_manager)
	
	# 9. UI Manager (3D UI system)
	ui_3d_manager = preload("res://3D/3DManagers/UI3DManager.gd").new()
	add_child(ui_3d_manager)
	
	print("✓ All 3D managers initialized")

func _setup_3d_world():
	"""Setup the 3D world with all components"""
	
	# Verify scene references are set
	if not world_container:
		print("⚠ World container not set, creating fallback")
		world_container = Node3D.new()
		world_container.name = "WorldContainer"
		get_parent().add_child(world_container)
	
	if not camera_3d:
		print("⚠ Camera3D not set, creating fallback")
		camera_3d = Camera3D.new()
		camera_3d.name = "Camera3D"
		camera_3d.position = Vector3(0, 200, 300)
		camera_3d.rotation_degrees = Vector3(-30, 0, 0)
		get_parent().add_child(camera_3d)
	
	if not ui_layer:
		print("⚠ UI layer not set, creating fallback")
		ui_layer = Control.new()
		ui_layer.name = "UILayer"
		get_parent().add_child(ui_layer)
	
	# Setup grid floor
	grid_3d_manager.setup(grid_size, cell_size, world_container)
	
	# Setup background system
	background_3d_manager.setup(camera_3d, world_container)
	
	# Setup camera system
	camera_3d_manager.setup(camera_3d, player_3d_manager, grid_3d_manager, background_3d_manager, cell_size)
	
	# Setup player system
	player_3d_manager.setup(grid_3d_manager, map_3d_manager, camera_3d_manager, cell_size)
	
	# Setup launch system
	launch_3d_manager.setup(player_3d_manager, camera_3d_manager, world_container, cell_size)
	
	# Setup UI system
	ui_3d_manager.setup(ui_layer, self)
	
	print("✓ 3D world setup complete")

func _connect_manager_signals():
	"""Connect all manager signals for coordinated game flow"""
	
	# Player signals
	player_3d_manager.player_moved.connect(_on_player_moved)
	player_3d_manager.player_ready.connect(_on_player_ready)
	
	# Camera signals
	camera_3d_manager.camera_moved.connect(_on_camera_moved)
	
	# Launch signals
	launch_3d_manager.ball_launched.connect(_on_ball_launched)
	launch_3d_manager.ball_landed.connect(_on_ball_landed)
	
	# Game state signals
	game_state_3d_manager.phase_changed.connect(_on_game_phase_changed)
	
	# UI signals
	ui_3d_manager.ui_action.connect(_on_ui_action)
	
	print("✓ All manager signals connected")

func _start_game_flow():
	"""Start the main game flow"""
	
	# Load initial map
	var initial_layout = map_3d_manager.load_initial_map()
	
	# Build 3D world from layout
	_build_3d_world_from_layout(initial_layout)
	
	# Position camera on pin
	var pin_position = map_3d_manager.get_pin_position()
	camera_3d_manager.position_camera_on_pin(pin_position)
	
	# Create player
	player_3d_manager.create_player()
	
	# Set initial game phase
	game_state_3d_manager.set_phase(GameState3DManager.GamePhase.READY)
	
	# Emit initialization complete
	course_initialized.emit()
	
	print("✓ Game flow started")

func _build_3d_world_from_layout(layout: Array):
	"""Build 3D world objects from layout"""
	
	print("🏗️ Building 3D world from layout...")
	print("📊 Layout size:", layout.size(), "x", layout[0].size() if layout.size() > 0 else 0)
	
	# Clear existing obstacles and old ground planes
	_clear_obstacles()
	_clear_old_ground_planes()
	
	# Create textured ground plane from layout (this replaces the grid floor)
	_create_layout_ground_texture(layout)
	
	# Only create 3D objects for special items (trees, tee, hole, etc.)
	var objects_created = 0
	var tile_counts = {}
	
	for y in range(layout.size()):
		for x in range(layout[y].size()):
			var code = layout[y][x]
			var world_pos = _grid_to_world_position(Vector2i(x, y))
			
			# Count tile types
			if not tile_counts.has(code):
				tile_counts[code] = 0
			tile_counts[code] += 1
			
			# Only create 3D objects for special items, not ground tiles
			if code in ["T", "P", "H"]:  # Trees, Tee, Hole
				print("Creating", code, "at grid", Vector2i(x, y), "world", world_pos)
				_create_3d_object(code, world_pos, Vector2i(x, y))
				objects_created += 1
	
	print("📊 Tile counts:", tile_counts)
	print("✅ Created", objects_created, "3D objects from layout")

func _create_layout_ground_texture(layout: Array):
	"""Create a textured ground plane from the layout data"""
	
	# Load tile textures
	var grass_texture = load("res://Obstacles/Grass.png")
	var fairway_texture = load("res://Obstacles/Fairway.png")
	var green_texture = load("res://Obstacles/Green.png")
	var rough_texture = load("res://Obstacles/RoughGrass.png")
	var sand_texture = load("res://Obstacles/Sand.png")
	var water_texture = load("res://Obstacles/Water.png")
	var tee_texture = load("res://Obstacles/Tee.png")
	
	# Create a large image for the entire layout
	var layout_width = layout[0].size()
	var layout_height = layout.size()
	var tile_size = 64  # Size of each tile in the texture
	var image_width = layout_width * tile_size
	var image_height = layout_height * tile_size
	
	var layout_image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	
	# Fill the image with tiles based on layout
	for y in range(layout_height):
		for x in range(layout_width):
			var tile_code = layout[y][x]
			var tile_texture = _get_tile_texture(tile_code, grass_texture, fairway_texture, green_texture, rough_texture, sand_texture, water_texture, tee_texture)
			
			if tile_texture:
				# Copy the tile texture to the layout image
				var tile_image = tile_texture.get_image()
				var dest_x = x * tile_size
				var dest_y = y * tile_size
				
				# Resize tile to fit our tile size
				tile_image.resize(tile_size, tile_size, Image.INTERPOLATE_LANCZOS)
				
				# Copy tile to layout image
				for ty in range(tile_size):
					for tx in range(tile_size):
						var pixel = tile_image.get_pixel(tx, ty)
						layout_image.set_pixel(dest_x + tx, dest_y + ty, pixel)
	
	# Create texture from the layout image
	var layout_texture = ImageTexture.create_from_image(layout_image)
	
	# Create the ground plane with the layout texture
	_create_ground_plane(layout_texture, layout_width, layout_height, tile_size)
	
	print("✓ Created layout ground texture")

func _create_ground_plane(layout_texture: Texture2D, layout_width: int, layout_height: int, tile_size: int):
	"""Create the ground plane with the layout texture"""
	
	# Remove any existing ground plane
	if grid_3d_manager.grid_floor:
		grid_3d_manager.grid_floor.queue_free()
		grid_3d_manager.grid_floor = null
	
	# Create plane mesh for the layout
	var plane_mesh = PlaneMesh.new()
	var plane_width = layout_width * tile_size
	var plane_height = layout_height * tile_size
	plane_mesh.size = Vector2(plane_width, plane_height)
	
	# Create material with the layout texture
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_texture = layout_texture
	
	# Create ground plane mesh instance
	var ground_plane = MeshInstance3D.new()
	ground_plane.mesh = plane_mesh
	ground_plane.material_override = ground_material
	ground_plane.position = Vector3(0, 0, 0)
	ground_plane.name = "LayoutGroundPlane"
	
	# Add to world container
	if world_container:
		world_container.add_child(ground_plane)
		grid_3d_manager.grid_floor = ground_plane
		print("✓ Created ground plane with layout texture")
	else:
		print("⚠ World container not available for ground plane")

func _get_tile_texture(tile_code: String, grass_tex, fairway_tex, green_tex, rough_tex, sand_tex, water_tex, tee_tex):
	"""Get the appropriate texture for a tile code"""
	match tile_code:
		"G": return green_tex      # Green (putting area)
		"F": return fairway_tex    # Fairway (main playing area)
		"R": return rough_tex      # Rough
		"S": return sand_tex       # Sand
		"W": return water_tex      # Water
		"P": return tee_tex        # Tee box
		"B": return grass_tex      # Base grass
		"Tee": return tee_tex      # Tee box
		"Base": return grass_tex   # Base grass
		_: return grass_tex        # Default to grass

func _clear_old_ground_planes():
	"""Clear any old ground planes or grid floors"""
	if world_container:
		# Remove any old grid floors or ground planes
		for child in world_container.get_children():
			if child is MeshInstance3D and child.name != "LayoutGroundPlane":
				print("🗑️ Removing old ground plane:", child.name)
				child.queue_free()
	
	# Also clear the grid manager's reference
	if grid_3d_manager and grid_3d_manager.grid_floor:
		grid_3d_manager.grid_floor = null

func _clear_obstacles():
	"""Clear all existing obstacles"""
	if not obstacle_container:
		print("⚠ Obstacle container not set, creating fallback")
		obstacle_container = Node3D.new()
		obstacle_container.name = "ObstacleContainer"
		obstacle_container.position = Vector3.ZERO  # Ensure it's at origin
		get_parent().add_child(obstacle_container)
		return
	
	for child in obstacle_container.get_children():
		child.queue_free()

func _create_3d_object(code: String, world_pos: Vector3, grid_pos: Vector2i):
	"""Create a 3D object based on layout code"""
	
	match code:
		"T":  # Tree
			_create_billboard_sprite("res://Obstacles/Tree.png", world_pos, "tree")
		"P":  # Player start (Tee box)
			player_3d_manager.set_start_position(grid_pos)
			# Create tee box visual
			_create_billboard_sprite("res://Obstacles/Tee.png", world_pos, "tee")
		"H":  # Hole
			_create_billboard_sprite("res://Obstacles/Pinhole.png", world_pos, "hole")
		"G":  # Grass (no sprite needed)
			pass
		"W":  # Water
			_create_billboard_sprite("res://Obstacles/Water.png", world_pos, "water")
		"S":  # Sand
			_create_billboard_sprite("res://Obstacles/Sand.png", world_pos, "sand")
		"F":  # Fairway (grass)
			pass
		"R":  # Rough (grass)
			pass
		"Base": # Base/grass
			pass

func _create_billboard_sprite(texture_path: String, position: Vector3, object_type: String):
	"""Create a billboard sprite for 3D objects"""
	
	# Ensure obstacle container exists
	if not obstacle_container:
		print("⚠ Obstacle container not set, creating fallback")
		obstacle_container = Node3D.new()
		obstacle_container.name = "ObstacleContainer"
		get_parent().add_child(obstacle_container)
	
	var texture = load(texture_path)
	if not texture:
		print("⚠ Could not load texture: ", texture_path)
		return
	
	var sprite_3d = Sprite3D.new()
	sprite_3d.texture = texture
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.pixel_size = 0.05  # Smaller size for better visibility
	sprite_3d.position = position
	sprite_3d.position.y = 0.5  # Just slightly above ground
	
	# Add metadata
	sprite_3d.set_meta("object_type", object_type)
	sprite_3d.set_meta("grid_position", _world_to_grid_position(position))
	
	obstacle_container.add_child(sprite_3d)
	
	print("✓ Created", object_type, "at", position)

func _grid_to_world_position(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to 3D world position"""
	var world_x = grid_pos.x * cell_size - (grid_size.x * cell_size) / 2
	var world_z = grid_pos.y * cell_size - (grid_size.y * cell_size) / 2
	return Vector3(world_x, 0, world_z)

func _world_to_grid_position(world_pos: Vector3) -> Vector2i:
	"""Convert 3D world position to grid position"""
	var grid_x = int((world_pos.x + (grid_size.x * cell_size) / 2) / cell_size)
	var grid_z = int((world_pos.z + (grid_size.y * cell_size) / 2) / cell_size)
	return Vector2i(grid_x, grid_z)

# Signal handlers
func _on_player_moved(new_position: Vector3):
	"""Handle player movement"""
	player_moved.emit(new_position)
	
	# Update camera to follow player
	camera_3d_manager.update_camera_to_player()
	
	# Update game state
	game_state_3d_manager.set_phase(GameState3DManager.GamePhase.PLAYER_MOVING)

func _on_player_ready():
	"""Handle player ready state"""
	game_state_3d_manager.set_phase(GameState3DManager.GamePhase.READY)
	ui_3d_manager.show_game_ui()

func _on_camera_moved():
	"""Handle camera movement"""
	# Update background parallax
	background_3d_manager.update_parallax()

func _on_ball_launched(ball: Node3D):
	"""Handle ball launch"""
	ball_launched.emit(ball)
	game_state_3d_manager.set_phase(GameState3DManager.GamePhase.BALL_FLYING)
	camera_3d_manager.start_ball_tracking(ball)

func _on_ball_landed(ball: Node3D):
	"""Handle ball landing"""
	game_state_3d_manager.set_phase(GameState3DManager.GamePhase.BALL_LANDED)
	camera_3d_manager.stop_ball_tracking()
	
	# Check if ball is in hole
	if _is_ball_in_hole(ball):
		_on_hole_completed()
	else:
		game_state_3d_manager.set_phase(GameState3DManager.GamePhase.READY)

func _on_game_phase_changed(new_phase: String):
	"""Handle game phase changes"""
	current_game_phase = new_phase
	game_phase_changed.emit(new_phase)
	
	# Update UI based on phase
	ui_3d_manager.update_ui_for_phase(new_phase)

func _on_ui_action(action: String, data: Dictionary):
	"""Handle UI actions"""
	match action:
		"move_player":
			player_3d_manager.move_player(data.direction)
		"launch_ball":
			launch_3d_manager.launch_ball(data.power, data.direction)
		"zoom_camera":
			camera_3d_manager.set_zoom_level(data.zoom_level)

func _is_ball_in_hole(ball: Node3D) -> bool:
	"""Check if ball is in the hole"""
	var ball_grid_pos = _world_to_grid_position(ball.global_position)
	var hole_positions = map_3d_manager.get_hole_positions()
	
	for hole_pos in hole_positions:
		if ball_grid_pos == hole_pos:
			return true
	return false

func _on_hole_completed():
	"""Handle hole completion"""
	game_state_3d_manager.set_phase(GameState3DManager.GamePhase.HOLE_COMPLETED)
	sound_3d_manager.play_hole_complete_sound()
	ui_3d_manager.show_hole_complete_ui()
	
	# Load next hole after delay
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(_load_next_hole)

func _load_next_hole():
	"""Load the next hole"""
	var next_layout = map_3d_manager.load_next_hole()
	if next_layout:
		_build_3d_world_from_layout(next_layout)
		player_3d_manager.reset_player_position()
		game_state_3d_manager.set_phase(GameState3DManager.GamePhase.READY)
	else:
		# Game completed
		game_state_3d_manager.set_phase(GameState3DManager.GamePhase.GAME_COMPLETED)
		ui_3d_manager.show_game_complete_ui()

# Public API
func get_current_phase() -> String:
	return current_game_phase

func get_game_state_manager() -> Node:
	"""Get the game state manager for direct access"""
	return game_state_3d_manager

func get_player_position() -> Vector3:
	return player_3d_manager.get_player_position()

func get_camera_position() -> Vector3:
	return camera_3d.position

func set_camera_position(position: Vector3):
	camera_3d.position = position

func get_manager(manager_name: String) -> Node:
	"""Get a specific manager by name"""
	match manager_name:
		"grid": return grid_3d_manager
		"player": return player_3d_manager
		"camera": return camera_3d_manager
		"map": return map_3d_manager
		"background": return background_3d_manager
		"ui": return ui_3d_manager
		"launch": return launch_3d_manager
		"game_state": return game_state_3d_manager
		"sound": return sound_3d_manager
		_: return null

# Performance optimization
func _process(delta):
	"""Optimized process function"""
	frame_count += 1
	
	# Only update every N frames for performance
	if frame_count % update_frequency != 0:
		return
	
	# Update managers that need frequent updates
	if player_3d_manager:
		player_3d_manager.update(delta)
	
	if camera_3d_manager:
		camera_3d_manager.update(delta)
	
	if launch_3d_manager:
		launch_3d_manager.update(delta) 
