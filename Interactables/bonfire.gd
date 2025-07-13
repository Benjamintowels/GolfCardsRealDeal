extends Node2D

# A rest site that you activate with fire and then you can rest there

@onready var bonfire_flame: Sprite2D = $BonfireFlame
@onready var bonfire_area: Area2D = $BonfireArea2D
@onready var top_height_marker: Marker2D = $TopHeight
@onready var ysort_point: Marker2D = $YsortPoint

# Flame animation properties
var flame_frames: Array[Texture2D] = []
var current_frame_index: int = 0
var animation_timer: float = 0.0
var animation_speed: float = 0.15  # Time between frame changes
var scale_variation: float = 0.1   # How much the flame scales
var base_scale: Vector2 = Vector2(1.0, 1.0)
var opacity_variation: float = 0.2 # How much opacity changes
var base_opacity: float = 1.0

# Height properties
var bonfire_height: float = 10.0  # Height from base to top

# Activation properties
var is_active: bool = false  # Whether the bonfire is lit
var cell_size: int = 48  # Tile size for grid calculations
var map_manager: Node = null  # Reference to map manager for tile checking

# Lighter dialog properties
var lighter_dialog: Control = null
var lighter_dialog_active: bool = false

func _ready():
	# Add to groups for Y-sorting and optimization
	add_to_group("visual_objects")
	add_to_group("ysort_objects")
	add_to_group("interactables")
	
	setup_flame_animation()
	setup_collision_detection()
	
	# Initialize Y-sorting
	_update_ysort()
	
	# Find map manager for tile checking
	_find_map_manager()
	
	# Start inactive
	set_bonfire_active(false)
	
	# Debug output
	print("=== BONFIRE READY DEBUG ===")
	print("Bonfire name:", name)
	print("Bonfire position:", global_position)
	print("Bonfire z_index:", z_index)
	print("Bonfire active:", is_active)
	var base_sprite = get_node_or_null("BonfireBaseSprite")
	print("Base sprite visible:", base_sprite.visible if base_sprite else "null")
	print("Flame sprite visible:", bonfire_flame.visible)
	print("=== END BONFIRE READY DEBUG ===")

func _find_map_manager():
	"""Find the map manager in the scene"""
	var course = get_tree().current_scene
	if course and course.has_node("MapManager"):
		map_manager = course.get_node("MapManager")
		print("Bonfire: Found MapManager")
	else:
		print("Bonfire: MapManager not found")

func setup_flame_animation():
	# Load flame textures
	flame_frames = [
		preload("res://Interactables/BonfireFlame1.png"),
		preload("res://Interactables/BonfireFlame2.png"),
		preload("res://Interactables/BonfireFlame3.png")
	]
	
	# Set initial frame
	if flame_frames.size() > 0:
		bonfire_flame.texture = flame_frames[0]
		bonfire_flame.visible = false  # Start hidden (inactive)
	else:
		print("✗ Bonfire flame frames failed to load")

func setup_collision_detection():
	# Connect collision signals
	bonfire_area.body_entered.connect(_on_body_entered)
	bonfire_area.body_exited.connect(_on_body_exited)

func _process(delta):
	if is_active:
		animate_flame(delta)
	
	# Check for fire tiles nearby
	_check_for_nearby_fire()

func animate_flame(delta):
	animation_timer += delta
	
	# Change frame
	if animation_timer >= animation_speed:
		animation_timer = 0.0
		current_frame_index = (current_frame_index + 1) % flame_frames.size()
		bonfire_flame.texture = flame_frames[current_frame_index]
	
	# Animate scale and opacity
	var time_factor = sin(Time.get_ticks_msec() * 0.003) * 0.5 + 0.5  # 0 to 1 oscillation
	var scale_factor = 1.0 + (time_factor * scale_variation)
	var opacity_factor = base_opacity - (time_factor * opacity_variation)
	
	bonfire_flame.scale = base_scale * scale_factor
	bonfire_flame.modulate = Color(1.0, 0.8, 0.6, opacity_factor)  # Orange-red-yellow tint

func _check_for_nearby_fire():
	"""Check if any adjacent tiles or the bonfire's own tile are on fire"""
	if is_active or not map_manager:
		return
	
	# Get bonfire's tile position
	var bonfire_tile = Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))
	
	# Check if bonfire's own tile is on fire
	if _is_tile_on_fire(bonfire_tile):
		print("Bonfire: Own tile caught fire - activating!")
		set_bonfire_active(true)
		return
	
	# Check adjacent tiles (8-directional)
	var adjacent_positions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, -1),  # Up-right
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	
	for direction in adjacent_positions:
		var check_tile = bonfire_tile + direction
		if _is_tile_on_fire(check_tile):
			print("Bonfire: Adjacent tile caught fire - activating!")
			set_bonfire_active(true)
			return

func _is_tile_on_fire(tile_pos: Vector2i) -> bool:
	"""Check if a tile is currently on fire"""
	# Check for existing fire tiles in the scene
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		if is_instance_valid(fire_tile) and fire_tile.has_method("is_fire_active"):
			if fire_tile.get_tile_position() == tile_pos and fire_tile.is_fire_active():
				return true
	return false

func set_bonfire_active(active: bool):
	"""Set the bonfire's active state"""
	if is_active == active:
		return  # No change
	
	is_active = active
	
	if active:
		# Activate bonfire
		bonfire_flame.visible = true
		print("Bonfire: Activated!")
		
		# Play activation sound
		var bonfire_sound = get_node_or_null("BonfireOn")
		if bonfire_sound and bonfire_sound.stream:
			bonfire_sound.play()
	else:
		# Deactivate bonfire
		bonfire_flame.visible = false
		print("Bonfire: Deactivated!")

func _on_body_entered(body: Node2D):
	if body.has_method("get_ball_height") and body.has_method("get_ball_velocity"):
		handle_ball_collision(body)
	elif body.name == "Player":
		handle_player_entered(body)

func _on_body_exited(body: Node2D):
	# Handle any cleanup when ball leaves bonfire area
	pass

func handle_ball_collision(ball: Node2D):
	var ball_height = ball.get_ball_height()
	var ball_velocity = ball.get_ball_velocity()
	var ball_position = ball.global_position
	
	# Check if ball is in air (above ground level)
	if ball_height > 0:
		# Ball in air - check height against bonfire
		if ball_height < bonfire_height:
			# Ball hits bonfire wall - reflect
			reflect_ball_off_wall(ball, ball_velocity)
		else:
			# Ball passes over bonfire
			ball_passes_over(ball, ball_velocity)
	else:
		# Ball is rolling on ground
		reflect_ball_off_wall(ball, ball_velocity)

func handle_player_entered(player: Node2D):
	"""Handle when player enters bonfire area"""
	if is_active:
		return  # Already active, no need for lighter dialog
	
	# Check if player has lighter equipped
	if _player_has_lighter():
		show_lighter_dialog()

func _player_has_lighter() -> bool:
	"""Check if the player has a Lighter equipped"""
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("has_lighter"):
		return equipment_manager.has_lighter()
	return false

func show_lighter_dialog():
	"""Show dialog asking if player wants to light the bonfire"""
	if lighter_dialog_active:
		return  # Already showing dialog
	
	lighter_dialog_active = true
	
	# Create dialog
	lighter_dialog = Control.new()
	lighter_dialog.name = "LighterDialog"
	lighter_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lighter_dialog.z_index = 1000
	lighter_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	lighter_dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(400, 200)
	main_container.position = Vector2(-200, -100)
	main_container.z_index = 1000
	lighter_dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = -1
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	title.text = "Light Bonfire?"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.ORANGE)
	title.position = Vector2(150, 20)
	title.size = Vector2(100, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = "You have a Lighter equipped.\nWould you like to light this bonfire?"
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.position = Vector2(50, 60)
	message.size = Vector2(300, 60)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(message)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(100, 140)
	button_container.size = Vector2(200, 40)
	main_container.add_child(button_container)
	
	# Yes button
	var yes_button = Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_lighter_yes)
	button_container.add_child(yes_button)
	
	# No button
	var no_button = Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(_on_lighter_no)
	button_container.add_child(no_button)
	
	# Add to UI layer
	var ui_layer = get_tree().current_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(lighter_dialog)
	else:
		get_tree().current_scene.add_child(lighter_dialog)
	
	print("Bonfire: Lighter dialog shown")

func _on_lighter_yes():
	"""Player chose to light the bonfire"""
	print("Bonfire: Player chose to light the bonfire")
	set_bonfire_active(true)
	_close_lighter_dialog()

func _on_lighter_no():
	"""Player chose not to light the bonfire"""
	print("Bonfire: Player chose not to light the bonfire")
	_close_lighter_dialog()

func _close_lighter_dialog():
	"""Close the lighter dialog"""
	if lighter_dialog and is_instance_valid(lighter_dialog):
		lighter_dialog.queue_free()
		lighter_dialog = null
	lighter_dialog_active = false

func reflect_ball_off_wall(ball: Node2D, velocity: Vector2):
	# Simple wall reflection - reverse horizontal velocity
	var reflected_velocity = Vector2(-velocity.x * 0.8, velocity.y)  # Reduce speed slightly
	ball.set_ball_velocity(reflected_velocity)

func ball_passes_over(ball: Node2D, velocity: Vector2):
	# Ball passes over bonfire - no collision, just continue
	# Could add visual effects here
	pass

# Getter methods for external access
func get_bonfire_height() -> float:
	return bonfire_height

func get_top_height_position() -> Vector2:
	return top_height_marker.global_position

func get_ysort_position() -> Vector2:
	return ysort_point.global_position

func get_y_sort_point() -> float:
	"""Get the Y-sort reference point for the bonfire"""
	# Use the YsortPoint marker for consistent Y-sorting
	if ysort_point:
		return ysort_point.global_position.y
	else:
		# Fallback to global position if no YsortPoint marker
		return global_position.y

func get_grid_position() -> Vector2i:
	"""Get the grid position of the bonfire"""
	return Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))

func is_bonfire_active() -> bool:
	"""Check if the bonfire is currently active"""
	return is_active

func _update_ysort():
	"""Update the Bonfire's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")
