extends Node
class_name GolfCourseLayout

const Hole1Layout = preload("res://Maps/Hole1Layout.gd")
const Hole2Layout = preload("res://Maps/Hole2Layout.gd")
const Hole3Layout = preload("res://Maps/Hole3Layout.gd")
const Hole4Layout = preload("res://Maps/Hole4Layout.gd")
const Hole5Layout = preload("res://Maps/Hole5Layout.gd")
const Hole6Layout = preload("res://Maps/Hole6Layout.gd")
const Hole7Layout = preload("res://Maps/Hole7Layout.gd")
const Hole8Layout = preload("res://Maps/Hole8Layout.gd")
const Hole9Layout = preload("res://Maps/Hole9Layout.gd")

const HOLE_LAYOUTS := [
	Hole1Layout.LAYOUT,
	Hole2Layout.LAYOUT,
	Hole3Layout.LAYOUT,
	Hole4Layout.LAYOUT,
	Hole5Layout.LAYOUT,
	Hole6Layout.LAYOUT,
	Hole7Layout.LAYOUT,
	Hole8Layout.LAYOUT,
	Hole9Layout.LAYOUT,
]

# Par values for each hole (0-based index)
const HOLE_PARS := [3, 3, 3, 3, 3, 3, 3, 3, 3]  # Starting with all par 3s as requested

const LEVEL_LAYOUT := HOLE_LAYOUTS[0]

# Returns the layout for the given hole index (0-based)
static func get_hole_layout(hole_index: int) -> Array:
	if hole_index >= 0 and hole_index < HOLE_LAYOUTS.size():
		return HOLE_LAYOUTS[hole_index]
	return HOLE_LAYOUTS[0] # fallback to first hole

# Returns the par value for the given hole index (0-based)
static func get_hole_par(hole_index: int) -> int:
	if hole_index >= 0 and hole_index < HOLE_PARS.size():
		return HOLE_PARS[hole_index]
	return 3 # fallback to par 3

# Returns the total par for the front 9
static func get_front_nine_par() -> int:
	var total_par = 0
	for i in range(9):
		total_par += get_hole_par(i)
	return total_par
