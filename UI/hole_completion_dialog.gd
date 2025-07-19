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
	if course and course.game_state_manager and course.game_state_manager.get_current_hole_index() < round_end_hole:
		# Show reward selection dialog
		if course.ui_manager and course.ui_manager.has_method("show_reward_phase"):
			course.ui_manager.show_reward_phase()
	else:
		# Show course complete dialog
		if course.has_method("show_course_complete_dialog"):
			course.show_course_complete_dialog()
