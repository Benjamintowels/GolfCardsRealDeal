extends Node
class_name WeaponHandler

# Weapon system variables
var is_weapon_mode := false
var selected_card: CardData = null
var active_button: TextureButton = null
var weapon_instance: Node2D = null

# Grenade launcher freeze system
var grenade_launcher_frozen := false
var frozen_rotation := 0.0
var frozen_flip_h := false
var frozen_flip_v := false

# References
var player_node: Node2D
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary
var camera: Camera2D
var launch_manager: LaunchManager = null  # Reference to LaunchManager for knife throwing

# Sound effects
var card_click_sound: AudioStreamPlayer2D
var card_play_sound: AudioStreamPlayer2D

# UI references
var card_stack_display: Control
var deck_manager: DeckManager

# Card effect handling
var card_effect_handler: Node

# Weapon properties
var weapon_damage := 200
var weapon_range := 1000.0  # Maximum shooting distance

# Weapon scene references
var pistol_scene = preload("res://Weapons/Pistol.tscn")
var throwing_knife_scene = preload("res://Weapons/ThrowingKnife.tscn")
var burst_shot_scene = preload("res://Weapons/BurstShot.tscn")
var shotgun_scene = preload("res://Weapons/Shotgun.tscn")
var sniper_scene = preload("res://Weapons/Sniper.tscn")
var grenade_scene = preload("res://Weapons/Grenade.tscn")
var spear_scene = preload("res://Weapons/Spear.tscn")
var grenade_launcher_scene = preload("res://Weapons/GrenadeLauncher.tscn")
var reticle_texture = preload("res://UI/Reticle.png")

# Signals
signal weapon_mode_entered
signal weapon_mode_exited
signal card_selected(card: CardData)
signal card_discarded(card: CardData)
signal npc_shot(npc: Node, damage: int)

func _init():
	pass

func setup(
	player_node_ref: Node2D,
	grid_tiles_ref: Array,
	grid_size_ref: Vector2i,
	cell_size_ref: int,
	obstacle_map_ref: Dictionary,
	player_grid_pos_ref: Vector2i,
	player_stats_ref: Dictionary,
	camera_ref: Camera2D,
	card_click_sound_ref: AudioStreamPlayer2D,
	card_play_sound_ref: AudioStreamPlayer2D,
	card_stack_display_ref: Control,
	deck_manager_ref: DeckManager,
	card_effect_handler_ref: Node,
	launch_manager_ref: LaunchManager = null
):
	player_node = player_node_ref
	grid_tiles = grid_tiles_ref
	grid_size = grid_size_ref
	cell_size = cell_size_ref
	obstacle_map = obstacle_map_ref
	player_grid_pos = player_grid_pos_ref
	player_stats = player_stats_ref
	camera = camera_ref
	card_click_sound = card_click_sound_ref
	card_play_sound = card_play_sound_ref
	card_stack_display = card_stack_display_ref
	deck_manager = deck_manager_ref
	card_effect_handler = card_effect_handler_ref
	launch_manager = launch_manager_ref

# Reference to movement controller for button cleanup
var movement_controller: Node = null

func set_movement_controller(controller: Node) -> void:
	movement_controller = controller

func _on_weapon_card_pressed(card: CardData, button: TextureButton) -> void:
	
	if selected_card == card:
		return
	card_click_sound.play()
	
	is_weapon_mode = true
	active_button = button
	selected_card = card
	
	# Discard the card immediately
	if deck_manager.hand.has(selected_card):
		deck_manager.discard(selected_card)
		card_stack_display.animate_card_discard(selected_card.name)
		emit_signal("card_discarded", selected_card)
	
	# Clean up the button
	cleanup_weapon_card_button()
	
	# Enter weapon aiming mode
	enter_weapon_aiming_mode()
	
	emit_signal("weapon_mode_entered")
	emit_signal("card_selected", card)

func enter_weapon_aiming_mode() -> void:
	"""Enter weapon aiming mode with mouse tracking"""
	
	# Reset grenade launcher freeze state
	grenade_launcher_frozen = false
	
	# Change mouse cursor based on weapon type
	if selected_card and selected_card.name == "Throwing Knife":
		# Hide mouse cursor for knife aiming (only use aiming circle)
		Input.set_custom_mouse_cursor(null)
	elif selected_card and selected_card.name == "GrenadeCard":
		# Hide mouse cursor for grenade aiming (only use aiming circle)
		Input.set_custom_mouse_cursor(null)
	elif selected_card and selected_card.name == "GrenadeLauncherWeaponCard":
		# Hide mouse cursor for grenade launcher aiming (only use aiming circle)
		Input.set_custom_mouse_cursor(null)
	elif selected_card and selected_card.name == "ShotgunCard":
		# Use regular reticle for shotgun aiming
		var reticle_texture = preload("res://UI/Reticle.png")
		Input.set_custom_mouse_cursor(reticle_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	elif selected_card and selected_card.name == "SniperCard":
		# Use regular reticle for sniper aiming
		var reticle_texture = preload("res://UI/Reticle.png")
		Input.set_custom_mouse_cursor(reticle_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		# Use regular reticle for pistol aiming
		var reticle_texture = preload("res://UI/Reticle.png")
		Input.set_custom_mouse_cursor(reticle_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	
	# Create weapon instance
	create_weapon_instance()
	
	# For knife mode, set up camera following like normal shot placement
	if selected_card and selected_card.name == "Throwing Knife" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		# Set up camera to follow mouse during knife aiming
		course.is_aiming_phase = true
		
		# Set a temporary club for knife aiming (use ThrowingKnife for character-specific range)
		var original_club = course.selected_club
		course.selected_club = "ThrowingKnife"
		
		# Show aiming circle with knife reticle image
		show_knife_aiming_circle()
		
		# Show knife-specific aiming instruction
		show_knife_aiming_instruction()
		
		# Store original club to restore later
		set_meta("original_club", original_club)
		
		# Position camera on player initially
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(course.camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# For grenade mode, set up camera following like normal shot placement
	elif selected_card and selected_card.name == "GrenadeCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		# Set up camera to follow mouse during grenade aiming
		course.is_aiming_phase = true
		
		# Set a temporary club for grenade aiming (use GrenadeCard for character-specific range)
		var original_club = course.selected_club
		course.selected_club = "GrenadeCard"
		
		# Show aiming circle with grenade reticle image
		show_grenade_aiming_circle()
		
		# Show grenade-specific aiming instruction
		show_grenade_aiming_instruction()
		
		# Store original club to restore later
		set_meta("original_club", original_club)
		
		# Position camera on player initially
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(course.camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	elif selected_card and selected_card.name == "GrenadeLauncherWeaponCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		# Set up camera to follow mouse during grenade launcher aiming
		course.is_aiming_phase = true
		
		# Set a temporary club for grenade launcher aiming (use GrenadeLauncherClubCard for character-specific range)
		var original_club = course.selected_club
		course.selected_club = "GrenadeLauncherClubCard"
		
		# Show aiming circle with grenade reticle image
		show_grenade_aiming_circle()
		
		# Show grenade-specific aiming instruction
		show_grenade_aiming_instruction()
		
		# Store original club to restore later
		set_meta("original_club", original_club)
		
		# Position camera on player initially
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(course.camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# For shotgun mode, set up camera following like normal shot placement
	elif selected_card and selected_card.name == "ShotgunCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		# Set up camera to follow mouse during shotgun aiming
		course.is_aiming_phase = true
		
		# Set a temporary club for shotgun aiming (use ShotgunCard for character-specific range)
		var original_club = course.selected_club
		course.selected_club = "ShotgunCard"
		
		# Show aiming circle with shotgun reticle image
		show_shotgun_aiming_circle()
		
		# Show shotgun-specific aiming instruction
		show_shotgun_aiming_instruction()
		
		# Store original club to restore later
		set_meta("original_club", original_club)
		
		# Position camera on player initially
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(course.camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# For sniper mode, set up camera following like normal shot placement
	elif selected_card and selected_card.name == "SniperCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		# Set up camera to follow mouse during sniper aiming
		course.is_aiming_phase = true
		
		# Set a temporary club for sniper aiming (use SniperCard for character-specific range)
		var original_club = course.selected_club
		course.selected_club = "SniperCard"
		
		# Show aiming circle with sniper reticle image
		show_sniper_aiming_circle()
		
		# Show sniper-specific aiming instruction
		show_sniper_aiming_instruction()
		
		# Store original club to restore later
		set_meta("original_club", original_club)
		
		# Position camera on player initially
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(course.camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Input is handled by the course's _input function

func show_knife_aiming_circle() -> void:
	"""Show aiming circle with knife reticle image"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	
	# Use the course's show_aiming_circle function but override the texture
	course.show_aiming_circle()
	
	# Replace the target circle texture with knife reticle texture
	if course.aiming_circle:
		var circle = course.aiming_circle.get_node_or_null("CircleVisual")
		if circle:
			var knife_reticle_texture = preload("res://UI/knifeReticle.png")
			circle.texture = knife_reticle_texture

func show_knife_aiming_instruction() -> void:
	"""Show knife-specific aiming instruction"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	var existing_instruction = course.get_node_or_null("UILayer/AimingInstructionLabel")
	if existing_instruction:
		existing_instruction.queue_free()
	
	var instruction_label := Label.new()
	instruction_label.name = "AimingInstructionLabel"
	instruction_label.text = "Move mouse to set knife target\nLeft click to throw, Right click to cancel"
	
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.YELLOW)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	instruction_label.position = Vector2(400, 50)
	instruction_label.z_index = 200
	
	course.get_node("UILayer").add_child(instruction_label)

func show_shotgun_aiming_circle() -> void:
	"""Show aiming circle with shotgun reticle image"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	
	# Use the course's show_aiming_circle function but override the texture
	course.show_aiming_circle()
	
	# Replace the target circle texture with shotgun reticle texture
	if course.aiming_circle:
		var circle = course.aiming_circle.get_node_or_null("CircleVisual")
		if circle:
			var shotgun_reticle_texture = preload("res://UI/Reticle.png")  # Use regular reticle for now
			circle.texture = shotgun_reticle_texture

func show_shotgun_aiming_instruction() -> void:
	"""Show shotgun-specific aiming instruction"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	var existing_instruction = course.get_node_or_null("UILayer/AimingInstructionLabel")
	if existing_instruction:
		existing_instruction.queue_free()
	
	var instruction_label := Label.new()
	instruction_label.name = "AimingInstructionLabel"
	instruction_label.text = "Move mouse to aim shotgun\nLeft click to fire, Right click to cancel"
	
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.ORANGE)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	instruction_label.position = Vector2(400, 50)
	instruction_label.z_index = 200
	
	course.get_node("UILayer").add_child(instruction_label)

func show_sniper_aiming_circle() -> void:
	"""Show aiming circle with sniper reticle image"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	
	# Use the course's show_aiming_circle function but override the texture
	course.show_aiming_circle()
	
	# Replace the target circle texture with sniper reticle texture
	if course.aiming_circle:
		var circle = course.aiming_circle.get_node_or_null("CircleVisual")
		if circle:
			var sniper_reticle_texture = preload("res://UI/Reticle.png")  # Use regular reticle for now
			circle.texture = sniper_reticle_texture

func show_sniper_aiming_instruction() -> void:
	"""Show sniper-specific aiming instruction"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	var existing_instruction = course.get_node_or_null("UILayer/AimingInstructionLabel")
	if existing_instruction:
		existing_instruction.queue_free()
	
	var instruction_label := Label.new()
	instruction_label.name = "AimingInstructionLabel"
	instruction_label.text = "Move mouse to aim sniper rifle\nLeft click to fire, Right click to cancel"
	
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.RED)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	instruction_label.position = Vector2(400, 50)
	instruction_label.z_index = 200
	
	course.get_node("UILayer").add_child(instruction_label)

func show_grenade_aiming_circle() -> void:
	"""Show aiming circle with grenade reticle image"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	
	# Use the course's show_aiming_circle function but override the texture
	course.show_aiming_circle()
	
	# Replace the target circle texture with grenade reticle texture
	if course.aiming_circle:
		var circle = course.aiming_circle.get_node_or_null("CircleVisual")
		if circle:
			var grenade_reticle_texture = preload("res://UI/Reticle.png")  # Use regular reticle for now
			circle.texture = grenade_reticle_texture

func show_grenade_aiming_instruction() -> void:
	"""Show grenade-specific aiming instruction"""
	if not card_effect_handler or not card_effect_handler.course:
		return
	
	var course = card_effect_handler.course
	var existing_instruction = course.get_node_or_null("UILayer/AimingInstructionLabel")
	if existing_instruction:
		existing_instruction.queue_free()
	
	var instruction_label := Label.new()
	instruction_label.name = "AimingInstructionLabel"
	instruction_label.text = "Move mouse to set grenade target\nLeft click to throw, Right click to cancel"
	
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.RED)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	instruction_label.position = Vector2(400, 50)
	instruction_label.z_index = 200
	
	course.get_node("UILayer").add_child(instruction_label)

func create_weapon_instance() -> void:
	"""Create the weapon instance (pistol, knife, burst shot, shotgun, or grenade) in front of the player"""
	
	if weapon_instance:
		weapon_instance.queue_free()
	
	# Determine which weapon to create based on the selected card
	var weapon_scene = pistol_scene  # Default to pistol
	if selected_card and selected_card.name == "Throwing Knife":
		weapon_scene = throwing_knife_scene
	elif selected_card and selected_card.name == "GrenadeCard":
		weapon_scene = grenade_scene
	elif selected_card and selected_card.name == "GrenadeLauncherWeaponCard":
		weapon_scene = grenade_launcher_scene
	elif selected_card and selected_card.name == "BurstShot":
		weapon_scene = burst_shot_scene
	elif selected_card and selected_card.name == "ShotgunCard":
		weapon_scene = shotgun_scene
	elif selected_card and selected_card.name == "SniperCard":
		weapon_scene = sniper_scene
	elif selected_card and selected_card.name == "SpearCard":
		weapon_scene = spear_scene
	else:
		weapon_scene = pistol_scene # Fallback to pistol
	
	weapon_instance = weapon_scene.instantiate()
	
	if weapon_instance and player_node:
		player_node.add_child(weapon_instance)
		
		# Reset weapon sprite flip state
		var weapon_sprite = weapon_instance.get_node_or_null("Sprite2D")
		if weapon_sprite:
			weapon_sprite.flip_h = false
			weapon_sprite.flip_v = false
		
		# Position the weapon closer to the player's hands with the specified offset
		var weapon_offset = Vector2(-37.955, 0)  # Closer to player's hands
		weapon_instance.position = weapon_offset
	else:
		printerr("ERROR: Could not create weapon instance or player_node is null")

func show_grenade_launcher_weapon() -> void:
	"""Show the GrenadeLauncher weapon when GrenadeLauncherClubCard is selected"""
	if weapon_instance:
		weapon_instance.queue_free()
	
	weapon_instance = grenade_launcher_scene.instantiate()
	player_node.add_child(weapon_instance)
	
	# Reset weapon sprite flip state
	var weapon_sprite = weapon_instance.get_node_or_null("Sprite2D")
	if weapon_sprite:
		weapon_sprite.flip_h = false
		weapon_sprite.flip_v = false
	
	# Position the weapon closer to the player's hands with the specified offset
	var weapon_offset = Vector2(-37.955, 0)  # Closer to player's hands
	weapon_instance.position = weapon_offset
	
	# Start updating weapon rotation and position
	update_weapon_rotation()

func hide_weapon() -> void:
	"""Hide the weapon when switching to a different club"""
	if weapon_instance:
		weapon_instance.queue_free()
		weapon_instance = null
	
	# Reset grenade launcher freeze state when hiding weapon
	grenade_launcher_frozen = false

func freeze_grenade_launcher() -> void:
	"""Freeze the grenade launcher at its current rotation and flip state"""
	if not weapon_instance:
		return
	
	# Check if this is a grenade launcher (either weapon card or club card)
	var is_grenade_launcher = false
	if selected_card and selected_card.name == "GrenadeLauncherWeaponCard":
		is_grenade_launcher = true
	elif card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		if course.selected_club == "GrenadeLauncherClubCard":
			is_grenade_launcher = true
	
	if not is_grenade_launcher:
		return
	
	# Store current rotation and flip state
	frozen_rotation = weapon_instance.rotation
	var weapon_sprite = weapon_instance.get_node_or_null("Sprite2D")
	if weapon_sprite:
		frozen_flip_h = weapon_sprite.flip_h
		frozen_flip_v = weapon_sprite.flip_v
	
	# Set frozen state
	grenade_launcher_frozen = true

func update_weapon_rotation() -> void:
	"""Update weapon rotation to follow mouse and position based on player direction"""
	if not weapon_instance or not player_node or not camera:
		return
	
	# Check if grenade launcher should be frozen
	var is_grenade_launcher = false
	if selected_card and selected_card.name == "GrenadeLauncherWeaponCard":
		is_grenade_launcher = true
	elif card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		if course.selected_club == "GrenadeLauncherClubCard":
			is_grenade_launcher = true
	
	if is_grenade_launcher and grenade_launcher_frozen:
		# Apply frozen rotation and flip state
		weapon_instance.rotation = frozen_rotation
		var weapon_sprite = weapon_instance.get_node_or_null("Sprite2D")
		if weapon_sprite:
			weapon_sprite.flip_h = frozen_flip_h
			weapon_sprite.flip_v = frozen_flip_v
		return
	
	var mouse_pos = camera.get_global_mouse_position()
	var player_pos = player_node.global_position
	var direction = (mouse_pos - player_pos).normalized()
	
	# Calculate angle to mouse
	var angle = atan2(direction.y, direction.x)
	weapon_instance.rotation = angle
	
	# Get the player's character sprite to check its flip state
	var player_sprite = player_node.get_character_sprite()
	if player_sprite:
		var y_offset = -33 
		var weapon_offset = Vector2(37.955, y_offset)  # Base offset (right side)
		var weapon_sprite = weapon_instance.get_node_or_null("Sprite2D")
		
		# Handle weapon positioning and flipping based on player direction
		if player_sprite.flip_h:
			weapon_offset.x = -37.955
			if weapon_sprite:
				# For knife, we might want different flip behavior
				if selected_card and selected_card.name == "Throwing Knife":
					weapon_sprite.flip_h = true
					weapon_sprite.flip_v = false
				elif selected_card and selected_card.name == "ShotgunCard":
					# Shotgun behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = true
				elif selected_card and selected_card.name == "SniperCard":
					# Sniper behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = true
				elif selected_card and selected_card.name == "GrenadeLauncherClubCard":
					# GrenadeLauncher behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = true
				elif selected_card and selected_card.name == "GrenadeLauncherWeaponCard":
					# GrenadeLauncherWeaponCard behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = true
				else:
					# Pistol and BurstShot behavior
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = true
		else:
			if weapon_sprite:
				# For knife, we might want different flip behavior
				if selected_card and selected_card.name == "Throwing Knife":
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = false
				elif selected_card and selected_card.name == "ShotgunCard":
					# Shotgun behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = false
				elif selected_card and selected_card.name == "SniperCard":
					# Sniper behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = false
				elif selected_card and selected_card.name == "GrenadeLauncherClubCard":
					# GrenadeLauncher behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = false
				elif selected_card and selected_card.name == "GrenadeLauncherWeaponCard":
					# GrenadeLauncherWeaponCard behavior (same as pistol)
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = false
				else:
					# Pistol and BurstShot behavior
					weapon_sprite.flip_h = false
					weapon_sprite.flip_v = false
		weapon_instance.position = weapon_offset

func fire_weapon() -> void:
	"""Fire the weapon and perform raytrace or launch knife/grenade"""
	if not weapon_instance or not player_node:
		return
	
	# Check if this is a throwing knife and we have LaunchManager
	if selected_card and selected_card.name == "Throwing Knife" and launch_manager:
		# Use LaunchManager for knife throwing
		launch_throwing_knife()
		return
	
	# Check if this is a grenade and we have LaunchManager
	if selected_card and selected_card.name == "GrenadeCard" and launch_manager:
		# Use LaunchManager for grenade throwing
		launch_grenade()
		return
	
	# Check if this is a grenade launcher weapon and we have LaunchManager
	if selected_card and selected_card.name == "GrenadeLauncherWeaponCard" and launch_manager:
		# Use LaunchManager for grenade launcher throwing
		launch_grenade_launcher()
		return
	
	# Check if this is a spear and we have LaunchManager
	if selected_card and selected_card.name == "SpearCard" and launch_manager:
		# Use LaunchManager for spear throwing
		launch_spear()
		return
	
	# Check if this is a BurstShot weapon
	if selected_card and selected_card.name == "BurstShot":
		fire_burst_shot()
		return
	
	# Check if this is a ShotgunCard weapon
	if selected_card and selected_card.name == "ShotgunCard":
		fire_shotgun()
		return
	
	# Check if this is a SniperCard weapon
	if selected_card and selected_card.name == "SniperCard":
		fire_sniper()
		return
	
	# Otherwise use the original raytrace system for pistols
	# Play weapon sound from player node based on weapon type
	var weapon_sound = null
	if selected_card and selected_card.name == "Throwing Knife":
		# For now, use pistol sound for knife - you can add a knife sound later
		weapon_sound = player_node.get_node_or_null("PistolShot")
	elif selected_card and selected_card.name == "ShotgunCard":
		# Use shotgun sound if available, otherwise pistol sound
		weapon_sound = player_node.get_node_or_null("Shotgun") or player_node.get_node_or_null("PistolShot")
	else:
		weapon_sound = player_node.get_node_or_null("PistolShot")
	
	if weapon_sound:
		weapon_sound.play()
	else:
		return
	
	# Perform raytrace
	var hit_target = perform_raytrace()
	
	if hit_target:
		# Deal damage to all targets (including oil drums)
		if hit_target.has_method("take_damage"):
			# Check what type of target this is and call take_damage with appropriate parameters
			var weapon_pos = weapon_instance.global_position if weapon_instance else Vector2.ZERO
			
			if hit_target.get_script() and hit_target.get_script().resource_path.ends_with("oil_drum.gd"):
				# Oil drum only takes damage amount
				hit_target.take_damage(weapon_damage)
			elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("GangMember.gd"):
				# GangMember takes damage, is_headshot, and weapon_position
				hit_target.take_damage(weapon_damage, false, weapon_pos)
			elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("Player.gd"):
				# Player takes damage and is_headshot
				hit_target.take_damage(weapon_damage, false)
			else:
				# Default: just pass damage amount
				hit_target.take_damage(weapon_damage)
			
			emit_signal("npc_shot", hit_target, weapon_damage)
		else:
			return
	
	# Exit weapon mode after firing
	exit_weapon_mode()

func fire_burst_shot() -> void:
	"""Fire bullets in quick succession based on effective strength"""
	if not weapon_instance or not player_node:
		return
	
	# Play burst sound
	var burst_sound = player_node.get_node_or_null("BurstShot")
	if burst_sound:
		burst_sound.play()
	
	# Get burst count from effective strength
	var burst_count = selected_card.get_effective_strength()
	var total_duration = 1.0  # 1 second total
	var burst_delay = total_duration / burst_count  # Time between shots
	
	# Start the burst sequence
	start_burst_sequence(burst_count, burst_delay)

func start_burst_sequence(burst_count: int, burst_delay: float) -> void:
	"""Start the burst firing sequence with updated mechanics"""
	# Fire the first shot immediately
	fire_single_burst_shot(false)
	
	# Time the remaining shots
	for i in range(1, burst_count):
		# Create a timer for this shot
		var shot_timer = Timer.new()
		shot_timer.wait_time = i * burst_delay
		shot_timer.one_shot = true
		shot_timer.timeout.connect(func(): fire_single_burst_shot(i == burst_count - 1))
		add_child(shot_timer)
		shot_timer.start()

func fire_single_burst_shot(is_last_shot: bool) -> void:
	"""Fire a single shot in the burst sequence with updated mechanics"""
	if not weapon_instance or not player_node or not camera:
		return
	
	# Get current mouse position and weapon position for this shot
	var mouse_pos = camera.get_global_mouse_position()
	var weapon_pos = weapon_instance.global_position
	var direction = (mouse_pos - weapon_pos).normalized()
	
	# Create visual tracer line
	create_tracer_line(weapon_pos, mouse_pos)
	
	# Perform raytrace from weapon to mouse position
	var hit_target = perform_raytrace_with_direction(weapon_pos, direction)
	
	if hit_target:
		# Deal damage to all targets (including oil drums)
		if hit_target.has_method("take_damage"):
			# Check what type of target this is and call take_damage with appropriate parameters
			var weapon_pos_global = weapon_instance.global_position if weapon_instance else Vector2.ZERO
			
			if hit_target.get_script() and hit_target.get_script().resource_path.ends_with("oil_drum.gd"):
				# Oil drum only takes damage amount
				hit_target.take_damage(weapon_damage)
			elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("GangMember.gd"):
				# GangMember takes damage, is_headshot, and weapon_position
				hit_target.take_damage(weapon_damage, false, weapon_pos_global)
			elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("Player.gd"):
				# Player takes damage and is_headshot
				hit_target.take_damage(weapon_damage, false)
			else:
				# Default: just pass damage amount
				hit_target.take_damage(weapon_damage)
			
			emit_signal("npc_shot", hit_target, weapon_damage)
	
	# Exit weapon mode after the last shot
	if is_last_shot:
		exit_weapon_mode()

func fire_shotgun() -> void:
	"""Fire 5 bullets in a spread pattern with short range"""
	if not weapon_instance or not player_node or not camera:
		return
	
	# Play shotgun sound
	var shotgun_sound = player_node.get_node_or_null("ShotgunShot")
	if not shotgun_sound:
		shotgun_sound = player_node.get_node_or_null("PistolShot")  # Fallback
	if shotgun_sound and shotgun_sound is AudioStreamPlayer2D:
		shotgun_sound.play()
		# Play ShotgunCock sound after ShotgunShot finishes
		shotgun_sound.finished.connect(_on_shotgun_shot_finished, CONNECT_ONE_SHOT)
	
	# Shotgun settings - shots based on effective strength
	var spread_count = selected_card.get_effective_strength()
	var spread_angle = 0.3  # ~17 degrees total spread (0.3 radians)
	var base_direction = Vector2.ZERO
	
	# Get the base direction from weapon to mouse
	var mouse_pos = camera.get_global_mouse_position()
	var weapon_pos = weapon_instance.global_position
	base_direction = (mouse_pos - weapon_pos).normalized()
	
	# Calculate spread angles
	var angle_step = spread_angle / (spread_count - 1)
	var start_angle = -spread_angle / 2
	
	# Fire all shots at once
	for i in range(spread_count):
		var current_angle = start_angle + (i * angle_step)
		var spread_direction = base_direction.rotated(current_angle)
		
		# Create visual tracer line for this shot
		var end_pos = weapon_pos + spread_direction * 350.0  # Shotgun range is 350 pixels
		create_tracer_line(weapon_pos, end_pos)
		
		# Perform raytrace with limited range for shotgun
		var hit_target = perform_raytrace_with_direction_and_range(weapon_pos, spread_direction, 350.0)
		
		if hit_target:
			# Deal damage to all targets (including oil drums)
			if hit_target.has_method("take_damage"):
				# Check what type of target this is and call take_damage with appropriate parameters
				var weapon_pos_global = weapon_instance.global_position if weapon_instance else Vector2.ZERO
				
				if hit_target.get_script() and hit_target.get_script().resource_path.ends_with("oil_drum.gd"):
					# Oil drum only takes damage amount
					hit_target.take_damage(weapon_damage)
				elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("GangMember.gd"):
					# GangMember takes damage, is_headshot, and weapon_position
					hit_target.take_damage(weapon_damage, false, weapon_pos_global)
				elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("Player.gd"):
					# Player takes damage and is_headshot
					hit_target.take_damage(weapon_damage, false)
				else:
					# Default: just pass damage amount
					hit_target.take_damage(weapon_damage)
				
				emit_signal("npc_shot", hit_target, weapon_damage)
	
	# Exit weapon mode after firing
	exit_weapon_mode()

func fire_sniper() -> void:
	"""Fire a single piercing bullet with long range"""
	if not weapon_instance or not player_node or not camera:
		return
	
	# Play sniper sound
	var sniper_sound = player_node.get_node_or_null("SniperShot")
	if not sniper_sound:
		sniper_sound = player_node.get_node_or_null("PistolShot")  # Fallback
	if sniper_sound and sniper_sound is AudioStreamPlayer2D:
		sniper_sound.play()
		# Play SniperCock sound after SniperShot finishes
		sniper_sound.finished.connect(_on_sniper_shot_finished, CONNECT_ONE_SHOT)
	
	# Sniper settings - single piercing shot with long range
	var weapon_pos = weapon_instance.global_position
	var mouse_pos = camera.get_global_mouse_position()
	var direction = (mouse_pos - weapon_pos).normalized()
	
	# Create visual tracer line for sniper shot
	var end_pos = weapon_pos + direction * 1500.0  # Sniper range is 1500 pixels
	create_tracer_line(weapon_pos, end_pos)
	
	# Perform piercing raytrace with sniper range
	var hit_targets = perform_piercing_raytrace(weapon_pos, direction, 1500.0)
	
	# Deal damage to all hit targets
	for hit_target in hit_targets:
		if hit_target.has_method("take_damage"):
			# Check what type of target this is and call take_damage with appropriate parameters
			var weapon_pos_global = weapon_instance.global_position if weapon_instance else Vector2.ZERO
			
			if hit_target.get_script() and hit_target.get_script().resource_path.ends_with("oil_drum.gd"):
				# Oil drum only takes damage amount
				hit_target.take_damage(weapon_damage)
			elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("GangMember.gd"):
				# GangMember takes damage, is_headshot, and weapon_position
				hit_target.take_damage(weapon_damage, false, weapon_pos_global)
			elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("Player.gd"):
				# Player takes damage and is_headshot
				hit_target.take_damage(weapon_damage, false)
			else:
				# Default: just pass damage amount
				hit_target.take_damage(weapon_damage)
			
			emit_signal("npc_shot", hit_target, weapon_damage)
	
	# Tween camera back to player after firing
	if card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var tween := get_tree().create_tween()
		tween.tween_property(course.camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Exit weapon mode after firing
	exit_weapon_mode()

func create_tracer_line(start_pos: Vector2, end_pos: Vector2) -> void:
	"""Create a grey thin tracer line that flashes briefly"""
	# Create a Line2D node for the tracer
	var tracer_line = Line2D.new()
	tracer_line.width = 1.0  # Thin line
	tracer_line.default_color = Color(0.5, 0.5, 0.5, 0.8)  # Grey with some transparency
	tracer_line.points = [start_pos, end_pos]
	tracer_line.z_index = 1000  # Ensure it's visible above other elements
	
	# Add to the scene
	var course = card_effect_handler.course if card_effect_handler else get_tree().current_scene
	course.add_child(tracer_line)
	
	# Create a timer to remove the tracer after a short duration
	var remove_timer = Timer.new()
	remove_timer.wait_time = 0.1  # Flash for 100ms
	remove_timer.one_shot = true
	remove_timer.timeout.connect(func(): 
		tracer_line.queue_free()
		remove_timer.queue_free()
	)
	course.add_child(remove_timer)
	remove_timer.start()

func perform_raytrace_with_direction(weapon_pos: Vector2, direction: Vector2) -> Node:
	"""Perform raytrace from weapon position in the specified direction"""
	if not card_effect_handler or not card_effect_handler.course:
		return null
	
	var course = card_effect_handler.course
	
	# Cast ray from weapon position in the specified direction
	var ray_end = weapon_pos + direction * weapon_range
	
	# Check for obstacles along the bullet path
	var space_state = course.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(weapon_pos, ray_end)
	query.collision_mask = 2  # Collide with layer 2 (HitBoxes for weapons)
	query.collide_with_bodies = false  # We're using Area2D HitBoxes
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Bullet hit something
		var hit_object = result.collider
		
		# Check if it's a HitBox Area2D
		if hit_object.name == "HitBox":
			var parent = hit_object.get_parent()
			
			# Check if it's a tree's HitBox
			if parent and (parent.name == "Tree" or "Tree" in str(parent.get_script()) or parent.has_method("_handle_trunk_collision")):
				return null  # Tree blocks the shot
			
			# Check if it's a GangMember's HitBox
			if parent and parent.has_method("take_damage"):
				return parent  # Return the parent GangMember, not the HitBox
			
			# Check if it's an OilDrum's HitBox
			if parent and (parent.name == "OilDrum" or "oil_drum.gd" in str(parent.get_script())):
				return parent  # Return the parent OilDrum, not the HitBox
	else:
		# No obstacles hit, check if any NPCs are in the direct path
		var entities = course.get_node_or_null("Entities")
		if entities:
			var npcs = entities.get_npcs()
			var closest_npc = null
			var closest_distance = weapon_range
			
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("take_damage"):
					var npc_pos = npc.global_position
					var to_npc = npc_pos - weapon_pos
					var distance = to_npc.length()
					
					# Check if NPC is in the direct line of fire
					if distance <= weapon_range:
						var dot_product = to_npc.normalized().dot(direction)
						if dot_product > 0.99:  # Very precise aim required
							# Double-check no obstacles in the way
							var final_query = PhysicsRayQueryParameters2D.create(weapon_pos, npc_pos)
							final_query.collision_mask = 2  # Check for HitBoxes on layer 2
							final_query.collide_with_bodies = true
							final_query.collide_with_areas = true
							
							var final_result = space_state.intersect_ray(final_query)
							
							if final_result and final_result.collider == npc:
								if distance < closest_distance:
									closest_distance = distance
									closest_npc = npc
			
			if closest_npc:
				return closest_npc
	
	return null

func perform_raytrace_with_direction_and_range(weapon_pos: Vector2, direction: Vector2, custom_range: float) -> Node:
	"""Perform raytrace from weapon position in the specified direction with custom range"""
	if not card_effect_handler or not card_effect_handler.course:
		return null
	
	var course = card_effect_handler.course
	
	# Cast ray from weapon position in the specified direction with custom range
	var ray_end = weapon_pos + direction * custom_range
	
	# Check for obstacles along the bullet path
	var space_state = course.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(weapon_pos, ray_end)
	query.collision_mask = 2  # Collide with layer 2 (HitBoxes for weapons)
	query.collide_with_bodies = false  # We're using Area2D HitBoxes
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Bullet hit something
		var hit_object = result.collider
		
		# Check if it's a HitBox Area2D
		if hit_object.name == "HitBox":
			var parent = hit_object.get_parent()
			
			# Check if it's a tree's HitBox
			if parent and (parent.name == "Tree" or "Tree" in str(parent.get_script()) or parent.has_method("_handle_trunk_collision")):
				return null  # Tree blocks the shot
			
			# Check if it's a GangMember's HitBox
			if parent and parent.has_method("take_damage"):
				return parent  # Return the parent GangMember, not the HitBox
			
			# Check if it's an OilDrum's HitBox
			if parent and (parent.name == "OilDrum" or "oil_drum.gd" in str(parent.get_script())):
				return parent  # Return the parent OilDrum, not the HitBox
	else:
		# No obstacles hit, check if any NPCs are in the direct path
		var entities = course.get_node_or_null("Entities")
		if entities:
			var npcs = entities.get_npcs()
			var closest_npc = null
			var closest_distance = custom_range
			
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("take_damage"):
					var npc_pos = npc.global_position
					var to_npc = npc_pos - weapon_pos
					var distance = to_npc.length()
					
					# Check if NPC is in the direct line of fire
					if distance <= custom_range:
						var dot_product = to_npc.normalized().dot(direction)
						if dot_product > 0.99:  # Very precise aim required
							# Double-check no obstacles in the way
							var final_query = PhysicsRayQueryParameters2D.create(weapon_pos, npc_pos)
							final_query.collision_mask = 2  # Check for HitBoxes on layer 2
							final_query.collide_with_bodies = true
							final_query.collide_with_areas = true
							
							var final_result = space_state.intersect_ray(final_query)
							
							if final_result and final_result.collider == npc:
								if distance < closest_distance:
									closest_distance = distance
									closest_npc = npc
			
			if closest_npc:
				return closest_npc
	
	return null

func launch_throwing_knife() -> void:
	"""Launch a throwing knife using the LaunchManager system"""
	if not launch_manager or not weapon_instance or not camera:
		return
	
	# Get the landing spot from the aiming circle if available, otherwise use mouse position
	var landing_spot = camera.get_global_mouse_position()  # Default to mouse position
	if card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		if course.chosen_landing_spot != Vector2.ZERO:
			landing_spot = course.chosen_landing_spot
	
	# Set up LaunchManager for knife mode
	launch_manager.chosen_landing_spot = landing_spot
	launch_manager.player_stats = player_stats
	
	# Create a knife instance if it doesn't exist
	var knife_instance = null
	var knives = get_tree().get_nodes_in_group("knives")
	for knife in knives:
		if is_instance_valid(knife):
			knife_instance = knife
			break
	
	if not knife_instance:
		return
	
	# Set up the knife properties
	knife_instance.cell_size = cell_size
	knife_instance.map_manager = card_effect_handler.course.get_node_or_null("MapManager") if card_effect_handler else null
	
	# Enter knife mode in LaunchManager
	launch_manager.enter_knife_mode()
	
	# Exit weapon mode (LaunchManager will handle the rest)
	exit_weapon_mode()

func launch_grenade() -> void:
	"""Launch a grenade using the LaunchManager system"""
	if not launch_manager or not weapon_instance or not camera:
		return
	
	# Get the landing spot from the aiming circle if available, otherwise use mouse position
	var landing_spot = camera.get_global_mouse_position()  # Default to mouse position
	if card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		if course.chosen_landing_spot != Vector2.ZERO:
			landing_spot = course.chosen_landing_spot
	
	# Set up LaunchManager for grenade mode
	launch_manager.chosen_landing_spot = landing_spot
	launch_manager.player_stats = player_stats
	
	# Enter grenade mode in LaunchManager (it will handle grenade creation)
	launch_manager.enter_grenade_mode()
	
	# Exit weapon mode (LaunchManager will handle the rest)
	exit_weapon_mode()

func launch_grenade_launcher() -> void:
	"""Launch a grenade using the LaunchManager system with GrenadeLauncherClubCard stats"""
	if not launch_manager or not weapon_instance or not camera:
		return
	
	# Get the landing spot from the aiming circle if available, otherwise use mouse position
	var landing_spot = camera.get_global_mouse_position()  # Default to mouse position
	if card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		if course.chosen_landing_spot != Vector2.ZERO:
			landing_spot = course.chosen_landing_spot
	
	# Set up LaunchManager for grenade launcher mode
	launch_manager.chosen_landing_spot = landing_spot
	launch_manager.player_stats = player_stats
	
	# Enter grenade mode in LaunchManager (it will handle grenade creation)
	# Use the same grenade mode but with GrenadeLauncherClubCard stats
	launch_manager.enter_grenade_mode()
	
	# Don't exit weapon mode immediately - let the grenade landing handlers clear the weapon
	# This allows the weapon to stay visible during the grenade's flight
	# The weapon will be cleared when the grenade lands/explodes
	
	# Reset weapon mode state but keep the weapon instance
	is_weapon_mode = false
	selected_card = null
	active_button = null
	
	# Clean up aiming mode if it was active
	if card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		course.is_aiming_phase = false
		course.hide_aiming_circle()
		course.hide_aiming_instruction()
		
		# Restore zoom after aiming
		if course.has_method("restore_zoom_after_aiming"):
			course.restore_zoom_after_aiming()
		
		# Restore original club if it was stored
		if has_meta("original_club"):
			course.selected_club = get_meta("original_club")
			remove_meta("original_club")
	
	emit_signal("weapon_mode_exited")

func launch_spear() -> void:
	"""Launch a spear using the LaunchManager system"""
	if not launch_manager or not weapon_instance or not camera:
		return
	
	# Get the landing spot from the aiming circle if available, otherwise use mouse position
	var landing_spot = camera.get_global_mouse_position()  # Default to mouse position
	if card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		if course.chosen_landing_spot != Vector2.ZERO:
			landing_spot = course.chosen_landing_spot
	
	# Set up LaunchManager for spear mode
	launch_manager.chosen_landing_spot = landing_spot
	launch_manager.player_stats = player_stats
	
	# Create a spear instance if it doesn't exist
	var spear_instance = null
	var spears = get_tree().get_nodes_in_group("spears")
	for spear in spears:
		if is_instance_valid(spear):
			spear_instance = spear
			break
	
	if not spear_instance:
		# Create a new spear instance
		spear_instance = spear_scene.instantiate()
		
		# Add spear to groups for smart optimization
		spear_instance.add_to_group("spears")
		spear_instance.add_to_group("collision_objects")
		
		# Add to the CameraContainer like golf balls
		if card_effect_handler and card_effect_handler.course:
			var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
			if camera_container:
				camera_container.add_child(spear_instance)
				spear_instance.global_position = player_node.global_position
			else:
				# Fallback to course if CameraContainer not found
				card_effect_handler.course.add_child(spear_instance)
				spear_instance.global_position = player_node.global_position
		else:
			return
	
	# Set up the spear properties
	spear_instance.cell_size = cell_size
	spear_instance.map_manager = card_effect_handler.course.map_manager if card_effect_handler else null
	
	# Enter spear mode in LaunchManager
	launch_manager.enter_spear_mode()
	
	# Exit weapon mode (LaunchManager will handle the rest)
	exit_weapon_mode()

func perform_raytrace() -> Node:
	"""Perform raytrace from pistol center to mouse position with proper bullet physics"""
	if not weapon_instance or not player_node or not camera:
		return null
	
	# Get pistol center position (weapon's global position)
	var pistol_pos = weapon_instance.global_position
	var mouse_pos = camera.get_global_mouse_position()
	
	# Get course reference for obstacle checking
	if not card_effect_handler or not card_effect_handler.course:
		return null
	
	var course = card_effect_handler.course
	
	# Cast ray from pistol center to mouse position, extending beyond mouse
	var direction = (mouse_pos - pistol_pos).normalized()
	var ray_end = pistol_pos + direction * weapon_range
	
	# Check for obstacles along the bullet path
	var space_state = course.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(pistol_pos, ray_end)
	query.collision_mask = 2  # Collide with layer 2 (HitBoxes for weapons)
	query.collide_with_bodies = false  # We're using Area2D HitBoxes
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Bullet hit something
		var hit_object = result.collider
		var hit_distance = result.position.distance_to(pistol_pos)
		
		# Check if it's a HitBox Area2D
		if hit_object.name == "HitBox":
			var parent = hit_object.get_parent()
			
			# Check if it's a tree's HitBox
			if parent and (parent.name == "Tree" or "Tree" in str(parent.get_script()) or parent.has_method("_handle_trunk_collision")):
				return null  # Tree blocks the shot
			
			# Check if it's a GangMember's HitBox
			if parent and parent.has_method("take_damage"):
				return parent  # Return the parent GangMember, not the HitBox
			
			# Check if it's an OilDrum's HitBox
			if parent and (parent.name == "OilDrum" or "oil_drum.gd" in str(parent.get_script())):
				return parent  # Return the parent OilDrum, not the HitBox
	else:
		# No obstacles hit, check if any NPCs are in the direct path
		var entities = course.get_node_or_null("Entities")
		if entities:
			var npcs = entities.get_npcs()
			var closest_npc = null
			var closest_distance = weapon_range
			
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("take_damage"):
					var npc_pos = npc.global_position
					var to_npc = npc_pos - pistol_pos
					var distance = to_npc.length()
					
					# Check if NPC is in the direct line of fire
					if distance <= weapon_range:
						var dot_product = to_npc.normalized().dot(direction)
						if dot_product > 0.99:  # Very precise aim required
							# Double-check no obstacles in the way
							var final_query = PhysicsRayQueryParameters2D.create(pistol_pos, npc_pos)
							final_query.collision_mask = 2  # Check for HitBoxes on layer 2
							final_query.collide_with_bodies = true
							final_query.collide_with_areas = true
							
							var final_result = space_state.intersect_ray(final_query)
							
							if final_result and final_result.collider == npc:
								if distance < closest_distance:
									closest_distance = distance
									closest_npc = npc
			
			if closest_npc:
				return closest_npc
	
	# Fallback: If physics raycast isn't working, try a simpler distance-based check
	var fallback_hit = _fallback_distance_check(pistol_pos, direction)
	if fallback_hit:
		_handle_knife_hit(null, fallback_hit)
		return fallback_hit
	
	return null

func _fallback_distance_check(pistol_pos: Vector2, direction: Vector2) -> Node:
	"""Fallback method to check for objects along the bullet path using distance calculations"""
	
	# Check for HitBox Area2D nodes first
	var hitboxes = get_tree().get_nodes_in_group("hitboxes")
	
	if not hitboxes:
		# Try to find HitBox nodes by name
		hitboxes = []
		for node in get_tree().get_nodes_in_group("."):
			if node.name == "HitBox":
				hitboxes.append(node)
	
	# Check each HitBox
	for hitbox in hitboxes:
		if is_instance_valid(hitbox):
			var hitbox_pos = hitbox.global_position
			var to_hitbox = hitbox_pos - pistol_pos
			var distance = to_hitbox.length()
			
			# Check if HitBox is in the bullet path
			if distance <= weapon_range:
				var dot_product = to_hitbox.normalized().dot(direction)
				
				if dot_product > 0.95:  # Within ~18 degrees of aim direction
					var parent = hitbox.get_parent()
					
					# Check if it's a tree's HitBox
					if parent and (parent.name == "Tree" or "Tree" in str(parent.get_script()) or parent.has_method("_handle_trunk_collision")):
						return null  # Tree blocks the shot
					
					# Check if it's a GangMember's HitBox
					if parent and parent.has_method("take_damage"):
						return parent  # Return the parent GangMember
					
					# Check if it's an OilDrum's HitBox
					if parent and (parent.name == "OilDrum" or "oil_drum.gd" in str(parent.get_script())):
						return parent  # Return the parent OilDrum
	
	# Check for GangMembers (fallback for entities without HitBox)
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if entities:
		var npcs = entities.get_npcs()
		var closest_npc = null
		var closest_distance = weapon_range
		
		for npc in npcs:
			if is_instance_valid(npc) and npc.has_method("take_damage"):
				var npc_pos = npc.global_position
				var to_npc = npc_pos - pistol_pos
				var distance = to_npc.length()
				
				# Check if NPC is in the bullet path
				if distance <= weapon_range:
					var dot_product = to_npc.normalized().dot(direction)
					if dot_product > 0.95:  # Within ~18 degrees of aim direction
						# Check if any HitBoxes are blocking the shot
						var blocked = false
						for hitbox in hitboxes:
							if is_instance_valid(hitbox):
								var hitbox_pos = hitbox.global_position
								var hitbox_to_npc = npc_pos - hitbox_pos
								var hitbox_to_pistol = pistol_pos - hitbox_pos
								
								# If HitBox is between pistol and NPC
								if hitbox_to_pistol.dot(hitbox_to_npc) > 0 and hitbox_to_npc.length() < distance:
									blocked = true
									break
						
						if not blocked and distance < closest_distance:
							closest_distance = distance
							closest_npc = npc
		
		if closest_npc:
			return closest_npc
	
	return null

func exit_weapon_mode() -> void:
	"""Exit weapon aiming mode"""
	
	is_weapon_mode = false
	
	# Reset grenade launcher freeze state
	grenade_launcher_frozen = false
	
	# Restore default mouse cursor
	Input.set_custom_mouse_cursor(null)
	
	# Remove weapon instance
	if weapon_instance:
		weapon_instance.queue_free()
		weapon_instance = null
	
	# Clean up knife aiming mode if it was active
	if selected_card and selected_card.name == "Throwing Knife" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		course.is_aiming_phase = false
		course.hide_aiming_circle()
		course.hide_aiming_instruction()
		
		# Restore original club if it was stored
		if has_meta("original_club"):
			course.selected_club = get_meta("original_club")
			remove_meta("original_club")
	
	# Clean up grenade aiming mode if it was active
	if selected_card and selected_card.name == "GrenadeCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		course.is_aiming_phase = false
		course.hide_aiming_circle()
		course.hide_aiming_instruction()
		
		# Restore original club if it was stored
		if has_meta("original_club"):
			course.selected_club = get_meta("original_club")
			remove_meta("original_club")
	
	# Clean up grenade launcher weapon aiming mode if it was active
	if selected_card and selected_card.name == "GrenadeLauncherWeaponCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		course.is_aiming_phase = false
		course.hide_aiming_circle()
		course.hide_aiming_instruction()
		
		# Restore original club if it was stored
		if has_meta("original_club"):
			course.selected_club = get_meta("original_club")
			remove_meta("original_club")
	
	# Clean up shotgun aiming mode if it was active
	if selected_card and selected_card.name == "ShotgunCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		course.is_aiming_phase = false
		course.hide_aiming_circle()
		course.hide_aiming_instruction()
		
		# Restore original club if it was stored
		if has_meta("original_club"):
			course.selected_club = get_meta("original_club")
			remove_meta("original_club")
	
	# Clean up sniper aiming mode if it was active
	if selected_card and selected_card.name == "SniperCard" and card_effect_handler and card_effect_handler.course:
		var course = card_effect_handler.course
		course.is_aiming_phase = false
		course.hide_aiming_circle()
		course.hide_aiming_instruction()
		
		# Restore original club if it was stored
		if has_meta("original_club"):
			course.selected_club = get_meta("original_club")
			remove_meta("original_club")
	
	# Input is handled by the course's _input function
	
	selected_card = null
	active_button = null
	
	emit_signal("weapon_mode_exited")

func cleanup_weapon_card_button() -> void:
	"""Clean up the button for a weapon card that was just used"""
	if active_button and active_button.is_inside_tree():
		if movement_controller and movement_controller.has_method("get_movement_buttons_container"):
			var container = movement_controller.get_movement_buttons_container()
			if container and container.has_node(NodePath(active_button.name)):
				container.remove_child(active_button)
		
		active_button.queue_free()
		
		# Also remove from movement controller's button list if it exists
		if movement_controller and movement_controller.has_method("remove_button_from_list"):
			movement_controller.remove_button_from_list(active_button)
	
	active_button = null

func clear_all_weapon_ui() -> void:
	"""Clear all weapon-related UI elements"""
	selected_card = null
	active_button = null
	is_weapon_mode = false
	
	if weapon_instance:
		weapon_instance.queue_free()
		weapon_instance = null

func update_player_position(new_grid_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	player_grid_pos = new_grid_pos

func is_in_weapon_mode() -> bool:
	return is_weapon_mode

func get_selected_card() -> CardData:
	return selected_card

func handle_input(event: InputEvent) -> bool:
	"""Handle input when in weapon mode. Returns true if input was handled."""
	if not is_weapon_mode:
		return false
	
	# Handle mouse movement for aiming
	if event is InputEventMouseMotion:
		update_weapon_rotation()
		
		# For knife mode, update aiming circle like normal shot placement
		if selected_card and selected_card.name == "Throwing Knife" and card_effect_handler and card_effect_handler.course:
			var course = card_effect_handler.course
			if course.is_aiming_phase and course.aiming_circle:
				course.update_aiming_circle()
		
		# For grenade mode, update aiming circle like normal shot placement
		if selected_card and selected_card.name == "GrenadeCard" and card_effect_handler and card_effect_handler.course:
			var course = card_effect_handler.course
			if course.is_aiming_phase and course.aiming_circle:
				course.update_aiming_circle()
		
		# For grenade launcher weapon mode, update aiming circle like normal shot placement
		if selected_card and selected_card.name == "GrenadeLauncherWeaponCard" and card_effect_handler and card_effect_handler.course:
			var course = card_effect_handler.course
			if course.is_aiming_phase and course.aiming_circle:
				course.update_aiming_circle()
		
		# For shotgun mode, update aiming circle like normal shot placement
		if selected_card and selected_card.name == "ShotgunCard" and card_effect_handler and card_effect_handler.course:
			var course = card_effect_handler.course
			if course.is_aiming_phase and course.aiming_circle:
				course.update_aiming_circle()
		
		# For sniper mode, update aiming circle like normal shot placement
		if selected_card and selected_card.name == "SniperCard" and card_effect_handler and card_effect_handler.course:
			var course = card_effect_handler.course
			if course.is_aiming_phase and course.aiming_circle:
				course.update_aiming_circle()
		return true
	
	# Handle left click for firing
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		fire_weapon()
		return true
	
	# Handle right click to cancel weapon mode
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		exit_weapon_mode()
		return true
	
	return false 

func _handle_knife_hit(knife_instance: Node2D, hit_target: Node) -> void:
	"""Handle the hit from a thrown knife"""
	if not knife_instance or not hit_target:
		return
	
	# Deal damage to the target
	if hit_target.has_method("take_damage"):
		# Check what type of target this is and call take_damage with appropriate parameters
		if hit_target.get_script() and hit_target.get_script().resource_path.ends_with("oil_drum.gd"):
			# Oil drum only takes damage amount
			hit_target.take_damage(weapon_damage)
		elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("GangMember.gd"):
			# GangMember takes damage, is_headshot, and weapon_position
			hit_target.take_damage(weapon_damage, false, knife_instance.global_position)
		elif hit_target.get_script() and hit_target.get_script().resource_path.ends_with("Player.gd"):
			# Player takes damage and is_headshot
			hit_target.take_damage(weapon_damage, false)
		else:
			# Default: just pass damage amount
			hit_target.take_damage(weapon_damage)
		
		emit_signal("npc_shot", hit_target, weapon_damage)
		
		# Check if the target died
		if hit_target.has_method("get_is_dead"):
			var is_dead = hit_target.get_is_dead()
		elif hit_target.has_method("is_dead"):
			var is_dead = hit_target.is_dead
	else:
		return
	
	# Exit weapon mode after hitting
	exit_weapon_mode()

func _on_shotgun_shot_finished() -> void:
	"""Called when the ShotgunShot sound finishes playing"""
	# Play ShotgunCock sound
	var shotgun_cock_sound = player_node.get_node_or_null("ShotgunCock")
	if shotgun_cock_sound and shotgun_cock_sound is AudioStreamPlayer2D:
		shotgun_cock_sound.play()

func _on_sniper_shot_finished() -> void:
	"""Called when the SniperShot sound finishes playing"""
	# Play SniperCock sound
	var sniper_cock_sound = player_node.get_node_or_null("SniperCock")
	if sniper_cock_sound and sniper_cock_sound is AudioStreamPlayer2D:
		sniper_cock_sound.play()

func perform_piercing_raytrace(weapon_pos: Vector2, direction: Vector2, max_range: float) -> Array:
	"""Perform raytrace that pierces through the first object and stops on the second"""
	if not card_effect_handler or not card_effect_handler.course:
		return []
	
	var course = card_effect_handler.course
	var hit_targets = []
	var current_pos = weapon_pos
	var remaining_range = max_range
	
	# First raytrace - pierce through first object
	var first_ray_end = current_pos + direction * remaining_range
	var space_state = course.get_world_2d().direct_space_state
	var first_query = PhysicsRayQueryParameters2D.create(current_pos, first_ray_end)
	first_query.collision_mask = 2  # Collide with layer 2 (HitBoxes for weapons)
	first_query.collide_with_bodies = false
	first_query.collide_with_areas = true
	
	var first_result = space_state.intersect_ray(first_query)
	
	if first_result:
		# Bullet hit first object
		var first_hit_object = first_result.collider
		
		# Check if it's a HitBox Area2D
		if first_hit_object.name == "HitBox":
			var parent = first_hit_object.get_parent()
			
			# Check if parent has take_damage method (NPC, Player, etc.)
			if parent and parent.has_method("take_damage"):
				hit_targets.append(parent)
			
			# Check if parent is an oil drum
			elif parent and parent.get_script() and parent.get_script().resource_path.ends_with("oil_drum.gd"):
				hit_targets.append(parent)
		else:
			# Direct hit on object with take_damage method
			if first_hit_object.has_method("take_damage"):
				hit_targets.append(first_hit_object)
		
		# Calculate remaining range after first hit
		var first_hit_distance = current_pos.distance_to(first_result.position)
		remaining_range -= first_hit_distance
		current_pos = first_result.position
		
		# Second raytrace - stop on second object
		if remaining_range > 0:
			var second_ray_end = current_pos + direction * remaining_range
			var second_query = PhysicsRayQueryParameters2D.create(current_pos, second_ray_end)
			second_query.collision_mask = 2
			second_query.collide_with_bodies = false
			second_query.collide_with_areas = true
			
			var second_result = space_state.intersect_ray(second_query)
			
			if second_result:
				# Bullet hit second object
				var second_hit_object = second_result.collider
				
				# Check if it's a HitBox Area2D
				if second_hit_object.name == "HitBox":
					var parent = second_hit_object.get_parent()
					
					# Check if parent has take_damage method (NPC, Player, etc.)
					if parent and parent.has_method("take_damage"):
						hit_targets.append(parent)
					
					# Check if parent is an oil drum
					elif parent and parent.get_script() and parent.get_script().resource_path.ends_with("oil_drum.gd"):
						hit_targets.append(parent)
				else:
					# Direct hit on object with take_damage method
					if second_hit_object.has_method("take_damage"):
						hit_targets.append(second_hit_object)
	
	return hit_targets
