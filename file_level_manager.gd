extends Node

#use to keep track of the ClubHouse level and the individual Character level for meta upgrades

signal experience_gained(character_exp: int, clubhouse_exp: int)
signal level_up(character_level: int, clubhouse_level: int)

# Experience tracking
var character_experience: int = 0
var clubhouse_experience: int = 0

# Level tracking (start at level 1)
var character_level: int = 1
var clubhouse_level: int = 1

# Experience required for each level (simple progression: 100 * level)
func get_exp_required_for_level(level: int) -> int:
	return level * 100

# Add experience points
func add_experience(exp_points: int):
	character_experience += exp_points
	clubhouse_experience += exp_points
	
	# Check for level ups
	check_level_ups()
	
	# Emit signal for UI updates
	experience_gained.emit(character_experience, clubhouse_experience)
	print("📡 FileLevelManager: experience_gained signal emitted - Character: ", character_experience, " ClubHouse: ", clubhouse_experience)

# Check if character or clubhouse should level up
func check_level_ups():
	var character_exp_required = get_exp_required_for_level(character_level)
	var clubhouse_exp_required = get_exp_required_for_level(clubhouse_level)
	
	# Check character level up
	if character_experience >= character_exp_required:
		character_level += 1
		level_up.emit(character_level, clubhouse_level)
		print("📡 FileLevelManager: level_up signal emitted - Character: ", character_level, " ClubHouse: ", clubhouse_level)
	
	# Check clubhouse level up
	if clubhouse_experience >= clubhouse_exp_required:
		clubhouse_level += 1
		level_up.emit(character_level, clubhouse_level)
		print("📡 FileLevelManager: level_up signal emitted - Character: ", character_level, " ClubHouse: ", clubhouse_level)

# Get current experience progress (0.0 to 1.0)
func get_character_exp_progress() -> float:
	var current_level_exp = character_experience
	var exp_required = get_exp_required_for_level(character_level)
	
	# Subtract experience from previous levels
	for i in range(1, character_level):
		current_level_exp -= get_exp_required_for_level(i)
	
	return float(current_level_exp) / float(exp_required)

func get_clubhouse_exp_progress() -> float:
	var current_level_exp = clubhouse_experience
	var exp_required = get_exp_required_for_level(clubhouse_level)
	
	# Subtract experience from previous levels
	for i in range(1, clubhouse_level):
		current_level_exp -= get_exp_required_for_level(i)
	
	return float(current_level_exp) / float(exp_required)

# Get experience points for completing a hole
func get_hole_completion_exp(hole_number: int) -> int:
	match hole_number:
		9: return 40
		18: return 100
		_: return 10

# Complete a hole and add experience
func complete_hole(hole_number: int):
	var exp_gained = get_hole_completion_exp(hole_number)
	add_experience(exp_gained)
	print("Completed hole ", hole_number, " - gained ", exp_gained, " experience points")

# Reset progression (for new save file)
func reset_progression():
	character_experience = 0
	clubhouse_experience = 0
	character_level = 1
	clubhouse_level = 1
	print("Progression reset - starting at level 1")

# Get current stats for display
func get_current_stats() -> Dictionary:
	return {
		"character_level": character_level,
		"clubhouse_level": clubhouse_level,
		"character_experience": character_experience,
		"clubhouse_experience": clubhouse_experience,
		"character_exp_progress": get_character_exp_progress(),
		"clubhouse_exp_progress": get_clubhouse_exp_progress()
	}
