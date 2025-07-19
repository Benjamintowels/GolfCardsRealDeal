class_name UIManager
extends Node

# UI Layer reference
var ui_layer: CanvasLayer = null

# Dialog and overlay references
var drive_distance_dialog: Control = null
var shop_dialog: Control = null
var shop_overlay: Control = null
var mid_game_shop_overlay: Control = null
var puzzle_type_dialog: Control = null

# Button references
var end_round_button: Control = null
var end_turn_button: Control = null
var draw_cards_button: Control = null
var draw_club_cards_button: Control = null
var reach_ball_button: Control = null
var gimme_scene: Control = null

# Movement and card UI
var movement_buttons_container: BoxContainer = null
var movement_buttons: Array = []

# References to other systems
var course: Node = null
var player_manager: Node = null
var grid_manager: Node = null
var camera_manager: Node = null
var deck_manager: Node = null
var movement_controller: Node = null
var attack_handler: Node = null
var weapon_handler: Node = null
var launch_manager: Node = null

# UI state tracking
var shop_entrance_detected: bool = false

func setup(ui_layer_ref: CanvasLayer, course_ref: Node, player_mgr: Node, grid_mgr: Node, camera_mgr: Node, deck_mgr: Node, movement_ctrl: Node, attack_hdlr: Node, weapon_hdlr: Node, launch_mgr: Node):
	"""Initialize the UI manager with required references"""
	ui_layer = ui_layer_ref
	course = course_ref
	player_manager = player_mgr
	grid_manager = grid_mgr
	camera_manager = camera_mgr
	deck_manager = deck_mgr
	movement_controller = movement_ctrl
	attack_handler = attack_hdlr
	weapon_handler = weapon_hdlr
	launch_manager = launch_mgr
	
	# Get button references from UI layer
	end_round_button = ui_layer.get_node_or_null("EndRoundButton")
	end_turn_button = ui_layer.get_node_or_null("EndTurnButton")
	draw_cards_button = ui_layer.get_node_or_null("DrawCards")
	draw_club_cards_button = ui_layer.get_node_or_null("DrawClubCards")
	reach_ball_button = ui_layer.get_node_or_null("ReachBallButton")
	gimme_scene = ui_layer.get_node_or_null("Gimme")
	movement_buttons_container = ui_layer.get_node_or_null("CardHandAnchor/CardRow")
	
	print("UIManager setup complete")

# ===== DIALOG MANAGEMENT =====

func show_drive_distance_dialog(drive_distance: float) -> void:
	"""Show drive distance dialog"""
	print("=== SHOWING DRIVE DISTANCE DIALOG ===")
	print("Drive distance: ", drive_distance, " pixels")
	if drive_distance_dialog:
		print("Clearing existing drive distance dialog")
		drive_distance_dialog.queue_free()
	
	drive_distance_dialog = Control.new()
	drive_distance_dialog.name = "DriveDistanceDialog"
	drive_distance_dialog.size = course.get_viewport_rect().size
	drive_distance_dialog.z_index = 500  # Very high z-index to appear on top
	drive_distance_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = drive_distance_dialog.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP  # Make sure it can receive input
	drive_distance_dialog.add_child(background)
	background.gui_input.connect(_on_drive_distance_dialog_input)
	
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.9)
	dialog_box.size = Vector2(400, 200)
	dialog_box.position = (drive_distance_dialog.size - dialog_box.size) / 2  # Center the dialog
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drive_distance_dialog.add_child(dialog_box)
	
	var title_label := Label.new()
	title_label.text = "Shot Distance"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(150, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	var distance_label := Label.new()
	distance_label.text = "%d pixels" % drive_distance
	distance_label.add_theme_font_size_override("font_size", 36)
	distance_label.add_theme_color_override("font_color", Color.WHITE)
	distance_label.add_theme_constant_override("outline_size", 2)
	distance_label.add_theme_color_override("font_outline_color", Color.BLACK)
	distance_label.position = Vector2(150, 80)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(distance_label)
	
	var instruction_label := Label.new()
	instruction_label.text = "Click anywhere to continue"
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	instruction_label.position = Vector2(120, 150)
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(instruction_label)
	
	ui_layer.add_child(drive_distance_dialog)

func _on_drive_distance_dialog_input(event: InputEvent) -> void:
	"""Handle drive distance dialog input"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("=== DRIVE DISTANCE DIALOG CLICKED ===")
		if drive_distance_dialog:
			print("Dismissing drive distance dialog")
			drive_distance_dialog.queue_free()
			drive_distance_dialog = null
		
		# Always transition to move phase after drive distance dialog
		print("Setting game phase to 'move' and showing draw cards button")
		if course.game_state_manager:
			course.game_state_manager.set_game_phase("move")
		course._update_player_mouse_facing_state()
		draw_cards_button.visible = true
		# Camera tween is already handled in the ball landing logic, so we don't need to call it here

func show_out_of_bounds_dialog() -> void:
	"""Show out of bounds dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Out of Bounds!"
	dialog.dialog_text = "Your ball went out of bounds!\n\nPenalty: +1 stroke\nYour ball has been returned to where you took the shot from.\n\nClick to select your club for the penalty shot."
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.RED)
	dialog.position = Vector2(400, 300)
	ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		course.enter_draw_cards_phase()  # Go directly to club selection
	)

func show_sand_landing_dialog() -> void:
	"""Show sand landing dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Sand Trap!"
	dialog.dialog_text = "Your ball landed in a sand trap!\n\nThis is a valid shot - no penalty.\nYou'll take your next shot from here."
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.ORANGE)
	dialog.position = Vector2(400, 300)
	ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
	)

func show_hole_completion_dialog() -> void:
	"""Show hole completion dialog using the existing HoleCompletionDialog scene"""
	print("=== SHOW_HOLE_COMPLETION_DIALOG CALLED ===")
	
	# Get the existing HoleCompletionDialog from the course
	var hole_completion_dialog = course.get_node_or_null("UILayer/HoleCompletionDialog")
	if hole_completion_dialog:
		# Setup and show the dialog
		hole_completion_dialog.setup_dialog(course, ui_layer)
		hole_completion_dialog.visible = true
		
		# Connect to dialog closed signal for cleanup
		if not hole_completion_dialog.dialog_closed.is_connected(_on_hole_completion_dialog_closed):
			hole_completion_dialog.dialog_closed.connect(_on_hole_completion_dialog_closed)
	else:
		print("ERROR: HoleCompletionDialog not found in UILayer")

func _on_hole_completion_dialog_closed() -> void:
	"""Handle cleanup when hole completion dialog is closed"""
	print("Hole completion dialog closed - cleanup complete")

# ===== SHOP MANAGEMENT =====

func show_shop_entrance_dialog() -> void:
	"""Show shop entrance dialog"""
	if shop_dialog:
		shop_dialog.queue_free()
	
	shop_dialog = Control.new()
	shop_dialog.name = "ShopEntranceDialog"
	shop_dialog.size = course.get_viewport_rect().size
	shop_dialog.z_index = 500
	shop_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = shop_dialog.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_dialog.add_child(background)
	
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.9)
	dialog_box.size = Vector2(400, 200)
	dialog_box.position = (shop_dialog.size - dialog_box.size) / 2  # Center the dialog
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_dialog.add_child(dialog_box)
	
	var title_label := Label.new()
	title_label.text = "Golf Shop"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.position = Vector2(150, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	var question_label := Label.new()
	question_label.text = "Would you like to enter the shop?"
	question_label.add_theme_font_size_override("font_size", 18)
	question_label.add_theme_color_override("font_color", Color.WHITE)
	question_label.position = Vector2(100, 80)
	question_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(question_label)
	
	var yes_button := Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.position = Vector2(120, 140)
	yes_button.pressed.connect(_on_shop_enter_yes)
	dialog_box.add_child(yes_button)
	
	var no_button := Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.position = Vector2(220, 140)
	no_button.pressed.connect(_on_shop_enter_no)
	dialog_box.add_child(no_button)
	
	ui_layer.add_child(shop_dialog)
	print("Shop entrance dialog created")

func show_shop_overlay() -> void:
	"""Show shop overlay"""
	print("=== SHOWING SHOP OVERLAY ===")
	var shop_scene = preload("res://Shop/ShopInterior.tscn")
	var shop_instance = shop_scene.instantiate()
	ui_layer.add_child(shop_instance)
	shop_instance.z_index = 1000
	course.get_tree().paused = true
	shop_overlay = shop_instance
	shop_instance.connect("shop_closed", _on_shop_overlay_return)
	print("=== SHOP OVERLAY SHOWN ===")

func show_mid_game_shop_overlay() -> void:
	"""Show the mid-game shop as an overlay"""
	print("=== SHOWING MID-GAME SHOP OVERLAY ===")
	
	# Create and show the mid-game shop overlay
	var mid_game_shop_scene = preload("res://MidGameShop.tscn")
	var mid_game_shop_instance = mid_game_shop_scene.instantiate()
	ui_layer.add_child(mid_game_shop_instance)
	mid_game_shop_instance.z_index = 1000
	
	# Store reference to the overlay
	mid_game_shop_overlay = mid_game_shop_instance
	
	# Pause the game while shop is open
	course.get_tree().paused = true
	
	print("=== MID-GAME SHOP OVERLAY SHOWN ===")

func show_reward_phase() -> void:
	"""Show the suitcase for reward selection"""
	print("Starting reward phase...")
	
	# Clear the player's hand and UI elements before showing rewards
	if deck_manager:
		print("Clearing player hand for reward phase - hand size before:", deck_manager.hand.size())
		deck_manager.hand.clear()
		print("Player hand cleared - hand size after:", deck_manager.hand.size())
		# Update the deck display to reflect the cleared hand
		course.ui_manager.update_deck_display()
	
	# Clear any movement buttons that might still be visible
	if movement_controller:
		movement_controller.clear_all_movement_ui()
	if attack_handler:
		attack_handler.clear_all_attack_ui()
	if weapon_handler:
		weapon_handler.clear_all_weapon_ui()
	
	# Create and show the suitcase
	var suitcase_scene = preload("res://UI/SuitCase.tscn")
	var suitcase = suitcase_scene.instantiate()
	suitcase.name = "SuitCase"  # Give it a specific name for cleanup
	ui_layer.add_child(suitcase)
	
	# Connect the suitcase opened signal
	suitcase.suitcase_opened.connect(_on_suitcase_opened)

# ===== EVENT HANDLERS =====

func _on_gimme_button_pressed() -> void:
	"""Handle gimme button press"""
	print("=== GIMME BUTTON PRESSED ===")
	
	# Hide the gimme button
	hide_gimme_button()
	
	# Complete the hole via gimme
	if course.has_method("complete_gimme_hole"):
		course.complete_gimme_hole()

func _on_shop_enter_yes() -> void:
	"""Handle shop enter yes button"""
	print("=== ENTERING SHOP ===")
	
	# Shop is now overlay system - no entrance detection needed
	
	# Show shop overlay
	show_shop_overlay()

func _on_shop_enter_no() -> void:
	"""Handle shop enter no button"""
	print("=== DECLINING SHOP ENTRANCE ===")
	
	# Shop is now overlay system - no state restoration needed
	# Just close the dialog and continue gameplay

func _on_shop_overlay_return() -> void:
	"""Handle returning from shop overlay"""
	print("=== RETURNING FROM SHOP ===")
	
	# Shop is now overlay system - no state restoration needed
	# Just continue gameplay

func _on_suitcase_opened() -> void:
	"""Handle suitcase opened"""
	print("=== SUITCASE OPENED ===")
	
	# Clear the suitcase from the UI
	var existing_suitcase = ui_layer.get_node_or_null("SuitCase")
	if existing_suitcase:
		existing_suitcase.queue_free()
	
	# Show the reward selection dialog
	show_suitcase_reward_selection()

func _on_reward_selected(reward_data: Resource, reward_type: String) -> void:
	"""Handle when a reward is selected"""
	print("=== REWARD SELECTED ===")
	print("Reward type:", reward_type)
	
	# Apply the reward based on type
	if reward_type == "card":
		course.deck_manager.add_card_to_current_deck(reward_data)
	elif reward_type == "equipment":
		var equipment_manager = course.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.add_equipment(reward_data)
	elif reward_type == "bag_upgrade":
		course.apply_bag_upgrade(reward_data)
	elif reward_type == "looty":
		course.add_looty_reward(reward_data)
	
	# Update HUD to reflect any changes (including $Looty balance)
	course.ui_manager.update_deck_display()
	
	# Clear the reward dialog
	var existing_reward_dialog = ui_layer.get_node_or_null("RewardSelectionDialog")
	if existing_reward_dialog:
		existing_reward_dialog.queue_free()
	
	# Continue to next hole
	course._on_advance_to_next_hole()

func _on_suitcase_reached() -> void:
	"""Handle when the player reaches a SuitCase"""
	print("=== SUITCASE REACHED ===")
	# This would handle suitcase reaching logic
	# Implementation depends on the specific suitcase system

func _on_map_suitcase_opened() -> void:
	"""Handle when the map SuitCase is opened"""
	print("=== MAP SUITCASE OPENED ===")
	# This would handle map suitcase opening logic
	# Implementation depends on the specific suitcase system

func _on_suitcase_reward_selected(reward_data: Resource, reward_type: String) -> void:
	"""Handle when a SuitCase reward is selected"""
	print("=== SUITCASE REWARD SELECTED ===")
	print("Reward type:", reward_type)
	
	# Apply the reward based on type
	if reward_type == "card":
		course.deck_manager.add_card_to_current_deck(reward_data)
	elif reward_type == "equipment":
		var equipment_manager = course.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.add_equipment(reward_data)
	elif reward_type == "bag_upgrade":
		course.apply_bag_upgrade(reward_data)
	elif reward_type == "looty":
		course.add_looty_reward(reward_data)
	
	# Update HUD to reflect any changes (including $Looty balance)
	course.ui_manager.update_deck_display()
	
	# Clear the reward dialog and SuitCase overlay
	var existing_reward_dialog = ui_layer.get_node_or_null("SuitCaseRewardDialog")
	if existing_reward_dialog:
		existing_reward_dialog.queue_free()
	
	var existing_map_suitcase_overlay = ui_layer.get_node_or_null("MapSuitCaseOverlay")
	if existing_map_suitcase_overlay:
		existing_map_suitcase_overlay.queue_free()
	
	# Resume gameplay (don't transition to next hole)
	print("SuitCase reward selection complete - resuming gameplay")

func _on_puzzle_type_selected(puzzle_type: String) -> void:
	"""Handle puzzle type selection"""
	print("Puzzle type selected:", puzzle_type)
	
	# Update game state with selected puzzle type
	if course.game_state_manager:
		course.game_state_manager.set_next_puzzle_type(puzzle_type)
	
	# Clean up the dialog
	var puzzle_dialog = ui_layer.get_node_or_null("PuzzleTypeSelectionDialog")
	if puzzle_dialog:
		puzzle_dialog.queue_free()
	
	# Reset for next hole (this will advance to the next hole and set up the new hole)
	course.reset_for_next_hole()

func show_suitcase_overlay() -> void:
	"""Show the SuitCase overlay for reward selection"""
	print("=== SHOWING SUITCASE OVERLAY ===")
	
	# Clear any movement buttons that might still be visible during SuitCase interaction
	if movement_controller:
		movement_controller.clear_all_movement_ui()
	if attack_handler:
		attack_handler.clear_all_attack_ui()
	if weapon_handler:
		weapon_handler.clear_all_weapon_ui()
	
	# Create and show the SuitCase overlay
	var suitcase_scene = preload("res://UI/SuitCase.tscn")
	var suitcase = suitcase_scene.instantiate()
	suitcase.name = "MapSuitCaseOverlay"  # Give it a specific name for cleanup
	ui_layer.add_child(suitcase)
	
	# Connect the suitcase opened signal
	suitcase.suitcase_opened.connect(_on_map_suitcase_opened)

func show_suitcase_reward_selection() -> void:
	"""Show suitcase reward selection"""
	# Create and show the reward selection dialog
	var reward_dialog_scene = preload("res://RewardSelectionDialog.tscn")
	var reward_dialog = reward_dialog_scene.instantiate()
	reward_dialog.name = "SuitCaseRewardDialog"  # Give it a specific name for cleanup
	ui_layer.add_child(reward_dialog)
	
	# Connect the reward selected signal to the hole completion reward handler
	reward_dialog.reward_selected.connect(_on_reward_selected)
	
	# Show the reward selection without the advance button
	reward_dialog.show_reward_selection()
	
	# Remove the advance button for SuitCase rewards
	var advance_button = reward_dialog.get_node_or_null("RewardContainer/AdvanceButton")
	if advance_button:
		advance_button.queue_free()

# ===== COMPLETION DIALOGS =====

func show_front_nine_complete_dialog() -> void:
	"""Show front nine completion dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Front Nine Complete!"
	dialog.dialog_text = "Congratulations! You've completed the front nine holes!\n\nWould you like to continue to the back nine?"
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.GREEN)
	dialog.position = Vector2(400, 300)
	ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		course.start_back_nine()
	)

func show_back_nine_complete_dialog() -> void:
	"""Show back nine completion dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Back Nine Complete!"
	dialog.dialog_text = "Congratulations! You've completed the back nine holes!\n\nWould you like to see your final score?"
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.GREEN)
	dialog.position = Vector2(400, 300)
	ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		show_course_complete_dialog()
	)

func show_course_complete_dialog() -> void:
	"""Show course completion dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Course Complete!"
	dialog.dialog_text = "Congratulations! You've completed the entire course!\n\nClick to return to the main menu."
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("font_color", Color.GOLD)
	dialog.position = Vector2(400, 300)
	ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		course._change_to_main()
	)

# ===== UTILITY FUNCTIONS =====

func show_turn_message(message: String, duration: float) -> void:
	"""Show a turn message for the specified duration"""
	var message_label := Label.new()
	message_label.name = "TurnMessageLabel"
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 48)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the message on screen
	var viewport_size = course.get_viewport_rect().size
	message_label.position = Vector2(viewport_size.x / 2 - 150, viewport_size.y / 2 - 50)
	message_label.z_index = 1000
	ui_layer.add_child(message_label)
	
	# Remove message after duration
	var timer = course.get_tree().create_timer(duration)
	await timer.timeout
	if is_instance_valid(message_label):
		message_label.queue_free()

func show_pause_menu() -> void:
	"""Show pause menu"""
	var pause_dialog = Control.new()
	pause_dialog.name = "PauseDialog"
	pause_dialog.position = Vector2.ZERO
	pause_dialog.size = Vector2(400, 300)
	pause_dialog.z_index = 1000
	pause_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.size = course.get_viewport_rect().size
	background.position = Vector2.ZERO
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dialog.add_child(background)
	
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.1, 0.1, 0.1, 0.95)
	dialog_box.size = Vector2(380, 280)
	dialog_box.position = Vector2(10, 10)
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_dialog.add_child(dialog_box)
	
	var title_label := Label.new()
	title_label.text = "Game Paused"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.position = Vector2(150, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title_label)
	
	var button_container = VBoxContainer.new()
	button_container.position = Vector2(100, 80)
	button_container.size = Vector2(200, 150)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(button_container)
	
	var end_round_button = Button.new()
	end_round_button.text = "End Round"
	end_round_button.size = Vector2(200, 40)
	end_round_button.pressed.connect(func(): _on_pause_end_round_pressed(pause_dialog))
	button_container.add_child(end_round_button)
	
	var quit_game_button = Button.new()
	quit_game_button.text = "Quit Game"
	quit_game_button.size = Vector2(200, 40)
	quit_game_button.pressed.connect(func(): _on_quit_game_pressed())
	button_container.add_child(quit_game_button)
	
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.size = Vector2(200, 40)
	cancel_button.pressed.connect(func(): _on_cancel_pause_pressed(pause_dialog))
	button_container.add_child(cancel_button)
	
	ui_layer.add_child(pause_dialog)

func _on_pause_end_round_pressed(pause_dialog: Control) -> void:
	"""Handle pause end round button"""
	pause_dialog.queue_free()
	course._on_end_round_pressed()

func _on_quit_game_pressed() -> void:
	"""Handle quit game button"""
	course.get_tree().quit()

func _on_cancel_pause_pressed(pause_dialog: Control) -> void:
	"""Handle cancel pause button"""
	pause_dialog.queue_free()

func show_puzzle_type_selection() -> void:
	"""Show puzzle type selection dialog"""
	# Create and show the puzzle type selection dialog
	var puzzle_dialog_scene = preload("res://PuzzleTypeSelectionDialog.tscn")
	var puzzle_dialog = puzzle_dialog_scene.instantiate()
	puzzle_dialog.name = "PuzzleTypeSelectionDialog"  # Give it a specific name for cleanup
	ui_layer.add_child(puzzle_dialog)
	
	# Connect the puzzle type selected signal
	puzzle_dialog.puzzle_type_selected.connect(_on_puzzle_type_selected)
	
	# Show the puzzle type selection
	puzzle_dialog.show_puzzle_selection()

# ===== INSTRUCTION AND GUIDANCE UI =====

func show_tee_selection_instruction() -> void:
	"""Show tee selection instruction"""
	var instruction_label := Label.new()
	instruction_label.name = "TeeInstructionLabel"
	instruction_label.text = "Click on a Tee Box to start your round!"
	instruction_label.add_theme_font_size_override("font_size", 24)
	instruction_label.add_theme_color_override("font_color", Color.YELLOW)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	instruction_label.position = Vector2(400, 200)
	instruction_label.z_index = 200
	ui_layer.add_child(instruction_label)

func show_aiming_instruction() -> void:
	"""Show aiming instruction"""
	var existing_instruction = ui_layer.get_node_or_null("AimingInstructionLabel")
	if existing_instruction:
		existing_instruction.queue_free()
	
	var instruction_label := Label.new()
	instruction_label.name = "AimingInstructionLabel"
	
	# Get club data from course
	var club_data = course.club_data if course.has_method("get_club_data") else {}
	var selected_club = course.game_state_manager.get_selected_club() if course.game_state_manager else ""
	
	if club_data.get(selected_club, {}).get("is_putter", false):
		instruction_label.text = "Move mouse to set landing spot\nLeft click to confirm, Right click to cancel\n(Putter: Power only, no height)"
	else:
		instruction_label.text = "Move mouse to set landing spot\nLeft click to confirm, Right click to cancel"
	
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.YELLOW)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	instruction_label.position = Vector2(400, 50)
	instruction_label.z_index = 200
	
	ui_layer.add_child(instruction_label)

func hide_aiming_instruction() -> void:
	"""Hide aiming instruction"""
	var instruction_label = ui_layer.get_node_or_null("AimingInstructionLabel")
	if instruction_label:
		instruction_label.queue_free()

# ===== GIMME UI =====

func show_gimme_animation() -> void:
	"""Show the gimme animation"""
	print("=== SHOWING GIMME ANIMATION ===")
	
	# Make gimme scene visible and animate it to the target position
	if gimme_scene:
		gimme_scene.visible = true
		print("Gimme scene made visible")
		
		# Create tween to animate gimme scene to target position
		var tween = course.create_tween()
		tween.set_parallel(true)
		
		# Animate position from current position (bottom of screen) to target position
		var current_pos = gimme_scene.position
		var target_pos = Vector2(451, 1018.0)  # Target position as specified (screen coordinates)
		print("Animating gimme from", current_pos, "to", target_pos)
		
		tween.tween_property(gimme_scene, "position", target_pos, 0.8)
		tween.tween_callback(func():
			print("=== GIMME ANIMATION COMPLETE - PLAYING SOUNDS ===")
			# Play gimme sounds through SoundManager
			course.sound_manager.play_gimme_sounds()
		).set_delay(0.5)

func show_gimme_button() -> void:
	"""Show the gimme button"""
	if gimme_scene:
		gimme_scene.visible = true
		print("Gimme button shown")

func hide_gimme_button() -> void:
	"""Hide the gimme button"""
	if gimme_scene:
		gimme_scene.visible = false
		print("Gimme button hidden")

# ===== BUTTON MANAGEMENT =====

func show_draw_cards_button_for_turn_start() -> void:
	"""Show draw cards button for turn start"""
	if draw_cards_button:
		draw_cards_button.visible = true

func show_draw_club_cards_button() -> void:
	"""Show draw club cards button"""
	if draw_club_cards_button:
		draw_club_cards_button.visible = true

func enter_draw_cards_phase() -> void:
	"""Enter the draw cards phase - start with club selection"""
	# Set game phase to draw_cards instead of launch to prevent immediate ball launch
	course.game_state_manager.set_game_phase("draw_cards")
	
	# Show the draw club cards button to start the phase
	show_draw_club_cards_button()

func show_aiming_circle() -> void:
	"""Show the aiming circle for shot direction"""
	if course.game_state_manager and course.game_state_manager.get_aiming_circle_manager():
		course.game_state_manager.get_aiming_circle_manager().show_aiming_circle()

func hide_aiming_circle() -> void:
	"""Hide the aiming circle"""
	if course.game_state_manager and course.game_state_manager.get_aiming_circle_manager():
		course.game_state_manager.get_aiming_circle_manager().hide_aiming_circle()

func update_aiming_circle() -> void:
	"""Update the aiming circle position and rotation"""
	if course.game_state_manager and course.game_state_manager.get_aiming_circle_manager():
		var manager = course.game_state_manager.get_aiming_circle_manager()
		if manager and manager.has_method("update_aiming_circle_position"):
			var player_global_pos = course.player_manager.get_player_node().global_position
			var player_local_pos = course.camera.to_local(player_global_pos)
			manager.update_aiming_circle_position(player_global_pos, player_local_pos)

func cleanup() -> void:
	"""Clean up UI manager resources"""
	# Clear all dialogs and overlays
	if drive_distance_dialog and is_instance_valid(drive_distance_dialog):
		drive_distance_dialog.queue_free()
		drive_distance_dialog = null
	
	if shop_dialog and is_instance_valid(shop_dialog):
		shop_dialog.queue_free()
		shop_dialog = null
	
	if shop_overlay and is_instance_valid(shop_overlay):
		shop_overlay.queue_free()
		shop_overlay = null
	
	if mid_game_shop_overlay and is_instance_valid(mid_game_shop_overlay):
		mid_game_shop_overlay.queue_free()
		mid_game_shop_overlay = null
	
	if puzzle_type_dialog and is_instance_valid(puzzle_type_dialog):
		puzzle_type_dialog.queue_free()
		puzzle_type_dialog = null

# ===== PLAYER INPUT HANDLING =====

func handle_player_input(event: InputEvent, game_state_manager: Node, course: Node) -> void:
	"""Handle player input events"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_state_manager.get_game_phase() == "move":
			course.enter_aiming_phase()  # Start aiming phase instead of just drawing cards
		elif game_state_manager.get_game_phase() == "draw_cards":
			# In draw_cards phase, clicking should draw cards and transition to club_selection phase
			if course.deck_manager.hand.size() == 0:
				course.draw_cards_for_next_shot()  # Draw cards for shot
			else:
				pass # Already have cards in draw_cards phase - ready to take shot
		elif game_state_manager.get_game_phase() == "club_selection":
			# In club_selection phase, clicking should show club selection UI
			# This is handled by the draw club cards button, so no action needed here
			pass
		elif game_state_manager.get_game_phase() == "launch":
			if course.deck_manager.hand.size() == 0:
				course.draw_cards_for_next_shot()  # Draw cards for shot
			else:
				pass # Already have cards in launch phase - ready to take shot
		else:
			pass # Player clicked but not in move, draw_cards, club_selection, or launch phase

func update_deck_display() -> void:
	"""Update the deck display to show current deck state"""
	var hud := course.get_node("UILayer/HUD")
	hud.get_node("TurnLabel").text = "Turn: %d (Global: %d)" % [course.game_state_manager.get_turn_count(), Global.global_turn_count]
	
	# Show separate counts for club and action cards using the new ordered deck system
	var club_draw_count = deck_manager.club_draw_pile.size()
	var club_discard_count = deck_manager.club_discard_pile.size()
	
	# Use the new ordered deck system for action cards
	var action_draw_remaining = deck_manager.get_action_deck_remaining_cards().size()
	var action_discard_count = deck_manager.get_action_discard_pile().size()
	
	hud.get_node("DrawLabel").text = "Club Draw: %d | Action Draw: %d" % [club_draw_count, action_draw_remaining]
	hud.get_node("DiscardLabel").text = "Club Discard: %d | Action Discard: %d" % [club_discard_count, action_discard_count]
	hud.get_node("ShotLabel").text = "Shots: %d" % course.game_state_manager.get_hole_score()
	
	# Show next spawn increase milestone
	var next_milestone = ((Global.global_turn_count - 1) / 5 + 1) * 5
	var turns_until_milestone = next_milestone - Global.global_turn_count
	if turns_until_milestone > 0:
		hud.get_node("ShotLabel").text += " | Next spawn increase: %d turns" % turns_until_milestone
	
	# Show current reward tier
	hud.get_node("ShotLabel").text += " | Reward Tier: %d" % Global.get_current_reward_tier()
	
	# Show $Looty balance
	var looty_label = hud.get_node_or_null("LootyLabel")
	if not looty_label:
		looty_label = Label.new()
		looty_label.name = "LootyLabel"
		hud.add_child(looty_label)
	looty_label.text = "$Looty: %d" % Global.get_looty()
	looty_label.add_theme_color_override("font_color", Color.GOLD)
	
	# Update card stack display with total counts (for backward compatibility)
	var total_draw_cards = action_draw_remaining + club_draw_count
	var total_discard_cards = action_discard_count + club_discard_count
	course.card_stack_display.update_draw_stack(total_draw_cards)
	course.card_stack_display.update_discard_stack(total_discard_cards)

func display_selected_character() -> void:
	"""Display the selected character information"""
	var character_name = ""
	if course.character_label:
		match Global.selected_character:
			1: character_name = "Layla"
			2: character_name = "Benny"
			3: character_name = "Clark"
			_: character_name = "Unknown"
		course.character_label.text = character_name
	if course.character_image:
		match Global.selected_character:
			1: 
				course.character_image.texture = load("res://character1.png")
				course.character_image.scale = Vector2(0.42, 0.42)
				course.character_image.position.y = 320.82
			2: 
				course.character_image.texture = load("res://character2.png")
			3: 
				course.character_image.texture = load("res://character3.png")
	
	if course.bag and course.bag.has_method("set_character"):
		course.bag.set_character(character_name)

# ===== GIMME SEQUENCE MANAGEMENT =====

func trigger_gimme_sequence() -> void:
	"""Trigger the gimme sequence with animations and sounds"""
	# Early return if game_state_manager is not initialized yet
	if not course.game_state_manager:
		return
		
	print("=== TRIGGERING GIMME SEQUENCE ===")
	
	# Set gimme as active
	course.game_state_manager.activate_gimme(course.launch_manager.golf_ball)
	
	# Get the gimme scene
	if not gimme_scene:
		print("ERROR: Could not find Gimme scene")
		return
	
	# Make sure the gimme scene is visible
	gimme_scene.visible = true
	print("Gimme scene made visible")
	
	# Play the gimme sounds
	course.sound_manager.play_gimme_sounds()
	
	# Complete the hole with an extra stroke
	complete_hole_with_gimme()

func complete_hole_with_gimme() -> void:
	"""Complete the hole with gimme (add extra stroke and show completion)"""
	# Early return if game_state_manager is not initialized yet
	if not course.game_state_manager:
		return
		
	print("=== COMPLETING GIMME HOLE ===")
	
	# Add extra stroke for the gimme putt
	course.game_state_manager.increment_hole_score()
	print("Added gimme stroke - final hole score:", course.game_state_manager.get_hole_score())
	
	# Clear the ball
	if course.launch_manager.golf_ball and is_instance_valid(course.launch_manager.golf_ball):
		course.launch_manager.golf_ball.queue_free()
		course.launch_manager.golf_ball = null
	
	# Hide the gimme button
	hide_gimme_button()
	
	# Reset gimme state
	course.game_state_manager.deactivate_gimme()
	
	# Show hole completion dialog
	show_hole_completion_dialog()

func clear_gimme_state() -> void:
	"""Clear the gimme state when appropriate (new ball launched, hole completed, etc.)"""
	# Early return if game_state_manager is not initialized yet
	if not course.game_state_manager:
		return
		
	print("=== CLEARING GIMME STATE ===")
	course.game_state_manager.deactivate_gimme()
	hide_gimme_button()
	print("Gimme state cleared")

func complete_gimme_hole() -> void:
	"""Complete the hole with gimme (add extra stroke and show completion)"""
	# Early return if game_state_manager is not initialized yet
	if not course.game_state_manager:
		return
		
	print("=== COMPLETING GIMME HOLE ===")
	
	# Add extra stroke for the gimme putt
	course.game_state_manager.increment_hole_score()
	print("Added gimme stroke - final hole score:", course.game_state_manager.get_hole_score())
	
	# Clear the ball
	if course.launch_manager.golf_ball and is_instance_valid(course.launch_manager.golf_ball):
		course.launch_manager.golf_ball.queue_free()
		course.launch_manager.golf_ball = null
	
	# Animate gimme scene back out of the way
	if gimme_scene:
		var tween = course.create_tween()
		var hide_pos = gimme_scene.position + Vector2(0, 200)  # Move down to hide
		tween.tween_property(gimme_scene, "position", hide_pos, 0.5)
		tween.tween_callback(func():
			gimme_scene.visible = false
		)
	
	# Reset gimme state
	course.game_state_manager.deactivate_gimme()
	
	# Show hole completion dialog
	show_hole_completion_dialog() 
