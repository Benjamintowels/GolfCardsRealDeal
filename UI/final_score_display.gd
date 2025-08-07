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
@onready var level_up_sound: AudioStreamPlayer2D = $LevelUp

var file_level_manager: Node

# Animation variables
var is_animating: bool = false
var animation_duration: float = 1.5
var animation_timer: float = 0.0

# Level up animation variables
var current_animation_level: int = 1
var target_animation_level: int = 1
var animation_start_exp: int = 0
var animation_target_exp: int = 0
var is_leveling_up: bool = false
var level_up_delay: float = 0.5  # Delay after level up before continuing

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
		
		if is_leveling_up:
			# Wait for level up delay
			if animation_timer >= level_up_delay:
				is_leveling_up = false
				animation_timer = 0.0
				# Continue to next level
				_start_next_level_animation()
		else:
			var progress = min(animation_timer / animation_duration, 1.0)
			
			# Animate current level
			var current_exp = lerp(animation_start_exp, animation_target_exp, progress)
			var exp_progress = _calculate_exp_progress_for_level(current_exp, current_animation_level)
			character_exp_bar.value = exp_progress * 100.0
			clubhouse_exp_bar.value = exp_progress * 100.0
			
			# Update labels
			_update_labels_for_level(current_exp, current_animation_level)
			
			# Check if we've reached 100% and need to level up
			if progress >= 1.0 and current_animation_level < target_animation_level:
				_trigger_level_up()
			elif progress >= 1.0 and current_animation_level >= target_animation_level:
				# Animation complete
				is_animating = false
				# Final update to ensure exact values
				update_display()

func _calculate_exp_progress_for_level(exp: int, level: int) -> float:
	var current_level_exp = exp
	var exp_required = file_level_manager.get_exp_required_for_level(level)
	
	# Ensure we don't go negative
	current_level_exp = max(0, current_level_exp)
	
	return float(current_level_exp) / float(exp_required)

func _update_labels_for_level(exp: int, level: int):
	# Update character label
	var exp_required = file_level_manager.get_exp_required_for_level(level)
	var current_exp = max(0, exp)  # Ensure we don't show negative values
	character_exp_label.text = str(current_exp) + " / " + str(exp_required) + " XP"
	
	# Update clubhouse label (same logic for now)
	clubhouse_exp_label.text = str(current_exp) + " / " + str(exp_required) + " XP"
	
	# Update titles
	character_title.text = "Benny - Level " + str(level)
	clubhouse_title.text = "ClubHouse - Level " + str(level)

func _trigger_level_up():
	"""Trigger level up animation and sound"""
	is_leveling_up = true
	animation_timer = 0.0
	
	# Play level up sound
	if level_up_sound:
		level_up_sound.play()
	
	# Set progress bar to 100% for this level
	character_exp_bar.value = 100.0
	clubhouse_exp_bar.value = 100.0

func _start_next_level_animation():
	"""Start animation for the next level"""
	current_animation_level += 1
	
	# Start from 0 exp in the new level
	animation_start_exp = 0
	
	# Calculate target exp in the new level
	var pre_round_values = file_level_manager.get_pre_round_values()
	var current_values = file_level_manager.get_current_stats()
	var total_exp_gained = current_values.character_experience - pre_round_values.character_experience
	
	# Calculate how much exp has been used in previous levels
	var exp_used_in_previous_levels = 0
	for level in range(1, current_animation_level):
		exp_used_in_previous_levels += file_level_manager.get_exp_required_for_level(level)
	
	# Calculate remaining exp for current level
	var remaining_exp = total_exp_gained - exp_used_in_previous_levels
	animation_target_exp = max(0, remaining_exp)  # Ensure we don't go negative
	
	# Reset animation timer
	animation_timer = 0.0

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
	var current_values = file_level_manager.get_current_stats()
	
	# Initialize animation variables
	current_animation_level = pre_round_values.character_level
	target_animation_level = current_values.character_level
	
	# Calculate start exp for the first level
	var start_level_exp = pre_round_values.character_experience
	for i in range(1, current_animation_level):
		start_level_exp -= file_level_manager.get_exp_required_for_level(i)
	animation_start_exp = max(0, start_level_exp)  # Ensure we don't start negative
	
	# Calculate target exp for the first level
	if current_animation_level == target_animation_level:
		# Same level, animate to current exp
		var current_level_exp = current_values.character_experience
		for i in range(1, current_animation_level):
			current_level_exp -= file_level_manager.get_exp_required_for_level(i)
		animation_target_exp = max(0, current_level_exp)
	else:
		# Different level, animate to 100% of current level
		animation_target_exp = file_level_manager.get_exp_required_for_level(current_animation_level)
	
	# Start with pre-round values
	character_exp_bar.value = _calculate_exp_progress_for_level(animation_start_exp, current_animation_level) * 100.0
	clubhouse_exp_bar.value = _calculate_exp_progress_for_level(animation_start_exp, current_animation_level) * 100.0
	
	# Update labels with pre-round values
	_update_labels_for_level(animation_start_exp, current_animation_level)
	
	# Start animation
	is_animating = true
	is_leveling_up = false
	animation_timer = 0.0
	
	show()
