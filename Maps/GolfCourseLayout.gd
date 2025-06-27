extends Node
class_name GolfCourseLayout

const Hole1Layout = preload("res://Maps/Hole1Layout.gd")
const Hole2Layout = preload("res://Maps/Hole2Layout.gd")
const Hole3Layout = preload("res://Maps/Hole3Layout.gd")

const HOLE_LAYOUTS := [
	Hole1Layout.LAYOUT,
	Hole2Layout.LAYOUT,
	Hole3Layout.LAYOUT,
]

const LEVEL_LAYOUT := HOLE_LAYOUTS[0]

# Returns the layout for the given hole index (0-based)
static func get_hole_layout(hole_index: int) -> Array:
	if hole_index >= 0 and hole_index < HOLE_LAYOUTS.size():
		return HOLE_LAYOUTS[hole_index]
	return HOLE_LAYOUTS[0] # fallback to first hole
