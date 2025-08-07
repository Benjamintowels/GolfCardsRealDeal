extends Control

#use for tracking experience progression during a round. Upon death, or course completion (hole18) we want to transition to this scene to show progress before transitioning to the ClubHouse
#track number of holes completed. Show the Player and ClubHouse filling up an experience bar to level up.

signal return_to_clubhouse

@onready var character_title: Label = $MainPanel/VBoxContainer/ExperienceSection/CharacterSection/CharacterTitle
@onready var character_exp_bar: ProgressBar = $MainPanel/VBoxContainer/ExperienceSection/CharacterSection/CharacterExpBar
@onready var character_exp_label: Label = $MainPanel/VBoxContainer/ExperienceSection/CharacterSection/CharacterExpLabel

@onready var clubhouse_title: Label = $MainPanel/VBoxContainer/ExperienceSection/ClubhouseSection/ClubhouseTitle
@onready var clubhouse_exp_bar: ProgressBar = $MainPanel/VBoxContainer/ExperienceSection/ClubhouseSection/ClubhouseExpBar
@onready var clubhouse_exp_label: Label = $MainPanel/VBoxContainer/ExperienceSection/ClubhouseSection/ClubhouseExpLabel

@onready var continue_button: Button = $MainPanel/VBoxContainer/ContinueButton

var file_level_manager: Node

# Animation variables
var is_animating: bool = false
var animation_duration: float = 1.5
var animation_timer: float = 0.0

func _ready():
	# FileLevelManager is now an autoload, accessible globally
	file_level_manager = FileLevelManager
	
	# Connect to signals
	if file_level_manager:
		file_level_manager.experience_gained.connect(_on_experience_gained)
		file_level_manager.level_up.connect(_on_level_up)
	
	# Focus the continue button
	continue_button.grab_focus()

func _process(delta):
	if is_animating:
		animation_timer += delta
		var progress = min(animation_timer / animation_duration, 1.0)
		
		# Get pre-round values
		var pre_round_values = file_level_manager.get_pre_round_values()
		
		# Animate character experience bar
		var current_character_exp = lerp(pre_round_values.character_experience, file_level_manager.character_experience, progress)
		var current_character_level = file_level_manager.character_level
		var character_exp_progress = _calculate_exp_progress(current_character_exp, current_character_level)
		character_exp_bar.value = character_exp_progress * 100.0
		
		# Animate clubhouse experience bar
		var current_clubhouse_exp = lerp(pre_round_values.clubhouse_experience, file_level_manager.clubhouse_experience, progress)
		var current_clubhouse_level = file_level_manager.clubhouse_level
		var clubhouse_exp_progress = _calculate_exp_progress(current_clubhouse_exp, current_clubhouse_level)
		clubhouse_exp_bar.value = clubhouse_exp_progress * 100.0
		
		# Update labels during animation
		_update_labels(current_character_exp, current_clubhouse_exp, current_character_level, current_clubhouse_level)
		
		if progress >= 1.0:
			is_animating = false
			# Final update to ensure exact values
			update_display()

func _calculate_exp_progress(exp: int, level: int) -> float:
	var current_level_exp = exp
	var exp_required = file_level_manager.get_exp_required_for_level(level)
	
	# Subtract experience from previous levels
	for i in range(1, level):
		current_level_exp -= file_level_manager.get_exp_required_for_level(i)
	
	return float(current_level_exp) / float(exp_required)

func _update_labels(character_exp: int, clubhouse_exp: int, character_level: int, clubhouse_level: int):
	# Update character label
	var character_exp_required = file_level_manager.get_exp_required_for_level(character_level)
	var character_current_exp = character_exp
	for i in range(1, character_level):
		character_current_exp -= file_level_manager.get_exp_required_for_level(i)
	character_exp_label.text = str(character_current_exp) + " / " + str(character_exp_required) + " XP"
	
	# Update clubhouse label
	var clubhouse_exp_required = file_level_manager.get_exp_required_for_level(clubhouse_level)
	var clubhouse_current_exp = clubhouse_exp
	for i in range(1, clubhouse_level):
		clubhouse_current_exp -= file_level_manager.get_exp_required_for_level(i)
	clubhouse_exp_label.text = str(clubhouse_current_exp) + " / " + str(clubhouse_exp_required) + " XP"

func update_display():
	if not file_level_manager:
		return
	
	var stats = file_level_manager.get_current_stats()
	
	# Update character section
	character_title.text = "Benny - Level " + str(stats.character_level)
	character_exp_bar.value = stats.character_exp_progress * 100.0
	
	var character_exp_required = file_level_manager.get_exp_required_for_level(stats.character_level)
	var character_current_exp = stats.character_experience
	for i in range(1, stats.character_level):
		character_current_exp -= file_level_manager.get_exp_required_for_level(i)
	
	character_exp_label.text = str(character_current_exp) + " / " + str(character_exp_required) + " XP"
	
	# Update clubhouse section
	clubhouse_title.text = "ClubHouse - Level " + str(stats.clubhouse_level)
	clubhouse_exp_bar.value = stats.clubhouse_exp_progress * 100.0
	
	var clubhouse_exp_required = file_level_manager.get_exp_required_for_level(stats.clubhouse_level)
	var clubhouse_current_exp = stats.clubhouse_experience
	for i in range(1, stats.clubhouse_level):
		clubhouse_current_exp -= file_level_manager.get_exp_required_for_level(i)
	
	clubhouse_exp_label.text = str(clubhouse_current_exp) + " / " + str(clubhouse_exp_required) + " XP"

func _on_experience_gained(character_exp: int, clubhouse_exp: int):
	update_display()

func _on_level_up(character_level: int, clubhouse_level: int):
	update_display()
	# Could add level up effects here (particles, sounds, etc.)

func _on_continue_button_pressed():
	# Emit signal to return to clubhouse
	return_to_clubhouse.emit()
	
	# Change scene back to main (clubhouse)
	get_tree().change_scene_to_file("res://Main.tscn")

# Function to be called when transitioning to this scene
func show_final_score():
	# Get pre-round values from FileLevelManager
	var pre_round_values = file_level_manager.get_pre_round_values()
	
	# Start with pre-round values
	character_exp_bar.value = _calculate_exp_progress(pre_round_values.character_experience, pre_round_values.character_level) * 100.0
	clubhouse_exp_bar.value = _calculate_exp_progress(pre_round_values.clubhouse_experience, pre_round_values.clubhouse_level) * 100.0
	
	# Update labels with pre-round values
	_update_labels(pre_round_values.character_experience, pre_round_values.clubhouse_experience, pre_round_values.character_level, pre_round_values.clubhouse_level)
	
	# Update titles with pre-round levels
	character_title.text = "Benny - Level " + str(pre_round_values.character_level)
	clubhouse_title.text = "ClubHouse - Level " + str(pre_round_values.clubhouse_level)
	
	# Start animation
	is_animating = true
	animation_timer = 0.0
	
	show()
