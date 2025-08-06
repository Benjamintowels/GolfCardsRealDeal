extends Node

signal save_file_loaded(save_data: Dictionary)
signal save_file_created(slot_id: int)
signal save_file_deleted(slot_id: int)
signal progression_updated(category: String, key: String, value)

# Save file structure
const SAVE_FILE_PATHS = {
	1: "user://save_file_1.save",
	2: "user://save_file_2.save", 
	3: "user://save_file_3.save"
}

# Current save data structure
var current_save_data: Dictionary = {}
var current_save_slot: int = 0

# =============================================================================
# PROGRESSION SYSTEM MODULES
# =============================================================================

# 1. CHARACTER PROGRESSION SYSTEM
var CHARACTER_PROGRESSION = {
	# Unlocked characters (0 = none, 1 = Layla only, 2 = Benny only, 3 = Layla + Benny, 4 = All)
	"unlocked_characters": 2,  # Default: Benny only unlocked
	
	# Individual character meta levels (starts at 1)
	"character_levels": {
		1: 1,  # Layla
		2: 1,  # Benny  
		3: 1   # Clark
	},
	
	# Character experience points
	"character_exp": {
		1: 0,  # Layla
		2: 0,  # Benny
		3: 0   # Clark
	},
	
	# Character-specific achievements
	"character_achievements": {
		1: [],  # Layla achievements
		2: [],  # Benny achievements
		3: []   # Clark achievements
	}
}

# 2. CONTENT UNLOCK SYSTEM
var CONTENT_UNLOCKS = {
	# Available decks (Starter is default)
	"unlocked_decks": ["starter"],
	
	# Available equipment (starts empty)
	"unlocked_equipment": [],
	
	# Available maps/courses (Golf Island is default)
	"unlocked_maps": ["golf_island"],
	
	# Map checkpoints (tracks progress on each map)
	"map_checkpoints": {
		"golf_island": {
			"front_9_unlocked": true,
			"back_9_unlocked": false,
			"boss_room_unlocked": false,
			"fight_room_unlocked": false
		}
	}
}

# 3. GAMEPLAY TRACKING SYSTEM
var GAMEPLAY_STATS = {
	# Golf scores for completed rounds
	"golf_scores": {
		"front_9_scores": [],      # Array of front 9 scores
		"back_9_scores": [],       # Array of back 9 scores
		"full_18_scores": [],      # Array of full 18 scores
		"best_front_9": 999,
		"best_back_9": 999,
		"best_full_18": 999
	},
	
	# Puzzle type scores
	"puzzle_scores": {
		"bounce_room": [],
		"damage_round": [],
		"generator": [],
		"mob_encounter": [],
		"miniboss": [],
		"fight_room": []
	},
	
	# Round grades (F to SS+)
	"round_grades": {
		"front_9_grades": [],
		"back_9_grades": [],
		"full_18_grades": [],
		"best_grade": "F"
	},
	
	# General gameplay stats
	"total_holes_played": 0,
	"total_rounds_completed": 0,
	"total_looty_earned": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"holes_in_one": 0,
	"eagles": 0,
	"birdies": 0
}

# 4. STORY/QUEST PROGRESSION SYSTEM
var STORY_PROGRESSION = {
	# Core story flags
	"first_time_playing": true,
	"completed_tutorial": false,
	"completed_front_9": false,
	"completed_back_9": false,
	"defeated_first_boss": false,
	"defeated_final_boss": false,
	
	# NPC questlines (modular system)
	"npc_quests": {
		"golfsmith": {
			"appear": false,        # Golfsmith appears in game
			"shop": false,          # Golfsmith appears in shop
			"quest_completed": false, # Golfsmith quest finished
			"quest_progress": 0     # Quest progress (0-100)
		}
		# Easy to add more NPCs: "npc_name": { "appear": false, "shop": false, etc. }
	},
	
	# Story events and cutscenes
	"story_events": {
		"heard_intro_speech": false,
		"heard_golfsmith_intro": false,
		"heard_boss_intro": false,
		"heard_victory_speech": false,
		"first_shop_visit": false,
		"first_boss_encounter": false
	}
}

# 5. CLUBHOUSE PROGRESSION SYSTEM
var CLUBHOUSE_PROGRESSION = {
	# ClubHouse level (separate from character levels)
	"clubhouse_level": 1,
	"clubhouse_exp": 0,
	"clubhouse_exp_to_next": 100,
	
	# ClubHouse decor and upgrades
	"clubhouse_decor": {
		"wallpaper": "default",
		"flooring": "default",
		"furniture": "default",
		"lighting": "default"
	},
	
	# ClubHouse perks (selected before rounds)
	"available_perks": [],
	"selected_perk": null,
	
	# ClubHouse equipment storage
	"clubhouse_equipment": [],
	"equipment_table_unlocked": false
}

# =============================================================================
# CORE SAVE FILE MANAGER FUNCTIONS
# =============================================================================

func _ready():
	# Make this a singleton
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_save_file_info(slot_id: int) -> Dictionary:
	"""Get information about a save file slot"""
	var save_path = SAVE_FILE_PATHS.get(slot_id, "")
	if not save_path:
		return {"exists": false, "slot_id": slot_id}
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {"exists": false, "slot_id": slot_id}
	
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not save_data:
		return {"exists": false, "slot_id": slot_id}
	
	return {
		"exists": true,
		"slot_id": slot_id,
		"character_name": save_data.get("character_name", "Unknown"),
		"total_score": save_data.get("total_score", 0),
		"total_holes_played": save_data.get("total_holes_played", 0),
		"last_played": save_data.get("last_played", ""),
		"clubhouse_level": save_data.get("clubhouse_level", 1),
		"unlocked_characters": save_data.get("unlocked_characters", 2)
	}

func create_new_save_file(slot_id: int, character_id: int) -> bool:
	"""Create a new save file in the specified slot"""
	var save_path = SAVE_FILE_PATHS.get(slot_id, "")
	if not save_path:
		print("ERROR: Invalid save slot ID:", slot_id)
		return false
	
	# Initialize save data with all progression systems
	current_save_data = {
		"version": "1.0",
		"created_date": Time.get_datetime_string_from_system(),
		"last_played": Time.get_datetime_string_from_system(),
		"character_id": character_id,
		"character_name": get_character_name(character_id),
		"total_score": 0,
		"total_holes_played": 0,
		"current_looty": 50,
		
		# Initialize all progression systems
		"character_progression": CHARACTER_PROGRESSION.duplicate(true),
		"content_unlocks": CONTENT_UNLOCKS.duplicate(true),
		"gameplay_stats": GAMEPLAY_STATS.duplicate(true),
		"story_progression": STORY_PROGRESSION.duplicate(true),
		"clubhouse_progression": CLUBHOUSE_PROGRESSION.duplicate(true),
		
		# Game state
		"game_state": {
			"current_hole": 0,
			"front_9_score": 0,
			"back_9_score": 0,
			"global_turn_count": 1,
			"current_reward_tier": 1
		},
		
		# Character state
		"character_state": {
			"current_hp": get_character_max_hp(character_id),
			"max_hp": get_character_max_hp(character_id),
			"equipped_items": [],
			"clothing_slots": {}
		},
		
		# Deck state
		"deck_state": {
			"current_deck": [],
			"bag_level": 1,
			"bag_slots": {
				"equipment": 1,
				"movement_cards": 16,
				"club_cards": 2
			}
		}
	}
	
	# Save to file
	if save_to_file(save_path, current_save_data):
		current_save_slot = slot_id
		emit_signal("save_file_created", slot_id)
		return true
	
	return false

func load_save_file(slot_id: int) -> bool:
	"""Load a save file from the specified slot"""
	var save_path = SAVE_FILE_PATHS.get(slot_id, "")
	if not save_path:
		print("ERROR: Invalid save slot ID:", slot_id)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open save file:", save_path)
		return false
	
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not save_data:
		print("ERROR: Invalid save file format")
		return false
	
	current_save_data = save_data
	current_save_slot = slot_id
	
	# Apply save data to global systems
	apply_save_data_to_globals()
	
	emit_signal("save_file_loaded", current_save_data)
	return true

func save_current_game() -> bool:
	"""Save the current game state"""
	if current_save_slot == 0:
		print("ERROR: No save slot selected")
		return false
	
	# Update save data with current game state
	update_save_data_from_globals()
	
	var save_path = SAVE_FILE_PATHS.get(current_save_slot, "")
	return save_to_file(save_path, current_save_data)

func delete_save_file(slot_id: int) -> bool:
	"""Delete a save file from the specified slot"""
	var save_path = SAVE_FILE_PATHS.get(slot_id, "")
	if not save_path:
		print("ERROR: Invalid save slot ID:", slot_id)
		return false
	
	print("Attempting to delete file at path: ", save_path)
	
	# Check if file exists first
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("File doesn't exist: ", save_path)
		# File doesn't exist, but we'll still emit the signal to update UI
		if current_save_slot == slot_id:
			current_save_slot = 0
			current_save_data = {}
		emit_signal("save_file_deleted", slot_id)
		return true
	file.close()
	
	print("File exists, attempting to delete...")
	
	var dir = DirAccess.open("user://")
	if not dir:
		print("ERROR: Could not open user:// directory")
		return false
	
	var filename = save_path.get_file()
	print("Attempting to remove file: ", filename)
	
	# Try with just filename first
	if dir.remove(filename):
		# Reset current save slot if we're deleting the currently loaded save
		if current_save_slot == slot_id:
			current_save_slot = 0
			current_save_data = {}
		emit_signal("save_file_deleted", slot_id)
		print("Save file deleted successfully: ", filename)
		return true
	
	print("Failed to delete save file: ", filename)
	print("DirAccess error code: ", dir.get_open_error())
	
	# Try alternative deletion method using full path
	print("Trying alternative deletion method with full path...")
	if dir.remove(save_path):
		if current_save_slot == slot_id:
			current_save_slot = 0
			current_save_data = {}
		emit_signal("save_file_deleted", slot_id)
		print("Save file deleted successfully using full path: ", save_path)
		return true
	
	# Try using FileAccess to truncate and then delete
	print("Trying FileAccess truncation method...")
	var alt_file = FileAccess.open(save_path, FileAccess.WRITE)
	if alt_file:
		alt_file.close()
		# Try DirAccess again with filename
		if dir.remove(filename):
			if current_save_slot == slot_id:
				current_save_slot = 0
				current_save_data = {}
			emit_signal("save_file_deleted", slot_id)
			print("Save file deleted successfully using truncation method: ", filename)
			return true
	
	print("All deletion methods failed")
	return false

func save_to_file(path: String, data: Dictionary) -> bool:
	"""Save data to file"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("ERROR: Could not create save file:", path)
		return false
	
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func apply_save_data_to_globals():
	"""Apply save data to global variables and managers"""
	if not current_save_data.has("game_state"):
		return
	
	var game_state = current_save_data["game_state"]
	var character_state = current_save_data.get("character_state", {})
	
	# Apply to Global singleton
	Global.selected_character = current_save_data.get("character_id", 1)
	Global.current_looty = current_save_data.get("current_looty", 50)
	Global.final_18_hole_score = game_state.get("front_9_score", 0) + game_state.get("back_9_score", 0)
	Global.front_9_score = game_state.get("front_9_score", 0)
	Global.global_turn_count = game_state.get("global_turn_count", 1)
	Global.current_reward_tier = game_state.get("current_reward_tier", 1)
	
	# Load FileLevelManager data
	load_file_level_manager_data()

func update_save_data_from_globals():
	"""Update save data with current global state"""
	current_save_data["last_played"] = Time.get_datetime_string_from_system()
	current_save_data["current_looty"] = Global.current_looty
	
	# Update game state
	var game_state = current_save_data.get("game_state", {})
	game_state["front_9_score"] = Global.front_9_score
	game_state["global_turn_count"] = Global.global_turn_count
	game_state["current_reward_tier"] = Global.current_reward_tier
	current_save_data["game_state"] = game_state
	
	# Update FileLevelManager progression data
	update_file_level_manager_data()

func update_file_level_manager_data():
	"""Update save data with FileLevelManager progression"""
	var file_level_manager = FileLevelManager
	if file_level_manager:
		var stats = file_level_manager.get_current_stats()
		current_save_data["file_level_manager"] = {
			"character_experience": stats.character_experience,
			"clubhouse_experience": stats.clubhouse_experience,
			"character_level": stats.character_level,
			"clubhouse_level": stats.clubhouse_level
		}
		print("FileLevelManager data saved to save file")
	else:
		print("ERROR: FileLevelManager not found when saving data")

func load_file_level_manager_data():
	"""Load FileLevelManager data from save file"""
	var file_level_manager = FileLevelManager
	if not file_level_manager:
		print("ERROR: FileLevelManager not found when loading data")
		return
	
	var saved_data = current_save_data.get("file_level_manager", {})
	if saved_data.is_empty():
		print("No FileLevelManager data found in save file - using defaults")
		return
	
	# Load the data into FileLevelManager
	file_level_manager.character_experience = saved_data.get("character_experience", 0)
	file_level_manager.clubhouse_experience = saved_data.get("clubhouse_experience", 0)
	file_level_manager.character_level = saved_data.get("character_level", 1)
	file_level_manager.clubhouse_level = saved_data.get("clubhouse_level", 1)
	
	print("FileLevelManager data loaded from save file: ", saved_data)

# =============================================================================
# PROGRESSION SYSTEM API FUNCTIONS
# =============================================================================

# 1. CHARACTER PROGRESSION FUNCTIONS
func unlock_character(character_id: int) -> bool:
	"""Unlock a character"""
	var progression = current_save_data.get("character_progression", {})
	var unlocked = progression.get("unlocked_characters", 2)
	
	if character_id > unlocked:
		progression["unlocked_characters"] = character_id
		current_save_data["character_progression"] = progression
		emit_signal("progression_updated", "character", "unlocked_characters", character_id)
		return true
	return false

func add_character_exp(character_id: int, exp_amount: int) -> bool:
	"""Add experience to a character"""
	var progression = current_save_data.get("character_progression", {})
	var exp_data = progression.get("character_exp", {})
	var level_data = progression.get("character_levels", {})
	
	# Add experience
	exp_data[str(character_id)] = exp_data.get(str(character_id), 0) + exp_amount
	
	# Check for level up (simple system: 100 exp per level)
	var current_exp = exp_data[str(character_id)]
	var current_level = level_data.get(str(character_id), 1)
	var exp_needed = current_level * 100
	
	if current_exp >= exp_needed:
		level_data[str(character_id)] = current_level + 1
		emit_signal("progression_updated", "character", "level_up", character_id)
	
	progression["character_exp"] = exp_data
	progression["character_levels"] = level_data
	current_save_data["character_progression"] = progression
	
	return true

func get_character_level(character_id: int) -> int:
	"""Get character level"""
	var progression = current_save_data.get("character_progression", {})
	var level_data = progression.get("character_levels", {})
	return level_data.get(str(character_id), 1)

func is_character_unlocked(character_id: int) -> bool:
	"""Check if character is unlocked"""
	var progression = current_save_data.get("character_progression", {})
	var unlocked = progression.get("unlocked_characters", 2)
	
	# unlocked_characters: 0=none, 1=Layla only, 2=Benny only, 3=Layla+Benny, 4=All
	match unlocked:
		0: return false
		1: return character_id == 1  # Layla only
		2: return character_id == 2  # Benny only
		3: return character_id <= 2  # Layla + Benny
		4: return character_id <= 3  # All characters
		_: return character_id == 2  # Default to Benny only

# 2. CONTENT UNLOCK FUNCTIONS
func unlock_deck(deck_name: String) -> bool:
	"""Unlock a deck"""
	var unlocks = current_save_data.get("content_unlocks", {})
	var decks = unlocks.get("unlocked_decks", ["starter"])
	
	if not decks.has(deck_name):
		decks.append(deck_name)
		unlocks["unlocked_decks"] = decks
		current_save_data["content_unlocks"] = unlocks
		emit_signal("progression_updated", "content", "deck_unlocked", deck_name)
		return true
	return false

func unlock_equipment(equipment_name: String) -> bool:
	"""Unlock equipment"""
	var unlocks = current_save_data.get("content_unlocks", {})
	var equipment = unlocks.get("unlocked_equipment", [])
	
	if not equipment.has(equipment_name):
		equipment.append(equipment_name)
		unlocks["unlocked_equipment"] = equipment
		current_save_data["content_unlocks"] = unlocks
		emit_signal("progression_updated", "content", "equipment_unlocked", equipment_name)
		return true
	return false

func unlock_map(map_name: String) -> bool:
	"""Unlock a map"""
	var unlocks = current_save_data.get("content_unlocks", {})
	var maps = unlocks.get("unlocked_maps", ["golf_island"])
	
	if not maps.has(map_name):
		maps.append(map_name)
		unlocks["unlocked_maps"] = maps
		current_save_data["content_unlocks"] = unlocks
		emit_signal("progression_updated", "content", "map_unlocked", map_name)
		return true
	return false

func unlock_map_checkpoint(map_name: String, checkpoint: String) -> bool:
	"""Unlock a map checkpoint"""
	var unlocks = current_save_data.get("content_unlocks", {})
	var checkpoints = unlocks.get("map_checkpoints", {})
	
	if not checkpoints.has(map_name):
		checkpoints[map_name] = {
			"front_9_unlocked": true,
			"back_9_unlocked": false,
			"boss_room_unlocked": false,
			"fight_room_unlocked": false
		}
	
	if checkpoint in checkpoints[map_name]:
		checkpoints[map_name][checkpoint] = true
		unlocks["map_checkpoints"] = checkpoints
		current_save_data["content_unlocks"] = unlocks
		emit_signal("progression_updated", "content", "checkpoint_unlocked", map_name + "_" + checkpoint)
		return true
	return false

func is_deck_unlocked(deck_name: String) -> bool:
	"""Check if deck is unlocked"""
	var unlocks = current_save_data.get("content_unlocks", {})
	var decks = unlocks.get("unlocked_decks", ["starter"])
	return decks.has(deck_name)

func is_equipment_unlocked(equipment_name: String) -> bool:
	"""Check if equipment is unlocked"""
	var unlocks = current_save_data.get("content_unlocks", {})
	var equipment = unlocks.get("unlocked_equipment", [])
	return equipment.has(equipment_name)

func is_map_unlocked(map_name: String) -> bool:
	"""Check if map is unlocked"""
	var unlocks = current_save_data.get("content_unlocks", {})
	var maps = unlocks.get("unlocked_maps", ["golf_island"])
	return maps.has(map_name)

# 3. GAMEPLAY TRACKING FUNCTIONS
func add_golf_score(round_type: String, score: int) -> bool:
	"""Add a golf score"""
	var stats = current_save_data.get("gameplay_stats", {})
	var scores = stats.get("golf_scores", {})
	
	match round_type:
		"front_9":
			var front_scores = scores.get("front_9_scores", [])
			front_scores.append(score)
			scores["front_9_scores"] = front_scores
			if score < scores.get("best_front_9", 999):
				scores["best_front_9"] = score
		"back_9":
			var back_scores = scores.get("back_9_scores", [])
			back_scores.append(score)
			scores["back_9_scores"] = back_scores
			if score < scores.get("best_back_9", 999):
				scores["best_back_9"] = score
		"full_18":
			var full_scores = scores.get("full_18_scores", [])
			full_scores.append(score)
			scores["full_18_scores"] = full_scores
			if score < scores.get("best_full_18", 999):
				scores["best_full_18"] = score
	
	stats["golf_scores"] = scores
	current_save_data["gameplay_stats"] = stats
	return true

func add_puzzle_score(puzzle_type: String, score: int) -> bool:
	"""Add a puzzle score"""
	var stats = current_save_data.get("gameplay_stats", {})
	var puzzle_scores = stats.get("puzzle_scores", {})
	
	if puzzle_scores.has(puzzle_type):
		var scores = puzzle_scores[puzzle_type]
		scores.append(score)
		puzzle_scores[puzzle_type] = scores
		stats["puzzle_scores"] = puzzle_scores
		current_save_data["gameplay_stats"] = stats
		return true
	return false

func set_round_grade(round_type: String, grade: String) -> bool:
	"""Set a round grade"""
	var stats = current_save_data.get("gameplay_stats", {})
	var grades = stats.get("round_grades", {})
	
	match round_type:
		"front_9":
			var front_grades = grades.get("front_9_grades", [])
			front_grades.append(grade)
			grades["front_9_grades"] = front_grades
		"back_9":
			var back_grades = grades.get("back_9_grades", [])
			back_grades.append(grade)
			grades["back_9_grades"] = back_grades
		"full_18":
			var full_grades = grades.get("full_18_grades", [])
			full_grades.append(grade)
			grades["full_18_grades"] = full_grades
	
	# Update best grade if better
	var grade_values = {"F": 0, "D": 1, "C": 2, "B": 3, "A": 4, "S": 5, "SS": 6, "SS+": 7}
	var current_best = grades.get("best_grade", "F")
	if grade_values.get(grade, 0) > grade_values.get(current_best, 0):
		grades["best_grade"] = grade
	
	stats["round_grades"] = grades
	current_save_data["gameplay_stats"] = stats
	return true

# 4. STORY PROGRESSION FUNCTIONS
func set_story_flag(flag: String, value: bool = true) -> bool:
	"""Set a story progression flag"""
	var story = current_save_data.get("story_progression", {})
	story[flag] = value
	current_save_data["story_progression"] = story
	
	# Trigger appropriate events
	trigger_story_events(flag, value)
	
	emit_signal("progression_updated", "story", flag, value)
	return true

func set_npc_quest_progress(npc_name: String, progress: int) -> bool:
	"""Set NPC quest progress"""
	var story = current_save_data.get("story_progression", {})
	var npc_quests = story.get("npc_quests", {})
	
	if not npc_quests.has(npc_name):
		npc_quests[npc_name] = {
			"appear": false,
			"shop": false,
			"quest_completed": false,
			"quest_progress": 0
		}
	
	npc_quests[npc_name]["quest_progress"] = progress
	
	# Auto-trigger quest stages
	if progress >= 25 and not npc_quests[npc_name]["appear"]:
		npc_quests[npc_name]["appear"] = true
		emit_signal("progression_updated", "story", npc_name + "_appear", true)
	
	if progress >= 75 and not npc_quests[npc_name]["shop"]:
		npc_quests[npc_name]["shop"] = true
		emit_signal("progression_updated", "story", npc_name + "_shop", true)
	
	if progress >= 100 and not npc_quests[npc_name]["quest_completed"]:
		npc_quests[npc_name]["quest_completed"] = true
		emit_signal("progression_updated", "story", npc_name + "_completed", true)
	
	story["npc_quests"] = npc_quests
	current_save_data["story_progression"] = story
	return true

func get_story_flag(flag: String) -> bool:
	"""Get story flag value"""
	var story = current_save_data.get("story_progression", {})
	return story.get(flag, false)

func get_npc_quest_progress(npc_name: String) -> int:
	"""Get NPC quest progress"""
	var story = current_save_data.get("story_progression", {})
	var npc_quests = story.get("npc_quests", {})
	if npc_quests.has(npc_name):
		return npc_quests[npc_name].get("quest_progress", 0)
	return 0

# 5. CLUBHOUSE PROGRESSION FUNCTIONS
func add_clubhouse_exp(exp_amount: int) -> bool:
	"""Add ClubHouse experience"""
	var clubhouse = current_save_data.get("clubhouse_progression", {})
	var current_exp = clubhouse.get("clubhouse_exp", 0)
	var current_level = clubhouse.get("clubhouse_level", 1)
	var exp_to_next = clubhouse.get("clubhouse_exp_to_next", 100)
	
	current_exp += exp_amount
	
	# Check for level up
	if current_exp >= exp_to_next:
		current_level += 1
		current_exp -= exp_to_next
		exp_to_next = current_level * 100  # Simple progression
		emit_signal("progression_updated", "clubhouse", "level_up", current_level)
	
	clubhouse["clubhouse_exp"] = current_exp
	clubhouse["clubhouse_level"] = current_level
	clubhouse["clubhouse_exp_to_next"] = exp_to_next
	current_save_data["clubhouse_progression"] = clubhouse
	
	return true

func unlock_clubhouse_equipment_table() -> bool:
	"""Unlock the ClubHouse equipment table"""
	var clubhouse = current_save_data.get("clubhouse_progression", {})
	if not clubhouse.get("equipment_table_unlocked", false):
		clubhouse["equipment_table_unlocked"] = true
		current_save_data["clubhouse_progression"] = clubhouse
		emit_signal("progression_updated", "clubhouse", "equipment_table_unlocked", true)
		return true
	return false

func add_clubhouse_equipment(equipment_name: String) -> bool:
	"""Add equipment to ClubHouse storage"""
	var clubhouse = current_save_data.get("clubhouse_progression", {})
	var equipment = clubhouse.get("clubhouse_equipment", [])
	
	if not equipment.has(equipment_name):
		equipment.append(equipment_name)
		clubhouse["clubhouse_equipment"] = equipment
		current_save_data["clubhouse_progression"] = clubhouse
		emit_signal("progression_updated", "clubhouse", "equipment_added", equipment_name)
		return true
	return false

func get_clubhouse_level() -> int:
	"""Get ClubHouse level"""
	var clubhouse = current_save_data.get("clubhouse_progression", {})
	return clubhouse.get("clubhouse_level", 1)

func is_equipment_table_unlocked() -> bool:
	"""Check if equipment table is unlocked"""
	var clubhouse = current_save_data.get("clubhouse_progression", {})
	return clubhouse.get("equipment_table_unlocked", false)

# =============================================================================
# EVENT TRIGGERING SYSTEM
# =============================================================================

func trigger_story_events(flag: String, value: bool):
	"""Trigger speech bubbles and cutscenes based on story flags"""
	if not value:  # Only trigger on positive flags
		return
	
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if not speech_manager:
		return
	
	match flag:
		"first_time_playing":
			trigger_intro_speech()
		"met_golfsmith":
			trigger_golfsmith_intro()
		"completed_front_9":
			trigger_front_9_completion()
		"defeated_first_boss":
			trigger_boss_defeat()
		"defeated_final_boss":
			trigger_victory_sequence()

func trigger_intro_speech():
	"""Trigger the intro speech for new players"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if speech_manager:
		var character_name = get_character_name(Global.selected_character)
		speech_manager.add_speech("intro_speech", 
			"Welcome to GolfCards, " + character_name + "! Ready to show off your skills?", 
			4.0, character_name)
		
		var player = get_tree().current_scene.get_node_or_null("Player")
		if player:
			speech_manager.trigger_speech("intro_speech", player)

func trigger_golfsmith_intro():
	"""Trigger golfsmith introduction speech"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if speech_manager:
		speech_manager.add_speech("golfsmith_intro", 
			"Welcome to my shop! I've got the finest equipment for a golfer like you.", 
			4.0, "Golfsmith")

func trigger_front_9_completion():
	"""Trigger front 9 completion speech"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if speech_manager:
		var character_name = get_character_name(Global.selected_character)
		speech_manager.add_speech("front_9_completion", 
			"Great work on the front 9! Ready for the back 9 challenge?", 
			4.0, character_name)

func trigger_boss_defeat():
	"""Trigger boss defeat speech"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if speech_manager:
		var character_name = get_character_name(Global.selected_character)
		speech_manager.add_speech("boss_defeat", 
			"Excellent! You've proven your worth. The course awaits!", 
			4.0, character_name)

func trigger_victory_sequence():
	"""Trigger the final victory sequence"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if speech_manager:
		var character_name = get_character_name(Global.selected_character)
		speech_manager.add_speech("victory_speech", 
			"Congratulations! You've mastered GolfCards! You're a true champion!", 
			5.0, character_name)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

func get_character_name(character_id: int) -> String:
	"""Get character name from ID"""
	match character_id:
		1: return "Layla"
		2: return "Benny"
		3: return "Clark"
		_: return "Unknown"

func get_character_max_hp(character_id: int) -> int:
	"""Get character max HP from ID"""
	match character_id:
		1: return 125
		2: return 150
		3: return 200
		_: return 100

func get_total_progression() -> int:
	"""Get total progression percentage (0-100)"""
	var total_flags = 0
	var completed_flags = 0
	
	# Count story flags
	var story = current_save_data.get("story_progression", {})
	for flag in story.values():
		if typeof(flag) == TYPE_BOOL:
			total_flags += 1
			if flag:
				completed_flags += 1
	
	# Count character unlocks
	var char_prog = current_save_data.get("character_progression", {})
	var unlocked = char_prog.get("unlocked_characters", 2)
	total_flags += 3  # 3 characters total
	completed_flags += unlocked
	
	# Count content unlocks
	var content = current_save_data.get("content_unlocks", {})
	var decks = content.get("unlocked_decks", ["starter"])
	var maps = content.get("unlocked_maps", ["golf_island"])
	
	total_flags += 5  # Assume 5 total decks
	completed_flags += decks.size()
	
	total_flags += 3  # Assume 3 total maps
	completed_flags += maps.size()
	
	if total_flags == 0:
		return 0
	
	return int((float(completed_flags) / float(total_flags)) * 100) 
