extends Node2D

# Shop height for collision detection
var height: float = 200.0  # Shop height (ball needs 110.0 to pass over)

# Returns the Y-sorting reference point (base of shop building)
func get_y_sort_point() -> float:
	# Use the base of the shop building for Y-sorting
	# The sprite is positioned at (15.845, -34.905), so the base is at +34.905 from the origin
	return global_position.y + 34.905
