extends Node2D

signal suitcase_reached

var grid_position: Vector2i
var cell_size: int = 48
var is_activated: bool = false

func _ready():
	# Set up collision detection
	var area2d = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	collision_shape.shape = shape
	area2d.add_child(collision_shape)
	add_child(area2d)
	
	# Connect to player detection
	area2d.body_entered.connect(_on_body_entered)
	area2d.area_entered.connect(_on_area_entered)
	
	# Set grid position from metadata if available
	if has_meta("grid_position"):
		grid_position = get_meta("grid_position")
	
	print("MapSuitCase ready at grid position:", grid_position)

func _on_body_entered(body: Node2D):
	_check_player_reached(body)

func _on_area_entered(area: Area2D):
	_check_player_reached(area.get_parent())

func _check_player_reached(node: Node2D):
	if is_activated:
		return
		
	# Check if this is the player
	if node.has_method("take_damage") and node.has_method("get_grid_position"):
		var player_grid_pos = node.get_grid_position()
		if player_grid_pos == grid_position:
			print("Player reached SuitCase at grid position:", grid_position)
			is_activated = true
			suitcase_reached.emit()
			
			# Hide the SuitCase after activation
			visible = false
			
			# Remove from collision detection
			var area2d = get_node_or_null("Area2D")
			if area2d:
				area2d.queue_free()

func get_grid_position() -> Vector2i:
	return grid_position 
