extends Control

signal dialog_closed

const BossFight := preload("res://Maps/BossFightLayout.gd")

var course: Node = null
var ui_layer: CanvasLayer = null
var round_end_hole: int = 0

func _ready():
	# Connect to input events for click to continue
	gui_input.connect(_on_gui_input)
	
	# Make sure the dialog starts hidden and is on top when shown
	visible = false
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup_dialog(course_ref: Node, ui_layer_ref: CanvasLayer) -> void:
	"""Setup the dialog with course and UI layer references"""
	course = course_ref
	ui_layer = ui_layer_ref
	
	# Quest trigger: If Golfsmith survived this hole, play success and set appear flag
	if course:
		var npcs = course.get_tree().get_nodes_in_group("NPC")
		var golfsmith_node: Node = null
		var golfsmith_alive := false
		for n in npcs:
			if is_instance_valid(n) and n.name == "GolfSmith":
				golfsmith_node = n
				var alive := true
				if n.has_method("get_is_dead"):
					alive = not n.get_is_dead()
				elif n.has_method("is_dead"):
					alive = not n.is_dead()
				elif "is_dead" in n:
					alive = not n.is_dead
				golfsmith_alive = alive
				break
		if golfsmith_alive and golfsmith_node:
			var success_audio = golfsmith_node.get_node_or_null("Success")
			if success_audio and success_audio.has_method("play"):
				success_audio.play()
			var save_file_manager = course.get_node_or_null("/root/SaveFileManager")
			if save_file_manager and save_file_manager.has_method("get_npc_quest_progress") and save_file_manager.has_method("set_npc_quest_progress"):
				var current_progress: int = save_file_manager.get_npc_quest_progress("golfsmith")
				if current_progress < 25:
					save_file_manager.set_npc_quest_progress("golfsmith", 25)
	
	# Play hole complete sound
	var hole_complete_sound = course.get_node_or_null("HoleComplete")
	if hole_complete_sound and hole_complete_sound.stream:
		hole_complete_sound.play()
	
	# Play background squish animation on hole completion
	if course.has_method("play_background_squish_animation"):
		course.play_background_squish_animation()
	
	# Give $Looty reward for completing the hole
	var looty_reward = Global.give_hole_completion_reward()
	
	# Initialize variables with default values
	var hole_score = 0
	var current_hole = 0
	var round_scores = []
	var is_back_9_mode = false
	var score_text = ""
	
	if course.game_state_manager:
		course.game_state_manager.complete_hole()
		hole_score = course.game_state_manager.get_hole_score()
		current_hole = course.game_state_manager.get_current_hole_index()
		round_scores = course.game_state_manager.get_round_scores()
		is_back_9_mode = course.game_state_manager.is_back_9_mode
		
		var hole_par = GolfCourseLayout.get_hole_par(current_hole)
		var score_vs_par = hole_score - hole_par
		score_text = "Hole %d Complete!\n\n" % (current_hole + 1)
		score_text += "Hole Score: %d strokes\n" % hole_score
		score_text += "Par: %d\n" % hole_par
		score_text += "Reward: %d $Looty\n" % looty_reward
		if score_vs_par == 0:
			score_text += "Score: Par ✓\n"
		elif score_vs_par == 1:
			score_text += "Score: Bogey (+1)\n"
		elif score_vs_par == 2:
			score_text += "Score: Double Bogey (+2)\n"
		elif score_vs_par == -1:
			score_text += "Score: Birdie (-1) ✓\n"
		elif score_vs_par == -2:
			score_text += "Score: Eagle (-2) ✓\n"
		else:
			score_text += "Score: %+d\n" % score_vs_par
		var total_round_score = 0
		for score in round_scores:
			total_round_score += score
		# Expected par uses simple 4-per-hole for holes actually completed
		var total_par = round_scores.size() * 4
		var round_vs_par = total_round_score - total_par
		# Store running score for final screen logic
		Global.last_round_score = total_round_score
		Global.last_round_expected_par = total_par
		
		score_text += "\nRound Progress: %d/%d holes\n" % [current_hole + 1, course.game_state_manager.NUM_HOLES]
		score_text += "Round Score: %d\n" % total_round_score
		score_text += "Round vs Par: %+d\n" % round_vs_par
		if is_back_9_mode:
			round_end_hole = course.game_state_manager.back_9_start_hole + course.game_state_manager.NUM_HOLES - 1  # Hole 18 (index 17)
		else:
			round_end_hole = course.game_state_manager.NUM_HOLES - 1  # Hole 9 (index 8)
		if current_hole < round_end_hole:
			score_text += "\nClick to continue to the next hole."
		elif current_hole == round_end_hole and not is_back_9_mode:
			# This is hole 9 in front 9 mode - show front nine completion message
			score_text += "\nClick to continue to the back nine!"
		else:
			score_text += "\nClick to see your final round score!"
	
	# Update the Score label with the score text
	var score_label = get_node_or_null("DialogBox/Score")
	if score_label:
		score_label.text = score_text
		score_label.add_theme_font_size_override("font_size", 16)
		score_label.add_theme_color_override("font_color", Color.BLACK)
		score_label.add_theme_constant_override("outline_size", 2)
		score_label.add_theme_color_override("font_outline_color", Color.WHITE)
		print("Score label updated with text: ", score_text)
	else:
		print("ERROR: Could not find Score label at DialogBox/Score")

func _on_gui_input(event: InputEvent) -> void:
	"""Handle input events for the dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()

func close_dialog() -> void:
	"""Close the dialog and handle next steps"""
	# Hide the dialog
	visible = false
	
	# Emit signal for cleanup
	dialog_closed.emit()
	
	# Handle next steps based on game state
	var current_hole = course.game_state_manager.get_current_hole_index() if course and course.game_state_manager else 0
	var is_back_9_mode = course.game_state_manager.is_back_9_mode if course and course.game_state_manager else false
	
	# Integrate with FileLevelManager progression system
	_integrate_progression_system(current_hole, is_back_9_mode)
	
	# Handle ClubHouse Looty transfer for final holes
	_handle_clubhouse_looty_transfer(current_hole, is_back_9_mode)
	
	# Calculate the actual hole number (1-18) based on current hole index and mode
	var actual_hole_number = current_hole + 1
	# Note: In back 9 mode, current_hole is already the absolute index (9-17 for holes 10-18)
	# So we don't need to add back_9_start_hole again
	
	# Special case: Hole 18 in Adventure Mode (back 9 mode) - transition to boss fight
	if actual_hole_number == 18 and is_back_9_mode:
		print("Hole 18 completed in Adventure Mode - transitioning to BossEye fight")
		_transition_to_boss_fight()
		return
	
	if current_hole < round_end_hole:
		# Show reward selection dialog for regular holes
		if course.ui_manager and course.ui_manager.has_method("show_reward_phase"):
			course.ui_manager.show_reward_phase()
	elif current_hole == round_end_hole and not is_back_9_mode:
		# This is hole 9 in front 9 mode - show front nine completion dialog
		if course.ui_manager and course.ui_manager.has_method("show_front_nine_complete_dialog"):
			course.ui_manager.show_front_nine_complete_dialog()
	else:
		# Show course complete dialog for final hole
		if course.has_method("show_course_complete_dialog"):
			course.show_course_complete_dialog()

func _integrate_progression_system(current_hole: int, is_back_9_mode: bool):
	"""Integrate with FileLevelManager progression system"""
	# FileLevelManager is now an autoload, accessible globally
	var file_level_manager = FileLevelManager
	if not file_level_manager:
		print("ERROR: FileLevelManager autoload not found in hole completion dialog!")
		return
	
	# Calculate the actual hole number (1-18) based on current hole index and mode
	var actual_hole_number = current_hole + 1
	# Note: In back 9 mode, current_hole is already the absolute index (9-17 for holes 10-18)
	# So we don't need to add back_9_start_hole again
	
	print("Hole completion dialog: Debug - current_hole:", current_hole, "is_back_9_mode:", is_back_9_mode, "back_9_start_hole:", course.game_state_manager.back_9_start_hole, "calculated hole:", actual_hole_number)
	file_level_manager.complete_hole(actual_hole_number)
	
	# Check if this is the final hole (hole 18 or hole 9 in front 9 mode)
	var is_final_hole = false
	if is_back_9_mode:
		is_final_hole = (actual_hole_number == 18)
	else:
		is_final_hole = (actual_hole_number == 9)
	
	# If this is the final hole, set global flag to show final score display when returning to main
	# But only if we're not transitioning to a boss fight
	if is_final_hole and not (actual_hole_number == 18 and is_back_9_mode):
		print("Final hole completed - setting global flag to show final score display")
		Global.show_final_score_display = true

func _handle_clubhouse_looty_transfer(current_hole: int, is_back_9_mode: bool):
	"""Handle ClubHouse Looty transfer for final holes"""
	var clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	if not clubhouse_upgrade_manager:
		print("ERROR: ClubHouseUpgradeManager not found in hole completion dialog!")
		return
	
	# Calculate the actual hole number (1-18) based on current hole index and mode
	var actual_hole_number = current_hole + 1
	# Note: In back 9 mode, current_hole is already the absolute index (9-17 for holes 10-18)
	# So we don't need to add back_9_start_hole again
	
	# Check if this is hole 18 (final hole)
	if actual_hole_number == 18:
		print("Hole 18 completed! Doubling course Looty")
		clubhouse_upgrade_manager.handle_hole_18_completion()
	
	# Check if this is the final hole of the round (hole 9 or 18)
	var is_final_hole = false
	if is_back_9_mode:
		is_final_hole = (actual_hole_number == 18)
	else:
		is_final_hole = (actual_hole_number == 9)
	
	# Transfer course Looty to ClubHouse for final holes
	# But only if we're not transitioning to a boss fight
	if is_final_hole and not (actual_hole_number == 18 and is_back_9_mode):
		print("Final hole completed - transferring course Looty to ClubHouse")
		clubhouse_upgrade_manager.transfer_course_looty_to_clubhouse()

func _transition_to_boss_fight() -> void:
	"""Transition to BossEye fight after hole 18 completion"""
	print("=== TRANSITIONING TO BOSS FIGHT ===")
	
	# Set a flag to indicate we're in post-hole-18 boss fight mode
	Global.post_hole_18_boss_fight = true
	
	# Load the boss fight layout
	if course.map_manager and course.map_manager.has_method("load_map_data"):
		course.map_manager.load_map_data(BossFight.LAYOUT)
		print("Loaded Boss Fight layout for post-hole-18 boss fight")
	
	# Rebuild the map with boss fight layout
	if course.build_map and course.build_map.has_method("build_map_from_layout_with_randomization"):
		course.build_map.build_map_from_layout_with_randomization(
			course.map_manager.level_layout, 
			course.game_state_manager.get_current_hole_index(), 
			"boss_fight"  # Build boss fight with boss layout + difficulty-based NPCs
		)
		print("Built boss fight map")
	
	# Set the puzzle type to boss_fight for the boss fight
	if course.game_state_manager:
		course.game_state_manager.set_current_puzzle_type("boss_fight")
		course.game_state_manager.set_next_puzzle_type("boss_fight")
		print("Set puzzle type to boss_fight for boss fight")
	
	# Do NOT pre-place the player; mimic new-hole flow so player places once at tee
	
	# Reset game state for boss fight
	if course.game_state_manager:
		course.game_state_manager.set_game_phase("tee_select")
		course.game_state_manager.set_is_placing_player(true)
		course.game_state_manager.reset_hole_score()
		print("Reset game state for boss fight")
		# Re-enable camera panning for boss fight placement
		if course.camera_manager and course.camera_manager.has_method("enable_camera_panning"):
			course.camera_manager.enable_camera_panning()
			print("Camera panning enabled for boss fight")

	# Align camera intro to Boss Room flow: start on Boss area then tween to Tee
	if course.has_method("position_camera_on_pin"):
		course.position_camera_on_pin(true)
		print("Camera positioned on pin with intro transition for boss fight")

	# Highlight tee tiles and show instruction like normal hole start
	if course.map_manager and course.map_manager.has_method("highlight_tee_tiles"):
		course.map_manager.highlight_tee_tiles()
	if course.has_method("show_tee_selection_instruction"):
		course.show_tee_selection_instruction()
	
	# Show boss fight intro dialog or message
	if course.ui_manager and course.ui_manager.has_method("show_boss_fight_intro"):
		course.ui_manager.show_boss_fight_intro()
	else:
		# Fallback: show a simple message
		if course.ui_manager and course.ui_manager.has_method("show_turn_message"):
			course.ui_manager.show_turn_message("Boss Fight!", 3.0)
	
	print("=== BOSS FIGHT TRANSITION COMPLETE ===")
