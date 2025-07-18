extends Node
class_name AttackHandler

# Attack system variables
var is_attack_mode := false
var attack_range := 1
var valid_attack_tiles := []
var selected_card: CardData = null
var active_button: TextureButton = null
var attack_buttons := []
var attack_buttons_container: BoxContainer

# References
var player_node: Node2D
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary

# Sound effects
var card_click_sound: AudioStreamPlayer2D
var card_play_sound: AudioStreamPlayer2D
var kick_sound: AudioStreamPlayer2D  # Reference to KickSound from player scene
var punchb_sound: AudioStreamPlayer2D  # Reference to PunchB sound from player scene
var assassin_dash_sound: AudioStreamPlayer2D  # Reference to AssassinDash sound
var assassin_cut_sound: AudioStreamPlayer2D  # Reference to AssassinDash cut sound

# UI references
var card_stack_display: Control
var deck_manager: DeckManager
var card_row: Control  # Reference to the CardRow for animation

# Card effect handling
var card_effect_handler: Node

# CardRow animation variables
var card_row_original_position: Vector2
var card_row_animation_tween: Tween
var card_row_animation_duration: float = 0.3
var card_row_animation_offset: float = 100.0  # How far down to move the CardRow

# Attack properties
var attack_damage := 25
var knockback_distance := 1

# Ash dog attack properties
var ash_dog_damage := 50

# Signals
signal attack_mode_entered
signal attack_mode_exited
signal card_selected(card: CardData)
signal card_discarded(card: CardData)
signal npc_attacked(npc: Node, damage: int)
signal kick_attack_performed
signal punchb_attack_performed
signal ash_dog_attack_performed

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
	attack_buttons_container_ref: BoxContainer,
	card_click_sound_ref: AudioStreamPlayer2D,
	card_play_sound_ref: AudioStreamPlayer2D,
	card_stack_display_ref: Control,
	deck_manager_ref: DeckManager,
	card_effect_handler_ref: Node,
	kick_sound_ref: AudioStreamPlayer2D = null,
	punchb_sound_ref: AudioStreamPlayer2D = null,
	assassin_dash_sound_ref: AudioStreamPlayer2D = null,
	assassin_cut_sound_ref: AudioStreamPlayer2D = null,
	card_row_ref: Control = null
):
	player_node = player_node_ref
	grid_tiles = grid_tiles_ref
	grid_size = grid_size_ref
	cell_size = cell_size_ref
	obstacle_map = obstacle_map_ref
	player_grid_pos = player_grid_pos_ref
	player_stats = player_stats_ref
	attack_buttons_container = attack_buttons_container_ref
	card_click_sound = card_click_sound_ref
	card_play_sound = card_play_sound_ref
	card_stack_display = card_stack_display_ref
	deck_manager = deck_manager_ref
	card_effect_handler = card_effect_handler_ref
	kick_sound = kick_sound_ref
	punchb_sound = punchb_sound_ref
	assassin_dash_sound = assassin_dash_sound_ref
	assassin_cut_sound = assassin_cut_sound_ref
	card_row = card_row_ref
	
	# Store the original position of the CardRow for animation
	if card_row:
		card_row_original_position = card_row.position

# Reference to movement controller for button cleanup
var movement_controller: Node = null

func set_movement_controller(controller: Node) -> void:
	movement_controller = controller

func create_attack_buttons() -> void:
	# Attack cards are now handled by the movement controller
	# This function is kept for compatibility but doesn't create separate buttons
	pass

func _on_attack_card_pressed(card: CardData, button: TextureButton) -> void:
	print("=== ATTACK CARD PRESSED ===")
	print("Card:", card.name, "Effect type:", card.effect_type)
	print("Card in hand:", deck_manager.hand.has(card))
	print("Attack handler setup check - card_effect_handler:", card_effect_handler != null)
	print("Attack handler setup check - deck_manager:", deck_manager != null)
	
	if selected_card == card:
		print("Card already selected, returning")
		return
	card_click_sound.play()
	hide_all_attack_highlights()
	valid_attack_tiles.clear()

	is_attack_mode = true
	active_button = button
	selected_card = card
	attack_range = card.get_effective_strength()
	print("Attack range set to:", attack_range)

	calculate_valid_attack_tiles()
	show_attack_highlights()
	
	emit_signal("attack_mode_entered")
	emit_signal("card_selected", card)
	print("=== END ATTACK CARD PRESSED ===")

func _on_aoe_attack_card_pressed(card: CardData, button: TextureButton) -> void:
	print("=== AOE ATTACK CARD PRESSED ===")
	print("Card:", card.name, "Effect type:", card.effect_type)
	print("Card in hand:", deck_manager.hand.has(card))
	print("Attack handler setup check - card_effect_handler:", card_effect_handler != null)
	print("Attack handler setup check - deck_manager:", deck_manager != null)
	
	if selected_card == card:
		print("Card already selected, returning")
		return
	card_click_sound.play()
	hide_all_attack_highlights()
	valid_attack_tiles.clear()

	is_attack_mode = true
	active_button = button
	selected_card = card
	attack_range = card.get_effective_strength()
	print("AOE attack range set to:", attack_range)

	calculate_valid_aoe_attack_tiles()
	show_attack_highlights()
	
	emit_signal("attack_mode_entered")
	emit_signal("card_selected", card)
	print("=== END AOE ATTACK CARD PRESSED ===")

func calculate_valid_attack_tiles() -> void:
	valid_attack_tiles.clear()
	print("=== CALCULATING VALID ATTACK TILES ===")
	print("Player position:", player_grid_pos, "Attack range:", attack_range)
	print("Selected card:", selected_card.name if selected_card else "None")

	# Special case for Kick card - show all adjacent tiles regardless of content
	if selected_card and selected_card.name == "Kick":
		print("Kick card detected - showing all adjacent tiles")
		for y in grid_size.y:
			for x in grid_size.x:
				var pos := Vector2i(x, y)
				if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
					valid_attack_tiles.append(pos)
					print("Added adjacent tile for Kick card at:", pos)
		print("Total adjacent tiles for Kick card:", valid_attack_tiles.size())
		return

	# Special case for Punch card - show all tiles in cross pattern regardless of content
	if selected_card and selected_card.name == "Punch":
		print("Punch card detected - showing all tiles in cross pattern")
		var cross_positions = []
		
		# Add positions in cross pattern: up, down, left, right (no diagonals)
		for distance in range(1, attack_range + 1):
			# Up
			var up_pos = Vector2i(player_grid_pos.x, player_grid_pos.y - distance)
			if up_pos.y >= 0:
				cross_positions.append(up_pos)
			
			# Down
			var down_pos = Vector2i(player_grid_pos.x, player_grid_pos.y + distance)
			if down_pos.y < grid_size.y:
				cross_positions.append(down_pos)
			
			# Left
			var left_pos = Vector2i(player_grid_pos.x - distance, player_grid_pos.y)
			if left_pos.x >= 0:
				cross_positions.append(left_pos)
			
			# Right
			var right_pos = Vector2i(player_grid_pos.x + distance, player_grid_pos.y)
			if right_pos.x < grid_size.x:
				cross_positions.append(right_pos)
		
		# Add all cross positions to valid attack tiles (regardless of content)
		for pos in cross_positions:
			valid_attack_tiles.append(pos)
			print("Added cross pattern tile for Punch card at:", pos)
		
		print("Total cross pattern tiles for Punch card:", valid_attack_tiles.size())
		return

	# Special case for PunchB card - show all tiles in cross pattern regardless of content
	if selected_card and selected_card.name == "PunchB":
		print("PunchB card detected - showing all tiles in cross pattern")
		var cross_positions = []
		
		# Add positions in cross pattern: up, down, left, right (no diagonals)
		for distance in range(1, attack_range + 1):
			# Up
			var up_pos = Vector2i(player_grid_pos.x, player_grid_pos.y - distance)
			if up_pos.y >= 0:
				cross_positions.append(up_pos)
			
			# Down
			var down_pos = Vector2i(player_grid_pos.x, player_grid_pos.y + distance)
			if down_pos.y < grid_size.y:
				cross_positions.append(down_pos)
			
			# Left
			var left_pos = Vector2i(player_grid_pos.x - distance, player_grid_pos.y)
			if left_pos.x >= 0:
				cross_positions.append(left_pos)
			
			# Right
			var right_pos = Vector2i(player_grid_pos.x + distance, player_grid_pos.y)
			if right_pos.x < grid_size.x:
				cross_positions.append(right_pos)
		
		# Add all cross positions to valid attack tiles (regardless of content)
		for pos in cross_positions:
			valid_attack_tiles.append(pos)
			print("Added cross pattern tile for PunchB card at:", pos)
		
		print("Total cross pattern tiles for PunchB card:", valid_attack_tiles.size())
		return

	# Special case for AttackDog card - show all tiles within range regardless of content
	if selected_card and selected_card.name == "AttackDog":
		print("AttackDog card detected - showing all tiles within range")
		for y in grid_size.y:
			for x in grid_size.x:
				var pos := Vector2i(x, y)
				if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
					valid_attack_tiles.append(pos)
					print("Added tile for AttackDog card at:", pos)
		print("Total tiles for AttackDog card:", valid_attack_tiles.size())
		return

	# Special case for AssassinDash card - show cross pattern but only if tile behind enemy is available
	if selected_card and selected_card.name == "AssassinDash":
		print("AssassinDash card detected - showing cross pattern with behind-enemy validation")
		
		var cross_positions = []
		
		# Add positions in cross pattern: up, down, left, right (no diagonals)
		for distance in range(1, attack_range + 1):
			# Up
			var up_pos = Vector2i(player_grid_pos.x, player_grid_pos.y - distance)
			if up_pos.y >= 0:
				cross_positions.append(up_pos)
			
			# Down
			var down_pos = Vector2i(player_grid_pos.x, player_grid_pos.y + distance)
			if down_pos.y < grid_size.y:
				cross_positions.append(down_pos)
			
			# Left
			var left_pos = Vector2i(player_grid_pos.x - distance, player_grid_pos.y)
			if left_pos.x >= 0:
				cross_positions.append(left_pos)
			
			# Right
			var right_pos = Vector2i(player_grid_pos.x + distance, player_grid_pos.y)
			if right_pos.x < grid_size.x:
				cross_positions.append(right_pos)
		
		# Check each cross position for NPCs and validate behind-enemy tiles
		for pos in cross_positions:
			if has_npc_at_position(pos):
				# Calculate the position behind the enemy (opposite direction from player)
				var direction = pos - player_grid_pos
				var behind_enemy_pos = pos + direction
				
				# Check if the tile behind the enemy is available
				if is_position_valid_for_assassin_dash(behind_enemy_pos):
					valid_attack_tiles.append(pos)
					print("Added AssassinDash target at:", pos, "with valid behind-enemy tile at:", behind_enemy_pos)
				else:
					print("Skipped AssassinDash target at:", pos, "- behind-enemy tile not available at:", behind_enemy_pos)
		
		print("Total valid AssassinDash targets:", valid_attack_tiles.size())
		return

	# DEBUG: Print all oil drum grid positions
	var interactables = get_tree().get_nodes_in_group("interactables")
	print("Found", interactables.size(), "interactables in group")
	for interactable in interactables:
		if is_instance_valid(interactable) and interactable.has_method("get_grid_position") and interactable.name.begins_with("OilDrum"):
			print("OIL DRUM DEBUG: Oil drum '", interactable.name, "' at grid position:", interactable.get_grid_position())

	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)

			if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
				# Check if there's an NPC at this position
				if has_npc_at_position(pos):
					valid_attack_tiles.append(pos)
					print("Found valid attack tile at:", pos)
				# Check if there's an oil drum at this position (for KickB card)
				elif has_oil_drum_at_position(pos):
					valid_attack_tiles.append(pos)
					print("Found oil drum at attack tile:", pos)
	
	print("Total valid attack tiles found:", valid_attack_tiles.size())
	print("=== END CALCULATING VALID ATTACK TILES ===")

func calculate_valid_aoe_attack_tiles() -> void:
	valid_attack_tiles.clear()
	print("Calculating valid AOE attack tiles - Player at:", player_grid_pos, "AOE attack range:", attack_range)

	# Special case for Meteor card - show all tiles within range for 3x2 placement
	if selected_card and selected_card.name == "Meteor":
		print("Meteor card detected - showing all tiles within range for 3x2 placement")
		for y in grid_size.y:
			for x in grid_size.x:
				var pos := Vector2i(x, y)
				if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
					# Check if this position can be the top-left corner of a 3x2 area
					if can_place_3x2_area_at_position(pos):
						valid_attack_tiles.append(pos)
						print("Added valid 3x2 placement position for Meteor at:", pos)
		print("Total valid 3x2 placement positions for Meteor:", valid_attack_tiles.size())
		return

	print("Total valid AOE attack tiles found:", valid_attack_tiles.size())

func can_place_3x2_area_at_position(top_left_pos: Vector2i) -> bool:
	"""Check if a 3x2 area can be placed with the given position as top-left corner"""
	# Check if all 6 tiles in the 3x2 area are within grid bounds
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var check_pos = top_left_pos + Vector2i(x_offset, y_offset)
			if check_pos.x >= grid_size.x or check_pos.y >= grid_size.y:
				return false
	return true

func find_valid_3x2_target_position(clicked_pos: Vector2i) -> Vector2i:
	"""Find the top-left position of a valid 3x2 area that contains the clicked position"""
	# Check all possible 3x2 areas that could contain the clicked position
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var top_left_pos = clicked_pos - Vector2i(x_offset, y_offset)
			
			# Check if this top-left position is in our valid tiles list
			if top_left_pos in valid_attack_tiles:
				print("Found valid 3x2 area with top-left at:", top_left_pos, "containing clicked position:", clicked_pos)
				return top_left_pos
	
	# If no valid 3x2 area found, return invalid position
	return Vector2i(-1, -1)

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func has_npc_at_position(pos: Vector2i) -> bool:
	"""Check if there's an NPC at the given grid position"""
	if not card_effect_handler or not card_effect_handler.course:
		print("No card_effect_handler or course found for NPC check at:", pos)
		return false
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("No Entities found for NPC check at:", pos)
		return false
	
	var npcs = entities.get_npcs()
	print("=== NPC DETECTION DEBUG ===")
	print("Checking for NPC at position:", pos)
	print("Total NPCs in Entities:", npcs.size())
	
	for npc in npcs:
		if is_instance_valid(npc):
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("NPC:", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("NPC:", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("NPC:", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("NPC:", npc.name, "at position:", npc_pos, "(calculated from world position)")
			
			if npc_pos == pos:
				print("✓ Found NPC at position:", pos, "NPC:", npc.name)
				return true
		else:
			print("✗ Invalid NPC reference:", npc)
	
	print("✗ No NPC found at position:", pos)
	print("=== END NPC DETECTION DEBUG ===")
	return false

func get_npc_at_position(pos: Vector2i) -> Node:
	"""Get the NPC at the given grid position, or null if none"""
	print("=== GETTING NPC AT POSITION ===")
	print("Position:", pos)
	print("Card effect handler:", card_effect_handler != null)
	
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ No card_effect_handler or course found")
		return null
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("✗ No Entities node found")
		return null
	
	print("✓ Entities found")
	var npcs = entities.get_npcs()
	print("Total NPCs found:", npcs.size())
	
	for npc in npcs:
		print("=== CHECKING NPC ===")
		print("NPC reference:", npc)
		print("Is instance valid:", is_instance_valid(npc))
		
		if is_instance_valid(npc):
			print("NPC name:", npc.name)
			print("NPC class:", npc.get_class())
			print("NPC script:", npc.get_script().resource_path if npc.get_script() else "No script")
			print("NPC global position:", npc.global_position)
			
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(calculated from world position)")
			
			if npc_pos == pos:
				print("✓ Found NPC at position:", pos, "NPC:", npc.name)
				return npc
		else:
			print("✗ NPC is invalid - reference:", npc)
			if npc != null:
				print("  - NPC name (if available):", npc.name if "name" in npc else "No name property")
				print("  - NPC class (if available):", npc.get_class() if "get_class" in npc else "No get_class method")
		
		print("=== END CHECKING NPC ===")
	
	print("✗ No NPC found at position:", pos)
	return null

func show_attack_highlights() -> void:
	hide_all_attack_highlights()
	print("=== SHOWING ATTACK HIGHLIGHTS ===")
	print("Valid attack tiles count:", valid_attack_tiles.size())
	print("Player position:", player_grid_pos)
	
	for pos in valid_attack_tiles:
		grid_tiles[pos.y][pos.x].get_node("AttackHighlight").visible = true
		print("Made attack highlight visible for tile at", pos)
	
	print("=== END SHOWING ATTACK HIGHLIGHTS ===")
	
	# Animate CardRow down to get out of the way of range display
	animate_card_row_down()
	
	# Zoom out camera for Meteor card to show the full attack range
	if selected_card and selected_card.name == "Meteor":
		zoom_out_camera_for_meteor_range()

func hide_all_attack_highlights() -> void:
	print("=== HIDING ALL ATTACK HIGHLIGHTS ===")
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("AttackHighlight").visible = false
	print("=== END HIDING ALL ATTACK HIGHLIGHTS ===")

func animate_card_row_down() -> void:
	"""Animate the CardRow downwards to get out of the way of range display"""
	if not card_row:
		return
	
	# Stop any existing animation
	if card_row_animation_tween and card_row_animation_tween.is_valid():
		card_row_animation_tween.kill()
	
	# Create new tween for smooth animation
	card_row_animation_tween = create_tween()
	card_row_animation_tween.set_trans(Tween.TRANS_QUAD)
	card_row_animation_tween.set_ease(Tween.EASE_OUT)
	
	# Animate to the offset position
	var target_position = card_row_original_position + Vector2(0, card_row_animation_offset)
	card_row_animation_tween.tween_property(card_row, "position", target_position, card_row_animation_duration)
	
	print("AttackHandler: Animating CardRow down by", card_row_animation_offset, "pixels")

func animate_card_row_up() -> void:
	"""Animate the CardRow back to its original position"""
	if not card_row:
		return
	
	# Stop any existing animation
	if card_row_animation_tween and card_row_animation_tween.is_valid():
		card_row_animation_tween.kill()
	
	# Create new tween for smooth animation
	card_row_animation_tween = create_tween()
	card_row_animation_tween.set_trans(Tween.TRANS_QUAD)
	card_row_animation_tween.set_ease(Tween.EASE_OUT)
	
	# Animate back to the original position
	card_row_animation_tween.tween_property(card_row, "position", card_row_original_position, card_row_animation_duration)
	
	print("AttackHandler: Animating CardRow back to original position")

func zoom_out_camera_for_meteor_range() -> void:
	"""Zoom out the camera to show the full meteor attack range"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for meteor camera zoom")
		return
	
	var course = card_effect_handler.course
	if not course.camera or not course.camera.has_method("set_zoom_level"):
		print("✗ ERROR: Course camera not available for meteor zoom")
		return
	
	print("=== ZOOMING OUT CAMERA FOR METEOR RANGE ===")
	
	# Store current zoom to restore later
	if not course.has_meta("pre_meteor_zoom"):
		course.set_meta("pre_meteor_zoom", course.camera.get_current_zoom())
		print("✓ Stored pre-meteor zoom level:", course.get_meta("pre_meteor_zoom"))
	
	# Zoom out to show the full 10-tile range
	var meteor_zoom = 0.4  # Zoom out to 40% to show more of the map
	course.camera.set_zoom_level(meteor_zoom)
	print("✓ Camera zoomed out for meteor range to", meteor_zoom)
	
	# Center camera on player to show range around them
	if course.has_method("create_camera_tween"):
		var player_pos = Vector2.ZERO
		if course.player_node:
			var sprite = course.player_node.get_node_or_null("Sprite2D")
			var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(48, 48)
			player_pos = course.player_node.global_position + player_size / 2
		
		course.create_camera_tween(player_pos, 0.8)
		print("✓ Camera centered on player for meteor range display")

func restore_camera_zoom_after_meteor() -> void:
	"""Restore camera zoom to previous level after meteor range display"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for meteor camera zoom restoration")
		return
	
	var course = card_effect_handler.course
	if not course.camera or not course.camera.has_method("set_zoom_level"):
		print("✗ ERROR: Course camera not available for meteor zoom restoration")
		return
	
	# Check if we stored a pre-meteor zoom level
	if course.has_meta("pre_meteor_zoom"):
		var pre_zoom = course.get_meta("pre_meteor_zoom")
		print("=== RESTORING CAMERA ZOOM AFTER METEOR ===")
		print("Restoring zoom from", course.camera.get_current_zoom(), "to", pre_zoom)
		
		# Create a smooth zoom tween back to original level
		var zoom_tween = get_tree().create_tween()
		zoom_tween.set_trans(Tween.TRANS_SINE)
		zoom_tween.set_ease(Tween.EASE_IN_OUT)
		zoom_tween.tween_method(func(zoom_level: float):
			course.camera.set_zoom_level(zoom_level)
		, course.camera.get_current_zoom(), pre_zoom, 0.8)
		
		# Clean up the stored zoom level
		course.remove_meta("pre_meteor_zoom")
		print("✓ Camera zoom restored to", pre_zoom)
	else:
		print("No pre-meteor zoom level stored - skipping restoration")

func exit_attack_mode() -> void:
	print("=== EXITING ATTACK MODE ===")
	
	# Restore camera zoom if it was changed for meteor range
	restore_camera_zoom_after_meteor()
	
	print("Selected card:", selected_card.name if selected_card else "None")
	print("Card in hand:", deck_manager.hand.has(selected_card) if selected_card else "N/A")
	print("Hand contents:", deck_manager.hand.map(func(c): return c.name))
	is_attack_mode = false
	hide_all_attack_highlights()
	valid_attack_tiles.clear()
	# Animate CardRow back to original position
	animate_card_row_up()
	if selected_card:
		print("AttackHandler: Exiting attack mode with card:", selected_card.name)
		print("AttackHandler: Card in hand:", deck_manager.hand.has(selected_card))
		if deck_manager.hand.has(selected_card):
			print("AttackHandler: Discarding attack card from hand:", selected_card.name)
			deck_manager.discard(selected_card)
			card_stack_display.animate_card_discard(selected_card.name)
			emit_signal("card_discarded", selected_card)
		else:
			print("AttackHandler: Card not in hand:", selected_card.name)
	print("=== END EXITING ATTACK MODE ===")
	# Clean up the button directly
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
	selected_card = null
	emit_signal("attack_mode_exited")

func handle_tile_click(x: int, y: int) -> bool:
	"""Handle tile click and return true if attack was successful"""
	var clicked := Vector2i(x, y)
	print("Attack tile click at:", clicked, "Attack mode:", is_attack_mode, "Valid tiles:", valid_attack_tiles)
	
	# Special handling for Meteor card - check if clicked position is within any valid 3x2 area
	if is_attack_mode and selected_card and selected_card.name == "Meteor":
		print("Meteor card detected - checking if clicked position is within valid 3x2 area")
		var target_pos = find_valid_3x2_target_position(clicked)
		if target_pos != Vector2i(-1, -1):
			print("✓ Valid 3x2 target found at:", target_pos, "for clicked position:", clicked)
			perform_meteor_attack(target_pos)
			card_play_sound.play()
			return true
		else:
			print("✗ Clicked position not within any valid 3x2 area:", clicked)
			return false
	
	if is_attack_mode and clicked in valid_attack_tiles:
		print("=== ATTACK TILE CLICK DEBUG ===")
		print("Selected card:", selected_card.name if selected_card else "None")
		print("Card name check:", selected_card.name == "Kick" if selected_card else "N/A")
		
		# Check if this is a KickB card attack on an oil drum
		if selected_card and selected_card.name == "Kick":
			print("Kick card detected - checking for oil drum at:", clicked)
			var oil_drum = get_oil_drum_at_position(clicked)
			if oil_drum:
				print("✓ Oil drum found - performing KickB attack!")
				perform_kickb_attack_on_oil_drum(oil_drum, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No oil drum found at position:", clicked)
		
		# Check if this is a PunchB card attack
		if selected_card and selected_card.name == "PunchB":
			print("PunchB card detected - checking for target at:", clicked)
			var npc = get_npc_at_position(clicked)
			var oil_drum = get_oil_drum_at_position(clicked)
			
			if npc:
				print("✓ NPC found - performing PunchB attack!")
				perform_punchb_attack_on_npc(npc, clicked)
				card_play_sound.play()
				return true
			elif oil_drum:
				print("✓ Oil drum found - performing PunchB attack!")
				perform_punchb_attack_on_oil_drum(oil_drum, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No valid target found at position:", clicked)
				return false
		
		# Check if this is an AttackDog card attack
		if selected_card and selected_card.name == "AttackDog":
			print("AttackDog card detected - checking for target at:", clicked)
			var npc = get_npc_at_position(clicked)
			
			if npc:
				print("✓ NPC found - performing AttackDog attack!")
				perform_attackdog_attack_on_npc(npc, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No NPC found at position:", clicked)
				return false

		# Check if this is an AssassinDash card attack
		if selected_card and selected_card.name == "AssassinDash":
			print("AssassinDash card detected - checking for target at:", clicked)
			var npc = get_npc_at_position(clicked)
			
			if npc:
				print("✓ NPC found - performing AssassinDash attack!")
				perform_assassin_dash_attack_on_npc(npc, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No NPC found at position:", clicked)
				return false
		

		
		# Check for normal NPC attack
		var npc = get_npc_at_position(clicked)
		if npc:
			print("Performing attack on NPC at:", clicked)
			perform_attack(npc, clicked)
			card_play_sound.play()
			return true
		else:
			print("No NPC found at attack position:", clicked)
			return false
	else:
		print("Invalid attack tile or not in attack mode - Clicked:", clicked, "Valid tiles:", valid_attack_tiles, "Attack mode:", is_attack_mode)
		return false

func perform_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Perform the attack on the NPC"""
	
	# Play KickSound if this is a Kick attack
	if selected_card and selected_card.name == "Kick":
		if kick_sound:
			kick_sound.play()
		
		# Emit kick attack signal for animation
		emit_signal("kick_attack_performed")
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("Attacking dead NPC - pushing corpse")
		# Don't deal damage to dead NPCs, just push them
		attack_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(attack_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, attack_damage)
	
	# Exit attack mode
	exit_attack_mode()

func apply_knockback(npc: Node, current_pos: Vector2i) -> void:
	"""Apply knockback to the NPC, pushing them 1 tile away from the player"""
	
	# Calculate direction from player to NPC
	var direction = current_pos - player_grid_pos
	# For grid-based movement, we need to handle direction differently
	var knockback_pos = current_pos
	
	# Check if this is a GangMember and if it's frozen
	var actual_knockback_distance = knockback_distance
	if npc.has_method("is_frozen_state") and npc.is_frozen_state():
		actual_knockback_distance = knockback_distance * 3
		print("GangMember is frozen - applying triple knockback distance:", actual_knockback_distance)
	
	if direction.x > 0:
		knockback_pos.x += actual_knockback_distance
	elif direction.x < 0:
		knockback_pos.x -= actual_knockback_distance
	elif direction.y > 0:
		knockback_pos.y += actual_knockback_distance
	elif direction.y < 0:
		knockback_pos.y -= actual_knockback_distance
	
	# Check if knockback position is valid
	if is_position_valid_for_knockback(knockback_pos):
		# Use animated pushback if the NPC supports it
		if npc.has_method("push_back"):
			npc.push_back(knockback_pos)
			print("Applied animated pushback to NPC (distance:", actual_knockback_distance, ")")
		else:
			# Fallback to instant position change
			npc.set_grid_position(knockback_pos)
			
			# Update Y-sorting
			if npc.has_method("update_z_index_for_ysort"):
				npc.update_z_index_for_ysort()
			print("Applied instant pushback to NPC (distance:", actual_knockback_distance, ", no animation support)")

func is_position_valid_for_assassin_dash(pos: Vector2i) -> bool:
	"""Check if a position is valid for AssassinDash behind-enemy movement"""
	var is_valid = true
	
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x >= grid_size.x or pos.y >= grid_size.y:
		is_valid = false
	
	# Check if the position is occupied by an obstacle
	elif obstacle_map.has(pos):
		var obstacle = obstacle_map[pos]
		if obstacle.has_method("blocks") and obstacle.blocks():
			is_valid = false
	
	# Check if the position is occupied by another NPC
	elif card_effect_handler and card_effect_handler.course:
		var entities = card_effect_handler.course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("get_grid_position"):
					if npc.get_grid_position() == pos:
						is_valid = false
						break
	
	# Check if the position is occupied by the player
	elif pos == player_grid_pos:
		is_valid = false
	
	return is_valid

func is_position_valid_for_knockback(pos: Vector2i) -> bool:
	"""Check if a position is valid for NPC knockback"""
	var is_valid = true
	
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		is_valid = false
	
	# Check if the position is occupied by an obstacle
	elif obstacle_map.has(pos):
		var obstacle = obstacle_map[pos]
		if obstacle.has_method("blocks") and obstacle.blocks():
			is_valid = false
	
	# Check if the position is occupied by another NPC
	elif card_effect_handler and card_effect_handler.course:
		var entities = card_effect_handler.course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("get_grid_position"):
					if npc.get_grid_position() == pos:
						is_valid = false
						break
	
	# Check if the position is occupied by the player
	elif pos == player_grid_pos:
		is_valid = false
	
	return is_valid

func handle_tile_mouse_entered(x: int, y: int, is_panning: bool) -> void:
	if not is_panning and is_attack_mode:
		# Get tile from grid manager for proper access
		var tile: Control = null
		if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_method("get_grid_manager"):
			var grid_manager = card_effect_handler.course.get_grid_manager()
			if grid_manager and grid_manager.has_method("get_grid_tile"):
				tile = grid_manager.get_grid_tile(x, y)
		
		# Fallback to direct array access
		if not tile and y < grid_tiles.size() and x < grid_tiles[y].size():
			tile = grid_tiles[y][x]
		
		if tile:
			var clicked := Vector2i(x, y)
			
			if not Vector2i(x, y) in valid_attack_tiles:
				var highlight = tile.get_node_or_null("Highlight")
				if highlight:
					highlight.visible = true

func handle_tile_mouse_exited(x: int, y: int, is_panning: bool) -> void:
	if not is_panning:
		# Get tile from grid manager for proper access
		var tile = null
		if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_method("get_grid_manager"):
			var grid_manager = card_effect_handler.course.get_grid_manager()
			if grid_manager and grid_manager.has_method("get_grid_tile"):
				tile = grid_manager.get_grid_tile(x, y)
		
		# Fallback to direct array access
		if not tile and y < grid_tiles.size() and x < grid_tiles[y].size():
			tile = grid_tiles[y][x]
		
		if tile:
			var highlight = tile.get_node_or_null("Highlight")
			if highlight:
				highlight.visible = false

func clear_all_attack_ui() -> void:
	"""Clear all attack-related UI elements"""
	hide_all_attack_highlights()
	selected_card = null
	active_button = null
	is_attack_mode = false

func get_attack_cards_for_inventory() -> Array[CardData]:
	"""Get all attack cards from the current hand"""
	return deck_manager.hand.filter(func(card): return card.effect_type == "Attack")

func _debug_list_all_npcs() -> void:
	"""Debug function to list all NPCs and their positions"""
	print("=== DEBUG: LISTING ALL NPCs ===")
	
	if not card_effect_handler or not card_effect_handler.course:
		print("No card_effect_handler or course found")
		return
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("No Entities found")
		return
	
	var npcs = entities.get_npcs()
	print("Total NPCs in Entities:", npcs.size())
	
	for i in range(npcs.size()):
		var npc = npcs[i]
		if is_instance_valid(npc):
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(calculated from world position)")
		else:
			print("NPC", i, ": Invalid NPC reference:", npc)
	
	print("=== END DEBUG: LISTING ALL NPCs ===")

func update_player_position(new_grid_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	print("=== ATTACK HANDLER: UPDATING PLAYER POSITION ===")
	print("Old position:", player_grid_pos, "New position:", new_grid_pos)
	print("Attack mode:", is_attack_mode)
	
	player_grid_pos = new_grid_pos
	
	# If we're in attack mode, recalculate valid attack tiles with the new position
	if is_attack_mode:
		print("Recalculating attack tiles due to player movement")
		calculate_valid_attack_tiles()
		show_attack_highlights()
		print("Attack tiles updated - new count:", valid_attack_tiles.size())
	else:
		print("Not in attack mode, skipping attack tile recalculation")
	
	print("=== END ATTACK HANDLER: UPDATING PLAYER POSITION ===")

func is_in_attack_mode() -> bool:
	return is_attack_mode

func get_selected_card() -> CardData:
	return selected_card

func get_valid_attack_tiles() -> Array:
	return valid_attack_tiles.duplicate()

func has_oil_drum_at_position(pos: Vector2i) -> bool:
	"""Check if there's an oil drum at the given grid position"""
	if not card_effect_handler or not card_effect_handler.course:
		print("No card_effect_handler or course found for oil drum check at:", pos)
		return false
	
	# Look for oil drums in the interactables group
	var interactables = get_tree().get_nodes_in_group("interactables")
	
	for interactable in interactables:
		if is_instance_valid(interactable) and interactable.has_method("get_grid_position"):
			var interactable_pos = interactable.get_grid_position()
			if interactable_pos == pos and interactable.name.begins_with("OilDrum"):
				print("Found oil drum at position:", pos, "Oil drum:", interactable.name)
				return true
	
	print("No oil drum found at position:", pos)
	return false

func get_oil_drum_at_position(pos: Vector2i) -> Node:
	"""Get the oil drum at the given grid position, or null if none"""
	# Look for oil drums in the interactables group
	var interactables = get_tree().get_nodes_in_group("interactables")
	for interactable in interactables:
		if is_instance_valid(interactable) and interactable.has_method("get_grid_position"):
			if interactable.get_grid_position() == pos and interactable.name.begins_with("OilDrum"):
				return interactable
	
	return null

func perform_kickb_attack_on_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform KickB attack on oil drum - tips it over immediately"""
	print("=== PERFORMING KICKB ATTACK ON OIL DRUM ===")
	print("Oil drum:", oil_drum.name)
	print("Target position:", target_pos)
	print("Oil drum has take_damage method:", oil_drum.has_method("take_damage"))
	
	# Play KickSound
	if kick_sound:
		kick_sound.play()
	
	# Emit kick attack signal for animation
	emit_signal("kick_attack_performed")
	
	# Check if oil drum is already tipped over
	var is_tipped = false
	if oil_drum.has_method("get_is_tipped_over"):
		is_tipped = oil_drum.get_is_tipped_over()
		print("Oil drum tipped over status:", is_tipped)
	elif "is_tipped_over" in oil_drum:
		is_tipped = oil_drum.is_tipped_over
		print("Oil drum tipped over status (property):", is_tipped)
	
	if is_tipped:
		print("Oil drum is already tipped over - no effect")
	else:
		print("Tipping over oil drum with KickB attack!")
		# Force the oil drum to tip over by setting its health to 0
		if oil_drum.has_method("take_damage"):
			print("Calling take_damage(50) on oil drum")
			# Deal enough damage to kill it (50 damage)
			oil_drum.take_damage(50)
		else:
			print("Oil drum doesn't have take_damage method!")
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", oil_drum, 50)  # Use 50 damage for signal
	
	# Exit attack mode
	exit_attack_mode()
	
	print("=== END KICKB ATTACK ON OIL DRUM ===") 

func perform_attackdog_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AttackDog attack on NPC with Ash dog animation"""
	print("=== PERFORMING ATTACKDOG ATTACK ON NPC ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Emit ash dog attack signal for animation
	emit_signal("ash_dog_attack_performed")
	
	# Create and animate Ash dog
	create_and_animate_ash_dog(npc, target_pos)

func create_and_animate_ash_dog(npc: Node, target_pos: Vector2i) -> void:
	"""Create Ash dog and animate it to attack the target"""
	# Load Ash scene
	var ash_scene = preload("res://NPC/Animals/Ash/Ash.tscn")
	if not ash_scene:
		print("Error: Failed to load Ash scene")
		complete_attackdog_attack(npc, target_pos)
		return
	
	var ash = ash_scene.instantiate()
	if not ash:
		print("Error: Failed to instantiate Ash")
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Add Ash as child of the player character (BennyChar, LaylaChar, etc.)
	var character_node = null
	if player_node:
		# Find the character node (BennyChar, LaylaChar, etc.)
		for child in player_node.get_children():
			if child.name.ends_with("Char"):
				character_node = child
				break
		
		if character_node:
			character_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of", character_node.name, "at position:", ash.global_position)
		else:
			# Fallback: add to player node directly
			player_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of player node at position:", ash.global_position)
	else:
		print("Error: No player node found")
		ash.queue_free()
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Play Ash bark sound
	var ash_bark = ash.get_node_or_null("AshBark")
	if ash_bark:
		ash_bark.play()
		print("Playing Ash bark sound")
	
	# Get target world position
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	if card_effect_handler and card_effect_handler.course:
		target_world_pos += card_effect_handler.course.camera_container.global_position
	
	# Calculate direction for sprite orientation
	var direction = target_world_pos - ash.global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	var is_up = direction.y < 0
	
	# Set up Ash sprites
	var default_sprite = ash.get_node_or_null("AshDefaultSprite")
	var attack_sprite = ash.get_node_or_null("AshAttackSprite")
	
	if not default_sprite or not attack_sprite:
		print("Error: Ash sprites not found")
		ash.queue_free()
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Hide default sprite, show attack sprite
	default_sprite.visible = false
	attack_sprite.visible = true
	
	# Set appropriate attack sprite based on direction
	if is_horizontal:
		# Use AshAttackLeftRight for horizontal movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = direction.x < 0  # Flip if moving left
	else:
		# Use AshAttackUp for vertical movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackUp.png")
		attack_sprite.flip_h = false  # No flip for vertical
	
	print("Ash dog attacking in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", attack_sprite.flip_h)
	
	# Animate Ash to target position
	var tween = create_tween()
	tween.tween_property(ash, "global_position", target_world_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		# Flash effect at target
		create_flash_effect(target_world_pos)
		
		# Switch to default sprite
		attack_sprite.visible = false
		default_sprite.visible = true
		
		# Set appropriate default sprite based on direction
		if is_horizontal:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = direction.x < 0  # Flip if moving left
		else:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultUp.png")
			default_sprite.flip_h = false  # No flip for vertical
		
		# Flip the sprite to face the opposite direction for return journey
		if is_horizontal:
			default_sprite.flip_h = direction.x >= 0  # Flip to face opposite direction
		# For vertical movement, we don't need to flip since it's the same sprite
		
		# Animate back to player
		var return_tween = create_tween()
		return_tween.tween_property(ash, "global_position", player_node.global_position, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return_tween.tween_callback(func():
			# Remove Ash and complete attack
			ash.queue_free()
			complete_attackdog_attack(npc, target_pos)
		)
	)

func create_flash_effect(position: Vector2) -> void:
	"""Create a flash effect at the specified position"""
	# Create a simple flash effect using a ColorRect
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.size = Vector2(48, 48)  # Same size as a tile
	flash.global_position = position - flash.size / 2
	flash.z_index = 1000  # Very high z-index to appear on top
	
	# Add to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(flash)
	else:
		add_child(flash)
	
	# Animate flash
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)

func complete_attackdog_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Complete the AttackDog attack by dealing damage"""
	print("Completing AttackDog attack on NPC:", npc.name)
	
	# Deal 50 damage to the NPC
	var damage = ash_dog_damage
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("Attacking dead NPC - pushing corpse")
		damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, damage)
	
	# Exit attack mode
	exit_attack_mode()
	
	print("=== END ATTACKDOG ATTACK ===")

func perform_punchb_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack on NPC with movement animation"""
	print("=== PERFORMING PUNCHB ATTACK ON NPC ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Calculate distance to target
	var distance = calculate_grid_distance(player_grid_pos, target_pos)
	print("Distance to target:", distance)
	
	# Store original player position
	var original_player_pos = player_grid_pos
	
	# If target is adjacent (distance = 1), attack immediately
	if distance == 1:
		print("Target is adjacent - attacking immediately")
		perform_punchb_attack_immediate(npc, target_pos)
	else:
		# Target is 2 tiles away - animate player movement
		print("Target is 2 tiles away - animating player movement")
		perform_punchb_attack_with_movement(npc, target_pos, original_player_pos)

func perform_punchb_attack_on_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack on oil drum with movement animation"""
	print("=== PERFORMING PUNCHB ATTACK ON OIL DRUM ===")
	print("Oil drum:", oil_drum.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Calculate distance to target
	var distance = calculate_grid_distance(player_grid_pos, target_pos)
	print("Distance to target:", distance)
	
	# Store original player position
	var original_player_pos = player_grid_pos
	
	# If target is adjacent (distance = 1), attack immediately
	if distance == 1:
		print("Target is adjacent - attacking immediately")
		perform_punchb_attack_immediate_oil_drum(oil_drum, target_pos)
	else:
		# Target is 2 tiles away - animate player movement
		print("Target is 2 tiles away - animating player movement")
		perform_punchb_attack_with_movement_oil_drum(oil_drum, target_pos, original_player_pos)

func perform_punchb_attack_immediate(npc: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately (target is adjacent)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Emit punchb attack signal for animation
	emit_signal("punchb_attack_performed")
	
	# Deal 30 damage
	var punchb_damage = 30
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("Attacking dead NPC - pushing corpse")
		punchb_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(punchb_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, punchb_damage)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_immediate_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately on oil drum (target is adjacent)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Emit punchb attack signal for animation
	emit_signal("punchb_attack_performed")
	
	# Check if oil drum is already tipped over
	var is_tipped = false
	if oil_drum.has_method("get_is_tipped_over"):
		is_tipped = oil_drum.get_is_tipped_over()
	elif "is_tipped_over" in oil_drum:
		is_tipped = oil_drum.is_tipped_over
	
	if is_tipped:
		print("Oil drum is already tipped over - no effect")
	else:
		print("Tipping over oil drum with PunchB attack!")
		# Force the oil drum to tip over by setting its health to 0
		if oil_drum.has_method("take_damage"):
			oil_drum.take_damage(50)
		else:
			print("Oil drum doesn't have take_damage method!")
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", oil_drum, 50)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_immediate_no_animation(npc: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately without triggering animation (animation already playing)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Deal 30 damage
	var punchb_damage = 30
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("Attacking dead NPC - pushing corpse")
		punchb_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(punchb_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, punchb_damage)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_immediate_oil_drum_no_animation(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately on oil drum without triggering animation (animation already playing)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Check if oil drum is already tipped over
	var is_tipped = false
	if oil_drum.has_method("get_is_tipped_over"):
		is_tipped = oil_drum.get_is_tipped_over()
	elif "is_tipped_over" in oil_drum:
		is_tipped = oil_drum.is_tipped_over
	
	if is_tipped:
		print("Oil drum is already tipped over - no effect")
	else:
		print("Tipping over oil drum with PunchB attack!")
		# Force the oil drum to tip over by setting its health to 0
		if oil_drum.has_method("take_damage"):
			oil_drum.take_damage(50)
		else:
			print("Oil drum doesn't have take_damage method!")
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", oil_drum, 50)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_with_movement(npc: Node, target_pos: Vector2i, original_player_pos: Vector2i) -> void:
	"""Perform PunchB attack with player movement animation (target is 2 tiles away)"""
	# Calculate the intermediate position (1 tile closer to target)
	var direction = target_pos - original_player_pos
	var intermediate_pos = original_player_pos + Vector2i(sign(direction.x), sign(direction.y))
	
	print("Moving player from", original_player_pos, "to", intermediate_pos, "then to", target_pos)
	
	# Start punch animation immediately when movement begins
	emit_signal("punchb_attack_performed")
	
	# Animate player movement to target
	if player_node and player_node.has_method("animate_to_position"):
		# First move to intermediate position
		player_node.animate_to_position(intermediate_pos, func():
			# Then move to target position
			player_node.animate_to_position(target_pos, func():
				# Perform the attack (without animation since it's already playing)
				perform_punchb_attack_immediate_no_animation(npc, target_pos)
				# Move back to original position
				player_node.animate_to_position(original_player_pos, func():
					# Update player grid position
					player_grid_pos = original_player_pos
					# Update the course's player position reference
					if card_effect_handler and card_effect_handler.course:
						card_effect_handler.course.player_grid_pos = original_player_pos
				)
			)
		)
	else:
		# Fallback if animation is not available
		print("Player animation not available - performing immediate attack")
		perform_punchb_attack_immediate(npc, target_pos)

func perform_punchb_attack_with_movement_oil_drum(oil_drum: Node, target_pos: Vector2i, original_player_pos: Vector2i) -> void:
	"""Perform PunchB attack on oil drum with player movement animation (target is 2 tiles away)"""
	# Calculate the intermediate position (1 tile closer to target)
	var direction = target_pos - original_player_pos
	var intermediate_pos = original_player_pos + Vector2i(sign(direction.x), sign(direction.y))
	
	print("Moving player from", original_player_pos, "to", intermediate_pos, "then to", target_pos)
	
	# Start punch animation immediately when movement begins
	emit_signal("punchb_attack_performed")
	
	# Animate player movement to target
	if player_node and player_node.has_method("animate_to_position"):
		# First move to intermediate position
		player_node.animate_to_position(intermediate_pos, func():
			# Then move to target position
			player_node.animate_to_position(target_pos, func():
				# Perform the attack (without animation since it's already playing)
				perform_punchb_attack_immediate_oil_drum_no_animation(oil_drum, target_pos)
				# Move back to original position
				player_node.animate_to_position(original_player_pos, func():
					# Update player grid position
					player_grid_pos = original_player_pos
					# Update the course's player position reference
					if card_effect_handler and card_effect_handler.course:
						card_effect_handler.course.player_grid_pos = original_player_pos
				)
			)
		)
	else:
		# Fallback if animation is not available
		print("Player animation not available - performing immediate attack")
		perform_punchb_attack_immediate_oil_drum(oil_drum, target_pos)

func perform_assassin_dash_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AssassinDash attack on NPC with movement to behind-enemy position"""
	print("=== PERFORMING ASSASSIN DASH ATTACK ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	print("[AssassinDash] selected_card:", selected_card.name if selected_card else "None", "hand:", deck_manager.hand.map(func(c): return c.name))
	# Calculate the position behind the enemy (opposite direction from player)
	var direction = target_pos - player_grid_pos
	var behind_enemy_pos = target_pos + direction
	print("Moving player to behind-enemy position:", behind_enemy_pos)
	# Store original player position
	var original_player_pos = player_grid_pos
	# Play camera whoosh sound when card is played
	if assassin_dash_sound:
		assassin_dash_sound.play()
	# Animate player movement to behind-enemy position
	if player_node and player_node.has_method("animate_to_position"):
		player_node.animate_to_position(behind_enemy_pos, func():
			# Play cut sound when reaching the NPC
			if assassin_cut_sound:
				assassin_cut_sound.play()
			# Deal 40 damage to the NPC
			var assassin_damage = 40
			# Check if NPC is dead
			var is_dead = false
			if npc.has_method("get_is_dead"):
				is_dead = npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_dead = npc.is_dead()
			elif "is_dead" in npc:
				is_dead = npc.is_dead
			if is_dead:
				print("Attacking dead NPC - pushing corpse")
				assassin_damage = 0
			else:
				# Deal damage to the NPC
				if npc.has_method("take_damage"):
					npc.take_damage(assassin_damage)
				else:
					print("NPC does not have take_damage method")
			# Apply knockback (works for both living and dead NPCs)
			apply_knockback(npc, target_pos)
			# Emit signal
			emit_signal("npc_attacked", npc, assassin_damage)
			
			# Update player grid position to behind-enemy position (stay there)
			player_grid_pos = behind_enemy_pos
			# Update the course's player position reference
			if card_effect_handler and card_effect_handler.course:
				card_effect_handler.course.player_grid_pos = behind_enemy_pos
			
			# CRITICAL: Update player Y-sorting immediately after AssassinDash movement
			if player_node and player_node.has_method("update_z_index_for_ysort"):
				player_node.update_z_index_for_ysort([], Vector2i.ZERO)
				print("✓ Updated player Y-sorting after AssassinDash movement to position:", behind_enemy_pos)
			
			# Exit attack mode
			exit_attack_mode()
		)
	else:
		# Fallback if animation is not available
		print("Player animation not available - performing immediate attack")
		perform_assassin_dash_attack_immediate(npc, target_pos)

func perform_assassin_dash_attack_immediate(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AssassinDash attack immediately without movement animation"""
	# Play cut sound
	if assassin_cut_sound:
		assassin_cut_sound.play()
	
	# Deal 40 damage
	var assassin_damage = 40
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("Attacking dead NPC - pushing corpse")
		assassin_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(assassin_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, assassin_damage)
	
	# Exit attack mode
	exit_attack_mode() 

func perform_meteor_attack(target_pos: Vector2i) -> void:
	"""Perform Meteor AOE attack at the specified position"""
	print("=== PERFORMING METEOR AOE ATTACK ===")
	print("Target position:", target_pos)
	
	# Calculate the 3x2 area positions
	var aoe_positions = []
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var pos = target_pos + Vector2i(x_offset, y_offset)
			aoe_positions.append(pos)
	
	print("AOE positions:", aoe_positions)
	
	# Create and animate the meteor
	create_and_animate_meteor(target_pos, aoe_positions)

func create_and_animate_meteor(target_pos: Vector2i, aoe_positions: Array) -> void:
	"""Create and animate the meteor falling to the target position"""
	print("Creating meteor at target position:", target_pos)
	
	# Load the meteor scene
	var meteor_scene = load("res://Particles/Meteor.tscn")
	if not meteor_scene:
		print("✗ ERROR: Could not load Meteor.tscn")
		exit_attack_mode()
		return
	
	# Create meteor instance
	var meteor = meteor_scene.instantiate()
	if not meteor:
		print("✗ ERROR: Could not instantiate meteor")
		exit_attack_mode()
		return
	
	# Add meteor to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(meteor)
	else:
		add_child(meteor)
	
	# Calculate world position for the meteor target (center of the 3x2 area)
	var world_target_x = (target_pos.x + 1.5) * cell_size  # Center of 3-tile width
	var world_target_y = (target_pos.y + 0.5) * cell_size  # Center of 2-tile height
	var world_target_pos = Vector2(world_target_x, world_target_y)
	
	# Add camera container offset to get correct world position
	if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_node("CameraContainer"):
		var camera_container = card_effect_handler.course.get_node("CameraContainer")
		world_target_pos += camera_container.global_position
		print("✓ Added camera container offset:", camera_container.global_position, "to meteor target position")
	else:
		print("⚠ No camera container found for meteor positioning")
	
	# Position meteor much further up and to the left for dramatic effect
	var meteor_start_pos = Vector2(world_target_x - 300, -400)  # Start much higher and to the left
	# Add camera container offset to meteor start position
	if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_node("CameraContainer"):
		var camera_container = card_effect_handler.course.get_node("CameraContainer")
		meteor_start_pos += camera_container.global_position
		print("✓ Added camera container offset to meteor start position")
	meteor.global_position = meteor_start_pos
	
	# Set initial bright white color and large scale for the meteor
	var meteor_sprite = meteor.get_node_or_null("MeteorSprite")
	if meteor_sprite:
		meteor_sprite.modulate = Color.WHITE
		meteor_sprite.scale = Vector2(3.0, 3.0)  # Start 3x larger
		print("✓ Set meteor to bright white initial color and 3x scale")
	
	# Focus camera on meteor during animation
	focus_camera_on_meteor(meteor, world_target_pos)
	
	# Play meteor start sound
	var meteor_start_sound = meteor.get_node_or_null("MeteorStart")
	if meteor_start_sound:
		meteor_start_sound.play()
	
	# Animate meteor falling
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	
	# Meteor falls to target over 1.5 seconds
	tween.tween_property(meteor, "global_position", world_target_pos, 1.5)
	
	# Animate scale from 3x to 1x over the fall duration
	if meteor_sprite:
		tween.parallel().tween_property(meteor_sprite, "scale", Vector2(1.0, 1.0), 1.5)
	
	# Animate color transition from bright white to flashing red
	if meteor_sprite:
		# First transition to red over 0.5 seconds
		tween.parallel().tween_property(meteor_sprite, "modulate", Color.RED, 0.5)
		
		# Then create flashing red effect for the remaining time
		tween.parallel().tween_method(func(progress: float):
			if is_instance_valid(meteor_sprite):
				var flash_intensity = 0.5 + 0.5 * sin(progress * 20.0)  # Fast flashing
				meteor_sprite.modulate = Color.RED * flash_intensity
		, 0.5, 1.0, 1.0)  # Flash for the last 1 second
	
	# Update YSort during meteor fall animation
	tween.parallel().tween_method(func(progress: float):
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
	, 0.0, 1.0, 1.5)
	tween.tween_callback(func():
		# Meteor has landed - update YSort for final position
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
		
		# Play crash and land sounds
		var meteor_crash_sound = meteor.get_node_or_null("MeteorCrash")
		var meteor_land_sound = meteor.get_node_or_null("MeteorLand")
		
		if meteor_crash_sound:
			meteor_crash_sound.play()
		if meteor_land_sound:
			meteor_land_sound.play()
		
		# Start crater animation sequence
		start_crater_animation(meteor, aoe_positions)
	)

func start_crater_animation(meteor: Node, aoe_positions: Array) -> void:
	"""Start the crater animation sequence"""
	print("Starting crater animation for AOE positions:", aoe_positions)
	
	# Get the crater sprites
	var meteor_sprite = meteor.get_node_or_null("MeteorSprite")
	var crater_explosion1 = meteor.get_node_or_null("CraterExplosion1")
	var crater_explosion2 = meteor.get_node_or_null("CraterExplosion2")
	var crater_sprite = meteor.get_node_or_null("CraterSprite")
	
	if not meteor_sprite or not crater_explosion1 or not crater_explosion2 or not crater_sprite:
		print("✗ ERROR: Missing crater sprites in meteor scene")
		complete_meteor_attack(meteor, aoe_positions)
		return
	
	# Stop meteor tracking and start crash sequence
	stop_meteor_camera_tracking(meteor)
	start_crash_camera_sequence(meteor)
	
	# Hide meteor sprite and show first explosion
	meteor_sprite.visible = false
	crater_explosion1.visible = true
	
	# Animate through the crater sequence
	var tween = create_tween()
	
	# Show first explosion for 0.3 seconds
	tween.tween_callback(func():
		crater_explosion1.visible = false
		crater_explosion2.visible = true
		# Update YSort for explosion sprites
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
	).set_delay(0.3)
	
	# Show second explosion for 0.3 seconds
	tween.tween_callback(func():
		crater_explosion2.visible = false
		crater_sprite.visible = true
		# Update YSort for crater sprite
		if is_instance_valid(meteor) and meteor.has_method("update_ysort"):
			meteor.update_ysort()
	).set_delay(0.3)
	
	# Show final crater for 0.5 seconds then complete attack
	tween.tween_callback(func():
		# Create persistent crater before completing attack
		create_persistent_crater(meteor, aoe_positions)
		complete_meteor_attack(meteor, aoe_positions)
	).set_delay(0.5)

func complete_meteor_attack(meteor: Node, aoe_positions: Array) -> void:
	"""Complete the meteor attack by dealing damage to NPCs in the AOE area"""
	print("Completing meteor attack for AOE positions:", aoe_positions)
	
	var meteor_damage = 35  # Base meteor damage
	var total_damage_dealt = 0
	
	# Deal damage to all NPCs in the AOE area
	for pos in aoe_positions:
		var npc = get_npc_at_position(pos)
		if npc:
			print("Dealing meteor damage to NPC at position:", pos)
			
			# Check if NPC is dead
			var is_dead = false
			if npc.has_method("get_is_dead"):
				is_dead = npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_dead = npc.is_dead()
			elif "is_dead" in npc:
				is_dead = npc.is_dead
			
			if not is_dead:
				# Deal damage to the NPC
				if npc.has_method("take_damage"):
					npc.take_damage(meteor_damage)
					total_damage_dealt += meteor_damage
					print("Dealt", meteor_damage, "damage to NPC:", npc.name)
				else:
					print("NPC does not have take_damage method:", npc.name)
			else:
				print("NPC is already dead, skipping damage:", npc.name)
	
	print("Meteor attack complete - total damage dealt:", total_damage_dealt)
	
	# Camera return is now handled by the crash sequence
	# Clean up meteor from scene after a short delay
	call_deferred("_cleanup_meteor", meteor)
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", null, total_damage_dealt)
	
	# Exit attack mode
	exit_attack_mode()

func _cleanup_meteor(meteor: Node):
	"""Clean up the specific meteor from the scene after the attack is complete"""
	if is_instance_valid(meteor):
		meteor.queue_free()
		print("Cleaned up meteor from scene")

func focus_camera_on_meteor(meteor: Node, target_pos: Vector2) -> void:
	"""Focus camera on the meteor during its animation and return to player when done"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for camera focus")
		return
	
	var course = card_effect_handler.course
	if not course.has_method("create_camera_tween") or not course.has_method("transition_camera_to_player"):
		print("✗ ERROR: Course missing camera methods")
		return
	
	print("=== FOCUSING CAMERA ON METEOR ===")
	
	# Store player position for return
	var player_pos = Vector2.ZERO
	if course.player_node:
		var sprite = course.player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(48, 48)
		player_pos = course.player_node.global_position + player_size / 2
	
	# Store references for meteor tracking
	meteor.set_meta("camera_return_to_player", true)
	meteor.set_meta("player_position", player_pos)
	meteor.set_meta("course_reference", course)
	meteor.set_meta("target_position", target_pos)
	
	# Store current zoom to restore later
	if course.camera and course.camera.has_method("set_zoom_level"):
		if not meteor.has_meta("pre_meteor_zoom"):
			meteor.set_meta("pre_meteor_zoom", course.camera.get_current_zoom())
	
	# Start meteor tracking immediately
	start_meteor_camera_tracking(meteor)

func start_meteor_camera_tracking(meteor: Node) -> void:
	"""Start tracking the meteor with the camera during its fall animation"""
	if not meteor.has_meta("course_reference"):
		print("✗ ERROR: Meteor missing course reference for tracking")
		return
	
	var course = meteor.get_meta("course_reference")
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for meteor tracking")
		return
	
	print("=== STARTING METEOR CAMERA TRACKING ===")
	
	# Immediately focus camera on the meteor's current position (in the air)
	var meteor_start_pos = meteor.global_position
	course.create_camera_tween(meteor_start_pos, 0.5)
	print("✓ Camera focused on meteor in air at:", meteor_start_pos)
	
	# Zoom in for close-up meteor tracking (but respect range display zoom if it exists)
	if course.camera and course.camera.has_method("set_zoom_level"):
		var tracking_zoom = 1.2  # Zoom in to 120% for close tracking
		
		# Check if we're currently showing meteor range (zoomed out)
		if course.has_meta("pre_meteor_zoom"):
			# We're in range display mode, use a more moderate zoom for tracking
			tracking_zoom = 0.8  # Keep some zoom out for better meteor visibility
			print("✓ Using moderate zoom for meteor tracking (range display mode):", tracking_zoom)
		else:
			# Normal meteor tracking zoom
			print("✓ Camera zoomed in for meteor tracking to", tracking_zoom)
		
		course.camera.set_zoom_level(tracking_zoom)
	
	# Set up continuous tracking during meteor fall
	meteor.set_meta("is_being_tracked", true)
	meteor.set_meta("last_tracked_position", meteor.global_position)
	
	# Start a timer to continuously update camera position
	var tracking_timer = get_tree().create_timer(0.1)  # Update every 0.1 seconds
	tracking_timer.timeout.connect(func():
		update_meteor_camera_tracking(meteor)
	)
	
	# Store the timer reference for cleanup
	meteor.set_meta("tracking_timer", tracking_timer)

func update_meteor_camera_tracking(meteor: Node) -> void:
	"""Update camera tracking for the meteor during its fall animation"""
	if not is_instance_valid(meteor) or not meteor.has_meta("is_being_tracked") or not meteor.get_meta("is_being_tracked"):
		return
	
	var last_pos = meteor.get_meta("last_tracked_position", Vector2.ZERO)
	var current_pos = meteor.global_position
	
	# Only update camera if meteor has moved significantly
	if current_pos.distance_to(last_pos) > 5.0:  # 5 pixel threshold
		if meteor.has_meta("course_reference"):
			var course = meteor.get_meta("course_reference")
			if course and is_instance_valid(course) and course.has_method("create_camera_tween"):
				# Use a very short tween for smooth following
				course.create_camera_tween(current_pos, 0.1)
		
		# Update last tracked position
		meteor.set_meta("last_tracked_position", current_pos)
	
	# Continue tracking if meteor is still being tracked
	if meteor.has_meta("is_being_tracked") and meteor.get_meta("is_being_tracked"):
		var tracking_timer = get_tree().create_timer(0.1)
		tracking_timer.timeout.connect(func():
			update_meteor_camera_tracking(meteor)
		)
		meteor.set_meta("tracking_timer", tracking_timer)

func stop_meteor_camera_tracking(meteor: Node) -> void:
	"""Stop tracking the meteor and clean up tracking resources"""
	if not meteor.has_meta("is_being_tracked"):
		return
	
	meteor.set_meta("is_being_tracked", false)
	
	# Clean up tracking timer if it exists
	if meteor.has_meta("tracking_timer"):
		var timer = meteor.get_meta("tracking_timer")
		if timer and is_instance_valid(timer):
			# Timer will be automatically cleaned up when it times out
			# No need to manually disconnect signals in Godot 4
			pass
		meteor.remove_meta("tracking_timer")
	
	# Clean up tracking metadata
	meteor.remove_meta("last_tracked_position")
	
	print("✓ Stopped meteor camera tracking")

func start_crash_camera_sequence(meteor: Node) -> void:
	"""Start the camera sequence for the meteor crash - zoom out and return to player"""
	if not meteor.has_meta("course_reference"):
		print("✗ ERROR: Meteor missing course reference for crash sequence")
		return
	
	var course = meteor.get_meta("course_reference")
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for crash sequence")
		return
	
	print("=== STARTING METEOR CRASH CAMERA SEQUENCE ===")
	
	# Get target position for crash focus
	var target_pos = meteor.get_meta("target_position", meteor.global_position)
	
	# Focus camera on crash position
	course.create_camera_tween(target_pos, 0.5)
	print("✓ Camera focused on crash position")
	
	# Start smooth zoom out effect
	if course.camera and course.camera.has_method("set_zoom_level"):
		var crash_zoom = 0.6  # Zoom out to 60% for dramatic crash effect
		
		# Check if we're coming from range display mode
		if course.has_meta("pre_meteor_zoom"):
			# We're already zoomed out for range display, use a more dramatic crash zoom
			crash_zoom = 0.4  # Even more zoom out for dramatic effect
			print("✓ Camera zoomed out for dramatic crash effect (from range display):", crash_zoom)
		else:
			# Normal crash zoom
			print("✓ Camera zoomed out for crash effect to", crash_zoom)
		
		course.camera.set_zoom_level(crash_zoom)
	
	# Set up delayed return to player
	var return_timer = get_tree().create_timer(1.5)  # Wait 1.5 seconds after crash starts
	return_timer.timeout.connect(func():
		# Capture necessary data before meteor might be cleaned up
		if is_instance_valid(meteor):
			return_camera_to_player(meteor)
		else:
			# Fallback: return camera to player without meteor reference
			_fallback_return_camera_to_player(course)
	)

func create_persistent_crater(meteor: Node, aoe_positions: Array) -> void:
	"""Create a persistent crater that stays in the scene after the meteor is cleaned up"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for persistent crater")
		return
	
	var course = card_effect_handler.course
	
	# Get the crater sprite from the meteor
	var crater_sprite = meteor.get_node_or_null("CraterSprite")
	if not crater_sprite:
		print("✗ ERROR: No crater sprite found in meteor")
		return
	
	# Create a new persistent crater node
	var persistent_crater = Node2D.new()
	persistent_crater.name = "PersistentCrater"
	
	# Copy the crater sprite to the persistent crater
	var new_crater_sprite = Sprite2D.new()
	new_crater_sprite.texture = crater_sprite.texture
	new_crater_sprite.position = crater_sprite.position
	new_crater_sprite.scale = crater_sprite.scale
	new_crater_sprite.modulate = crater_sprite.modulate
	new_crater_sprite.visible = true
	new_crater_sprite.z_index = crater_sprite.z_index
	
	# Add the crater sprite to the persistent crater
	persistent_crater.add_child(new_crater_sprite)
	
	# Position the persistent crater at the meteor's position
	persistent_crater.global_position = meteor.global_position
	
	# Add to groups for YSort system
	persistent_crater.add_to_group("craters")
	persistent_crater.add_to_group("ysort_objects")
	
	# Add the persistent crater to the course
	course.add_child(persistent_crater)
	
	# Update YSort for the persistent crater
	if persistent_crater.has_method("update_ysort"):
		persistent_crater.update_ysort()
	else:
		# Add YSort method to persistent crater
		persistent_crater.set_script(load("res://Particles/meteor.gd"))
		persistent_crater.update_ysort()
	
	print("✓ Created persistent crater at position:", persistent_crater.global_position)
	print("✓ Crater added to course and YSort system")
	
	# Store crater reference for potential cleanup later
	if not course.has_meta("meteor_craters"):
		course.set_meta("meteor_craters", [])
	
	var craters = course.get_meta("meteor_craters")
	craters.append(persistent_crater)
	course.set_meta("meteor_craters", craters)

func cleanup_all_meteor_craters() -> void:
	"""Clean up all persistent meteor craters from the scene"""
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ ERROR: No course reference for crater cleanup")
		return
	
	var course = card_effect_handler.course
	
	if not course.has_meta("meteor_craters"):
		print("✓ No meteor craters to clean up")
		return
	
	var craters = course.get_meta("meteor_craters")
	var craters_cleaned = 0
	
	for crater in craters:
		if is_instance_valid(crater):
			crater.queue_free()
			craters_cleaned += 1
	
	# Clear the craters list
	course.set_meta("meteor_craters", [])
	
	print("✓ Cleaned up", craters_cleaned, "meteor craters")

func return_camera_to_player(meteor: Node) -> void:
	"""Return camera to player after meteor attack completes"""
	# Check if meteor is valid first
	if not meteor or not is_instance_valid(meteor):
		print("✗ ERROR: Meteor is null or invalid for camera return")
		return
	
	if not meteor.has_meta("camera_return_to_player") or not meteor.has_meta("course_reference"):
		print("✗ ERROR: Meteor missing camera return metadata")
		return
	
	var course = meteor.get_meta("course_reference")
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for camera return")
		return
	
	print("=== RETURNING CAMERA TO PLAYER ===")
	
	# Get player position
	var player_pos = meteor.get_meta("player_position", Vector2.ZERO)
	
	# Smoothly tween camera back to player
	if course.has_method("create_camera_tween"):
		course.create_camera_tween(player_pos, 1.5)
		print("✓ Camera tweening back to player")
	
	# Restore zoom to previous level with a smooth tween
	if course.camera and course.camera.has_method("set_zoom_level"):
		if meteor.has_meta("pre_meteor_zoom"):
			var pre_zoom = meteor.get_meta("pre_meteor_zoom")
			# Create a smooth zoom tween back to original level
			var zoom_tween = get_tree().create_tween()
			zoom_tween.set_trans(Tween.TRANS_SINE)
			zoom_tween.set_ease(Tween.EASE_IN_OUT)
			zoom_tween.tween_method(func(zoom_level: float):
				course.camera.set_zoom_level(zoom_level)
			, course.camera.get_current_zoom(), pre_zoom, 1.5)
			print("✓ Camera zoom smoothly restored to", pre_zoom)

func _fallback_return_camera_to_player(course: Node) -> void:
	"""Fallback function to return camera to player when meteor is no longer valid"""
	if not course or not is_instance_valid(course):
		print("✗ ERROR: Invalid course reference for fallback camera return")
		return
	
	print("=== FALLBACK RETURNING CAMERA TO PLAYER ===")
	
	# Get player position from course
	var player_pos = Vector2.ZERO
	if course.player_node:
		var sprite = course.player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(48, 48)
		player_pos = course.player_node.global_position + player_size / 2
	
	# Smoothly tween camera back to player
	if course.has_method("create_camera_tween"):
		course.create_camera_tween(player_pos, 1.5)
		print("✓ Camera tweening back to player (fallback)")
	
	# Restore zoom to default level
	if course.camera and course.camera.has_method("set_zoom_level"):
		var default_zoom = 1.0  # Default zoom level
		# Create a smooth zoom tween back to default level
		var zoom_tween = get_tree().create_tween()
		zoom_tween.set_trans(Tween.TRANS_SINE)
		zoom_tween.set_ease(Tween.EASE_IN_OUT)
		zoom_tween.tween_method(func(zoom_level: float):
			course.camera.set_zoom_level(zoom_level)
		, course.camera.get_current_zoom(), default_zoom, 1.5)
		print("✓ Camera zoom smoothly restored to default (fallback)") 
