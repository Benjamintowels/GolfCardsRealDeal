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
		
		# Check if gimme is active
		if course.gimme_active:
			print("=== GIMME DIALOG DISMISSED - COMPLETING HOLE ===")
			course.complete_gimme_hole()
		else:
			print("Setting game phase to 'move' and showing draw cards button")
			course.game_phase = "move"
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
	"""Show hole completion dialog"""
	print("=== SHOW_HOLE_COMPLETION_DIALOG CALLED ===")
	print("Current hole:", course.current_hole)
	print("Hole score:", course.hole_score)
	
	# Play hole complete sound
	var hole_complete_sound = course.get_node_or_null("HoleComplete")
	if hole_complete_sound and hole_complete_sound.stream:
		hole_complete_sound.play()
		print("Playing hole complete sound")
	
	# Give $Looty reward for completing the hole
	var looty_reward = Global.give_hole_completion_reward()
	
	course.round_scores.append(course.hole_score)
	var hole_par = GolfCourseLayout.get_hole_par(course.current_hole)
	var score_vs_par = course.hole_score - hole_par
	var score_text = "Hole %d Complete!\n\n" % (course.current_hole + 1)
	score_text += "Hole Score: %d strokes\n" % course.hole_score
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
	for score in course.round_scores:
		total_round_score += score
	var total_par = 0
	if course.is_back_9_mode:
		total_par = GolfCourseLayout.get_back_nine_par()
	else:
		total_par = GolfCourseLayout.get_front_nine_par()
	var round_vs_par = total_round_score - total_par
	
	score_text += "\nRound Progress: %d/%d holes\n" % [course.current_hole + 1, course.NUM_HOLES]
	score_text += "Round Score: %d\n" % total_round_score
	score_text += "Round vs Par: %+d\n" % round_vs_par
	var round_end_hole = 0
	if course.is_back_9_mode:
		round_end_hole = course.back_9_start_hole + course.NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		round_end_hole = course.NUM_HOLES - 1  # Hole 9 (index 8)
	if course.current_hole < round_end_hole:
		score_text += "\nClick to continue to the next hole."
	else:
		score_text += "\nClick to see your final round score!"
	
	# Create custom dialog with Scorecard background
	var dialog = Control.new()
	dialog.name = "HoleCompletionDialog"
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)  # Center the dialog
	dialog.size = Vector2(600, 400)
	dialog.z_index = 1000
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.size = course.get_viewport_rect().size
	background.position = Vector2.ZERO
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.add_child(background)
	
	var dialog_box := ColorRect.new()
	dialog_box.color = Color(0.1, 0.1, 0.1, 0.95)
	dialog_box.size = Vector2(580, 380)
	dialog_box.position = Vector2(10, 10)
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(dialog_box)
	
	var score_label := Label.new()
	score_label.text = score_text
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_constant_override("outline_size", 2)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.position = Vector2(20, 20)
	score_label.size = Vector2(540, 340)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(score_label)
	
	# Add click to continue functionality
	background.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dialog.queue_free()
			if course.current_hole < round_end_hole:
				# Show reward selection dialog instead of calling non-existent start_next_hole
				show_reward_phase()
			else:
				course.show_course_complete_dialog()
	)
	
	ui_layer.add_child(dialog)

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

func _on_shop_enter_yes() -> void:
	"""Handle shop enter yes button"""
	show_shop_overlay()

func _on_shop_enter_no() -> void:
	"""Handle shop enter no button"""
	if shop_dialog:
		shop_dialog.queue_free()
		shop_dialog = null
	
	course.shop_entrance_detected = false
	
	# Update Y-sort for all objects to ensure proper layering
	Global.update_all_objects_y_sort(course.ysort_objects)
	
	course.exit_movement_mode()

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

func _on_shop_overlay_return() -> void:
	"""Handle returning from shop overlay"""
	print("=== REMOVING SHOP OVERLAY ===")
	
	# Check if we're in mid-game shop mode
	if course.is_mid_game_shop_mode():
		# Return to MidGameShop overlay - just remove the shop interior
		if shop_overlay and is_instance_valid(shop_overlay):
			shop_overlay.queue_free()
			shop_overlay = null
		
		# Reset the mid-game shop mode flag
		Global.in_mid_game_shop_mode = false
		
		# Show the mid-game shop overlay again
		show_mid_game_shop_overlay()
		
		print("=== RETURNED TO MID-GAME SHOP OVERLAY ===")
		return
	
	# Normal shop return flow
	# Unpause the game
	course.get_tree().paused = false
	
	# Remove the shop overlay
	if shop_overlay and is_instance_valid(shop_overlay):
		shop_overlay.queue_free()
		shop_overlay = null
	
	# Clear any shop dialog that might still be present
	if shop_dialog:
		shop_dialog.queue_free()
		shop_dialog = null
	
	# Reset shop entrance detection
	shop_entrance_detected = false
	
	# Update Y-sort for all objects to ensure proper layering
	Global.update_all_objects_y_sort(course.ysort_objects)
	
	# Exit movement mode
	course.exit_movement_mode()
	
	# Update HUD to reflect any changes (including $Looty balance from shop purchases)
	course.update_deck_display()
	
	print("=== SHOP OVERLAY REMOVED ===")

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

# ===== BUTTON MANAGEMENT =====

func show_gimme_button() -> void:
	"""Show the gimme button"""
	print("=== SHOWING GIMME BUTTON ===")
	
	if gimme_scene:
		gimme_scene.visible = true
		print("Gimme button made visible")
		
		# Connect the button press signal if not already connected
		var gimme_button = gimme_scene.get_node_or_null("GimmeButton")
		if gimme_button:
			print("GimmeButton found:", gimme_button.name)
			print("GimmeButton type:", gimme_button.get_class())
			print("GimmeButton mouse_filter:", gimme_button.mouse_filter)
			print("GimmeButton disabled:", gimme_button.disabled)
			print("GimmeButton visible:", gimme_button.visible)
			
			if not gimme_button.pressed.is_connected(_on_gimme_button_pressed):
				gimme_button.pressed.connect(_on_gimme_button_pressed)
				print("Gimme button signal connected")
			else:
				print("Gimme button signal already connected")
		else:
			print("ERROR: Could not find GimmeButton within Gimme scene")
	else:
		print("ERROR: Could not find Gimme scene")

func hide_gimme_button() -> void:
	"""Hide the gimme button"""
	if gimme_scene:
		gimme_scene.visible = false
		print("Gimme button hidden")

func _on_gimme_button_pressed() -> void:
	"""Handle gimme button press"""
	print("=== GIMME BUTTON PRESSED ===")
	print("Gimme button was successfully clicked!")
	
	# Hide the gimme button
	hide_gimme_button()
	
	# Trigger the gimme sequence
	course.trigger_gimme_sequence()

func _on_suitcase_reached() -> void:
	"""Handle when the player reaches a SuitCase"""
	print("=== SUITCASE REACHED - SHOWING SUITCASE OVERLAY ===")
	
	# Clear the SuitCase position to prevent multiple triggers
	course.suitcase_grid_pos = Vector2i.ZERO
	
	# Exit movement mode
	course.exit_movement_mode()
	
	# Show the SuitCase overlay
	show_suitcase_overlay()

func show_draw_club_cards_button() -> void:
	"""Show the 'Draw Club Cards' button when player is on an active ball tile"""
	course.game_phase = "ball_tile_choice"
	course._update_player_mouse_facing_state()
	print("Player is on ball tile - showing 'Draw Club Cards' button")
	
	# Show the "Draw Club Cards" button
	draw_club_cards_button.visible = true
	
	# Exit movement mode but don't automatically enter launch phase
	movement_controller.exit_movement_mode()
	course.update_deck_display()
	
	# Camera follows player to ball position using managed tween
	var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(course.cell_size, course.cell_size)
	var player_center = player_manager.get_player_node().global_position + player_size / 2
	camera_manager.create_camera_tween(player_center, 1.0)

func show_draw_cards_button_for_turn_start() -> void:
	"""Show the DrawCardsButton at the start of a player turn instead of automatically drawing cards"""
	print("=== SHOWING DRAW CARDS BUTTON FOR TURN START ===")
	
	# Clear block when starting a new player turn (after world turn ends or is skipped)
	course.clear_block()
	
	# Deactivate ghost mode when starting a new player turn
	if course.ghost_mode_active:
		course.deactivate_ghost_mode()
	
	# Deactivate vampire mode when starting a new player turn
	if course.vampire_mode_active:
		course.deactivate_vampire_mode()
	
	# Reset ReachBallButton flag for new turn
	course.used_reach_ball_button = false
	print("ReachBallButton flag reset for new turn")
	
	# Set waiting_for_player_to_reach_ball back to true for new turn if there's a ball to reach
	if course.ball_landing_tile != Vector2i.ZERO:
		course.waiting_for_player_to_reach_ball = true
		print("waiting_for_player_to_reach_ball set to true for new turn")
	
	# Check if this ball is in gimme range
	course.check_and_show_gimme_button()
	
	# Show the DrawCardsButton instead of automatically drawing cards
	draw_cards_button.visible = true
	
	# Set game phase to indicate we're waiting for player to draw cards
	course.game_phase = "waiting_for_draw"
	
	print("DrawCardsButton shown for turn start. Game phase:", course.game_phase)

# ===== REWARD SYSTEM =====

func show_reward_phase() -> void:
	"""Show the suitcase for reward selection"""
	print("Starting reward phase...")
	
	# Clear the player's hand and UI elements before showing rewards
	if deck_manager:
		print("Clearing player hand for reward phase - hand size before:", deck_manager.hand.size())
		deck_manager.hand.clear()
		print("Player hand cleared - hand size after:", deck_manager.hand.size())
		# Update the deck display to reflect the cleared hand
		course.update_deck_display()
	
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

func _on_suitcase_opened() -> void:
	"""Handle suitcase opened"""
	# Create and show the reward selection dialog
	var reward_dialog_scene = preload("res://RewardSelectionDialog.tscn")
	var reward_dialog = reward_dialog_scene.instantiate()
	reward_dialog.name = "RewardSelectionDialog"  # Give it a specific name for cleanup
	ui_layer.add_child(reward_dialog)
	
	# Connect the reward selected signal
	reward_dialog.reward_selected.connect(_on_reward_selected)
	reward_dialog.advance_to_next_hole.connect(_on_advance_to_next_hole)
	
	# Show the reward selection
	reward_dialog.show_reward_selection()

func _on_reward_selected(reward_data: Resource, reward_type: String) -> void:
	"""Handle when a reward is selected"""
	
	if reward_data == null:
		print("ERROR: reward_data is null in _on_reward_selected! reward_type:", reward_type)
		return
	
	if reward_type == "equipment":
		var equip_data = reward_data as EquipmentData
		# TODO: Apply equipment effect
	
	# Update HUD to reflect any changes (including $Looty balance)
	course.update_deck_display()
	
	# Special handling for hole 9 - show front nine completion dialog
	if course.current_hole == 8 and not course.is_back_9_mode:  # Hole 9 (index 8) in front 9 mode
		show_front_nine_complete_dialog()
	else:
		# Show puzzle type selection dialog
		show_puzzle_type_selection()

func _on_advance_to_next_hole() -> void:
	"""Handle when the advance button is pressed"""
	
	# Update HUD to reflect any changes (including $Looty balance)
	course.update_deck_display()
	
	# Special handling for hole 9 - show front nine completion dialog
	if course.current_hole == 8 and not course.is_back_9_mode:  # Hole 9 (index 8) in front 9 mode
		show_front_nine_complete_dialog()
	else:
		# Show puzzle type selection dialog
		show_puzzle_type_selection()

func _on_puzzle_type_selected(puzzle_type: String) -> void:
	"""Handle when a puzzle type is selected"""
	
	print("🎯 PUZZLE SELECTION: Selected puzzle type:", puzzle_type)
	
	# Set the puzzle type for the next hole
	course.next_puzzle_type = puzzle_type
	
	# Clean up the dialog
	var existing_puzzle_dialog = ui_layer.get_node_or_null("PuzzleTypeSelectionDialog")
	if existing_puzzle_dialog:
		existing_puzzle_dialog.queue_free()
	
	# Fade to next hole with the selected puzzle type
	FadeManager.fade_to_black(func(): course.reset_for_next_hole(), 0.5)

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

func _on_map_suitcase_opened() -> void:
	"""Handle when the map SuitCase is opened"""
	print("=== MAP SUITCASE OPENED - SHOWING REWARDS ===")
	
	# Show the reward selection dialog
	show_suitcase_reward_selection()

func show_suitcase_reward_selection() -> void:
	"""Show reward selection dialog for SuitCase"""
	# Create and show the reward selection dialog
	var reward_dialog_scene = preload("res://RewardSelectionDialog.tscn")
	var reward_dialog = reward_dialog_scene.instantiate()
	reward_dialog.name = "SuitCaseRewardDialog"  # Give it a specific name for cleanup
	ui_layer.add_child(reward_dialog)
	
	# Connect the reward selected signal
	reward_dialog.reward_selected.connect(_on_suitcase_reward_selected)
	
	# Show the reward selection without the advance button
	reward_dialog.show_reward_selection()
	
	# Remove the advance button for SuitCase rewards
	var advance_button = reward_dialog.get_node_or_null("RewardContainer/AdvanceButton")
	if advance_button:
		advance_button.queue_free()

func _on_suitcase_reward_selected(reward_data: Resource, reward_type: String) -> void:
	"""Handle when a SuitCase reward is selected"""
	print("=== SUITCASE REWARD SELECTED ===")
	
	# Play reward sound
	var reward_sound = AudioStreamPlayer.new()
	reward_sound.stream = preload("res://Sounds/Reward.mp3")
	reward_sound.volume_db = -8.0  # Lower volume by -8 dB
	course.add_child(reward_sound)
	reward_sound.play()
	
	# Handle the reward directly without calling _on_reward_selected (which includes hole transition)
	if reward_type == "card":
		course.add_card_to_current_deck(reward_data)
	elif reward_type == "equipment":
		course.add_equipment_to_manager(reward_data)
	elif reward_type == "bag_upgrade":
		course.apply_bag_upgrade(reward_data)
	elif reward_type == "looty":
		course.add_looty_reward(reward_data)
	
	# Update HUD to reflect any changes (including $Looty balance)
	course.update_deck_display()
	
	# Clear the reward dialog and SuitCase overlay
	var existing_reward_dialog = ui_layer.get_node_or_null("SuitCaseRewardDialog")
	if existing_reward_dialog:
		existing_reward_dialog.queue_free()
	
	var existing_map_suitcase_overlay = ui_layer.get_node_or_null("MapSuitCaseOverlay")
	if existing_map_suitcase_overlay:
		existing_map_suitcase_overlay.queue_free()
	
	# Resume gameplay (don't transition to next hole)
	print("SuitCase reward selection complete - resuming gameplay")

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
		course.show_course_complete_dialog()
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
	pause_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
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
