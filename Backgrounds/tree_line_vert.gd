extends Node2D
#if needed

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var mouse_area: Area2D = $MouseDetectionArea2D
@onready var sprite_left: Sprite2D = $Node2D/TreeLineVertSpriteLeft
@onready var sprite_left2: Sprite2D = $Node2D/TreeLineVertSpriteLeft2
@onready var sprite_right: Sprite2D = $Node2D/TreeLineVertSpriteRight
@onready var sprite_right2: Sprite2D = $Node2D/TreeLineVertSpriteRight2
@onready var node2d_container: Node2D = $Node2D

var is_hovering = false
var tween: Tween
var cell_size: int = 48

func _ready():
	add_to_group("TreeLineVert")
	mouse_area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	mouse_area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	
	# Position right sprites based on current map width
	position_right_sprites()

func position_right_sprites():
	# Get the map manager to access current map dimensions
	var map_manager = null
	
	# Try multiple paths to find MapManager
	if get_tree().get_root().has_node("Course1/MapManager"):
		map_manager = get_tree().get_root().get_node("Course1/MapManager")
	elif get_tree().get_root().has_node("MapManager"):
		map_manager = get_tree().get_root().get_node("MapManager")
	else:
		# Search for MapManager in the scene tree
		for node in get_tree().get_nodes_in_group("MapManager"):
			if node.get_class() == "MapManager":
				map_manager = node
				break
	
	if map_manager and map_manager.grid_width > 0:
		# Calculate right edge position based on map width
		var right_edge_x = map_manager.grid_width * cell_size
		
		# Position the right sprites at the right edge of the map
		# Add a large buffer to ensure they're well off the map edge
		sprite_right.position.x = right_edge_x + 500  # 500 pixels beyond the map edge
		sprite_right2.position.x = right_edge_x + 400  # 400 pixels beyond the map edge
		
		# Keep the Y positions as they were
		sprite_right.position.y = -655
		sprite_right2.position.y = 930
		
		print("TreeLineVert: Positioned right sprites at x=", right_edge_x + 200, " and x=", right_edge_x + 100)
	else:
		print("TreeLineVert: Could not find MapManager or grid_width is 0")

func _on_mouse_entered():
	if not is_hovering:
		is_hovering = true
		# Stop any existing tween
		if tween:
			tween.kill()
		
		# Create new tween for fade out
		tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_left, "modulate", Color(1, 1, 1, 0.254902), 1.5)
		tween.tween_property(sprite_left2, "modulate", Color(1, 1, 1, 0.254902), 1.5)
		tween.tween_property(sprite_right, "modulate", Color(1, 1, 1, 0.254902), 1.5)
		tween.tween_property(sprite_right2, "modulate", Color(1, 1, 1, 0.254902), 1.5)

func _on_mouse_exited():
	if is_hovering:
		is_hovering = false
		# Stop any existing tween
		if tween:
			tween.kill()
		
		# Create new tween for fade in
		tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_left, "modulate", Color(1, 1, 1, 1), 1.5)
		tween.tween_property(sprite_left2, "modulate", Color(1, 1, 1, 1), 1.5)
		tween.tween_property(sprite_right, "modulate", Color(1, 1, 1, 1), 1.5)
		tween.tween_property(sprite_right2, "modulate", Color(1, 1, 1, 1), 1.5)

func play_pseudo3d_effect():
	"""Play the pseudo3D animation for hole transition"""
	if anim_player and anim_player.has_animation("pseudo3D"):
		anim_player.play("pseudo3D")
		print("TreeLineVert: Playing pseudo3D animation")

func reverse_pseudo3d_effect():
	"""Reverse the pseudo3D animation when switching back"""
	if anim_player and anim_player.has_animation("pseudo3D"):
		anim_player.play_backwards("pseudo3D")
		print("TreeLineVert: Reversing pseudo3D animation")
