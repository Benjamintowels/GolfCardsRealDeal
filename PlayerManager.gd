extends Node

# Player references
var player_node: Node2D = null
var player_grid_pos := Vector2i(25, 25)
var player_stats: Dictionary = {}

# Health and combat system
var health_bar: HealthBar = null
var block_health_bar: BlockHealthBar = null
var block_active := false
var block_amount := 0

# Character selection and stats
var CHARACTER_STATS = {
	1: { "name": "Layla", "base_mobility": 3 },
	2: { "name": "Benny", "base_mobility": 2 },
	3: { "name": "Clark", "base_mobility": 1 }
}

# Special mode states
var ghost_mode_active := false
var ghost_mode_tween: Tween
var vampire_mode_active := false
var vampire_mode_tween: Tween
var dodge_mode_active := false
var dodge_mode_tween: Tween

# Grid and positioning
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var ysort_objects: Array
var shop_grid_pos: Vector2i

# Signals
signal player_clicked(event: InputEvent)
signal moved_to_tile(grid_pos: Vector2i)
signal player_died()

func setup(grid_size_param: Vector2i, cell_size_param: int, obstacle_map_param: Dictionary, 
		  ysort_objects_param: Array, shop_grid_pos_param: Vector2i, health_bar_param: HealthBar, 
		  block_health_bar_param: BlockHealthBar) -> void:
	"""Initialize the player manager with parameters"""
	grid_size = grid_size_param
	cell_size = cell_size_param
	obstacle_map = obstacle_map_param
	ysort_objects = ysort_objects_param
	shop_grid_pos = shop_grid_pos_param
	health_bar = health_bar_param
	block_health_bar = block_health_bar_param
	
	# Connect to Global equipment buffs signal
	if Global.equipment_buffs_applied.is_connected(update_player_stats_from_equipment):
		Global.equipment_buffs_applied.disconnect(update_player_stats_from_equipment)
	Global.equipment_buffs_applied.connect(update_player_stats_from_equipment)

func create_player() -> void:
	"""Create and setup the player character"""
	# Ensure selected_character is an integer when accessing CHARACTER_STATS
	var character_id = int(Global.selected_character)
	player_stats = Global.CHARACTER_STATS.get(character_id, {})
	
	# Initialize health bar with character stats
	if health_bar:
		var max_hp = player_stats.get("max_hp", 100)
		var current_hp = player_stats.get("current_hp", max_hp)
		health_bar.set_health(current_hp, max_hp)
		print("Health bar initialized: %d/%d HP" % [current_hp, max_hp])
	
	if player_node and is_instance_valid(player_node):
		player_node.set_grid_position(player_grid_pos, ysort_objects, shop_grid_pos)
		player_node.visible = true
		update_player_position()
		return

	var player_scene = preload("res://Characters/Player1.tscn")
	player_node = player_scene.instantiate()
	player_node.name = "Player"
	
	# Add player to groups for smart optimization
	player_node.add_to_group("players")
	player_node.add_to_group("collision_objects")
	
	# Get the grid container from the parent course's grid manager
	var course = get_parent()
	if course and course.has_node("GridManager"):
		var grid_manager = course.get_node("GridManager")
		if grid_manager and grid_manager.has_method("get_camera_container"):
			var grid_container = grid_manager.get_camera_container()
			if grid_container:
				grid_container.add_child(player_node)
			else:
				# Fallback: add to the course directly
				course.add_child(player_node)
		else:
			# Fallback: add to the course directly
			course.add_child(player_node)
	else:
		# Fallback: add to the course directly
		if course:
			course.add_child(player_node)

	var char_scene_path = ""
	var char_scale = Vector2.ONE
	var char_offset = Vector2.ZERO
	
	match Global.selected_character:
		1:
			char_scene_path = "res://Characters/LaylaChar.tscn"
		2:
			char_scene_path = "res://Characters/BennyChar.tscn"
		3:
			char_scene_path = "res://Characters/ClarkChar.tscn"
		_:
			char_scene_path = "res://Characters/BennyChar.tscn" # Default to Benny
	
	if char_scene_path != "":
		var char_scene = load(char_scene_path)
		if char_scene:
			var char_instance = char_scene.instantiate()
			char_instance.scale = char_scale
			char_instance.position = char_offset
			player_node.add_child(char_instance)
			
			# Setup meditation system after character scene is added
			if player_node.has_method("setup_meditation_after_character"):
				player_node.setup_meditation_after_character()

	var base_mobility = player_stats.get("base_mobility", 0)
	# Add safety checks for parameters before calling setup
	if grid_size != Vector2i.ZERO and cell_size > 0:
		player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
	else:
		print("⚠ Warning: Invalid grid parameters in create_player - grid_size:", grid_size, "cell_size:", cell_size)
		# Set default values if parameters are invalid
		if grid_size == Vector2i.ZERO:
			grid_size = Vector2i(50, 50)
		if cell_size <= 0:
			cell_size = 48
		player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
	
	_set_player_node_grid_position_safely(player_grid_pos, ysort_objects, shop_grid_pos)

	player_node.player_clicked.connect(_on_player_input)
	player_node.moved_to_tile.connect(_on_player_moved_to_tile)
	player_node.pushed_to_tile.connect(_on_player_pushed_to_tile)
	


	update_player_position()
	if player_node:
		player_node.visible = false

func update_player_stats_from_equipment() -> void:
	"""Update player stats to reflect equipment buffs"""
	# Ensure selected_character is an integer when accessing CHARACTER_STATS
	var character_id = int(Global.selected_character)
	player_stats = Global.CHARACTER_STATS.get(character_id, {})
	
	if player_node and is_instance_valid(player_node):
		# Check if player_node has the setup method
		if player_node.has_method("setup"):
			var base_mobility = player_stats.get("base_mobility", 0)
			# Add safety checks for parameters
			if grid_size != Vector2i.ZERO and cell_size > 0:
				player_node.setup(grid_size, cell_size, base_mobility, obstacle_map)
				print("Updated player stats with equipment buffs:", player_stats)
			else:
				print("⚠ Warning: Invalid grid parameters - grid_size:", grid_size, "cell_size:", cell_size)
		else:
			print("⚠ Warning: Player node does not have setup method")
	else:
		print("⚠ Warning: Player node is not valid or not initialized")

func take_damage(amount: int) -> void:
	"""Player takes damage and updates health bar"""
	print("PlayerManager: take_damage called with amount:", amount)
	print("PlayerManager: dodge_mode_active =", dodge_mode_active)
	print("PlayerManager: vampire_mode_active =", vampire_mode_active)
	print("PlayerManager: block_active =", block_active)
	
	var damage_to_health = amount
	
	# Check if vampire mode is active - heal instead of taking damage
	if vampire_mode_active:
		print("Vampire mode active - healing for damage instead of taking damage!")
		heal_player(amount)
		return
	
	# Check if dodge mode is active - dodge the damage
	if dodge_mode_active:
		print("Dodge mode active - dodging damage!")
		trigger_dodge_animation()
		return
	
	# Check if block is active and apply damage to block first
	if block_active and block_health_bar and block_health_bar.has_block():
		damage_to_health = block_health_bar.take_block_damage(amount)
		block_amount = block_health_bar.get_block_amount()
		
		# If block is depleted, clear it
		if not block_health_bar.has_block():
			clear_block()
		
		print("Block absorbed damage. Remaining damage to health:", damage_to_health)

	# Apply remaining damage to health
	if health_bar and damage_to_health > 0:
		health_bar.take_damage(damage_to_health)
		# Update Global stats - ensure selected_character is an integer
		var character_id = int(Global.selected_character)
		Global.CHARACTER_STATS[character_id]["current_hp"] = health_bar.current_hp
		print("Player took %d damage to health. Current HP: %d" % [damage_to_health, health_bar.current_hp])
		
		# Play push sound when taking damage
		if player_node:
			var push_sound = player_node.get_node_or_null("Push")
			if push_sound and push_sound is AudioStreamPlayer2D:
				push_sound.play()
				print("✓ Played push sound for damage")
			else:
				print("✗ Push sound not found or not AudioStreamPlayer2D")
		
		# Flash red to indicate damage taken
		if player_node and player_node.has_method("flash_damage"):
			player_node.flash_damage()
			print("✓ Triggered damage flash effect")
		else:
			print("✗ Player node does not have flash_damage method")
		
		# Check if player is defeated
		if not health_bar.is_alive():
			print("Player is defeated!")
			handle_player_death()

func heal_player(amount: int) -> void:
	"""Player heals and updates health bar"""
	if health_bar:
		health_bar.heal(amount)
		# Update Global stats - ensure selected_character is an integer
		var character_id = int(Global.selected_character)
		Global.CHARACTER_STATS[character_id]["current_hp"] = health_bar.current_hp
		print("Player healed %d HP. Current HP: %d" % [amount, health_bar.current_hp])

func get_player_health() -> Dictionary:
	"""Get current player health info"""
	if health_bar:
		return {
			"current_hp": health_bar.current_hp,
			"max_hp": health_bar.max_hp,
			"is_alive": health_bar.is_alive()
		}
	return {"current_hp": 0, "max_hp": 0, "is_alive": false}

# Block system methods
func activate_block(amount: int) -> void:
	"""Activate block system with specified amount"""
	print("Activating block with", amount, "points")
	block_active = true
	block_amount = amount
	
	# Update block health bar
	if block_health_bar:
		block_health_bar.set_block(amount, amount)
	
	# Switch to block sprite for Benny character
	if Global.selected_character == 2:  # Benny
		switch_to_block_sprite()
	
	print("Block activated -", amount, "block points available")

func switch_to_block_sprite() -> void:
	"""Switch Benny character to block sprite"""
	print("=== SWITCH TO BLOCK SPRITE CALLED ===")
	if not player_node:
		print("✗ No player node found")
		return
	
	# Find the normal character sprite and block sprite in the player node
	var normal_sprite = null
	var block_sprite = null
	
	print("Searching for sprites in player node children...")
	for child in player_node.get_children():
		print("  Child:", child.name, "Type:", child.get_class())
		# The character scene (BennyChar) is a child of the player node
		if child.name == "BennyChar" or child.name == "LaylaChar" or child.name == "ClarkChar":
			print("  Found character scene:", child.name)
			# Look for sprites within the character scene
			for grandchild in child.get_children():
				print("    Grandchild:", grandchild.name, "Type:", grandchild.get_class())
				if grandchild is Sprite2D and grandchild.name == "Sprite2D":
					normal_sprite = grandchild
					print("    ✓ Found normal sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyBlock":
					block_sprite = grandchild
					print("    ✓ Found block sprite:", grandchild.name)
			break
	
	print("Normal sprite found:", normal_sprite != null)
	print("Block sprite found:", block_sprite != null)
	
	if normal_sprite and block_sprite:
		# Hide normal sprite, show block sprite
		normal_sprite.visible = false
		block_sprite.visible = true
		print("✓ Switched to block sprite")
	else:
		print("✗ Could not find required sprites for block animation")

func switch_to_normal_sprite() -> void:
	"""Switch Benny character back to normal sprite"""
	print("=== SWITCH TO NORMAL SPRITE CALLED ===")
	if not player_node:
		print("✗ No player node found")
		return
	
	# Find all sprites in the player node
	var normal_sprite = null
	var block_sprite = null
	var dodge_sprite = null
	var dodge_ready_sprite = null
	
	for child in player_node.get_children():
		# The character scene (BennyChar) is a child of the player node
		if child.name == "BennyChar" or child.name == "LaylaChar" or child.name == "ClarkChar":
			# Look for sprites within the character scene
			for grandchild in child.get_children():
				if grandchild is Sprite2D and grandchild.name == "Sprite2D":
					normal_sprite = grandchild
				elif grandchild is Sprite2D and grandchild.name == "BennyBlock":
					block_sprite = grandchild
				elif grandchild is Sprite2D and grandchild.name == "BennyDodge":
					dodge_sprite = grandchild
				elif grandchild is Sprite2D and grandchild.name == "BennyDodgeReady":
					dodge_ready_sprite = grandchild
			break
	
	if normal_sprite:
		# Show normal sprite, hide all other sprites
		normal_sprite.visible = true
		if block_sprite:
			block_sprite.visible = false
		if dodge_sprite:
			dodge_sprite.visible = false
		if dodge_ready_sprite:
			dodge_ready_sprite.visible = false
		print("✓ Switched to normal sprite")
	else:
		print("✗ Could not find normal sprite")

func update_block_sprite_flip() -> void:
	"""Update block sprite flip based on mouse position (for Benny character)"""
	if not player_node or Global.selected_character != 2:  # Only for Benny
		return
	
	# Find the block sprite
	var block_sprite = null
	for child in player_node.get_children():
		# The character scene (BennyChar) is a child of the player node
		if child.name == "BennyChar" or child.name == "LaylaChar" or child.name == "ClarkChar":
			# Look for sprites within the character scene
			for grandchild in child.get_children():
				if grandchild is Sprite2D and grandchild.name == "BennyBlock":
					block_sprite = grandchild
					break
			if block_sprite:
				break
	
	if not block_sprite:
		return
	
	# Get mouse position and determine flip
	var mouse_pos = get_viewport().get_mouse_position()
	var player_screen_pos = player_node.global_position
	
	if mouse_pos.x < player_screen_pos.x:
		block_sprite.flip_h = true
	else:
		block_sprite.flip_h = false

func update_dodge_sprite_flip() -> void:
	"""Update dodge sprite flip based on mouse position"""
	if not player_node:
		return
	
	# Get mouse position and determine flip
	var mouse_pos = get_viewport().get_mouse_position()
	var player_screen_pos = player_node.global_position
	
	var sprite = player_node.get_character_sprite()
	if sprite:
		if mouse_pos.x < player_screen_pos.x:
			sprite.flip_h = true
		else:
			sprite.flip_h = false

func switch_to_dodge_ready_sprite() -> void:
	"""Switch Benny character to dodge ready sprite"""
	print("=== SWITCH TO DODGE READY SPRITE CALLED ===")
	if not player_node:
		print("✗ No player node found")
		return
	
	# Find all sprites in the player node
	var normal_sprite = null
	var dodge_ready_sprite = null
	var dodge_sprite = null
	var block_sprite = null
	
	print("Searching for sprites in player node children...")
	for child in player_node.get_children():
		print("  Child:", child.name, "Type:", child.get_class())
		# The character scene (BennyChar) is a child of the player node
		if child.name == "BennyChar" or child.name == "LaylaChar" or child.name == "ClarkChar":
			print("  Found character scene:", child.name)
			# Look for sprites within the character scene
			for grandchild in child.get_children():
				print("    Grandchild:", grandchild.name, "Type:", grandchild.get_class())
				if grandchild is Sprite2D and grandchild.name == "Sprite2D":
					normal_sprite = grandchild
					print("    ✓ Found normal sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyDodgeReady":
					dodge_ready_sprite = grandchild
					print("    ✓ Found dodge ready sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyDodge":
					dodge_sprite = grandchild
					print("    ✓ Found dodge sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyBlock":
					block_sprite = grandchild
					print("    ✓ Found block sprite:", grandchild.name)
	
	if normal_sprite and dodge_ready_sprite:
		# Hide all sprites, show only dodge ready sprite
		normal_sprite.visible = false
		if dodge_sprite:
			dodge_sprite.visible = false
		if block_sprite:
			block_sprite.visible = false
		dodge_ready_sprite.visible = true
		print("✓ Switched to dodge ready sprite")
		
		# Auto-switch back to normal sprite after a brief moment
		var timer = get_tree().create_timer(1.0)  # Show for 1 second
		timer.timeout.connect(func():
			if dodge_mode_active:  # Only if still in dodge mode
				switch_to_normal_sprite()
		)
	else:
		print("✗ Could not find required sprites for dodge ready animation")

func switch_to_escape_sprite() -> void:
	"""Switch Benny character to escape sprite"""
	print("=== SWITCH TO ESCAPE SPRITE CALLED ===")
	if not player_node:
		print("✗ No player node found")
		return
	
	# Find all sprites in the player node
	var normal_sprite = null
	var escape_sprite = null
	var block_sprite = null
	var dodge_sprite = null
	var dodge_ready_sprite = null
	
	print("Searching for sprites in player node children...")
	for child in player_node.get_children():
		print("  Child:", child.name, "Type:", child.get_class())
		# The character scene (BennyChar) is a child of the player node
		if child.name == "BennyChar" or child.name == "LaylaChar" or child.name == "ClarkChar":
			print("  Found character scene:", child.name)
			# Look for sprites within the character scene
			for grandchild in child.get_children():
				print("    Grandchild:", grandchild.name, "Type:", grandchild.get_class())
				if grandchild is Sprite2D and grandchild.name == "Sprite2D":
					normal_sprite = grandchild
					print("    ✓ Found normal sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyEscape":
					escape_sprite = grandchild
					print("    ✓ Found escape sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyBlock":
					block_sprite = grandchild
					print("    ✓ Found block sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyDodge":
					dodge_sprite = grandchild
					print("    ✓ Found dodge sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyDodgeReady":
					dodge_ready_sprite = grandchild
					print("    ✓ Found dodge ready sprite:", grandchild.name)
	
	if normal_sprite and escape_sprite:
		# Hide all sprites, show only escape sprite
		normal_sprite.visible = false
		if block_sprite:
			block_sprite.visible = false
		if dodge_sprite:
			dodge_sprite.visible = false
		if dodge_ready_sprite:
			dodge_ready_sprite.visible = false
		escape_sprite.visible = true
		print("✓ Switched to escape sprite")
	else:
		print("✗ Could not find required sprites for escape animation")

func switch_from_escape_sprite() -> void:
	"""Switch Benny character back from escape sprite to normal"""
	print("=== SWITCH FROM ESCAPE SPRITE CALLED ===")
	if not player_node:
		print("✗ No player node found")
		return
	
	# Find all sprites in the player node
	var normal_sprite = null
	var escape_sprite = null
	var block_sprite = null
	var dodge_sprite = null
	var dodge_ready_sprite = null
	
	for child in player_node.get_children():
		# The character scene (BennyChar) is a child of the player node
		if child.name == "BennyChar" or child.name == "LaylaChar" or child.name == "ClarkChar":
			# Look for sprites within the character scene
			for grandchild in child.get_children():
				if grandchild is Sprite2D and grandchild.name == "Sprite2D":
					normal_sprite = grandchild
				elif grandchild is Sprite2D and grandchild.name == "BennyEscape":
					escape_sprite = grandchild
				elif grandchild is Sprite2D and grandchild.name == "BennyBlock":
					block_sprite = grandchild
				elif grandchild is Sprite2D and grandchild.name == "BennyDodge":
					dodge_sprite = grandchild
				elif grandchild is Sprite2D and grandchild.name == "BennyDodgeReady":
					dodge_ready_sprite = grandchild
			break
	
	if normal_sprite and escape_sprite:
		# Hide escape sprite, show normal sprite
		escape_sprite.visible = false
		normal_sprite.visible = true
		print("✓ Switched from escape sprite to normal")
	else:
		print("✗ Could not find required sprites for escape animation")

func switch_to_dodge_sprite() -> void:
	"""Switch Benny character to dodge sprite"""
	print("=== SWITCH TO DODGE SPRITE CALLED ===")
	if not player_node:
		print("✗ No player node found")
		return
	
	# Find all sprites in the player node
	var normal_sprite = null
	var dodge_sprite = null
	var dodge_ready_sprite = null
	var block_sprite = null
	
	print("Searching for sprites in player node children...")
	for child in player_node.get_children():
		print("  Child:", child.name, "Type:", child.get_class())
		# The character scene (BennyChar) is a child of the player node
		if child.name == "BennyChar" or child.name == "LaylaChar" or child.name == "ClarkChar":
			print("  Found character scene:", child.name)
			# Look for sprites within the character scene
			for grandchild in child.get_children():
				print("    Grandchild:", grandchild.name, "Type:", grandchild.get_class())
				if grandchild is Sprite2D and grandchild.name == "Sprite2D":
					normal_sprite = grandchild
					print("    ✓ Found normal sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyDodge":
					dodge_sprite = grandchild
					print("    ✓ Found dodge sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyDodgeReady":
					dodge_ready_sprite = grandchild
					print("    ✓ Found dodge ready sprite:", grandchild.name)
				elif grandchild is Sprite2D and grandchild.name == "BennyBlock":
					block_sprite = grandchild
					print("    ✓ Found block sprite:", grandchild.name)
	
	if normal_sprite and dodge_sprite:
		# Hide all sprites, show only dodge sprite
		normal_sprite.visible = false
		if dodge_ready_sprite:
			dodge_ready_sprite.visible = false
		if block_sprite:
			block_sprite.visible = false
		dodge_sprite.visible = true
		print("✓ Switched to dodge sprite")
		
		# Auto-switch back to normal sprite after dodge animation
		var timer = get_tree().create_timer(0.6)  # Show for 0.6 seconds (dodge animation duration)
		timer.timeout.connect(func():
			if dodge_mode_active:  # Only if still in dodge mode
				switch_to_normal_sprite()
		)
	else:
		print("✗ Could not find required sprites for dodge animation")

func clear_block() -> void:
	"""Clear the block system"""
	print("Clearing block")
	block_active = false
	block_amount = 0
	
	# Update block health bar
	if block_health_bar:
		block_health_bar.clear_block()
	
	# Switch back to normal sprite for Benny character
	if Global.selected_character == 2:  # Benny
		switch_to_normal_sprite()
	
	print("Block cleared")

func has_block() -> bool:
	"""Check if player has active block"""
	return block_active

func get_block_amount() -> int:
	"""Get current block amount"""
	return block_amount

func handle_player_death() -> void:
	"""Handle player death sequence"""
	print("=== PLAYER DEATH SEQUENCE ===")
	player_died.emit()
	
	# Call GameStateManager's death handling
	var course = get_parent()
	if course and course.game_state_manager:
		course.game_state_manager.handle_player_death()
	else:
		# Fallback: direct scene transition
		get_tree().change_scene_to_file("res://DeathScene.tscn")

func _on_player_input(event: InputEvent) -> void:
	"""Handle player input events"""
	player_clicked.emit(event)

func _on_player_moved_to_tile(grid_pos: Vector2i) -> void:
	"""Handle player movement to a new tile"""
	player_grid_pos = grid_pos
	moved_to_tile.emit(grid_pos)

func _on_player_pushed_to_tile(grid_pos: Vector2i) -> void:
	"""Handle when player is pushed to a new tile - this is forced movement, not voluntary movement"""
	player_grid_pos = grid_pos
	# Don't emit moved_to_tile signal since this is forced movement
	print("PlayerManager: Player was pushed to tile:", grid_pos)

func update_player_position() -> void:
	"""Update player's visual position based on grid position"""
	if not player_node:
		return
	
	# Get the course reference to access camera container
	var course = get_parent()
	if not course:
		return
	
	var camera_container = course.grid_manager.get_camera_container()
	if not camera_container:
		return
	
	# Calculate world position
	var world_pos = Vector2(player_grid_pos.x * cell_size + cell_size/2, player_grid_pos.y * cell_size + cell_size/2)
	var local_pos = world_pos - camera_container.global_position
	
	# Update player position
	player_node.position = local_pos
	
	# Update player's grid position reference without triggering unintended animations
	if player_node.has_method("set_grid_position"):
		_set_player_node_grid_position_safely(player_grid_pos, ysort_objects, shop_grid_pos)
	
	# Update camera snap back position to player's current position
	if course.camera_manager:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center: Vector2 = player_node.global_position + player_size / 2
		course.camera_manager.update_camera_snap_back_position(player_center)

# Cleanup function
func _exit_tree() -> void:
	"""Cleanup when PlayerManager is destroyed"""
	# Disconnect from Global equipment buffs signal
	if Global.equipment_buffs_applied.is_connected(update_player_stats_from_equipment):
		Global.equipment_buffs_applied.disconnect(update_player_stats_from_equipment)

# Special mode management
func activate_ghost_mode() -> void:
	"""Activate ghost mode - make player transparent and ignored by NPCs"""
	print("=== ACTIVATING GHOST MODE ===")
	
	if ghost_mode_active:
		print("Ghost mode already active, ignoring activation")
		return
	
	ghost_mode_active = true
	print("Ghost mode activated")
	
	# Make player sprite transparent
	if player_node:
		var sprite = player_node.get_character_sprite()
		if sprite:
			# Kill any existing tween
			if ghost_mode_tween and ghost_mode_tween.is_valid():
				ghost_mode_tween.kill()
			
			# Create new tween for transparency animation
			ghost_mode_tween = create_tween()
			ghost_mode_tween.tween_property(sprite, "modulate:a", 0.4, 0.5)  # Animate to 40% opacity
			ghost_mode_tween.set_trans(Tween.TRANS_SINE)
			ghost_mode_tween.set_ease(Tween.EASE_OUT)
			print("Player sprite transparency animation started")
		else:
			print("Warning: Could not find player sprite for ghost mode")
	
	print("=== GHOST MODE ACTIVATED ===")

func deactivate_ghost_mode() -> void:
	"""Deactivate ghost mode - restore player visibility"""
	print("=== DEACTIVATING GHOST MODE ===")
	
	if not ghost_mode_active:
		print("Ghost mode not active, ignoring deactivation")
		return
	
	ghost_mode_active = false
	print("Ghost mode deactivated")
	
	# Restore player sprite visibility
	if player_node:
		var sprite = player_node.get_character_sprite()
		if sprite:
			# Kill any existing tween
			if ghost_mode_tween and ghost_mode_tween.is_valid():
				ghost_mode_tween.kill()
			
			# Create new tween to restore opacity
			ghost_mode_tween = create_tween()
			ghost_mode_tween.tween_property(sprite, "modulate:a", 1.0, 0.5)  # Animate back to full opacity
			ghost_mode_tween.set_trans(Tween.TRANS_SINE)
			ghost_mode_tween.set_ease(Tween.EASE_OUT)
			print("Player sprite opacity restoration started")
		else:
			print("Warning: Could not find player sprite for ghost mode deactivation")
	
	print("=== GHOST MODE DEACTIVATED ===")

func is_ghost_mode_active() -> bool:
	"""Check if ghost mode is currently active"""
	return ghost_mode_active

func activate_vampire_mode() -> void:
	"""Activate vampire mode - make player heal from damage and apply dark red hue"""
	print("=== ACTIVATING VAMPIRE MODE ===")
	
	if vampire_mode_active:
		print("Vampire mode already active, ignoring activation")
		return
	
	vampire_mode_active = true
	print("Vampire mode activated")
	
	# Apply dark red hue to player sprite
	if player_node:
		var sprite = player_node.get_character_sprite()
		if sprite:
			# Kill any existing tween
			if vampire_mode_tween and vampire_mode_tween.is_valid():
				vampire_mode_tween.kill()
			
			# Create new tween for dark red hue animation
			vampire_mode_tween = create_tween()
			# Apply dark red hue (reduce green and blue channels)
			vampire_mode_tween.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.5)  # Dark red hue
			vampire_mode_tween.set_trans(Tween.TRANS_SINE)
			vampire_mode_tween.set_ease(Tween.EASE_OUT)
			print("Player sprite dark red hue animation started")
		else:
			print("Warning: Could not find player sprite for vampire mode")
	
	print("=== VAMPIRE MODE ACTIVATED ===")

func deactivate_vampire_mode() -> void:
	"""Deactivate vampire mode - restore player normal appearance"""
	print("=== DEACTIVATING VAMPIRE MODE ===")
	
	if not vampire_mode_active:
		print("Vampire mode not active, ignoring deactivation")
		return
	
	vampire_mode_active = false
	print("Vampire mode deactivated")
	
	# Restore player sprite normal appearance
	if player_node:
		var sprite = player_node.get_character_sprite()
		if sprite:
			# Kill any existing tween
			if vampire_mode_tween and vampire_mode_tween.is_valid():
				vampire_mode_tween.kill()
			
			# Create new tween to restore normal appearance
			vampire_mode_tween = create_tween()
			vampire_mode_tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)  # Restore normal color
			vampire_mode_tween.set_trans(Tween.TRANS_SINE)
			vampire_mode_tween.set_ease(Tween.EASE_OUT)
			print("Player sprite normal appearance restoration started")
		else:
			print("Warning: Could not find player sprite for vampire mode deactivation")
	
	print("=== VAMPIRE MODE DEACTIVATED ===")

func is_vampire_mode_active() -> bool:
	"""Check if vampire mode is currently active"""
	return vampire_mode_active

func activate_dodge_mode() -> void:
	"""Activate dodge mode - make player dodge incoming damage"""
	print("=== ACTIVATING DODGE MODE ===")
	print("Global.selected_character =", Global.selected_character)
	
	if dodge_mode_active:
		print("Dodge mode already active, ignoring activation")
		return
	
	dodge_mode_active = true
	print("Dodge mode activated - dodge_mode_active =", dodge_mode_active)
	
	# Show BennyDodgeReady sprite briefly to indicate dodge is active
	if Global.selected_character == 2:  # Benny
		print("Benny character detected - switching to dodge ready sprite")
		switch_to_dodge_ready_sprite()
	else:
		print("Not Benny character (selected_character =", Global.selected_character, ") - no sprite switching")
	
	print("=== DODGE MODE ACTIVATED ===")

func deactivate_dodge_mode() -> void:
	"""Deactivate dodge mode - restore player normal appearance"""
	print("=== DEACTIVATING DODGE MODE ===")
	
	if not dodge_mode_active:
		print("Dodge mode not active, ignoring deactivation")
		return
	
	dodge_mode_active = false
	print("Dodge mode deactivated")
	
	# Switch back to normal sprite for Benny character
	if Global.selected_character == 2:  # Benny
		switch_to_normal_sprite()
	
	print("=== DODGE MODE DEACTIVATED ===")

func is_dodge_mode_active() -> bool:
	"""Check if dodge mode is currently active"""
	return dodge_mode_active

func trigger_dodge_animation() -> void:
	"""Trigger the dodge animation when damage is avoided"""
	print("=== TRIGGERING DODGE ANIMATION ===")
	
	# Play dodge sound
	play_dodge_sound()
	
	# Switch to dodge sprite for Benny character
	if Global.selected_character == 2:  # Benny
		switch_to_dodge_sprite()
	
	# Animate dodge movement
	animate_dodge_movement()
	
	# Wait for animation to complete
	await get_tree().create_timer(0.6).timeout  # Wait for animation to complete

func animate_dodge_movement() -> void:
	"""Animate the dodge movement"""
	print("=== ANIMATING DODGE MOVEMENT ===")
	
	if not player_node:
		print("✗ No player node found")
		return
	
	# Store original position
	var original_position = player_node.global_position
	
	# Calculate dodge direction (slightly to the side)
	var dodge_offset = Vector2(20, 0)  # Move 20 pixels to the right
	
	# Create tween for dodge movement
	var dodge_tween = create_tween()
	
	# Move to dodge position
	dodge_tween.tween_property(player_node, "global_position", original_position + dodge_offset, 0.3)
	dodge_tween.set_trans(Tween.TRANS_SINE)
	dodge_tween.set_ease(Tween.EASE_OUT)
	
	# Wait a moment, then move back
	await get_tree().create_timer(0.3).timeout
	
	var return_tween = create_tween()
	return_tween.tween_property(player_node, "global_position", original_position, 0.3)
	return_tween.set_trans(Tween.TRANS_SINE)
	return_tween.set_ease(Tween.EASE_IN)
	
	print("✓ Dodge movement animation completed")



func play_dodge_sound() -> void:
	"""Play the dodge sound effect"""
	if player_node:
		var dodge_sound = player_node.get_node_or_null("Dodge")
		if dodge_sound and dodge_sound is AudioStreamPlayer2D:
			dodge_sound.play()
			print("✓ Playing dodge sound")
		else:
			print("✗ Dodge sound not found in player node")

# Getter methods
func get_player_node() -> Node2D:
	"""Get the player node"""
	return player_node

func get_player_grid_pos() -> Vector2i:
	"""Get the player's grid position"""
	return player_grid_pos

func set_player_grid_pos(pos: Vector2i) -> void:
	"""Set the player's grid position"""
	player_grid_pos = pos
	update_player_position()

func get_player_stats() -> Dictionary:
	"""Get the player's stats"""
	return player_stats

func set_player_stats(stats: Dictionary) -> void:
	"""Set the player's stats"""
	player_stats = stats

func get_character_name() -> String:
	"""Get the current character's name"""
	return player_stats.get("name", "Unknown")

# ===== PLAYER STATE MANAGEMENT =====

func update_player_mouse_facing_state(game_state_manager: Node, launch_manager: Node, camera: Node, weapon_handler: Node) -> void:
	"""Update the player's mouse facing state based on current game phase and launch state"""
	if not player_node or not player_node.has_method("set_game_phase"):
		return
	
	# Update game phase
	player_node.set_game_phase(game_state_manager.get_game_phase())
	
	# Update launch state from LaunchManager
	var is_charging = false
	var is_charging_height = false
	var is_selecting_height = false
	if launch_manager:
		is_charging = launch_manager.is_charging
		is_charging_height = launch_manager.is_charging_height
		is_selecting_height = launch_manager.is_selecting_height
	
	player_node.set_launch_state(is_charging, is_charging_height, is_selecting_height)
	
	# Update launch mode state
	var is_in_launch_mode = (game_state_manager.get_game_phase() == "ball_flying")
	player_node.set_launch_mode(is_in_launch_mode)
	
	# Set camera reference if not already set
	if player_node.has_method("set_camera_reference") and camera:
		player_node.set_camera_reference(camera)
	
	# Update block sprite flip to match normal sprite
	update_block_sprite_flip()
	
	# Update dodge sprite flip to match normal sprite
	update_dodge_sprite_flip()
	
	# Hide weapon when game phase changes to move (unless GrenadeLauncherClubCard is selected)
	if game_state_manager.get_game_phase() == "move" and game_state_manager.get_selected_club() != "GrenadeLauncherClubCard" and weapon_handler:
		weapon_handler.hide_weapon()

# ===== PLAYER MOVEMENT HANDLING =====

func handle_player_moved_to_tile(new_grid_pos: Vector2i, game_state_manager: Node, movement_controller: Node, attack_handler: Node, launch_manager: Node, course: Node) -> void:
	"""Handle when player moves to a new tile"""
	set_player_grid_pos(new_grid_pos)
	movement_controller.update_player_position(new_grid_pos)
	attack_handler.update_player_position(new_grid_pos)
	
	# Check for fire damage when player moves to new tile
	check_player_fire_damage(game_state_manager)
	
	# Check for SuitCase interaction
	if game_state_manager.get_suitcase_grid_position() != Vector2i.ZERO and get_player_grid_pos() == game_state_manager.get_suitcase_grid_position():
		print("=== SUITCASE REACHED ===")
		print("Player grid position:", get_player_grid_pos())
		print("SuitCase grid position:", game_state_manager.get_suitcase_grid_position())
		course._on_suitcase_reached()
		return  # Don't exit movement mode yet
	
func _handle_tile_interactions(course: Node) -> void:
	"""Handle tile-based interactions like FW tile detection"""
	# Check for FightRoom exit (FW tile) interaction
	var current_tile_type = _get_tile_type_at_position(get_player_grid_pos(), course)
	print("🔍 TILE DEBUG: Player at", get_player_grid_pos(), "tile type:", current_tile_type)
	
	# Also check if this is a fight room at all
	var is_fight_room = course.has_method("get_game_state_manager") and course.get_game_state_manager().get_current_puzzle_type() == "fight_room"
	print("🔍 PUZZLE DEBUG: Is fight room?", is_fight_room)
	
	if current_tile_type == "FW":
		print("=== FIGHT ROOM EXIT DETECTED ===")
		print("Player stepped on FW tile at:", get_player_grid_pos())
		print("Fight room key collected:", course.fight_room_key_collected if "fight_room_key_collected" in course else false)
		if course.game_state_manager:
			course.game_state_manager.set_fight_room_exit_detected(true)
		
		# Only show dialog if key has been collected (door is unlocked)
		if "fight_room_key_collected" in course and course.fight_room_key_collected:
			print("🔓 FW TILE: Key collected, showing exit dialog")
			if course.has_method("show_fight_room_exit_dialog"):
				course.show_fight_room_exit_dialog()
			else:
				print("❌ FW TILE: show_fight_room_exit_dialog method not found in course")
		else:
			print("🔒 FW TILE: Key not collected yet, tile should be blocked")
	else:
		if course.game_state_manager:
			course.game_state_manager.set_fight_room_exit_detected(false)

# ===== FIRE DAMAGE HANDLING =====

func check_player_fire_damage(game_state_manager: Node) -> void:
	"""Check if player should take fire damage from active fire tiles"""
	if not get_player_node() or not get_player_node().has_method("take_damage"):
		return
	
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	var player_took_damage = false
	
	for fire_tile in fire_tiles:
		if not is_instance_valid(fire_tile) or not fire_tile.has_method("is_fire_active"):
			continue
		
		# Skip if fire tile is not active (scorched)
		if not fire_tile.is_fire_active():
			continue
		
		var fire_tile_pos = fire_tile.get_tile_position()
		
		# Check if this fire tile has already damaged the player this turn
		if fire_tile_pos in game_state_manager.fire_tiles_that_damaged_player:
			continue
		
		# Check if player is on the fire tile or adjacent to it
		if is_player_affected_by_fire_tile(fire_tile_pos):
			# Determine damage amount
			var damage = 30 if get_player_grid_pos() == fire_tile_pos else 15
			
			# Apply damage to player
			get_player_node().take_damage(damage)
			print("Player took", damage, "fire damage from fire tile at", fire_tile_pos)
			
			# Play FlameOn sound effect
			var sound_manager = get_node_or_null("../SoundManager")
			if sound_manager and sound_manager.has_method("play_flame_on_sound"):
				sound_manager.play_flame_on_sound(get_player_node().global_position if get_player_node() else Vector2.ZERO)
			
			# Mark this fire tile as having damaged the player this turn
			game_state_manager.fire_tiles_that_damaged_player.append(fire_tile_pos)
			player_took_damage = true

	if player_took_damage:
		print("Player fire damage check complete - damage applied")

func is_player_affected_by_fire_tile(fire_tile_pos: Vector2i) -> bool:
	"""Check if player is on the fire tile or adjacent to it"""
	# Direct hit - player is on the fire tile
	if get_player_grid_pos() == fire_tile_pos:
		return true
	
	# Adjacent tiles (8-directional)
	var adjacent_positions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, -1),  # Up-right
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	
	for direction in adjacent_positions:
		if get_player_grid_pos() == fire_tile_pos + direction:
			return true
	
	return false

func reset_fire_damage_tracking(game_state_manager: Node) -> void:
	"""Reset the fire damage tracking at the start of each turn"""
	game_state_manager.fire_tiles_that_damaged_player.clear()

# ===== PLAYER POSITIONING =====

# Safely call player's set_grid_position without triggering duplicate/conflicting animations
func _set_player_node_grid_position_safely(pos: Vector2i, ysort: Array = [], shop_pos: Vector2i = Vector2i.ZERO) -> void:
	if not player_node:
		return
	var had_flag := false
	var original_enabled := false
	if "animations_enabled" in player_node:
		had_flag = true
		original_enabled = player_node.animations_enabled
		player_node.animations_enabled = false
	player_node.set_grid_position(pos, ysort, shop_pos)
	if had_flag:
		player_node.animations_enabled = original_enabled

func update_player_position_with_ball_creation(course: Node) -> void:
	"""Update player position and handle related logic including ball creation"""
	if not get_player_node():
		return
	var sprite = get_player_node().get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(course.cell_size, course.cell_size)

	_set_player_node_grid_position_safely(get_player_grid_pos(), course.ysort_objects)
	
	var player_center: Vector2 = get_player_node().global_position + player_size / 2
	course.camera_manager.update_camera_snap_back_position(player_center)
	
	# Create ball at tile center for all shots (including initial tee placement)
	var tile_center: Vector2 = Vector2(get_player_grid_pos().x * course.cell_size + course.cell_size/2, get_player_grid_pos().y * course.cell_size + course.cell_size/2) + course.grid_manager.get_camera_container().global_position
	course.launch_manager.create_or_update_ball_at_player_center(tile_center, course)
	
	if not course.game_state_manager.is_placing_player:
		# Cancel any ongoing pin-to-tee transition
		if course.camera_manager:
			course.camera_manager.cancel_pin_to_tee_transition()
		
		# Only create camera tween if camera is not already at the correct position
		# This prevents conflicts when camera has been immediately positioned (like in out-of-bounds)
		var camera_distance = course.camera.position.distance_to(player_center)
		if camera_distance > 5.0:  # Only tween if camera is more than 5 pixels away
			course.camera_manager.create_camera_tween(player_center, 0.5)
		else:
			# Camera is already close enough, just ensure it's exactly on target
			course.camera.position = player_center

func reset_player_to_tee(map_manager: Node, course: Node) -> void:
	"""Reset player to tee position"""
	for y in map_manager.level_layout.size():
		for x in map_manager.level_layout[y].size():
			if map_manager.get_tile_type(x, y) == "Tee":
				set_player_grid_pos(Vector2i(x, y))
				update_player_position_with_ball_creation(course)
				return
	set_player_grid_pos(Vector2i(25, 25))
	update_player_position_with_ball_creation(course)

func reset_player_for_boss_fight() -> void:
	"""Reset player position for boss fight - position at tee area"""
	print("=== RESETTING PLAYER FOR BOSS FIGHT ===")
	
	# Get the course reference
	var course = get_parent()
	if not course:
		print("ERROR: Course1 not found for boss fight player reset!")
		return
	
	# Find tee position in the boss fight layout
	var tee_found = false
	for y in course.map_manager.level_layout.size():
		for x in course.map_manager.level_layout[y].size():
			if course.map_manager.get_tile_type(x, y) == "Tee":
				set_player_grid_pos(Vector2i(x, y))
				tee_found = true
				print("Found tee position for boss fight at:", Vector2i(x, y))
				break
		if tee_found:
			break
	
	# Fallback to default position if no tee found
	if not tee_found:
		set_player_grid_pos(Vector2i(9, 15))  # Default position in boss fight layout
		print("No tee found, using default boss fight position:", Vector2i(9, 15))
	
	# Update player position and create ball
	update_player_position_with_ball_creation(course)
	
	# Ensure player is visible and animations are enabled
	if player_node:
		player_node.visible = true
		if player_node.has_method("enable_animations"):
			player_node.enable_animations()
	
	print("=== PLAYER RESET FOR BOSS FIGHT COMPLETE ===")

func _get_tile_type_at_position(grid_pos: Vector2i, course: Node) -> String:
	"""Get the tile type at a specific grid position"""
	if not course or not course.has_node("MapManager"):
		return ""
	
	var map_manager = course.get_node("MapManager")
	if not map_manager or not map_manager.has_method("get_tile_type"):
		return ""
	
	# Check if position is within bounds
	if grid_pos.x < 0 or grid_pos.y < 0:
		return ""
	
	return map_manager.get_tile_type(grid_pos.x, grid_pos.y)

 
