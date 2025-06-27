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
const Hole10Layout = preload("res://Maps/Hole10Layout.gd")
const Hole11Layout = preload("res://Maps/Hole11Layout.gd")
const Hole12Layout = preload("res://Maps/Hole12Layout.gd")
const Hole13Layout = preload("res://Maps/Hole13Layout.gd")
const Hole14Layout = preload("res://Maps/Hole14Layout.gd")
const Hole15Layout = preload("res://Maps/Hole15Layout.gd")
const Hole16Layout = preload("res://Maps/Hole16Layout.gd")
const Hole17Layout = preload("res://Maps/Hole17Layout.gd")
const Hole18Layout = preload("res://Maps/Hole18Layout.gd")

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
	Hole10Layout.LAYOUT,
	Hole11Layout.LAYOUT,
	Hole12Layout.LAYOUT,
	Hole13Layout.LAYOUT,
	Hole14Layout.LAYOUT,
	Hole15Layout.LAYOUT,
	Hole16Layout.LAYOUT,
	Hole17Layout.LAYOUT,
	Hole18Layout.LAYOUT,
]

# Par values for each hole (0-based index) - Front 9 and Back 9
const HOLE_PARS := [3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 5, 4, 3, 4, 5, 3, 4]  # Front 9 par 3s, Back 9 mixed pars

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

# Returns the total par for the back 9
static func get_back_nine_par() -> int:
	var total_par = 0
	for i in range(9, 18):
		total_par += get_hole_par(i)
	return total_par

# Returns the total par for all 18 holes
static func get_total_par() -> int:
	var total_par = 0
	for i in range(18):
		total_par += get_hole_par(i)
	return total_par
