extends Node
class_name MeleeAttackStrategy

#use for the Attacks that have a range of 1-3 tiles, player animates to the target and performs the animation, applies damage, knockback, etc 

# References needed for melee attacks
var card_effect_handler: Node
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary
var player_node: Node2D

# Movement tracking for distant attacks
var original_player_pos: Vector2i = Vector2i.ZERO
var needs_return_movement: bool = false

# Sound effects
var kick_sound: AudioStreamPlayer2D
var punchb_sound: AudioStreamPlayer2D
var slash_sound: AudioStreamPlayer2D

# Attack properties
var attack_damage := 25
var knockback_distance := 1
var slash_damage := 33

# SlashFX scene reference
var slashfx_scene = preload("res://Particles/SlashFX.tscn")

# Signals
signal npc_attacked(npc: Node, damage: int)
signal kick_attack_performed
signal punchb_attack_performed
signal slash_attack_performed
signal attack_completed

func setup(
	card_effect_handler_ref: Node,
	grid_tiles_ref: Array,
	grid_size_ref: Vector2i,
	cell_size_ref: int,
	obstacle_map_ref: Dictionary,
	player_grid_pos_ref: Vector2i,
	player_stats_ref: Dictionary,
	player_node_ref: Node2D,
	kick_sound_ref: AudioStreamPlayer2D = null,
	punchb_sound_ref: AudioStreamPlayer2D = null,
	slash_sound_ref: AudioStreamPlayer2D = null
):
	card_effect_handler = card_effect_handler_ref
	grid_tiles = grid_tiles_ref
	grid_size = grid_size_ref
	cell_size = cell_size_ref
	obstacle_map = obstacle_map_ref
	player_grid_pos = player_grid_pos_ref
	player_stats = player_stats_ref
	player_node = player_node_ref
	kick_sound = kick_sound_ref
	punchb_sound = punchb_sound_ref
	slash_sound = slash_sound_ref

func perform_kickb_attack(target_pos: Vector2i) -> void:
	"""Perform KickB attack at the specified position"""
	print("=== PERFORMING KICKB ATTACK ===")
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Calculate distance to target
	var distance_to_target = abs(target_pos.x - player_grid_pos.x) + abs(target_pos.y - player_grid_pos.y)
	print("Distance to target:", distance_to_target)
	
	# Check if target is adjacent (1 tile away) or distant (2 tiles away)
	if distance_to_target == 1:
		# Adjacent target - perform attack directly
		perform_kickb_attack_direct(target_pos)
	else:
		# Distant target (2 tiles away) - move to target, attack, then return
		perform_kickb_attack_with_movement(target_pos)

func perform_kickb_attack_direct(target_pos: Vector2i) -> void:
	"""Perform KickB attack directly on adjacent target"""
	print("Performing direct KickB attack on adjacent target")
	
	# Play KickSound
	if kick_sound:
		kick_sound.play()
	
	# Emit kick attack signal for animation
	print("🎯 EMITTING kick_attack_performed signal")
	emit_signal("kick_attack_performed")
	
	# Get NPC at target position
	var npc = get_npc_at_position(target_pos)
	if npc:
		print("Found NPC at target position:", npc.name)
		perform_kickb_attack_on_npc(npc, target_pos)
	else:
		# Check for oil drum at target position
		var oil_drum = get_oil_drum_at_position(target_pos)
		if oil_drum:
			print("Found oil drum at target position")
			perform_kickb_attack_on_oil_drum(oil_drum, target_pos)
		else:
			print("No target found at position:", target_pos)
			handle_attack_completion()

func perform_kickb_attack_with_movement(target_pos: Vector2i) -> void:
	"""Perform KickB attack with movement to distant target"""
	print("Performing KickB attack with movement to distant target")
	
	# Store original player position
	original_player_pos = player_grid_pos
	needs_return_movement = true
	
	# Calculate the position adjacent to the target (1 tile away from target towards player)
	var direction = player_grid_pos - target_pos
	var adjacent_pos = target_pos
	if direction.x > 0:
		adjacent_pos.x -= 1  # Move towards player (target is to the left of player)
	elif direction.x < 0:
		adjacent_pos.x += 1  # Move towards player (target is to the right of player)
	elif direction.y > 0:
		adjacent_pos.y -= 1  # Move towards player (target is above player)
	elif direction.y < 0:
		adjacent_pos.y += 1  # Move towards player (target is below player)
	
	print("Moving to adjacent position:", adjacent_pos, "to attack target at:", target_pos)
	
	# Start kick animation immediately when movement begins
	emit_signal("kick_attack_performed")
	
	# Chain the animations together for smooth movement
	if player_node and player_node.has_method("animate_to_position"):
		# First move to adjacent position
		player_node.animate_to_position(adjacent_pos, func():
			print("🔍 KICK DEBUG: Movement to adjacent position completed")
			# Now perform the attack
			perform_kickb_attack_direct(target_pos)
			# The attack completion will handle the return movement
		)
	else:
		print("Player node does not have animate_to_position method - performing direct attack")
		perform_kickb_attack_direct(target_pos)

func perform_kickb_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform KickB attack on an NPC"""
	print("Performing KickB attack on NPC:", npc.name)
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("NPC is already dead, skipping attack")
		handle_attack_completion()
		return
	
	# Deal damage to the NPC
	if npc.has_method("take_damage"):
		npc.take_damage(attack_damage)
		print("Dealt", attack_damage, "damage to NPC:", npc.name)
		
		# Apply knockback
		apply_knockback_to_npc(npc, target_pos)
		
		# Emit signal for attack completion
		emit_signal("npc_attacked", npc, attack_damage)
	else:
		print("NPC does not have take_damage method:", npc.name)
	
	handle_attack_completion()

func perform_kickb_attack_on_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform KickB attack on an oil drum"""
	print("Performing KickB attack on oil drum")
	
	# Check if oil drum is destroyed
	var is_destroyed = false
	if oil_drum.has_method("get_is_destroyed"):
		is_destroyed = oil_drum.get_is_destroyed()
	elif oil_drum.has_method("is_destroyed"):
		is_destroyed = oil_drum.is_destroyed()
	elif "is_destroyed" in oil_drum:
		is_destroyed = oil_drum.is_destroyed
	
	if is_destroyed:
		print("Oil drum is already destroyed, skipping attack")
		handle_attack_completion()
		return
	
	# Deal damage to the oil drum
	if oil_drum.has_method("take_damage"):
		oil_drum.take_damage(attack_damage)
		print("Dealt", attack_damage, "damage to oil drum")
		
		# Apply knockback
		apply_knockback_to_oil_drum(oil_drum, target_pos)
	else:
		print("Oil drum does not have take_damage method")
	
	handle_attack_completion()

func perform_punchb_attack(target_pos: Vector2i) -> void:
	"""Perform PunchB attack at the specified position"""
	print("=== PERFORMING PUNCHB ATTACK ===")
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Calculate distance to target
	var distance_to_target = abs(target_pos.x - player_grid_pos.x) + abs(target_pos.y - player_grid_pos.y)
	print("Distance to target:", distance_to_target)
	
	# Check if target is adjacent (1 tile away) or distant (2 tiles away)
	if distance_to_target == 1:
		# Adjacent target - perform attack directly
		perform_punchb_attack_direct(target_pos)
	else:
		# Distant target (2 tiles away) - move to target, attack, then return
		perform_punchb_attack_with_movement(target_pos)

func perform_punchb_attack_direct(target_pos: Vector2i) -> void:
	"""Perform PunchB attack directly on adjacent target"""
	print("Performing direct PunchB attack on adjacent target")
	
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Emit punch attack signal for animation
	print("🎯 EMITTING punchb_attack_performed signal")
	emit_signal("punchb_attack_performed")
	
	# Get NPC at target position
	var npc = get_npc_at_position(target_pos)
	if npc:
		print("Found NPC at target position:", npc.name)
		perform_punchb_attack_on_npc(npc, target_pos)
	else:
		# Check for oil drum at target position
		var oil_drum = get_oil_drum_at_position(target_pos)
		if oil_drum:
			print("Found oil drum at target position")
			perform_punchb_attack_on_oil_drum(oil_drum, target_pos)
		else:
			print("No target found at position:", target_pos)
			handle_attack_completion()

func perform_punchb_attack_with_movement(target_pos: Vector2i) -> void:
	"""Perform PunchB attack with movement to distant target"""
	print("Performing PunchB attack with movement to distant target")
	
	# Store original player position
	original_player_pos = player_grid_pos
	needs_return_movement = true
	
	# Calculate the position adjacent to the target (1 tile away from target towards player)
	var direction = player_grid_pos - target_pos
	var adjacent_pos = target_pos
	if direction.x > 0:
		adjacent_pos.x -= 1  # Move towards player (target is to the left of player)
	elif direction.x < 0:
		adjacent_pos.x += 1  # Move towards player (target is to the right of player)
	elif direction.y > 0:
		adjacent_pos.y -= 1  # Move towards player (target is above player)
	elif direction.y < 0:
		adjacent_pos.y += 1  # Move towards player (target is below player)
	
	print("Moving to adjacent position:", adjacent_pos, "to attack target at:", target_pos)
	
	# Start punch animation immediately when movement begins
	emit_signal("punchb_attack_performed")
	
	# Chain the animations together for smooth movement
	if player_node and player_node.has_method("animate_to_position"):
		# First move to adjacent position
		player_node.animate_to_position(adjacent_pos, func():
			print("🔍 PUNCH DEBUG: Movement to adjacent position completed")
			# Now perform the attack
			perform_punchb_attack_direct(target_pos)
			# The attack completion will handle the return movement
		)
	else:
		print("Player node does not have animate_to_position method - performing direct attack")
		perform_punchb_attack_direct(target_pos)

func perform_punchb_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack on an NPC"""
	print("Performing PunchB attack on NPC:", npc.name)
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("NPC is already dead, skipping attack")
		handle_attack_completion()
		return
	
	# Deal damage to the NPC
	if npc.has_method("take_damage"):
		npc.take_damage(attack_damage)
		print("Dealt", attack_damage, "damage to NPC:", npc.name)
		
		# Apply knockback
		apply_knockback_to_npc(npc, target_pos)
		
		# Emit signal for attack completion
		emit_signal("npc_attacked", npc, attack_damage)
	else:
		print("NPC does not have take_damage method:", npc.name)
	
	handle_attack_completion()

func perform_punchb_attack_on_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack on an oil drum"""
	print("Performing PunchB attack on oil drum")
	
	# Check if oil drum is destroyed
	var is_destroyed = false
	if oil_drum.has_method("get_is_destroyed"):
		is_destroyed = oil_drum.get_is_destroyed()
	elif oil_drum.has_method("is_destroyed"):
		is_destroyed = oil_drum.is_destroyed()
	elif "is_destroyed" in oil_drum:
		is_destroyed = oil_drum.is_destroyed
	
	if is_destroyed:
		print("Oil drum is already destroyed, skipping attack")
		handle_attack_completion()
		return
	
	# Deal damage to the oil drum
	if oil_drum.has_method("take_damage"):
		oil_drum.take_damage(attack_damage)
		print("Dealt", attack_damage, "damage to oil drum")
		
		# Apply knockback
		apply_knockback_to_oil_drum(oil_drum, target_pos)
	else:
		print("Oil drum does not have take_damage method")
	
	handle_attack_completion()

func perform_slash_attack(target_pos: Vector2i) -> void:
	"""Perform SlashCard AOE attack at the specified position"""
	print("=== PERFORMING SLASH AOE ATTACK ===")
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Play SlashSound
	if slash_sound:
		slash_sound.play()
	
	# Spawn SlashFX at the clicked tile location
	spawn_slashfx_at_position(target_pos)
	
	# Emit slash attack signal for animation
	print("🎯 EMITTING slash_attack_performed signal")
	emit_signal("slash_attack_performed")
	
	# Calculate the AOE area around the target position
	var aoe_positions = []
	var aoe_radius = 1  # 1 tile radius for the slash AOE
	
	# Get all positions within the AOE radius of the target
	for y_offset in range(-aoe_radius, aoe_radius + 1):
		for x_offset in range(-aoe_radius, aoe_radius + 1):
			var pos = target_pos + Vector2i(x_offset, y_offset)
			# Check if position is within grid bounds
			if pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y:
				aoe_positions.append(pos)
	
	print("AOE positions for slash attack:", aoe_positions)
	
	# Deal damage to all NPCs in the AOE area
	var total_damage_dealt = 0
	
	for pos in aoe_positions:
		var npc = get_npc_at_position(pos)
		if npc:
			print("Dealing slash damage to NPC at position:", pos)
			
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
					npc.take_damage(slash_damage)
					total_damage_dealt += slash_damage
					print("Dealt", slash_damage, "damage to NPC:", npc.name)
				else:
					print("NPC does not have take_damage method:", npc.name)
			else:
				print("NPC is already dead, skipping damage:", npc.name)
	
	print("Slash attack complete - total damage dealt:", total_damage_dealt)
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", null, total_damage_dealt)
	handle_attack_completion()
	
	print("=== END SLASH ATTACK ===")

func spawn_slashfx_at_position(grid_pos: Vector2i) -> void:
	"""Spawn a SlashFX at the specified grid position"""
	print("🎯 SPAWNING SLASHFX at grid position:", grid_pos)
	
	if not slashfx_scene:
		print("⚠ SlashFX scene not found")
		return
	
	# Calculate world position from grid position
	var world_pos = Vector2(grid_pos.x * cell_size + cell_size/2, grid_pos.y * cell_size + cell_size/2)
	print("🎯 Calculated base world position:", world_pos)
	
	# Add camera offset if available
	if card_effect_handler and card_effect_handler.course:
		var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
		if camera_container:
			world_pos += camera_container.global_position
			print("🎯 Added camera container offset:", camera_container.global_position, "Final world position:", world_pos)
		else:
			print("⚠ No camera container found")
	else:
		print("⚠ No card_effect_handler or course reference")
	
	# Create the SlashFX instance
	var slashfx = slashfx_scene.instantiate()
	
	# Set high z-index to ensure SlashFX appears above other elements
	slashfx.z_index = 1000
	
	# Add to the course scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(slashfx)
	else:
		# Fallback to current scene
		get_tree().current_scene.add_child(slashfx)
	
	# Position the SlashFX
	slashfx.global_position = world_pos
	
	# Get player's facing direction for proper orientation
	var player_facing_left = false
	
	# Try the most reliable method first - using the player's facing direction system
	if player_node and player_node.has_method("is_facing_left"):
		player_facing_left = player_node.is_facing_left()
		print("🎯 Using player.is_facing_left():", player_facing_left)
	elif player_node and player_node.has_method("get_current_facing_direction"):
		var facing_dir = player_node.get_current_facing_direction()
		player_facing_left = facing_dir.x < 0
		print("🎯 Using player.get_current_facing_direction():", facing_dir, "Facing left:", player_facing_left)
	elif player_node and player_node.has_method("get_character_sprite"):
		var sprite = player_node.get_character_sprite()
		if sprite:
			player_facing_left = sprite.flip_h
			print("🎯 Using character sprite flip_h:", player_facing_left)
	else:
		# Fallback: try to determine from player's current position vs target position
		var direction_to_target = grid_pos - player_grid_pos
		player_facing_left = direction_to_target.x < 0
		print("🎯 Fallback: Using direction to target:", direction_to_target, "Facing left:", player_facing_left)
	
	# Orient the SlashFX based on player's facing direction
	if slashfx.has_method("update_animation_facing_player_direction"):
		slashfx.update_animation_facing_player_direction(player_facing_left)
		print("🎯 Called update_animation_facing_player_direction with facing_left:", player_facing_left)
	elif slashfx is AnimatedSprite2D:
		# Fallback: manually set flip properties
		# The SlashFX has default flip_h = true and flip_v = true, so we need to account for this
		slashfx.flip_h = not player_facing_left  # Invert the player's facing direction
		slashfx.flip_v = false  # Keep vertical flip off for player-facing orientation
		print("🎯 Manually set flip_h:", slashfx.flip_h, "flip_v:", slashfx.flip_v, "(accounting for default flipped state)")
	
	# Start the slash animation
	if slashfx is AnimatedSprite2D:
		slashfx.play("slash")
		print("✓ Started SlashFX animation at position:", world_pos, "with facing_left:", player_facing_left)
		
		# Set up timer to clean up the SlashFX after animation
		var animation_duration = 0.4  # 8 frames at 20 FPS = 0.4 seconds
		var timer = get_tree().create_timer(animation_duration)
		timer.timeout.connect(func():
			if is_instance_valid(slashfx):
				slashfx.stop()
				slashfx.frame = 0
				slashfx.queue_free()  # Remove the SlashFX after animation completes
				print("✓ SlashFX animation completed and cleaned up")
		)
	else:
		print("⚠ SlashFX is not an AnimatedSprite2D")
		slashfx.queue_free()

func apply_knockback_to_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Apply knockback to the NPC, pushing them 1 tile away from the player"""
	
	# Calculate direction from player to NPC
	var direction = target_pos - player_grid_pos
	# For grid-based movement, we need to handle direction differently
	var knockback_pos = target_pos
	
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
		elif npc.has_method("set_grid_position"):
			# Fallback to instant position change
			npc.set_grid_position(knockback_pos)
			
			# Update Y-sorting
			if npc.has_method("update_z_index_for_ysort"):
				npc.update_z_index_for_ysort()
			print("Applied instant pushback to NPC (distance:", actual_knockback_distance, ", no animation support)")
		else:
			print("NPC does not have push_back or set_grid_position method, skipping knockback")
	else:
		print("Knockback position is not valid, skipping knockback")

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
				if is_instance_valid(npc):
					var npc_pos = Vector2i.ZERO
					
					# Try to get grid position using different methods
					if npc.has_method("get_grid_position"):
						npc_pos = npc.get_grid_position()
					elif "grid_position" in npc:
						npc_pos = npc.grid_position
					elif "grid_pos" in npc:
						npc_pos = npc.grid_pos
					else:
						# Fallback: calculate grid position from world position
						var world_pos = npc.global_position
						var cell_size_used = cell_size if "cell_size" in npc else 48
						npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
					
					if npc_pos == pos:
						is_valid = false
						break
	
	# Check if the position is occupied by the player
	elif pos == player_grid_pos:
		is_valid = false
	
	return is_valid

func apply_knockback_to_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Apply knockback to an oil drum"""
	
	# Calculate direction from player to oil drum
	var direction = target_pos - player_grid_pos
	# For grid-based movement, we need to handle direction differently
	var knockback_pos = target_pos
	
	if direction.x > 0:
		knockback_pos.x += knockback_distance
	elif direction.x < 0:
		knockback_pos.x -= knockback_distance
	elif direction.y > 0:
		knockback_pos.y += knockback_distance
	elif direction.y < 0:
		knockback_pos.y -= knockback_distance
	
	# Check if knockback position is valid
	if is_position_valid_for_knockback(knockback_pos):
		# Use animated pushback if the oil drum supports it
		if oil_drum.has_method("push_back"):
			oil_drum.push_back(knockback_pos)
			print("Applied animated pushback to oil drum (distance:", knockback_distance, ")")
		elif oil_drum.has_method("set_grid_position"):
			# Fallback to instant position change
			oil_drum.set_grid_position(knockback_pos)
			
			# Update Y-sorting
			if oil_drum.has_method("update_z_index_for_ysort"):
				oil_drum.update_z_index_for_ysort()
			print("Applied instant pushback to oil drum (distance:", knockback_distance, ", no animation support)")
		else:
			print("Oil drum does not have push_back or set_grid_position method, skipping knockback")
	else:
		print("Knockback position is not valid, skipping knockback")

# Helper functions to get NPCs and oil drums at positions
func get_npc_at_position(pos: Vector2i) -> Node:
	"""Get the NPC at the given grid position, or null if none"""
	print("=== GETTING NPC AT POSITION (MeleeStrategy) ===")
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

func get_oil_drum_at_position(pos: Vector2i) -> Node:
	"""Get oil drum at the specified grid position"""
	if not card_effect_handler or not card_effect_handler.course:
		return null
	
	var course = card_effect_handler.course
	if not course.has_method("get_oil_drum_at_position"):
		return null
	
	return course.get_oil_drum_at_position(pos)

func update_player_position(new_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	player_grid_pos = new_pos 

func handle_attack_completion() -> void:
	"""Handle attack completion, including return movement if needed"""
	if needs_return_movement:
		print("🔍 DEBUG: Attack completed, returning to original position:", original_player_pos)
		
		# Animate player movement back to original position
		if player_node and player_node.has_method("animate_to_position"):
			player_node.animate_to_position(original_player_pos, func():
				print("🔍 RETURN DEBUG: Return movement completed")
				# Reset movement tracking
				needs_return_movement = false
				original_player_pos = Vector2i.ZERO
				# Emit attack completed signal
				emit_signal("attack_completed")
			)
		else:
			print("Player node does not have animate_to_position method - instant return")
			# Reset movement tracking
			needs_return_movement = false
			original_player_pos = Vector2i.ZERO
			# Emit attack completed signal
			emit_signal("attack_completed")
	else:
		print("🔍 DEBUG: Attack completed, no return movement needed")
		emit_signal("attack_completed") 
