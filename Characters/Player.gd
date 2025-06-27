extends CharacterBody2D

signal player_clicked
signal moved_to_tile(new_grid_pos: Vector2i)

var grid_pos: Vector2i
var movement_range: int = 1
var base_mobility: int = 0
var valid_movement_tiles: Array = []
var is_movement_mode: bool = false
var selected_card = null
var obstacle_map = {}
var grid_size: Vector2i
var cell_size: int = 48

# Highlight effect variables
var character_sprite: Sprite2D = null
var highlight_tween: Tween = null

func _ready():
	# Recursively search for the first Sprite2D in any child Node2D
	for child in get_children():
		if child is Node2D:
			for grandchild in child.get_children():
				if grandchild is Sprite2D:
					character_sprite = grandchild
					print("[Player.gd] Found character sprite for highlight:", character_sprite, "Initial modulate:", character_sprite.modulate)
					return
	print("[Player.gd] No character sprite found in Node2D child!")

func get_character_sprite() -> Sprite2D:
	for child in get_children():
		if child is Node2D:
			for grandchild in child.get_children():
				if grandchild is Sprite2D:
					return grandchild
	return null

func show_highlight():
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] show_highlight: No character sprite for highlight!")
		return
	if highlight_tween:
		highlight_tween.kill()
	highlight_tween = create_tween()
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 0, 0.6), 0.3)

func hide_highlight():
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] hide_highlight: No character sprite for highlight!")
		return
	if highlight_tween:
		highlight_tween.kill()
	highlight_tween = create_tween()
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.3)

func force_reset_highlight():
	var sprite = get_character_sprite()
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		if highlight_tween:
			highlight_tween.kill()
	else:
		print("[Player.gd] force_reset_highlight: No character sprite to reset!")

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("player_clicked")

func setup(grid_size_: Vector2i, cell_size_: int, base_mobility_: int, obstacle_map_: Dictionary):
	grid_size = grid_size_
	cell_size = cell_size_
	base_mobility = base_mobility_
	obstacle_map = obstacle_map_
	
	# Create highlight sprite after setup is complete
	print("Setup complete, deferring highlight sprite creation...")
	call_deferred("create_highlight_sprite")

func set_grid_position(pos: Vector2i, ysort_objects: Array = []):
	grid_pos = pos
	self.position = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	if ysort_objects.size() > 0:
		update_z_index_for_ysort(ysort_objects)

func update_z_index_for_ysort(ysort_objects: Array) -> void:
	var in_front_zs = []
	var behind_zs = []
	print("Player grid_pos.y:", grid_pos.y)
	
	# Special case: If player is on shop entrance, always appear in front
	var is_on_shop_entrance = false
	for obj in ysort_objects:
		if not obj.has("grid_pos") or not obj.has("node"):
			continue
		var obj_grid_pos = obj["grid_pos"]
		var obj_node = obj["node"]
		
		# Check if the node is still valid and not freed
		if not obj_node or not is_instance_valid(obj_node):
			continue
			
		var is_shop = obj_node.name == "Shop" or obj_node.get_class() == "Shop"
		if is_shop and grid_pos == obj_grid_pos:
			is_on_shop_entrance = true
			break
	
	# If on shop entrance, always appear in front
	if is_on_shop_entrance:
		z_index = 1000  # Very high z-index to ensure player is always in front
		print("Player on shop entrance - setting z_index to 1000")
		return
	
	for obj in ysort_objects:
		if not obj.has("grid_pos") or not obj.has("node"):
			continue
		var obj_grid_pos = obj["grid_pos"]
		var obj_node = obj["node"]
		
		# Check if the node is still valid and not freed
		if not obj_node or not is_instance_valid(obj_node):
			continue
			
		var is_shop = obj_node.name == "Shop" or obj_node.get_class() == "Shop"
		var x_range = 3 if is_shop else 1
		if abs(obj_grid_pos.x - grid_pos.x) > x_range:
			continue  # Only consider objects in the same or adjacent (or wider for Shop) columns
		print("Object grid_pos.y:", obj_grid_pos.y, "Object z_index:", obj_node.z_index)
		if grid_pos.y > obj_grid_pos.y:
			# Player is at least one row below: in front
			in_front_zs.append(obj_node.z_index)
		else:
			# Player is on the same row or above: behind
			behind_zs.append(obj_node.z_index)
	if in_front_zs.size() > 0:
		z_index = in_front_zs.max() + 100
	elif behind_zs.size() > 0:
		z_index = 0  # Always behind when above the object row
	else:
		z_index = 0
	print("Player z_index after update:", z_index)

func start_movement_mode(card, movement_range_: int):
	selected_card = card
	movement_range = movement_range_
	is_movement_mode = true
	calculate_valid_movement_tiles()

func end_movement_mode():
	is_movement_mode = false
	selected_card = null
	valid_movement_tiles.clear()

func calculate_valid_movement_tiles():
	
	valid_movement_tiles.clear()
	var total_range = movement_range + base_mobility
	
	
	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)
			if calculate_grid_distance(grid_pos, pos) <= total_range and pos != grid_pos:
				if obstacle_map.has(pos):
					var obstacle = obstacle_map[pos]
					if obstacle.has_method("blocks") and obstacle.blocks():
						continue
				valid_movement_tiles.append(pos)
	
	

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func can_move_to(pos: Vector2i) -> bool:
	return is_movement_mode and pos in valid_movement_tiles

func move_to_grid(pos: Vector2i):
	
	if can_move_to(pos):
		set_grid_position(pos)
		emit_signal("moved_to_tile", pos)
		print("Signal emitted, ending movement mode")
		end_movement_mode()
		print("Movement mode ended")
	else:
		print("Movement is invalid - cannot move to this position")
	print("=== END PLAYER.GD MOVE_TO_GRID DEBUG ===")
