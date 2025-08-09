extends Control

signal cutscene_started(cutscene_id: String)
signal cutscene_ended(cutscene_id: String)
signal cutscene_skipped(cutscene_id: String)

# Preload dialog scripts
const IntroDialogScript = preload("res://Dialog/IntroDialogScript.gd")
const GolfsmithClubHouseIntro = preload("res://Dialog/GolfsmithClubHouseIntro.gd")

# Cutscene data structure
var cutscene_data = {
	"intro": {
		"title": "Welcome to GolfCards!",
		"dialog_script": "IntroDialogScript",
		"trigger_flag": "first_time_playing",
		"played_flag": "intro_cutscene_played",
		"setup_actions": [
			{
				"type": "hide_ui",
				"targets": ["character1_button", "character2_button", "character3_button", "start_putt_putt_button", "start_back_9_button", "driving_range_button", "boss_room_button", "fight_room_button", "kendama_button"]
			},
			{
				"type": "play_animation",
				"target": "FlippyTheDolphin",
				"animation": "flippy_intro"
			}
		],
		"cleanup_actions": [
			{
				"type": "show_ui",
				"targets": ["character1_button", "character2_button", "character3_button", "start_putt_putt_button", "start_back_9_button", "driving_range_button", "boss_room_button", "fight_room_button", "kendama_button"]
			},
			{
				"type": "show_flippy",
				"target": "FlippyTheDolphin"
			}
		]
	},
	"golfsmith_intro": {
		"title": "Golfsmith Arrives",
		"dialog_script": "GolfsmithClubHouseIntro",
		"trigger_flag": null,
		"played_flag": "heard_golfsmith_intro",
		"setup_actions": [
			{"type": "hide_ui", "targets": ["character1_button", "character2_button", "character3_button", "start_putt_putt_button", "start_back_9_button", "driving_range_button", "boss_room_button", "fight_room_button", "kendama_button"]}
		],
		"cleanup_actions": [
			{"type": "show_ui", "targets": ["character1_button", "character2_button", "character3_button", "start_putt_putt_button", "start_back_9_button", "driving_range_button", "boss_room_button", "fight_room_button", "kendama_button"]}
		]
	}
}

var current_cutscene: String = ""
var current_dialog_script: DialogScript
var save_file_manager: Node
var main_scene: Node

# UI Elements
var cutscene_panel: Panel
var skip_label: Label

# Dialog elements
var dialog_panel: Panel
var dialog_label: Label
var advance_label: Label

func _ready():
	save_file_manager = get_node("/root/SaveFileManager")
	_setup_ui()
	visible = false

func _setup_ui():
	"""Set up the cutscene UI elements"""
	# Main overlay panel
	cutscene_panel = Panel.new()
	cutscene_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutscene_panel.modulate = Color(0, 0, 0, 0.3)  # Semi-transparent
	cutscene_panel.z_index = 1000  # Set a lower z_index so speech bubbles appear above
	# Ensure the overlay captures mouse input so clicks don't hit UI beneath
	cutscene_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cutscene_panel)
	# Capture clicks on the overlay to advance dialog
	cutscene_panel.gui_input.connect(_on_cutscene_gui_input)
	
	# Dialog panel
	dialog_panel = Panel.new()
	dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialog_panel.offset_bottom = -50
	dialog_panel.offset_left = 100
	dialog_panel.offset_right = -100
	dialog_panel.offset_top = -150
	dialog_panel.modulate = Color(0, 0, 0, 0.8)
	# Also prevent dialog panel clicks from going through
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	cutscene_panel.add_child(dialog_panel)
	dialog_panel.gui_input.connect(_on_cutscene_gui_input)
	
	# Dialog label
	dialog_label = Label.new()
	dialog_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_label.offset_left = 20
	dialog_label.offset_right = -20
	dialog_label.offset_top = 20
	dialog_label.offset_bottom = -20
	dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialog_label.add_theme_font_size_override("font_size", 24)
	dialog_label.modulate = Color.WHITE
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_panel.add_child(dialog_label)
	
	# Advance instruction
	advance_label = Label.new()
	advance_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	advance_label.offset_bottom = -20
	advance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advance_label.text = "Left Click to advance • Spacebar to skip"
	advance_label.modulate = Color.GRAY
	cutscene_panel.add_child(advance_label)

func _on_cutscene_gui_input(event: InputEvent) -> void:
	if not visible or current_cutscene == "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_dialog()

func _input(event):
	"""Handle input for cutscene control"""
	if not visible or current_cutscene == "":
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_dialog()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		skip_current_cutscene()

func play_cutscene(cutscene_id: String, force: bool = false) -> bool:
	"""Play a cutscene"""
	if not cutscene_data.has(cutscene_id):
		print("Cutscene not found: ", cutscene_id)
		return false
	
	var cutscene = cutscene_data[cutscene_id]
	
	# Check if cutscene should be played
	if not force:
		if cutscene.has("trigger_flag"):
			if not save_file_manager.get_story_flag(cutscene["trigger_flag"]):
				return false
		
		if cutscene.has("played_flag"):
			if save_file_manager.get_story_flag(cutscene["played_flag"]):
				return false
	
	# Start the cutscene
	_start_cutscene(cutscene_id, cutscene)
	return true

func _start_cutscene(cutscene_id: String, cutscene: Dictionary):
	"""Start playing a cutscene"""
	current_cutscene = cutscene_id
	main_scene = get_tree().current_scene
	
	# Execute setup actions
	_execute_actions(cutscene.get("setup_actions", []))
	
	# Set up dialog script
	_setup_dialog_script(cutscene.get("dialog_script", ""))
	
	# Show cutscene UI
	visible = true
	dialog_panel.visible = false  # Start hidden
	
	# Start dialog
	advance_dialog()
	
	emit_signal("cutscene_started", cutscene_id)
	print("Playing cutscene: ", cutscene_id)

func _setup_dialog_script(script_name: String):
	"""Set up the dialog script for the cutscene"""
	match script_name:
		"IntroDialogScript":
			current_dialog_script = IntroDialogScript.new()
		"GolfsmithClubHouseIntro":
			current_dialog_script = GolfsmithClubHouseIntro.new()
		_:
			print("Unknown dialog script: ", script_name)
			return
	
	current_dialog_script.dialog_advance.connect(_on_dialog_advance)
	current_dialog_script.dialog_complete.connect(_on_dialog_complete)

func advance_dialog():
	"""Advance the dialog to the next line"""
	if not current_dialog_script:
		return
	
	var line = current_dialog_script.get_current_line()
	if line.is_empty():
		return
	
	# Show dialog panel
	dialog_panel.visible = true
	
	# Set dialog text
	dialog_label.text = line.get("text", "")
	
	# Play audio if specified
	if line.has("audio") and line["audio"]:
		_play_character_audio(line["speaker"], line["audio"])
	
	# Show speech bubble
	_show_speech_bubble(line["speaker"], line["text"])
	
	# Advance to next line
	current_dialog_script.advance_dialog()

func _on_dialog_advance(_line_index: int):
	"""Called when dialog advances"""
	# Don't clear speech bubbles immediately - let them show for a moment
	# They will be cleared when the next speech bubble is shown
	pass

func _on_dialog_complete():
	"""Called when dialog is complete"""
	_end_cutscene()

func _play_character_audio(speaker: String, audio_name: String):
	"""Play character audio"""
	var character_node = _get_character_node(speaker)
	if character_node and character_node.has_node(audio_name):
		var audio_player = character_node.get_node(audio_name)
		if audio_player is AudioStreamPlayer2D:
			audio_player.play()
			
			# Animate Flippy when he talks
			if speaker == "flippy":
				_animate_flippy_talking(character_node)

func _show_speech_bubble(speaker: String, text: String):
	"""Show speech bubble for the speaker"""
	# Don't show speech bubble for empty text
	if text.is_empty():
		return
	
	# Clear previous speech bubbles first
	_clear_speech_bubbles()
	
	var character_node = _get_character_node(speaker)
	if character_node:
		var speech_bubble = character_node.get_node_or_null("SpeechBubble")
		if speech_bubble and speech_bubble.has_method("setup_speech"):
			# Adjust positioning and scale for different characters
			if speaker == "benny":
				# Character2 (Benny) - static sprite in Main scene needs original positioning
				speech_bubble.position = Vector2(454.545, -834.507)
				speech_bubble.scale = Vector2(5.34362, 5.34362)
			elif speaker == "flippy":
				# Flippy - smaller scale to match his size
				speech_bubble.position = Vector2(45, -145)
				speech_bubble.scale = Vector2(0.7, 0.7)
			elif speaker == "golfsmith":
				# Golfsmith - use default position but lower pitch of boop sound
				var boop = speech_bubble.get_node_or_null("SpeechBoop")
				if boop and boop is AudioStreamPlayer2D:
					boop.pitch_scale = 0.75
			
			speech_bubble.setup_speech(text, 999.0, character_node)  # Long duration, manual control

func _clear_speech_bubbles():
	"""Clear all speech bubbles"""
	if main_scene:
		# Clear Benny's speech bubble
		var benny = main_scene.get_node_or_null("ClubHouseBackgroundLayers/Character2")
		if benny:
			var benny_speech = benny.get_node_or_null("SpeechBubble")
			if benny_speech:
				benny_speech.visible = false
		
		# Clear Flippy's speech bubble
		var flippy = main_scene.get_node_or_null("FlippyTheDolphin")
		if flippy:
			var flippy_speech = flippy.get_node_or_null("SpeechBubble")
			if flippy_speech:
				flippy_speech.visible = false

		# Clear Golfsmith's speech bubble
		var golfsmith = main_scene.get_node_or_null("ClubHouseBackgroundLayers/Table/GolfsmithClubHouse")
		if golfsmith:
			var golfsmith_speech = golfsmith.get_node_or_null("SpeechBubble")
			if golfsmith_speech:
				golfsmith_speech.visible = false

func _get_character_node(speaker: String) -> Node:
	"""Get the character node for the speaker"""
	if not main_scene:
		return null
	
	var character_node: Node = null
	match speaker:
		"benny":
			character_node = main_scene.get_node_or_null("ClubHouseBackgroundLayers/Character2")
		"flippy":
			character_node = main_scene.get_node_or_null("FlippyTheDolphin")
		"golfsmith":
			character_node = main_scene.get_node_or_null("ClubHouseBackgroundLayers/Table/GolfsmithClubHouse")
		_:
			return null
	
	return character_node

func _execute_actions(actions: Array):
	"""Execute setup or cleanup actions"""
	for action in actions:
		match action.get("type"):
			"hide_ui":
				_hide_ui_elements(action.get("targets", []))
			"show_ui":
				_show_ui_elements(action.get("targets", []))
			"play_animation":
				_play_animation(action.get("target", ""), action.get("animation", ""))
			"show_flippy":
				_show_flippy()

func _resolve_ui_target(target_name: String) -> Node:
	"""Resolve a logical target name to an actual node in the main scene"""
	if not main_scene:
		return null
	match target_name:
		"character1_button":
			return main_scene.get_node_or_null("UI/Character1Button")
		"character2_button":
			# Benny's button lives in the background layers
			return main_scene.get_node_or_null("ClubHouseBackgroundLayers/Character2")
		"character3_button":
			return main_scene.get_node_or_null("UI/Character3Button")
		"start_putt_putt_button":
			return main_scene.get_node_or_null("UI/StartPuttPutt")
		"start_back_9_button":
			return main_scene.get_node_or_null("UI/StartBack9")
		"driving_range_button":
			return main_scene.get_node_or_null("UI/DrivingRange")
		"boss_room_button":
			return main_scene.get_node_or_null("UI/BossRoom")
		"fight_room_button":
			return main_scene.get_node_or_null("UI/FightRoom")
		"kendama_button":
			return main_scene.get_node_or_null("UI/Kendama")
		_:
			# Fallback to UI namespace
			return main_scene.get_node_or_null("UI/" + target_name)

func _hide_ui_elements(targets: Array):
	"""Hide UI elements"""
	for target_name in targets:
		var target = _resolve_ui_target(target_name)
		if target:
			target.visible = false
			# If it's a button, also disable it to prevent input by script
			if target is BaseButton:
				target.disabled = true

func _show_ui_elements(targets: Array):
	"""Show UI elements"""
	for target_name in targets:
		var target = _resolve_ui_target(target_name)
		if target:
			target.visible = true
			if target is BaseButton:
				target.disabled = false

func _play_animation(target_name: String, animation_name: String):
	"""Play an animation on a target"""
	var target = main_scene.get_node_or_null(target_name)
	if target and target.has_node("AnimationPlayer"):
		var anim_player = target.get_node("AnimationPlayer")
		if anim_player.has_animation(animation_name):
			anim_player.play(animation_name)

func _show_flippy():
	"""Show Flippy in the ClubHouse"""
	var flippy = main_scene.get_node_or_null("FlippyTheDolphin")
	if flippy:
		flippy.visible = true

func _animate_flippy_talking(flippy_node: Node):
	"""Animate Flippy's sprite when he talks"""
	var sprite = flippy_node.get_node_or_null("FlippySprite")
	if sprite and sprite is AnimatedSprite2D:
		# Store original frame
		var _original_frame = sprite.frame
		
		# Play talking animation (frame 1 or 2 randomly)
		var talking_frame = randi() % 2 + 1  # Randomly choose frame 1 or 2 (which are frames 2 and 3 in 0-based indexing)
		sprite.frame = talking_frame
		
		# Return to default frame after a short delay
		await get_tree().create_timer(0.3).timeout
		sprite.frame = 0  # Return to default pose (frame 0)
	elif sprite and sprite is Sprite2D:
		# Fallback for regular Sprite2D (no animation)
		pass

func _end_cutscene():
	"""End the current cutscene"""
	# Execute cleanup actions
	var cutscene = cutscene_data[current_cutscene]
	_execute_actions(cutscene.get("cleanup_actions", []))
	
	# Mark as played
	if cutscene.has("played_flag"):
		save_file_manager.set_story_flag(cutscene["played_flag"], true)
	
	# Hide cutscene UI
	visible = false
	
	# Clear speech bubbles
	_clear_speech_bubbles()
	
	emit_signal("cutscene_ended", current_cutscene)
	print("Cutscene ended: ", current_cutscene)
	current_cutscene = ""

func skip_current_cutscene():
	"""Skip the currently playing cutscene"""
	if current_cutscene == "":
		return
	
	_end_cutscene()
	emit_signal("cutscene_skipped", current_cutscene)
	current_cutscene = ""

# Utility functions
func check_and_play_cutscenes():
	"""Check all cutscenes and play any that should be triggered"""
	for cutscene_id in cutscene_data.keys():
		play_cutscene(cutscene_id)

func is_cutscene_playing() -> bool:
	return visible and current_cutscene != ""

func get_current_cutscene() -> String:
	return current_cutscene
