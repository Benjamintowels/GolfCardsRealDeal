extends Node
class_name WeaponHandler

# Weapon system variables
var is_weapon_mode := false
var selected_card: CardData = null
var active_button: TextureButton = null
var weapon_instance: Node2D = null

# References
var player_node: Node2D
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary
var camera: Camera2D

# Sound effects
var card_click_sound: AudioStreamPlayer2D
var card_play_sound: AudioStreamPlayer2D

# UI references
var card_stack_display: Control
var deck_manager: DeckManager

# Card effect handling
var card_effect_handler: Node

# Weapon properties
var weapon_damage := 50
var weapon_range := 1000.0  # Maximum shooting distance

# Weapon scene references
var pistol_scene = preload("res://Weapons/Pistol.tscn")
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
	card_effect_handler_ref: Node
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

# Reference to movement controller for button cleanup
var movement_controller: Node = null

func set_movement_controller(controller: Node) -> void:
	movement_controller = controller

func _on_weapon_card_pressed(card: CardData, button: TextureButton) -> void:
	if selected_card == card:
		return
	card_click_sound.play()
	
	print("Weapon card pressed:", card.name)
	
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
	print("Entering weapon aiming mode")
	
	# Create weapon instance
	create_weapon_instance()
	
	# Input is handled by the course's _input function

func create_weapon_instance() -> void:
	"""Create the weapon instance (pistol) in front of the player"""
	if weapon_instance:
		weapon_instance.queue_free()
	
	weapon_instance = pistol_scene.instantiate()
	player_node.add_child(weapon_instance)
	
	# Position the weapon in front of the player
	var weapon_offset = Vector2(30, 0)  # 30 pixels in front
	weapon_instance.position = weapon_offset
	
	print("Weapon instance created")

func handle_input(event: InputEvent) -> bool:
	"""Handle input events during weapon mode. Returns true if event was handled."""
	if not is_weapon_mode:
		return false
	
	if event is InputEventMouseMotion:
		update_weapon_rotation()
		return true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		fire_weapon()
		return true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		exit_weapon_mode()
		return true
	
	return false

func update_weapon_rotation() -> void:
	"""Update weapon rotation to follow mouse"""
	if not weapon_instance or not player_node or not camera:
		return
	
	var mouse_pos = camera.get_global_mouse_position()
	var player_pos = player_node.global_position
	var direction = (mouse_pos - player_pos).normalized()
	
	# Calculate angle to mouse
	var angle = atan2(direction.y, direction.x)
	weapon_instance.rotation = angle

func fire_weapon() -> void:
	"""Fire the weapon and perform raytrace"""
	if not weapon_instance or not player_node:
		return
	
	print("Firing weapon!")
	
	# Play weapon sound from player node
	var pistol_shot = player_node.get_node_or_null("PistolShot")
	if pistol_shot:
		pistol_shot.play()
		print("Pistol shot sound played")
	else:
		print("Warning: PistolShot sound not found on player node")
	
	# Perform raytrace
	var hit_target = perform_raytrace()
	
	if hit_target:
		# Deal damage to the target
		if hit_target.has_method("take_damage"):
			print("Dealing", weapon_damage, "damage to", hit_target.name)
			hit_target.take_damage(weapon_damage)
			emit_signal("npc_shot", hit_target, weapon_damage)
			print("Hit target for", weapon_damage, "damage!")
			
			# Check if the target died
			if hit_target.has_method("get_is_dead"):
				var is_dead = hit_target.get_is_dead()
				print("Target is dead:", is_dead)
			elif hit_target.has_method("is_dead"):
				var is_dead = hit_target.is_dead
				print("Target is dead:", is_dead)
		else:
			print("Target doesn't have take_damage method")
	else:
		print("No target hit")
	
	# Exit weapon mode after firing
	exit_weapon_mode()

func perform_raytrace() -> Node:
	"""Perform raytrace from player position towards mouse direction"""
	var player_pos = player_node.global_position
	var mouse_pos = camera.get_global_mouse_position()
	var direction = (mouse_pos - player_pos).normalized()
	
	# Simple approach: check for NPCs in the direction
	if not card_effect_handler or not card_effect_handler.course:
		return null
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		return null
	
	var npcs = entities.get_npcs()
	var closest_npc = null
	var closest_distance = weapon_range
	
	for npc in npcs:
		if is_instance_valid(npc) and npc.has_method("take_damage"):
			var npc_pos = npc.global_position
			var to_npc = npc_pos - player_pos
			var distance = to_npc.length()
			
			# Check if NPC is within range and in the general direction
			if distance <= weapon_range:
				var dot_product = to_npc.normalized().dot(direction)
				if dot_product > 0.7:  # Within ~45 degrees of aim direction
					if distance < closest_distance:
						closest_distance = distance
						closest_npc = npc
	
	if closest_npc:
		print("Raytrace hit NPC:", closest_npc.name)
		return closest_npc
	
	return null

func exit_weapon_mode() -> void:
	"""Exit weapon aiming mode"""
	print("Exiting weapon mode")
	
	is_weapon_mode = false
	
	# Remove weapon instance
	if weapon_instance:
		weapon_instance.queue_free()
		weapon_instance = null
	
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