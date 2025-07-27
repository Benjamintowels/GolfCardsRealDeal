extends Node2D

@onready var area_2d = $Area2D
@onready var sprite = $Sprite2D

var grid_position: Vector2i

func _ready():
	# Connect to area entered signal for player collision
	if area_2d:
		area_2d.area_entered.connect(_on_area_2d_area_entered)
		
		# Set collision layer to 4 (item layer) for Ash dog detection
		area_2d.collision_layer = 4
		# Set collision mask to 3 (detect player on layers 1 & 2)
		area_2d.collision_mask = 3
		
		print("✓ Key Area2D configured for player and Ash dog detection")

func _on_area_2d_area_entered(area: Area2D):
	"""Handle collision with player or Ash dog"""
	print("🔍 KEY COLLISION: Area entered -", area.name if area else "null")
	
	# Get the parent of the area (the actual object)
	var object = area.get_parent()
	if not object:
		print("❌ KEY COLLISION: No parent object found for area")
		return
	
	print("🔍 KEY COLLISION: Object name:", object.name, "Type:", object.get_class())
	
	# Check if this is the Player
	var player_node = _find_player_in_hierarchy(object)
	if player_node:
		print("✅ KEY COLLISION: Found Player in hierarchy:", player_node.name)
		var course = get_tree().current_scene
		if course and course.has_method("_on_key_area_entered"):
			course._on_key_area_entered(player_node)
	else:
		print("❌ KEY COLLISION: Not a player object")

func _find_player_in_hierarchy(node: Node) -> Node:
	"""Find player node in hierarchy"""
	# Check if this node is the player
	if node.name == "Player" or node.name.contains("Player"):
		return node
	
	# Check parent
	var parent = node.get_parent()
	if parent and (parent.name == "Player" or parent.name.contains("Player")):
		return parent
	
	return null

func setup(pos: Vector2i, size: int):
	"""Setup the key with position"""
	grid_position = pos 
