extends Node2D

# This tile blocks movement until the fight room key is collected
var grid_position: Vector2i
var cell_size: int = 48

func setup(pos: Vector2i, size: int) -> void:
	"""Setup the FightWinTile with position and cell size"""
	grid_position = pos
	cell_size = size

func blocks() -> bool:
	"""Check if this tile blocks movement - blocked until key is collected"""
	var course = get_tree().current_scene
	if course and "fight_room_key_collected" in course:
		return not course.fight_room_key_collected
	return true  # Default to blocked

func is_walkable() -> bool:
	"""Check if this tile is walkable - opposite of blocks()"""
	return not blocks() 