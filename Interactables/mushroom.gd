extends Node2D

@onready var area_2d: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var grow_sound: AudioStreamPlayer2D = $Grow

var grid_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
	# Configure collision layers so player Areas can detect this item
	if area_2d:
		if not area_2d.area_entered.is_connected(_on_area_2d_area_entered):
			area_2d.area_entered.connect(_on_area_2d_area_entered)
		area_2d.collision_layer = 4  # Item layer
		area_2d.collision_mask = 3   # Detect player on layers 1 & 2

	# Add to common groups
	add_to_group("interactables")
	add_to_group("mushrooms")

	# Visual grow animation
	if sprite:
		sprite.scale = Vector2(0.1, 0.1)
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Play grow SFX
	if grow_sound and grow_sound.stream:
		grow_sound.play()

func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos

func _on_area_2d_area_entered(area: Area2D) -> void:
	# Find player from the entered area's hierarchy
	var parent = area.get_parent()
	if parent:
		var player_node = _find_player_in_hierarchy(parent)
		if player_node:
			Global.Tripping = true
			queue_free()

func _find_player_in_hierarchy(node: Node) -> Node:
	if node.name == "Player" or node.name.contains("Player"):
		return node
	var p = node.get_parent()
	if p and (p.name == "Player" or p.name.contains("Player")):
		return p
	return null
