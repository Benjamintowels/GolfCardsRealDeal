extends Node
class_name SoundManager

# UI sounds
var card_click_sound: AudioStreamPlayer2D
var card_play_sound: AudioStreamPlayer2D
var birds_tweeting_sound: AudioStreamPlayer2D

# Swing sound effects
var swing_strong_sound: AudioStreamPlayer2D
var swing_med_sound: AudioStreamPlayer2D
var swing_soft_sound: AudioStreamPlayer2D

# Collision sound effects
var water_plunk_sound: AudioStreamPlayer2D
var sand_thunk_sound: AudioStreamPlayer2D
var trunk_thunk_sound: AudioStreamPlayer2D

# Global sounds
var global_death_sound: AudioStreamPlayer

# Player sounds (references to player node sounds)
var player_kick_sound: AudioStreamPlayer2D
var player_punch_b_sound: AudioStreamPlayer2D
var player_assassin_dash_sound: AudioStreamPlayer2D
var player_assassin_cut_sound: AudioStreamPlayer2D
var player_coffee_sound: AudioStreamPlayer2D

# Card stack display sounds
var discard_sound: AudioStreamPlayer2D
var discard_empty_sound: AudioStreamPlayer2D

func setup_ui_sounds(card_click: AudioStreamPlayer2D, card_play: AudioStreamPlayer2D, birds_tweeting: AudioStreamPlayer2D) -> void:
	"""Setup UI-related sounds"""
	card_click_sound = card_click
	card_play_sound = card_play
	birds_tweeting_sound = birds_tweeting

func setup_swing_sounds(swing_strong: AudioStreamPlayer2D, swing_med: AudioStreamPlayer2D, swing_soft: AudioStreamPlayer2D) -> void:
	"""Setup swing sound effects"""
	swing_strong_sound = swing_strong
	swing_med_sound = swing_med
	swing_soft_sound = swing_soft

func setup_collision_sounds(water_plunk: AudioStreamPlayer2D, sand_thunk: AudioStreamPlayer2D, trunk_thunk: AudioStreamPlayer2D) -> void:
	"""Setup collision sound effects"""
	water_plunk_sound = water_plunk
	sand_thunk_sound = sand_thunk
	trunk_thunk_sound = trunk_thunk

func setup_player_sounds(player_node: Node2D) -> void:
	"""Setup player-related sounds"""
	if player_node:
		player_kick_sound = player_node.get_node_or_null("KickSound")
		player_punch_b_sound = player_node.get_node_or_null("PunchB")
		player_assassin_dash_sound = player_node.get_node_or_null("AssassinDash")
		player_assassin_cut_sound = player_node.get_node_or_null("AssassinCut")
		player_coffee_sound = player_node.get_node_or_null("Coffee")

func setup_card_stack_sounds(card_stack_display: Control) -> void:
	"""Setup card stack display sounds"""
	if card_stack_display:
		discard_sound = card_stack_display.get_node_or_null("Discard")
		discard_empty_sound = card_stack_display.get_node_or_null("DiscardEmpty")

func setup_global_death_sound() -> void:
	"""Setup global death sound that can be heard from anywhere"""
	global_death_sound = AudioStreamPlayer.new()
	var death_sound = preload("res://Sounds/DeathGroan.mp3")
	global_death_sound.stream = death_sound
	global_death_sound.volume_db = 0.0
	add_child(global_death_sound)
	print("Global death sound setup complete")

func play_card_click() -> void:
	"""Play card click sound"""
	if card_click_sound:
		card_click_sound.play()

func play_card_play() -> void:
	"""Play card play sound"""
	if card_play_sound:
		card_play_sound.play()

func play_birds_tweeting() -> void:
	"""Play birds tweeting sound"""
	if birds_tweeting_sound:
		birds_tweeting_sound.play()

func play_swing_sound(power: float) -> void:
	"""Play swing sound based on power level"""
	var power_percentage = (power - 300.0) / (1200.0 - 300.0)  # Using hardcoded values since constants are removed
	power_percentage = clamp(power_percentage, 0.0, 1.0)
	
	if power_percentage >= 0.7:  # Strong swing (70%+ power)
		if swing_strong_sound:
			swing_strong_sound.play()
	elif power_percentage >= 0.4:  # Medium swing (40-70% power)
		if swing_med_sound:
			swing_med_sound.play()
	else:  # Soft swing (0-40% power)
		if swing_soft_sound:
			swing_soft_sound.play()

func play_water_plunk() -> void:
	"""Play water plunk sound"""
	if water_plunk_sound and water_plunk_sound.stream:
		water_plunk_sound.play()

func play_sand_thunk() -> void:
	"""Play sand thunk sound"""
	if sand_thunk_sound and sand_thunk_sound.stream:
		sand_thunk_sound.play()

func play_trunk_thunk() -> void:
	"""Play trunk thunk sound"""
	if trunk_thunk_sound and trunk_thunk_sound.stream:
		trunk_thunk_sound.play()

func play_global_death_sound() -> void:
	"""Play global death sound"""
	if global_death_sound:
		global_death_sound.play()

func play_player_kick() -> void:
	"""Play player kick sound"""
	if player_kick_sound and player_kick_sound.stream:
		player_kick_sound.play()

func play_player_punch_b() -> void:
	"""Play player punch B sound"""
	if player_punch_b_sound and player_punch_b_sound.stream:
		player_punch_b_sound.play()

func play_player_assassin_dash() -> void:
	"""Play player assassin dash sound"""
	if player_assassin_dash_sound and player_assassin_dash_sound.stream:
		player_assassin_dash_sound.play()

func play_player_assassin_cut() -> void:
	"""Play player assassin cut sound"""
	if player_assassin_cut_sound and player_assassin_cut_sound.stream:
		player_assassin_cut_sound.play()

func play_player_coffee() -> void:
	"""Play player coffee sound"""
	if player_coffee_sound and player_coffee_sound.stream:
		player_coffee_sound.play()
		print("Playing coffee sound effect")
	else:
		print("Warning: Coffee sound not found on player")

func play_discard_sound() -> void:
	"""Play discard sound"""
	if discard_sound and discard_sound.stream:
		discard_sound.play()

func play_discard_empty_sound() -> void:
	"""Play discard empty sound"""
	if discard_empty_sound and discard_empty_sound.stream:
		discard_empty_sound.play()

func play_gimme_sounds() -> void:
	"""Play the gimme sound effects"""
	print("=== PLAYING GIMME SOUNDS ===")
	
	# Play SwingSoft sound
	if swing_soft_sound:
		swing_soft_sound.play()
		print("Playing SwingSoft sound for gimme")
	else:
		print("ERROR: swing_soft_sound is null!")
	
	# Play HoleIn sound after SwingSoft
	if swing_soft_sound:
		print("Playing HoleIn sound for gimme")
		# Load and play HoleIn sound
		var hole_in_sound = AudioStreamPlayer2D.new()
		var hole_in_stream = load("res://Sounds/HoleIn.mp3")
		if hole_in_stream:
			hole_in_sound.stream = hole_in_stream
			add_child(hole_in_sound)
			hole_in_sound.play()
			print("HoleIn sound played successfully")
			# Remove the sound player after it finishes
			hole_in_sound.finished.connect(func():
				hole_in_sound.queue_free()
			)

func play_flame_on_sound(player_position: Vector2) -> void:
	"""Play the FlameOn sound effect when player takes fire damage"""
	# Try to find an existing FlameOn sound in the scene
	var flame_sounds = get_tree().get_nodes_in_group("flame_sounds")
	if flame_sounds.size() > 0:
		var flame_sound = flame_sounds[0]
		if flame_sound and flame_sound.has_method("play"):
			flame_sound.play()
			return
	
	# Fallback: create a temporary audio player
	var temp_audio = AudioStreamPlayer2D.new()
	var sound_file = load("res://Sounds/FlameOn.mp3")
	if sound_file:
		temp_audio.stream = sound_file
		temp_audio.volume_db = -5.0  # Slightly quieter for player damage
		temp_audio.position = player_position
		add_child(temp_audio)
		temp_audio.play()
		# Remove the audio player after it finishes
		temp_audio.finished.connect(func(): temp_audio.queue_free())

func play_collision_sound(surface: String) -> void:
	"""Play collision sound based on surface type"""
	match surface.to_lower():
		"water":
			play_water_plunk()
		"sand":
			play_sand_thunk()
		"trunk", "tree":
			play_trunk_thunk()
		_:
			# Default to sand thunk for unknown surfaces
			play_sand_thunk() 