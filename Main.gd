extends Control

# These buttons might be hidden initially, so we'll get them when needed
var character1_button: Button
var character2_button: TextureButton
var character3_button: Button
# These buttons might be hidden initially, so we'll get them when needed
var start_putt_putt_button: Button
var start_back_9_button: Button
var driving_range_button: Button
var boss_room_button: Button
var fight_room_button: Button
var kendama_button: Button
@onready var select_sound = $Select
@onready var deck_select_sound = $DeckSelect
@onready var animation_player = $ClubHouseBackgroundLayers/AnimationPlayer
@onready var character_stat_banner = $CharacterStatBanner
@onready var club_house_camera = $ClubHouseCamera
@onready var final_score_display = $FinalScoreDisplay
@onready var clubhouse_upgrade_dialog = $ClubHouseUpgradeDialog
@onready var clubhouse_looty_label = $UI/ClubHouseLootyLabel
@onready var upgrade_clubhouse_button = $UI/UpgradeClubHouseButton
@onready var printer_dialog: Control = null
@onready var table_anim_player: AnimationPlayer = $ClubHouseBackgroundLayers/AnimationPlayer
var table_printer_node: Control
var table_sprite_node
@onready var open_printer_button: Button = $UI/Open3DPrinterButton

var selected_character = 1  # Default to character 1
var deck_selection_dialog: Control
var perk_selection_dialog: Control
var pending_game_mode = ""  # Store which game mode was selected while waiting for deck selection
var benny_selected = false  # Track if Benny was selected to play benny_door animation
var is_reversing_animations = false  # Track if we're currently reversing animations
var waiting_for_benny_confirmation = false  # Track if we're waiting for second click on Benny
var waiting_for_perk_selection = false  # Track if we're waiting for perk selection
var selected_course: String = ""  # "front_9" or "back_9" set by map marker buttons
var is_table_focused: bool = false  # True after playing select_table animation

func _ready():
	# Get the buttons that might be hidden initially
	character1_button = get_node_or_null("UI/Character1Button")
	character2_button = get_node_or_null("ClubHouseBackgroundLayers/Character2")
	character3_button = get_node_or_null("UI/Character3Button")
	start_putt_putt_button = get_node_or_null("UI/StartPuttPutt")
	start_back_9_button = get_node_or_null("UI/StartBack9")
	driving_range_button = get_node_or_null("UI/DrivingRange")
	boss_room_button = get_node_or_null("UI/BossRoom")
	fight_room_button = get_node_or_null("UI/FightRoom")
	kendama_button = get_node_or_null("UI/Kendama")
	# 3D Printer node (name starts with a digit; cannot use $ shorthand)
	table_printer_node = get_node_or_null("ClubHouseBackgroundLayers/Table/3dPrinter")
	
	# Set up button group for exclusive selection (only for UI buttons)
	var button_group = ButtonGroup.new()
	
	# Connect button signals with safety checks
	if character1_button and is_instance_valid(character1_button):
		character1_button.button_group = button_group
		character1_button.pressed.connect(_on_character1_selected)
		character1_button.button_pressed = true  # Set character 1 as default selected
		print("✅ Character1 button connected")
	
	if character2_button and is_instance_valid(character2_button):
		character2_button.pressed.connect(_on_character2_selected)
		print("✅ Character2 button connected")
	
	if character3_button and is_instance_valid(character3_button):
		character3_button.button_group = button_group
		character3_button.pressed.connect(_on_character3_selected)
		print("✅ Character3 button connected")
	
	if start_putt_putt_button and is_instance_valid(start_putt_putt_button):
		start_putt_putt_button.pressed.connect(_on_start_putt_putt_button_pressed)
		print("✅ StartPuttPutt button connected")
	
	if start_back_9_button and is_instance_valid(start_back_9_button):
		start_back_9_button.pressed.connect(_on_start_back_9_pressed)
		print("✅ StartBack9 button connected")
	
	if driving_range_button and is_instance_valid(driving_range_button):
		driving_range_button.pressed.connect(_on_driving_range_button_pressed)
		print("✅ DrivingRange button connected")
	
	if boss_room_button and is_instance_valid(boss_room_button):
		boss_room_button.pressed.connect(_on_boss_room_button_pressed)
		print("✅ BossRoom button connected")
	
	if fight_room_button and is_instance_valid(fight_room_button):
		fight_room_button.pressed.connect(_on_fight_room_button_pressed)
		print("✅ FightRoom button connected")
	
	if kendama_button and is_instance_valid(kendama_button):
		kendama_button.pressed.connect(_on_kendama_button_pressed)
		print("✅ Kendama button connected")
	
	# Create and setup deck selection dialog
	_setup_deck_selection_dialog()
	
	# Create and setup perk selection dialog
	_setup_perk_selection_dialog()
	
	# Connect input events for right-click functionality
	set_process_input(true)
	
	# Connect FinalScoreDisplay signal
	if final_score_display:
		final_score_display.return_to_clubhouse.connect(_on_return_to_clubhouse)
	
	# Connect FileLevelManager signals for UI updates (now an autoload)
	var file_level_manager = FileLevelManager
	if file_level_manager:
		file_level_manager.level_up.connect(_on_level_up)
		file_level_manager.experience_gained.connect(_on_experience_gained)
		print("✅ FileLevelManager signals connected successfully")
	else:
		print("❌ ERROR: FileLevelManager autoload not found in Main.gd _ready()")
	
	# Listen for save progression updates (e.g., 3D printer unlocked)
	var save_file_manager_signals = get_node("/root/SaveFileManager")
	if save_file_manager_signals:
		save_file_manager_signals.progression_updated.connect(_on_progression_updated)
	
	# Setup ClubHouse upgrade system (deferred to ensure all nodes are ready)
	call_deferred("_setup_clubhouse_upgrade_system")

	# Setup 3D printer interaction
	_setup_3d_printer_system()
	
	# Check if we have a loaded save file and update UI accordingly
	update_ui_from_save_data()
	
	# Check for intro cutscene on first load
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.get_story_flag("first_time_playing"):
		# Wait a moment for the scene to settle
		await get_tree().create_timer(1.0).timeout
		var cutscene_manager = get_node("/root/CutsceneManager")
		if cutscene_manager:
			cutscene_manager.play_cutscene("intro")
	
	# Check if we should show the final score display (set from course completion)
	if Global.show_final_score_display:
		print("Global flag set - showing final score display")
		show_final_score_display()
		Global.show_final_score_display = false  # Reset the flag
		# After final score is dismissed, check for Golfsmith intro cutscene
		# This is handled in _on_return_to_clubhouse()

	# Ensure Golfsmith clubhouse sprite visibility reflects save at startup
	_update_progression_ui()
	
	print("Buttons connected successfully")
	print("Initial selected_character: ", selected_character)
	print("Deck selection dialog setup complete")

func update_ui_from_save_data():
	"""Update UI based on loaded save data"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if not save_file_manager or save_file_manager.current_save_slot == 0:
		return
	
	var save_data = save_file_manager.current_save_data

	# If the loaded save has a ClubHouse level >= 4, ensure the Upgrade button is unlocked/visible
	var clubhouse_level_from_stats: int = 0
	var file_level_manager_local = FileLevelManager
	if file_level_manager_local:
		var stats = file_level_manager_local.get_current_stats()
		clubhouse_level_from_stats = int(stats.clubhouse_level)
	else:
		var flm_data: Dictionary = save_data.get("file_level_manager", {})
		clubhouse_level_from_stats = int(flm_data.get("clubhouse_level", 1))
	if clubhouse_level_from_stats >= 4:
		# Set story flag so the standard UI update flow reveals the button
		if not save_file_manager.get_story_flag("upgrade_button_unlocked"):
			save_file_manager.set_story_flag("upgrade_button_unlocked", true)
		# Also set visible immediately in case UI update runs later
		if upgrade_clubhouse_button and is_instance_valid(upgrade_clubhouse_button):
			upgrade_clubhouse_button.visible = true
		# If the upgrade UI system is already set up, refresh it
		if has_method("_update_clubhouse_upgrade_ui"):
			_update_clubhouse_upgrade_ui()
	
	# Update character selection
	selected_character = save_data.get("character_id", 1)
	_update_character_selection_ui()
	
	# Update progression-based UI elements
	_update_progression_ui()
	
	# Update game mode preference
	Global.score_only_mode = save_data.get("game_preferences", {}).get("score_only_mode", false)

func _update_character_selection_ui():
	"""Update character selection UI based on save data"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if not save_file_manager:
		return
	
	# Update character button states based on unlocks
	if character1_button and is_instance_valid(character1_button):
		character1_button.visible = save_file_manager.is_character_unlocked(1)
	
	if character2_button and is_instance_valid(character2_button):
		character2_button.visible = save_file_manager.is_character_unlocked(2)
	
	if character3_button and is_instance_valid(character3_button):
		character3_button.visible = save_file_manager.is_character_unlocked(3)
	
	# Set the correct character as selected (only for UI buttons)
	if character1_button and is_instance_valid(character1_button):
		if selected_character == 1:
			character1_button.button_pressed = true
	
	if character3_button and is_instance_valid(character3_button):
		if selected_character == 3:
			character3_button.button_pressed = true
	
	# Reset Benny selection flag based on current character
	benny_selected = (selected_character == 2)

func _update_progression_ui():
	"""Update UI elements based on progression"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if not save_file_manager:
		return
	
	# Show/hide buttons based on progression
	if save_file_manager.get_story_flag("completed_front_9"):
		start_back_9_button.visible = true
	
	if save_file_manager.get_story_flag("defeated_first_boss"):
		boss_room_button.visible = true
	
	# Update deck selection based on unlocked decks
	if deck_selection_dialog:
		deck_selection_dialog.update_available_decks()
	
	# Update ClubHouse level label with current level
	var file_level_manager = FileLevelManager
	if file_level_manager:
		var stats = file_level_manager.get_current_stats()
		var clubhouse_level_label = $UI/ClubHouseLevelLabel
		if clubhouse_level_label:
			clubhouse_level_label.text = "ClubHouse Level " + str(stats.clubhouse_level)
			print("✅ Initial ClubHouse level set to: ", clubhouse_level_label.text)
		else:
			print("❌ ERROR: ClubHouse level label not found in _update_progression_ui()")
	else:
		print("❌ ERROR: FileLevelManager autoload not found in _update_progression_ui()")

	# Toggle GolfsmithClubHouse visibility based on story flag
	var gs_node = get_node_or_null("ClubHouseBackgroundLayers/Table/GolfsmithClubHouse")
	if gs_node:
		var save_file_manager3 = get_node("/root/SaveFileManager")
		var story = save_file_manager3.current_save_data.get("story_progression", {}) if save_file_manager3 else {}
		var npc_quests = story.get("npc_quests", {})
		var gs = npc_quests.get("golfsmith", {})
		gs_node.visible = bool(gs.get("appear", false))

	# Toggle 3D Printer visibility based on unlock flag
	var save_file_manager4 = get_node("/root/SaveFileManager")
	if table_printer_node and save_file_manager4:
		table_printer_node.visible = save_file_manager4.is_3d_printer_unlocked()
	# Hide obsolete UI button always
	if open_printer_button and is_instance_valid(open_printer_button):
		open_printer_button.visible = false

func _on_progression_updated(category: String, key: String, value):
	"""Respond to save progression updates (e.g., unlocking features)"""
	if category == "clubhouse" and key == "3d_printer_unlocked" and bool(value):
		if table_printer_node:
			table_printer_node.visible = true
		if open_printer_button and is_instance_valid(open_printer_button):
			open_printer_button.visible = true

func _setup_deck_selection_dialog():
	"""Setup the deck selection dialog"""
	print("Setting up deck selection dialog...")
	var dialog_scene = preload("res://DeckSelectionDialog.tscn")
	print("Dialog scene preloaded successfully")
	deck_selection_dialog = dialog_scene.instantiate()
	print("Dialog instantiated successfully")
	add_child(deck_selection_dialog)
	print("Dialog added as child")
	
	# Connect dialog signals
	deck_selection_dialog.deck_selected.connect(_on_deck_selected)
	deck_selection_dialog.dialog_closed.connect(_on_deck_dialog_closed)
	print("Dialog signals connected")

func _setup_perk_selection_dialog():
	"""Setup the perk selection dialog"""
	print("Setting up perk selection dialog...")
	var dialog_scene = preload("res://PerkSelectionDialog.tscn")
	print("Perk dialog scene preloaded successfully")
	perk_selection_dialog = dialog_scene.instantiate()
	print("Perk dialog instantiated successfully")
	add_child(perk_selection_dialog)
	print("Perk dialog added as child")
	
	# Connect dialog signals
	perk_selection_dialog.perk_selected.connect(_on_perk_selected)
	perk_selection_dialog.dialog_closed.connect(_on_perk_dialog_closed)
	print("Perk dialog signals connected")
	print("Perk selection dialog setup complete!")

func _setup_clubhouse_upgrade_system():
	"""Setup the ClubHouse upgrade system"""
	# Get the ClubHouse upgrade manager
	var clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	if not clubhouse_upgrade_manager:
		print("ERROR: ClubHouseUpgradeManager not found!")
		return
	
	# Connect signals
	clubhouse_upgrade_manager.flippy_level_changed.connect(_on_flippy_level_changed)
	clubhouse_upgrade_manager.looty_changed.connect(_on_clubhouse_looty_changed)
	
	# Connect upgrade button (with safety check)
	if upgrade_clubhouse_button and is_instance_valid(upgrade_clubhouse_button):
		upgrade_clubhouse_button.pressed.connect(_on_upgrade_clubhouse_pressed)
		print("✅ Upgrade ClubHouse button connected")
	else:
		print("⚠️ Upgrade ClubHouse button not found or invalid")
	
	# Connect upgrade dialog signals (with safety check)
	if clubhouse_upgrade_dialog and is_instance_valid(clubhouse_upgrade_dialog):
		clubhouse_upgrade_dialog.upgrade_completed.connect(_on_upgrade_completed)
		clubhouse_upgrade_dialog.dialog_closed.connect(_on_upgrade_dialog_closed)
		print("✅ ClubHouse upgrade dialog signals connected")
	else:
		print("⚠️ ClubHouse upgrade dialog not found or invalid")
	
	# Update initial display
	_update_clubhouse_upgrade_ui()
	
	print("ClubHouse upgrade system setup complete")

func _setup_3d_printer_system():
	"""Make Table sprite clickable to focus table; clicking 3DPrinter opens dialog"""
	# Table sprite
	table_sprite_node = get_node_or_null("ClubHouseBackgroundLayers/Table")
	if table_sprite_node:
		if table_sprite_node.has_method("set"):
			table_sprite_node.set("input_pickable", true)
		if table_sprite_node.has_signal("input_event"):
			if not table_sprite_node.input_event.is_connected(_on_table_sprite_clicked):
				table_sprite_node.input_event.connect(_on_table_sprite_clicked)
	# 3D Printer control
	if table_printer_node and is_instance_valid(table_printer_node):
		table_printer_node.mouse_filter = Control.MOUSE_FILTER_STOP
		if not table_printer_node.gui_input.is_connected(_on_printer_control_clicked):
			table_printer_node.gui_input.connect(_on_printer_control_clicked)
		var save_file_manager = get_node("/root/SaveFileManager")
		if save_file_manager:
			table_printer_node.visible = save_file_manager.is_3d_printer_unlocked()
	# Always hide obsolete UI button
	if open_printer_button and is_instance_valid(open_printer_button):
		open_printer_button.visible = false

func _on_table_sprite_clicked(_viewport, event: InputEvent, _shape_idx: int):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if table_anim_player:
		table_anim_player.play("select_table")
		await table_anim_player.animation_finished
		is_table_focused = true

func _on_printer_control_clicked(event: InputEvent):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Require focusing the table first
	if not is_table_focused:
		if table_anim_player:
			table_anim_player.play("select_table")
			await table_anim_player.animation_finished
			is_table_focused = true
		return
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and not save_file_manager.is_3d_printer_unlocked():
		return
	_open_printer_dialog()

func _open_printer_dialog():
	if printer_dialog == null:
		var scene: PackedScene = preload("res://UI/PrinterDialog.tscn")
		printer_dialog = scene.instantiate()
		add_child(printer_dialog)
	# Show dialog
	if printer_dialog:
		printer_dialog.visible = true

func _play_select_sound():
	select_sound.play()

func _play_deck_select_sound():
	deck_select_sound.play()

func _on_character1_selected():
	# Prevent character selection during cutscenes
	var cutscene_manager = get_node_or_null("/root/CutsceneManager")
	if cutscene_manager and cutscene_manager.is_cutscene_playing():
		return
	_play_select_sound()
	selected_character = 1
	benny_selected = false  # Reset Benny selection flag
	waiting_for_benny_confirmation = false  # Reset Benny confirmation state
	
	# Hide character stat banner if it's visible
	if character_stat_banner and character_stat_banner.visible:
		_hide_character_stat_banner()
	
	# Update save data with selected character
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		save_file_manager.current_save_data["character_id"] = selected_character
		save_file_manager.save_current_game()
	
	print("Character 1 (Layla) selected, selected_character = ", selected_character)
	print("About to show deck selection dialog...")
	_show_deck_selection_dialog()

func _on_character2_selected():
	# Prevent character selection during cutscenes
	var cutscene_manager = get_node_or_null("/root/CutsceneManager")
	if cutscene_manager and cutscene_manager.is_cutscene_playing():
		return
	_play_select_sound()
	
	# If we're already waiting for confirmation, proceed with selection
	if waiting_for_benny_confirmation:
		waiting_for_benny_confirmation = false
		selected_character = 2
		benny_selected = true  # Mark that Benny was selected
		
		# Update save data with selected character
		var save_file_manager = get_node("/root/SaveFileManager")
		if save_file_manager and save_file_manager.current_save_slot > 0:
			save_file_manager.current_save_data["character_id"] = selected_character
			save_file_manager.save_current_game()
		
		print("Character 2 (Benny) confirmed, selected_character = ", selected_character)
		
		# Hide the stat banner with fade
		_hide_character_stat_banner()
		
		# Play the select_benny animation
		if animation_player:
			animation_player.play("select_benny")
			print("Playing select_benny animation")
		else:
			print("ERROR: Animation player not found!")
		
		print("About to show deck selection dialog...")
		_show_deck_selection_dialog()
	else:
		# First click - show the character stat banner
		waiting_for_benny_confirmation = true
		_show_character_stat_banner()
		print("Showing Benny's character stat banner")

func _on_character3_selected():
	# Prevent character selection during cutscenes
	var cutscene_manager = get_node_or_null("/root/CutsceneManager")
	if cutscene_manager and cutscene_manager.is_cutscene_playing():
		return
	_play_select_sound()
	selected_character = 3
	benny_selected = false  # Reset Benny selection flag
	waiting_for_benny_confirmation = false  # Reset Benny confirmation state
	
	# Hide character stat banner if it's visible
	if character_stat_banner and character_stat_banner.visible:
		_hide_character_stat_banner()
	
	# Update save data with selected character
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		save_file_manager.current_save_data["character_id"] = selected_character
		save_file_manager.save_current_game()
	
	print("Character 3 (Clark) selected, selected_character = ", selected_character)
	print("About to show deck selection dialog...")
	_show_deck_selection_dialog()

func _show_deck_selection_dialog():
	"""Show the deck selection dialog"""
	print("_show_deck_selection_dialog() called")
	if deck_selection_dialog:
		print("Deck selection dialog found, showing...")
		deck_selection_dialog.show_dialog()
	else:
		print("ERROR: Deck selection dialog is null!")

func _hide_deck_selection_dialog():
	"""Hide the deck selection dialog"""
	print("_hide_deck_selection_dialog() called")
	if deck_selection_dialog:
		print("Deck selection dialog found, hiding...")
		deck_selection_dialog.hide_dialog()
	else:
		print("ERROR: Deck selection dialog is null!")

func _show_character_stat_banner():
	"""Show the character stat banner with fade in"""
	if character_stat_banner:
		character_stat_banner.visible = true
		
		# Update the level display with current character level
		var file_level_manager = FileLevelManager
		if file_level_manager:
			var stats = file_level_manager.get_current_stats()
			var level_label = character_stat_banner.get_node_or_null("Level")
			if level_label:
				level_label.text = "Level " + str(stats.character_level)
		
		# Add fade in effect
		character_stat_banner.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(character_stat_banner, "modulate:a", 1.0, 0.3)
		print("Character stat banner shown with current level")

func _hide_character_stat_banner():
	"""Hide the character stat banner with fade out"""
	if character_stat_banner:
		var tween = create_tween()
		tween.tween_property(character_stat_banner, "modulate:a", 0.0, 0.3)
		await tween.finished
		character_stat_banner.visible = false
		print("Character stat banner hidden")

func _on_deck_selected(deck_type: String):
	"""Handle deck selection from dialog"""
	print("Deck selected:", deck_type)
	# Play deck selection sound
	_play_deck_select_sound()
	# Store the selected deck type in Global for reference
	Global.selected_deck_type = deck_type
	
	# Play benny_door animation if Benny was selected
	if benny_selected and animation_player:
		animation_player.play("benny_door")
		print("Playing benny_door animation")
		
		# Wait for benny_door animation to complete, then play map animations
		await animation_player.animation_finished
		
		# Play map_intro animation from CourseSelectionMap
		var course_selection_map = $ClubHouseBackgroundLayers/CourseSelectionMap
		if course_selection_map:
			# Check if back 9 flag upgrade is purchased BEFORE deciding the flow
			var save_file_manager = get_node("/root/SaveFileManager")
			var _flag_purchased = false
			if save_file_manager:
				_flag_purchased = save_file_manager.get_story_flag("back_9_flag_upgrade_purchased")
			
			var course_map_animation_player = course_selection_map.get_node("AnimationPlayer")
			var map_animation_player = course_selection_map.get_node("CourseSelectionAnimationPlayer")
			
			# Always play map reveal, then intro. Back9 marker visibility is handled by upgrade state
			if map_animation_player:
				map_animation_player.play("map_intro")
				print("Playing map_intro animation")
				await map_animation_player.animation_finished
				if course_map_animation_player:
					course_map_animation_player.play("intro")
					print("Playing intro animation")
				else:
					print("ERROR: CourseSelectionMap AnimationPlayer not found!")
			else:
				print("ERROR: CourseSelectionMap CourseSelectionAnimationPlayer not found!")
		else:
			print("ERROR: CourseSelectionMap not found!")
	
	# If there was a pending game mode, show perk selection instead of starting immediately
	if pending_game_mode != "":
		_show_perk_selection_dialog()

func _on_deck_dialog_closed():
	"""Handle deck dialog being closed without selection"""
	print("Deck selection dialog closed without selection")
	pending_game_mode = ""  # Clear any pending game mode

func _show_perk_selection_dialog():
	"""Show the perk selection dialog"""
	print("_show_perk_selection_dialog() called")
	
	# Check if Flippy is level 2 or higher (has perks to offer)
	var clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	if clubhouse_upgrade_manager:
		var flippy_level = clubhouse_upgrade_manager.get_flippy_level()
		var available_perks = clubhouse_upgrade_manager.get_flippy_perks_for_level()
		
		if flippy_level < 2 or available_perks.size() == 0:
			print("Flippy is level", flippy_level, "with", available_perks.size(), "perks - skipping perk dialog")
			# Skip perk dialog and go directly to game
			_start_pending_game_mode()
			return
	
	if perk_selection_dialog:
		print("Perk selection dialog found, showing...")
		perk_selection_dialog.show_dialog()
	else:
		print("ERROR: Perk selection dialog is null!")

func _hide_perk_selection_dialog():
	"""Hide the perk selection dialog"""
	print("_hide_perk_selection_dialog() called")
	if perk_selection_dialog:
		print("Perk selection dialog found, hiding...")
		perk_selection_dialog.hide_dialog()
	else:
		print("ERROR: Perk selection dialog is null!")

func _on_perk_selected(perk_type: String):
	"""Handle perk selection from dialog"""
	print("Perk selected:", perk_type)
	
	# Store the perk in PerkReceiver for later deployment
	print("Attempting to store perk in PerkReceiver...")
	PerkReceiver.store_perk(perk_type)
	print("Perk stored in PerkReceiver for later deployment")
	print("PerkReceiver has pending perk:", PerkReceiver.has_pending_perk())
	
	# Animate Flippy talking
	_animate_flippy_talking()
	
	# After animation, start the pending game mode
	await get_tree().create_timer(2.0).timeout  # Wait for talking animation
	_start_pending_game_mode()

func _on_perk_dialog_closed():
	"""Handle perk dialog being closed without selection"""
	print("Perk selection dialog closed without selection")
	# Still start the game mode even if no perk was selected
	_start_pending_game_mode()

func _on_map_marker_front_9_selected():
	"""Handle MapMarkerFront9 selection"""
	print("MapMarkerFront9 selected - toggled Front 9")
	_play_select_sound()
	# Toggle selection only; starting happens when clicking the door
	selected_course = "front_9"
	Global.starting_back_9 = false

func _on_map_marker_back_9_selected():
	"""Handle MapMarkerBack9 selection"""
	print("MapMarkerBack9 selected - toggled Back 9")
	_play_select_sound()
	# Toggle selection only; starting happens when clicking the door
	selected_course = "back_9"
	Global.starting_back_9 = true



func _animate_flippy_talking():
	"""Animate Flippy talking after perk selection"""
	var flippy = $FlippyTheDolphin
	if flippy:
		# Get the FlippySprite (AnimatedSprite2D)
		var sprite = flippy.get_node_or_null("FlippySprite")
		if sprite and sprite is AnimatedSprite2D:
			# Store original frame
			var _original_frame = sprite.frame
			
			# Play talking animation (frame 1 or 2 randomly)
			var talking_frame = randi() % 2 + 1  # Randomly choose frame 1 or 2 (which are frames 2 and 3 in 0-based indexing)
			sprite.frame = talking_frame
			
			# Play random talking sound
			var talk_sounds = ["talk1", "talk2", "talk3"]
			var random_sound = talk_sounds[randi() % talk_sounds.size()]
			var audio_player = flippy.get_node_or_null(random_sound)
			if audio_player and audio_player is AudioStreamPlayer2D:
				audio_player.play()
			
			# Return to default frame after a short delay
			await get_tree().create_timer(0.3).timeout
			sprite.frame = 0  # Return to default pose (frame 0)
		else:
			print("No FlippySprite found or not AnimatedSprite2D")
	else:
		print("No FlippyTheDolphin found")

func _on_start_round_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	Global.putt_putt_mode = false  # Ensure normal mode for regular rounds
	
	# If a course was selected via map markers, use that selection
	if selected_course != "":
		if Global.selected_deck_type == "":
			# Defer start until deck selection (and possibly perks) completes
			pending_game_mode = "back_9" if selected_course == "back_9" else "normal_round"
			_show_deck_selection_dialog()
		else:
			# Show perks if available, then start
			pending_game_mode = "back_9" if selected_course == "back_9" else "normal_round"
			_show_perk_selection_dialog()
		return
	
	# Fallback: no course selected, behave like normal round start
	print("No map course selected, defaulting to Front 9")
	if Global.selected_deck_type == "":
		pending_game_mode = "normal_round"
		_show_deck_selection_dialog()
	else:
		pending_game_mode = "normal_round"
		_show_perk_selection_dialog()

func _on_start_putt_putt_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	Global.putt_putt_mode = true  # Enable putt putt mode
	print("Selected character: ", selected_character, " - Starting Putt Putt mode")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "putt_putt"
		_show_deck_selection_dialog()
	else:
		# Change scene on next frame
		call_deferred("_change_scene")

func _on_start_back_9_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Back 9")
	print("Global.selected_character set to: ", Global.selected_character)
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "back_9"
		_show_deck_selection_dialog()
	else:
		# Set back 9 mode flag and start normal course
		Global.starting_back_9 = true
		call_deferred("_change_scene")

func _on_driving_range_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Driving Range")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "driving_range"
		_show_deck_selection_dialog()
	else:
		# Change to the driving range scene
		call_deferred("_change_to_driving_range")

func _on_boss_room_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Boss Room")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "boss_room"
		_show_deck_selection_dialog()
	else:
		# Set boss room mode flag
		Global.boss_room_mode = true
		# Change to Course1 scene with boss room mode
		call_deferred("_change_to_boss_room")

func _on_fight_room_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Fight Room")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "fight_room"
		_show_deck_selection_dialog()
	else:
		# Set fight room mode flag
		Global.fight_room_mode = true
		# Change to Course1 scene with fight room mode
		call_deferred("_change_to_fight_room")

func _on_kendama_button_pressed():
	_play_select_sound()
	# Store the selected character in a global variable
	Global.selected_character = selected_character
	print("Selected character: ", selected_character, " - Starting Kendama Game")
	
	# Check if deck has been selected, if not, show dialog and store pending mode
	if Global.selected_deck_type == "":
		pending_game_mode = "kendama"
		_show_deck_selection_dialog()
	else:
		# Change to the Kendama game scene
		call_deferred("_change_to_kendama_game")

func _start_pending_game_mode():
	"""Start the pending game mode after deck selection"""
	match pending_game_mode:
		"normal_round":
			_change_scene()
		"putt_putt":
			_change_scene()
		"back_9":
			Global.starting_back_9 = true
			_change_scene()
		"driving_range":
			_change_to_driving_range()
		"boss_room":
			Global.boss_room_mode = true
			_change_to_boss_room()
		"fight_room":
			Global.fight_room_mode = true
			_change_to_fight_room()
		"kendama":
			_change_to_kendama_game()
	
	pending_game_mode = ""  # Clear the pending mode

func _change_scene():
	# Deactivate the club house camera
	if club_house_camera:
		club_house_camera.deactivate()
	
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func _change_to_driving_range():
	# Deactivate the club house camera
	if club_house_camera:
		club_house_camera.deactivate()
	
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Stages/DrivingRange.tscn"), 0.5)
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func _change_to_boss_room():
	# Deactivate the club house camera
	if club_house_camera:
		club_house_camera.deactivate()
	
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func _change_to_fight_room():
	# Deactivate the club house camera
	if club_house_camera:
		club_house_camera.deactivate()
	
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func _input(event):
	"""Handle input events for right-click functionality"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click()

func _handle_right_click():
	"""Handle right-click to reverse animations and show Character2"""
	print("Right-click detected - reversing animations")
	
	# If the table focus is active, reverse the select_table animation first
	if is_table_focused and table_anim_player:
		# Prevent concurrent reversals
		if is_reversing_animations:
			return
		is_reversing_animations = true
		table_anim_player.play_backwards("select_table")
		await table_anim_player.animation_finished
		is_table_focused = false
		is_reversing_animations = false
		return

	# Don't handle right-click if we're already reversing
	if is_reversing_animations:
		print("Already reversing animations, ignoring right-click")
		return
	
	# If character stat banner is visible, hide it and reset confirmation state
	if character_stat_banner and character_stat_banner.visible:
		print("Character stat banner is visible, hiding it and resetting confirmation state")
		_hide_character_stat_banner()
		waiting_for_benny_confirmation = false
		return
	
	# Show the Character2Button again
	character2_button.visible = true
	
	# If deck selection dialog is visible, hide it and reverse select_benny
	if deck_selection_dialog and deck_selection_dialog.visible:
		print("Deck selection dialog is visible, hiding it and reversing select_benny")
		_reverse_select_benny_animation()
		return
	
	# If we're in the course selection phase (after deck selection), reverse those animations
	if benny_selected and Global.selected_deck_type != "":
		_reverse_course_selection_animations()
	else:
		# Just reverse the select_benny animation
		_reverse_select_benny_animation()

func _reverse_select_benny_animation():
	"""Reverse the select_benny animation"""
	is_reversing_animations = true
	
	# Hide deck selection dialog if it's visible (only if called from right-click, not from cancel button)
	if deck_selection_dialog and deck_selection_dialog.visible:
		_hide_deck_selection_dialog()
	
	_reverse_select_benny_animation_internal()

func _reverse_select_benny_animation_internal():
	"""Internal function to reverse the select_benny animation without hiding dialog"""
	if animation_player:
		animation_player.play_backwards("select_benny")
		print("Playing select_benny animation backwards")
		
		# Wait for animation to complete
		await animation_player.animation_finished
		
		# Reset Benny selection
		benny_selected = false
		selected_character = 1  # Reset to default character
		character1_button.button_pressed = true
		print("Benny selection reversed")
	
	is_reversing_animations = false

func _reverse_course_selection_animations():
	"""Reverse the course selection animations"""
	is_reversing_animations = true
	
	var course_selection_map = $ClubHouseBackgroundLayers/CourseSelectionMap
	if course_selection_map:
		# Check which animation was played to reverse it properly
		var save_file_manager = get_node("/root/SaveFileManager")
		var _flag_purchased = false
		if save_file_manager:
			_flag_purchased = save_file_manager.get_story_flag("back_9_flag_upgrade_purchased")
		
		# First reverse the course map intro animation (always used now)
		var course_map_animation_player = course_selection_map.get_node("AnimationPlayer")
		if course_map_animation_player:
			course_map_animation_player.play_backwards("intro")
			print("Playing intro animation backwards")
			await course_map_animation_player.animation_finished
		
		# Then reverse the map reveal
		var map_animation_player = course_selection_map.get_node("CourseSelectionAnimationPlayer")
		if map_animation_player:
			map_animation_player.play_backwards("map_intro")
			print("Playing map_intro animation backwards")
			await map_animation_player.animation_finished
		
		# Finally reverse the benny_door animation
		if animation_player:
			animation_player.play_backwards("benny_door")
			print("Playing benny_door animation backwards")
			await animation_player.animation_finished
			
			# Reset Benny selection and show deck selection dialog
			benny_selected = false
			selected_character = 1  # Reset to default character
			character1_button.button_pressed = true
			Global.selected_deck_type = ""  # Clear deck selection
			print("Course selection reversed, showing deck selection dialog")
			_show_deck_selection_dialog()
	else:
		print("ERROR: CourseSelectionMap not found for reverse animation")
	
	is_reversing_animations = false

func _change_to_kendama_game():
	# Deactivate the club house camera
	if club_house_camera:
		club_house_camera.deactivate()
	
	# Start fade to black first
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Stages/KendamaGame/KendamaGame.tscn"), 0.5)
	
	# Play door sounds during the fade
	$DoorOpen.play()
	await $DoorOpen.finished
	$DoorClose.play()

func show_final_score_display():
	"""Show the final score display with current progression"""
	if final_score_display:
		final_score_display.show()
		final_score_display.show_final_score()
		print("Final score display shown")

func complete_hole(hole_number: int):
	"""Complete a hole and add experience points"""
	var file_level_manager = FileLevelManager
	if file_level_manager:
		file_level_manager.complete_hole(hole_number)
		print("Hole ", hole_number, " completed - experience added")
	else:
		print("ERROR: FileLevelManager autoload not found!")

func _on_return_to_clubhouse():
	"""Handle return to clubhouse from final score display"""
	print("Returning to clubhouse from final score display")
	# Hide the final score display
	if final_score_display:
		final_score_display.hide()
	
	# Transfer course Looty to ClubHouse
	var clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	if clubhouse_upgrade_manager:
		clubhouse_upgrade_manager.transfer_course_looty_to_clubhouse()
		print("💰 Course Looty transferred to ClubHouse")
	
	# Save progression data when returning to clubhouse
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		# Unlock the upgrade button after the first return from a round (freebie entry point)
		if not save_file_manager.get_story_flag("upgrade_button_unlocked"):
			save_file_manager.set_story_flag("upgrade_button_unlocked", true)
		# Save after updating story flags
		save_file_manager.save_current_game()
		print("💾 Progression saved when returning to clubhouse")
	
	# Update ClubHouse upgrade UI
	_update_clubhouse_upgrade_ui()

	# If Golfsmith quest is completed and intro not played yet, show Golfsmith shop arrival cutscene
	var save_file_manager2 = get_node("/root/SaveFileManager")
	var cutscene_manager = get_node("/root/CutsceneManager")
	if save_file_manager2 and cutscene_manager:
		var story = save_file_manager2.current_save_data.get("story_progression", {})
		var npc_quests = story.get("npc_quests", {})
		var gs = npc_quests.get("golfsmith", {})
		var quest_completed: bool = bool(gs.get("quest_completed", false))
		var heard_intro: bool = story.get("story_events", {}).get("heard_golfsmith_intro", false)
		if quest_completed and not heard_intro:
			# Ensure clubhouse sprite visible
			var gs_node = get_node_or_null("ClubHouseBackgroundLayers/Table/GolfsmithClubHouse")
			if gs_node:
				gs_node.visible = true
			# Play Golfsmith clubhouse intro cutscene
			cutscene_manager.play_cutscene("golfsmith_intro", true)

func _on_level_up(character_level: int, clubhouse_level: int):
	"""Handle level up events from FileLevelManager"""
	print("🎉 LEVEL UP EVENT TRIGGERED! Character: ", character_level, " ClubHouse: ", clubhouse_level)
	
	# Update ClubHouse level label
	var clubhouse_level_label = $UI/ClubHouseLevelLabel
	if clubhouse_level_label:
		clubhouse_level_label.text = "ClubHouse Level " + str(clubhouse_level)
		print("✅ Updated ClubHouse level label to: ", clubhouse_level_label.text)
	else:
		print("❌ ERROR: ClubHouse level label not found!")
	
	# Update CharacterStatBanner level if it's visible and showing Benny
	if character_stat_banner and character_stat_banner.visible:
		var level_label = character_stat_banner.get_node_or_null("Level")
		if level_label:
			level_label.text = "Level " + str(character_level)
			print("✅ Updated CharacterStatBanner level to: ", level_label.text)
		else:
			print("❌ ERROR: CharacterStatBanner Level label not found!")
	else:
		print("ℹ️ CharacterStatBanner not visible or not found")

func _on_experience_gained(character_exp: int, clubhouse_exp: int):
	"""Handle experience gained events from FileLevelManager"""
	print("💫 EXPERIENCE GAINED! Character: ", character_exp, " ClubHouse: ", clubhouse_exp)
	# This could be used for visual effects or sound feedback

# ClubHouse Upgrade System Functions
func _update_clubhouse_upgrade_ui():
	"""Update ClubHouse upgrade UI elements"""
	print("🔄 Updating ClubHouse upgrade UI...")
	var clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	if not clubhouse_upgrade_manager:
		print("❌ ClubHouseUpgradeManager not found!")
		return
	
	# Update Looty display
	var clubhouse_looty = clubhouse_upgrade_manager.get_clubhouse_looty()
	print("💰 ClubHouse Looty amount:", clubhouse_looty)
	if clubhouse_looty_label:
		clubhouse_looty_label.text = "ClubHouse $Looty: " + str(clubhouse_looty)
		print("✅ Updated ClubHouse Looty label to:", clubhouse_looty_label.text)
	else:
		print("❌ ClubHouse Looty label not found!")
	
	# Update upgrade button visibility based on story flag: show after first return from a round
	var save_file_manager2 = get_node("/root/SaveFileManager")
	if upgrade_clubhouse_button and is_instance_valid(upgrade_clubhouse_button):
		var unlocked := false
		if save_file_manager2:
			unlocked = save_file_manager2.get_story_flag("upgrade_button_unlocked")
		upgrade_clubhouse_button.visible = unlocked
		print("🔘 Upgrade button visibility set to:", upgrade_clubhouse_button.visible, "(Unlocked:", unlocked, ")")
		# Ensure button is connected if it wasn't before
		if not upgrade_clubhouse_button.pressed.is_connected(_on_upgrade_clubhouse_pressed):
			upgrade_clubhouse_button.pressed.connect(_on_upgrade_clubhouse_pressed)
			print("✅ Upgrade ClubHouse button connected in UI update")
	else:
		print("⚠️ Could not update upgrade button (manager or button not found)")

func _on_flippy_level_changed(new_level: int):
	"""Handle Flippy level change"""
	print("Flippy level changed to:", new_level)
	_update_clubhouse_upgrade_ui()

func _on_clubhouse_looty_changed(new_amount: int):
	"""Handle ClubHouse Looty amount change"""
	print("ClubHouse Looty changed to:", new_amount)
	_update_clubhouse_upgrade_ui()

func _on_upgrade_clubhouse_pressed():
	"""Handle upgrade ClubHouse button press"""
	print("Upgrade ClubHouse button pressed")
	if clubhouse_upgrade_dialog:
		clubhouse_upgrade_dialog.show_dialog()

func _on_upgrade_completed():
	"""Handle upgrade completion"""
	print("Upgrade completed")
	_update_clubhouse_upgrade_ui()
	# Animate Flippy talking on successful Flippy upgrade (no speech bubble)
	_animate_flippy_talking()

func _on_upgrade_dialog_closed():
	"""Handle upgrade dialog close"""
	print("Upgrade dialog closed")
