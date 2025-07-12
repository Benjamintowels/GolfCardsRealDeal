extends Resource
class_name TreeData

@export var name: String = "Tree"
@export var sprite_texture: Texture2D
@export var rarity: float = 1.0  # Weight for random selection (higher = more common)
@export var description: String = "A tree"

func get_display_name() -> String:
	"""Get the display name for this tree variant"""
	return name 