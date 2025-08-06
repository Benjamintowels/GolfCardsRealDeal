extends Control

signal dialog_closed

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
		var total_par = 0
		if is_back_9_mode:
			total_par = GolfCourseLayout.get_back_nine_par()
		else:
			total_par = GolfCourseLayout.get_front_nine_par()
		var round_vs_par = total_round_score - total_par
		
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
	if is_back_9_mode:
		actual_hole_number = course.game_state_manager.back_9_start_hole + current_hole + 1
	
	print("Hole completion dialog: Adding experience for hole ", actual_hole_number)
	file_level_manager.complete_hole(actual_hole_number)
	
	# Check if this is the final hole (hole 18 or hole 9 in front 9 mode)
	var is_final_hole = false
	if is_back_9_mode:
		is_final_hole = (actual_hole_number == 18)
	else:
		is_final_hole = (actual_hole_number == 9)
	
	# If this is the final hole, set global flag to show final score display when returning to main
	if is_final_hole:
		print("Final hole completed - setting global flag to show final score display")
		Global.show_final_score_display = true
