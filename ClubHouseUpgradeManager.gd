extends Node

signal flippy_level_changed(new_level: int)
signal clubhouse_level_changed(new_level: int)
signal looty_changed(new_amount: int)

# Flippy level system
var flippy_level: int = 1
var flippy_upgrade_cost: int = 100

# ClubHouse level system (separate from FileLevelManager)
var clubhouse_level: int = 1

# Looty persistence system
var clubhouse_looty: int = 0  # Looty stored in ClubHouse
var course_looty: int = 0     # Looty earned during current course

# Flippy perk offerings based on level
var flippy_perk_offerings = {
	1: [],  # No perks at level 1
	2: ["receive_bounty", "start_with_200_looty"],  # 1 random perk
	3: ["receive_bounty", "start_with_200_looty", "random_rare_action"],  # 2 random perks
	4: ["receive_bounty", "start_with_200_looty", "random_rare_action", "random_equipment"],  # 2 random perks
	5: ["receive_bounty", "start_with_200_looty", "random_rare_action", "random_equipment", "random_club_card"],  # 2 random perks
	6: ["receive_bounty", "start_with_200_looty", "random_rare_action", "random_equipment", "random_club_card"]  # 3 random perks
}

var perk_descriptions = {
	"start_with_200_looty": "Start with 200 extra $Looty",
	"upgrade_card": "Upgrade a card in your deck",
	"random_rare_action": "Receive a random rare action card",
	"random_equipment": "Receive a random equipment",
	"random_club_card": "Receive a random club card", 
	"receive_bounty": "Receive a bounty (placeholder)"
}

func _ready():
	# Make this a singleton
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load data from save file if available
	_load_from_save_file()

func _load_from_save_file():
	"""Load ClubHouse upgrade data from save file"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		flippy_level = save_file_manager.get_flippy_level()
		clubhouse_looty = save_file_manager.get_clubhouse_looty()
		print("Loaded ClubHouse upgrade data from save file - Flippy level:", flippy_level, "ClubHouse Looty:", clubhouse_looty)
	else:
		print("No save file loaded, using default ClubHouse upgrade values")

func _save_to_save_file():
	"""Save ClubHouse upgrade data to save file"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		save_file_manager.set_flippy_level(flippy_level)
		save_file_manager.set_clubhouse_looty(clubhouse_looty)
		save_file_manager.save_current_game()
		print("Saved ClubHouse upgrade data to save file")

# Flippy Level System
func get_flippy_level() -> int:
	return flippy_level

func can_upgrade_flippy() -> bool:
	return clubhouse_looty >= flippy_upgrade_cost and flippy_level < 6

func upgrade_flippy() -> bool:
	if can_upgrade_flippy():
		clubhouse_looty -= flippy_upgrade_cost
		flippy_level += 1
		flippy_level_changed.emit(flippy_level)
		looty_changed.emit(clubhouse_looty)
		_save_to_save_file()
		print("Flippy upgraded to level", flippy_level, "for", flippy_upgrade_cost, "$Looty")
		return true
	return false

func get_flippy_upgrade_cost() -> int:
	return flippy_upgrade_cost

func get_flippy_perks_for_level() -> Array:
	var level = get_flippy_level()
	if not flippy_perk_offerings.has(level):
		return []
	
	var available_perks = flippy_perk_offerings[level].duplicate()
	var num_perks = _get_num_perks_for_level(level)
	
	# Shuffle and return the required number of perks
	available_perks.shuffle()
	return available_perks.slice(0, min(num_perks, available_perks.size()))

func _get_num_perks_for_level(level: int) -> int:
	match level:
		1: return 0
		2: return 1
		3, 4, 5: return 2
		6: return 3
		_: return 0

# ClubHouse Level System
func get_clubhouse_level() -> int:
	return clubhouse_level

func can_upgrade_clubhouse() -> bool:
	return clubhouse_level >= 2

# Looty Persistence System
func get_clubhouse_looty() -> int:
	return clubhouse_looty

func get_course_looty() -> int:
	return course_looty

func add_course_looty(amount: int):
	course_looty += amount
	print("Added", amount, "$Looty to course wallet. Total:", course_looty)

func transfer_course_looty_to_clubhouse():
	clubhouse_looty += course_looty
	course_looty = 0
	looty_changed.emit(clubhouse_looty)
	_save_to_save_file()
	print("Transferred course Looty to ClubHouse. ClubHouse total:", clubhouse_looty)

func handle_player_death():
	# Cut course Looty in half and transfer to ClubHouse
	var half_looty = course_looty / 2
	clubhouse_looty += half_looty
	course_looty = 0
	looty_changed.emit(clubhouse_looty)
	_save_to_save_file()
	print("Player died. Transferred", half_looty, "$Looty to ClubHouse")

func handle_hole_18_completion():
	# Double the course Looty
	course_looty *= 2
	print("Hole 18 completed! Course Looty doubled to:", course_looty)

func spend_clubhouse_looty(amount: int) -> bool:
	if clubhouse_looty >= amount:
		clubhouse_looty -= amount
		looty_changed.emit(clubhouse_looty)
		_save_to_save_file()
		print("Spent", amount, "$Looty from ClubHouse. Remaining:", clubhouse_looty)
		return true
	return false

# Save/Load System
func save_data() -> Dictionary:
	return {
		"flippy_level": flippy_level,
		"clubhouse_level": clubhouse_level,
		"clubhouse_looty": clubhouse_looty,
		"course_looty": course_looty
	}

func load_data(data: Dictionary):
	if data.has("flippy_level"):
		flippy_level = data.flippy_level
	if data.has("clubhouse_level"):
		clubhouse_level = data.clubhouse_level
	if data.has("clubhouse_looty"):
		clubhouse_looty = data.clubhouse_looty
	if data.has("course_looty"):
		course_looty = data.course_looty
	
	# Emit signals to update UI
	flippy_level_changed.emit(flippy_level)
	clubhouse_level_changed.emit(clubhouse_level)
	looty_changed.emit(clubhouse_looty)
