extends CharacterBody2D

# Import TreeData for sprite variations
const TreeData = preload("res://Obstacles/TreeData.gd")

# Tree Cutting System
# This system allows PowerBeam to cut trees into stumps and falling tops
# 
# Required scene structure:
# - TreeStump (Sprite2D): The remaining stump after cutting
#   - TopHeight (Marker2D): Height marker for collision detection
# - TreeTop (Sprite2D): The falling top section
#   - TreeTopAnimationPlayer (AnimationPlayer): Contains "pop_off" animation
#   - YSortPoint (Node2D): For proper Y-sorting when falling
#   - Area2D: For collision detection
# - Sprite2D: Default tree sprite (hidden when cut)
#   - TopHeight (Marker2D): Default height marker (hidden when cut)
#   - AnimationPlayer: For hover transparency effect
# - TrunkBaseArea (Area2D): Collision detection for PowerBeam
# - LightOccluder2D: Lighting occlusion (hidden when cut)



var blocks_movement := true  # Trees block by default; water might not

# TreeData support for sprite variations
@export var tree_data: TreeData

# Tree cutting system variables
var is_tree_cut := false
var tree_cut_direction := Vector2.ZERO
var tree_cut_rotation := 0.0

func blocks(): 
	return blocks_movement

# Returns the Y-sorting reference point (base of trunk)
func get_y_sort_point() -> float:
	if is_tree_cut:
		# When tree is cut, use TreeTop's YSortPoint
		var tree_top = get_node_or_null("TreeTop")
		if tree_top:
			var ysort_point = tree_top.get_node_or_null("YSortPoint")
			if ysort_point:
				return ysort_point.global_position.y
	
	# Default: use the original YsortPoint or tree position
	var ysort_point_node = get_node_or_null("YsortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

# Get the correct height marker based on whether tree is cut or not
func get_height_marker() -> Node2D:
	"""Get the appropriate height marker for collision detection"""
	if is_tree_cut:
		# Use stump's TopHeight marker when tree is cut
		var tree_stump = get_node_or_null("TreeStump")
		if tree_stump:
			var stump_top_height = tree_stump.get_node_or_null("TopHeight")
			if stump_top_height:
				return stump_top_height
		# Fallback to stump position if no marker
		if tree_stump:
			return tree_stump
	else:
		# Use default TopHeight marker when tree is intact
		var default_top_height = get_node_or_null("TopHeight")
		if default_top_height:
			return default_top_height
	
	# Fallback to self if no markers found
	return self

func is_cut() -> bool:
	"""Check if the tree has been cut"""
	return is_tree_cut

func _initialize_tree_cutting_components():
	"""Initialize tree cutting components to be hidden initially"""
	var tree_stump = get_node_or_null("TreeStump")
	var tree_top = get_node_or_null("TreeTop")
	
	if tree_stump:
		tree_stump.visible = false
		print("✓ TreeStump initialized (hidden)")
	
	if tree_top:
		tree_top.visible = false
		print("✓ TreeTop initialized (hidden)")
	
	print("✓ Tree cutting components initialized")

# Tree cutting system - called by PowerBeam
func take_damage(damage: int, attack_type: String = ""):
	"""Handle damage by cutting the tree only for specific attacks"""
	print("=== TREE TAKE_DAMAGE CALLED ===")
	print("Tree name:", name)
	print("Damage:", damage)
	print("Attack type:", attack_type)
	print("Is tree already cut:", is_tree_cut)
	
	if is_tree_cut:
		print("Tree is already cut - ignoring damage")
		return  # Already cut
	
	# Only cut the tree for specific attack types
	var can_cut_tree = false
	
	# Check if this is a PowerBeam attack
	if attack_type == "power_beam":
		can_cut_tree = true
		print("✓ PowerBeam attack detected - tree can be cut")
	
	# Check if this is a Slash attack
	elif attack_type == "slash":
		can_cut_tree = true
		print("✓ Slash attack detected - tree can be cut")
	
	# Check if this is a Meteor attack
	elif attack_type == "meteor":
		can_cut_tree = true
		print("✓ Meteor attack detected - tree can be cut")
	
	# Check if this is a PowerBeam by checking the caller's script
	elif attack_type == "" and _is_power_beam_attack():
		can_cut_tree = true
		print("✓ PowerBeam attack detected via script check - tree can be cut")
	
	# Check if this is a Slash attack by checking the caller's script
	elif attack_type == "" and _is_slash_attack():
		can_cut_tree = true
		print("✓ Slash attack detected via script check - tree can be cut")
	
	# Debug: log all attack types for troubleshooting
	print("DEBUG: Checking attack type:", attack_type, "against allowed types: power_beam, slash, meteor")
	print("DEBUG: can_cut_tree result:", can_cut_tree)
	
	if can_cut_tree:
		print("=== TREE CUTTING INITIATED ===")
		print("Damage received:", damage)
		print("Attack type:", attack_type)
		
		# Mark tree as cut
		is_tree_cut = true
		
		# Cut the tree
		_cut_tree()
	else:
		print("=== TREE DAMAGE IGNORED (NO CUTTING) ===")
		print("Damage received:", damage)
		print("Attack type:", attack_type)
		print("This attack type cannot cut trees - damage ignored for cutting")
		
		# Still handle the collision effects (sounds, etc.) even if not cutting
		_handle_non_cutting_damage(damage, attack_type)

func _is_power_beam_attack() -> bool:
	"""Check if the current attack is from PowerBeam by examining the call stack"""
	# Get the current call stack
	var stack = get_stack()
	
	# Look for PowerBeam in the call stack
	for frame in stack:
		if frame.source.ends_with("power_beam.gd"):
			return true
	
	return false

func _is_slash_attack() -> bool:
	"""Check if the current attack is from Slash by examining the call stack"""
	# Get the current call stack
	var stack = get_stack()
	
	# Look for MeleeAttackStrategy (which handles Slash) in the call stack
	for frame in stack:
		if frame.source.ends_with("MeleeAttackStrategy.gd"):
			# Check if this is specifically a slash attack by looking at the function name
			if frame.function == "perform_slash_attack":
				return true
	
	return false

func _handle_non_cutting_damage(damage: int, attack_type: String):
	"""Handle damage from attacks that don't cut the tree but should still have effects"""
	print("Handling non-cutting damage:", damage, "from attack type:", attack_type)
	
	# Play trunk thunk sound for any damage to the tree
	var thunk = get_node_or_null("TrunkThunk")
	if thunk:
		thunk.play()
		print("✓ TrunkThunk sound played for non-cutting damage")
	else:
		print("✗ TrunkThunk sound not found!")
	
	# You can add other effects here like:
	# - Particle effects
	# - Screen shake
	# - Visual feedback
	# - etc.

func get_grid_position() -> Vector2i:
	"""Get the grid position of the tree"""
	if has_meta("grid_position"):
		return get_meta("grid_position")
	elif get("grid_position") != null:
		return get("grid_position")
	else:
		# Fallback: calculate grid position from world position
		var world_pos = global_position
		var cell_size = 48  # Default cell size
		
		# Account for camera offset if available
		var course = get_tree().current_scene
		if course and course.has_method("get_camera_offset"):
			var camera_offset = course.get_camera_offset()
			world_pos -= camera_offset
			print("DEBUG: Tree grid calculation - Original world pos:", global_position, "Camera offset:", camera_offset, "Adjusted world pos:", world_pos)
		
		# Since the tree is placed at cell center, we need to adjust for the offset
		var grid_x = floor((world_pos.x - cell_size / 2) / cell_size)
		var grid_y = floor((world_pos.y - cell_size / 2) / cell_size)
		var grid_pos = Vector2i(grid_x, grid_y)
		print("DEBUG: Tree grid calculation - Final grid pos:", grid_pos)
		return grid_pos

func _cut_tree():
	"""Cut the tree into stump and falling top"""
	print("Cutting tree into stump and top...")
	
	# Disable default tree components
	var default_sprite = get_node_or_null("Sprite2D")
	var default_top_height = get_node_or_null("TopHeight")
	var light_occluder = get_node_or_null("LightOccluder2D")
	
	if default_sprite:
		default_sprite.visible = false
		print("✓ Disabled default tree sprite")
	
	if default_top_height:
		default_top_height.visible = false
		print("✓ Disabled default TopHeight marker")
	
	if light_occluder:
		light_occluder.visible = false
		print("✓ Disabled LightOccluder")
	
	# Enable stump and top components
	var tree_stump = get_node_or_null("TreeStump")
	var tree_top = get_node_or_null("TreeTop")
	
	if tree_stump:
		tree_stump.visible = true
		print("✓ Enabled TreeStump")
	
	if tree_top:
		tree_top.visible = true
		print("✓ Enabled TreeTop")
		
		# Start the pop-off animation with random direction
		_animate_tree_top_pop_off(tree_top)
	
	# Disable hover effect
	_disable_hover_effect()
	
	# Update collision detection to use stump height
	_update_collision_to_stump()
	
	print("✓ Tree cutting complete!")

func _animate_tree_top_pop_off(tree_top: Node2D):
	"""Animate the tree top to pop off in a random direction"""
	print("Starting tree top pop-off animation...")
	
	# Generate random direction and rotation
	var random_angle = randf_range(0, 2 * PI)
	var random_direction = Vector2(cos(random_angle), sin(random_angle))
	var random_rotation = randf_range(-PI/4, PI/4)  # ±45 degrees
	
	# Store the random values for the animation
	tree_cut_direction = random_direction
	tree_cut_rotation = random_rotation
	
	print("Random direction:", random_direction)
	print("Random rotation:", random_rotation)
	
	# Get the animation player
	var anim_player = tree_top.get_node_or_null("TreeTopAnimationPlayer")
	if not anim_player:
		print("✗ ERROR: TreeTopAnimationPlayer not found!")
		return
	
	# Check if the pop_off animation exists
	if not anim_player.has_animation("pop_off"):
		print("✗ ERROR: pop_off animation not found in TreeTopAnimationPlayer!")
		return
	
	# Start the pop_off animation
	anim_player.play("pop_off")
	print("✓ Started pop_off animation")
	
	# Create a tween for the random movement and rotation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Tween the position (random direction movement)
	var start_pos = tree_top.global_position
	var end_pos = start_pos + (random_direction * 100)  # Move 100 pixels in random direction
	tween.tween_property(tree_top, "global_position", end_pos, 0.6)
	
	# Tween the rotation (random rotation)
	var start_rotation = tree_top.rotation
	var end_rotation = start_rotation + random_rotation
	tween.tween_property(tree_top, "rotation", end_rotation, 0.6)
	
	print("✓ Started random movement and rotation tween (0.6s)")
	
	# Connect to animation finished signal to clean up if needed
	if not anim_player.animation_finished.is_connected(_on_tree_top_animation_finished):
		anim_player.animation_finished.connect(_on_tree_top_animation_finished)

func _on_tree_top_animation_finished(anim_name: String):
	"""Handle when the tree top animation finishes"""
	if anim_name == "pop_off":
		print("✓ Tree top pop-off animation finished")
		# You can add additional cleanup here if needed

func check_tree_top_landing_collision():
	"""Check for collisions when TreeTop lands on the ground - call from animation"""
	print("=== CHECKING TREE TOP LANDING COLLISION ===")
	
	var tree_top = get_node_or_null("TreeTop")
	if not tree_top:
		print("✗ ERROR: TreeTop not found!")
		return
	
	# Get the collision area for the tree top
	var tree_top_area = tree_top.get_node_or_null("Area2D")
	if not tree_top_area:
		print("✗ ERROR: TreeTop Area2D not found!")
		return
	
	# Get all overlapping areas
	var overlapping_areas = tree_top_area.get_overlapping_areas()
	if overlapping_areas.is_empty():
		print("✓ No collisions detected on landing")
		return
	
	print("Found", overlapping_areas.size(), "overlapping areas on landing")
	
	# Check each overlapping area for valid targets
	for area in overlapping_areas:
		var target = area.get_parent()
		if not target:
			continue
		
		print("Checking collision with:", target.name, "(", target.get_class(), ")")
		
		# Handle different types of targets
		_handle_tree_top_collision(target)

func _handle_tree_top_collision(target: Node):
	"""Handle collision between TreeTop and a target entity"""
	print("Handling tree top collision with:", target.name)
	
	# Check if target is a golf ball (special handling)
	if target.name == "GolfBall" or target.name == "GhostBall":
		_handle_tree_top_ball_collision(target)
		return
	
	# Check if target is a player
	if target.has_method("take_damage") and target.get_script() and target.get_script().resource_path.ends_with("Player.gd"):
		_handle_tree_top_player_collision(target)
		return
	
	# Check if target is an NPC (GangMember, Police, ZombieGolfer, etc.)
	if target.has_method("take_damage") and _is_npc(target):
		# Exclude boss objects from TreeTop damage
		if target.get_script() and (target.get_script().resource_path.ends_with("boss_hand.gd") or target.get_script().resource_path.ends_with("boss_eye.gd")):
			print("✓ Boss object", target.name, "ignored by TreeTop collision")
			return
		_handle_tree_top_npc_collision(target)
		return
	
	# Check if target is destructible (oil drum, etc.)
	if target.has_method("take_damage") and _is_destructible(target):
		_handle_tree_top_destructible_collision(target)
		return
	
	print("✓ Target", target.name, "is not a valid collision target")

func _handle_tree_top_ball_collision(ball: Node):
	"""Handle TreeTop collision with golf ball"""
	print("Tree top hit golf ball:", ball.name)
	
	var tree_top = get_node_or_null("TreeTop")
	if not tree_top:
		return
	
	# Check if ball is rolling or in flight
	var ball_velocity = Vector2.ZERO
	if "velocity" in ball:
		ball_velocity = ball.velocity
	
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	
	print("Ball velocity:", ball_velocity, "Ball height:", ball_height)
	
	# If ball is rolling (low height, has velocity), reflect it
	if ball_height <= 5.0 and ball_velocity.length() > 10.0:
		print("Ball is rolling - applying reflection")
		_apply_ball_reflection(ball, tree_top)
	else:
		# Ball is in flight or stopped - apply roof bounce or pass over
		print("Ball is in flight or stopped - checking for roof bounce")
		_apply_ball_roof_bounce(ball, tree_top)

func _apply_ball_reflection(ball: Node, tree_top: Node):
	"""Apply reflection to rolling ball"""
	var ball_velocity = ball.velocity
	var ball_pos = ball.global_position
	var tree_center = tree_top.global_position
	
	# Calculate the direction from tree center to ball
	var to_ball_direction = (ball_pos - tree_center).normalized()
	
	# Simple reflection: reflect the velocity across the tree center
	var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity to the ball
	ball.velocity = reflected_velocity
	
	# Notify ball of bounce if it has the method
	if ball.has_method("_notify_bounce_room_bounce"):
		ball._notify_bounce_room_bounce()
	
	print("✓ Applied reflection to ball:", reflected_velocity)

func _apply_ball_roof_bounce(ball: Node, tree_top: Node):
	"""Apply roof bounce or pass over for ball in flight"""
	var tree_height = Global.get_object_height_from_marker(tree_top)
	var ball_height = 0.0
	
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	
	print("Tree height:", tree_height, "Ball height:", ball_height)
	
	# If ball is above tree height, it can pass over (roof bounce)
	if ball_height > tree_height:
		print("Ball is above tree - allowing roof bounce")
		if ball.has_method("_set_ground_level"):
			ball._set_ground_level(tree_height)
		elif "current_ground_level" in ball:
			ball.current_ground_level = tree_height
		print("✓ Set ball ground level to tree height:", tree_height)
	else:
		# Ball is below tree height - reflect it
		print("Ball is below tree - applying reflection")
		_apply_ball_reflection(ball, tree_top)

func _handle_tree_top_player_collision(player: Node):
	"""Handle TreeTop collision with player"""
	print("Tree top hit player:", player.name)
	
	# Apply damage and knockback to player
	var tree_top = get_node_or_null("TreeTop")
	if tree_top:
		# Apply damage (tree top damage)
		player.take_damage(25, false)  # 25 damage, not headshot
		
		# Apply knockback
		var knockback_direction = (player.global_position - tree_top.global_position).normalized()
		var knockback_force = knockback_direction * 150  # 150 pixel knockback
		
		if player.has_method("apply_knockback"):
			player.apply_knockback(knockback_force)
		elif "velocity" in player:
			player.velocity = knockback_force
		
		print("✓ Applied damage and knockback to player")

func _handle_tree_top_npc_collision(npc: Node):
	"""Handle TreeTop collision with NPC"""
	print("Tree top hit NPC:", npc.name)
	
	# Apply damage and knockback to NPC
	var tree_top = get_node_or_null("TreeTop")
	if tree_top:
		# Apply damage (tree top damage)
		npc.take_damage(30, false, tree_top.global_position)  # 30 damage, not headshot, weapon position
		
		# Apply knockback
		var knockback_direction = (npc.global_position - tree_top.global_position).normalized()
		var knockback_force = knockback_direction * 120  # 120 pixel knockback
		
		if npc.has_method("apply_knockback"):
			npc.apply_knockback(knockback_force)
		elif "velocity" in npc:
			npc.velocity = knockback_force
		
		print("✓ Applied damage and knockback to NPC")

func _handle_tree_top_destructible_collision(destructible: Node):
	"""Handle TreeTop collision with destructible object"""
	print("Tree top hit destructible:", destructible.name)
	
	# Apply damage to destructible
	destructible.take_damage(40)  # 40 damage to destructibles
	
	print("✓ Applied damage to destructible")

func _is_npc(target: Node) -> bool:
	"""Check if target is an NPC"""
	var npc_scripts = [
		"GangMember.gd",
		"police.gd", 
		"ZombieGolfer.gd",
		"wraith.gd",
		"boss_eye.gd",
		"boss_hand.gd"
	]
	
	if target.get_script():
		var script_path = target.get_script().resource_path
		for npc_script in npc_scripts:
			if script_path.ends_with(npc_script):
				return true
	
	return false

func _is_destructible(target: Node) -> bool:
	"""Check if target is a destructible object"""
	var destructible_scripts = [
		"oil_drum.gd",
		"boulder.gd"
	]
	
	if target.get_script():
		var script_path = target.get_script().resource_path
		for destructible_script in destructible_scripts:
			if script_path.ends_with(destructible_script):
				return true
	
	return false

func _disable_hover_effect():
	"""Disable the hover transparency effect"""
	var mouse_area = get_node_or_null("MouseDetectionArea")
	var mouse_control = get_node_or_null("MouseControl")
	
	if mouse_area:
		mouse_area.monitoring = false
		mouse_area.monitorable = false
		print("✓ Disabled mouse detection area")
	
	if mouse_control:
		mouse_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("✓ Disabled mouse control")

func _update_collision_to_stump():
	"""Update collision detection to use stump height instead of full tree height"""
	var tree_stump = get_node_or_null("TreeStump")
	if tree_stump:
		var stump_top_height = tree_stump.get_node_or_null("TopHeight")
		if stump_top_height:
			# The stump's TopHeight marker should be used for collision detection now
			# This will be handled by the existing collision system using the new marker
			print("✓ Updated collision to use stump height")
	
	# Update Y-sorting to use the stump's YSortPoint if available
	var tree_top = get_node_or_null("TreeTop")
	if tree_top:
		var ysort_point = tree_top.get_node_or_null("YSortPoint")
		if ysort_point:
			# The TreeTop's YSortPoint will be used for Y-sorting
			print("✓ Updated Y-sorting to use TreeTop YSortPoint")
	
	# Force update Y-sorting
	call_deferred("_update_ysort")

func _ready():
	# Add tree to destructible_objects group for attack detection
	add_to_group("destructible_objects")
	print("✓ Tree added to destructible_objects group")
	
	# Connect to Area2D's area_entered and area_exited signals for collision detection
	var trunk_base_area = get_node_or_null("TrunkBaseArea")
	var leaves_area = get_node_or_null("Leaves")
	
	if trunk_base_area:
		# Use area_entered and area_exited for trunk collisions
		trunk_base_area.connect("area_entered", _on_trunk_area_entered)
		trunk_base_area.connect("area_exited", _on_trunk_area_exited)
		# Set collision layer to 1 so golf balls can detect it
		trunk_base_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		trunk_base_area.collision_mask = 1
		print("✓ Tree TrunkBaseArea setup complete for collision detection")
	else:
		print("✗ ERROR: TrunkBaseArea not found!")
	
	if leaves_area:
		# No longer using Area2D for leaves collision - using distance-based detection instead
		# Set collision layer to 1 so golf balls can detect it (for trunk collisions only)
		leaves_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1 (for trunk collisions only)
		leaves_area.collision_mask = 1
	else:
		print("ERROR: Leaves area not found!")
	
	if trunk_base_area or leaves_area:
		print("Tree Area2D nodes found and ready for collision detection")
	else:
		print("ERROR: Tree Area2D nodes not found!")
	
	# Setup HitBox for gun collision detection
	_setup_hitbox()
	
	# Setup mouse detection area for hover transparency
	_setup_mouse_detection()
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")
	
	# Ensure z_index is properly set for Ysort
	call_deferred("_update_ysort")
	
	# Apply TreeData if provided
	call_deferred("_apply_tree_data")
	
	# Initialize tree cutting components (initially hidden)
	call_deferred("_initialize_tree_cutting_components")

func _on_trunk_area_entered(area: Area2D):
	"""Handle collisions with the trunk base area (ground-level collision)"""
	var projectile = area.get_parent()
	
	print("=== TREE TRUNK AREA ENTERED ===")
	print("Area name:", area.name)
	print("Projectile parent:", projectile.name if projectile else "No parent")
	print("Projectile type:", projectile.get_class() if projectile else "Unknown")
	print("Projectile position:", projectile.global_position if projectile else "Unknown")
	
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		print("✓ Valid projectile detected:", projectile.name)
		# Handle the collision using proper Area2D collision detection
		_handle_trunk_area_collision(projectile)
	else:
		print("✗ Invalid projectile or non-projectile object:", projectile.name if projectile else "Unknown")
	
	print("=== END TREE TRUNK AREA ENTERED ===")

func _on_trunk_area_exited(area: Area2D):
	"""Handle when projectile exits the tree trunk area - reset ground level"""
	var projectile = area.get_parent()
	
	print("=== TREE TRUNK AREA EXITED ===")
	print("Projectile:", projectile.name if projectile else "Unknown")
	
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0
				print("✓ Reset projectile ground level to 0.0")
	
	print("=== END TREE TRUNK AREA EXITED ===")

func _handle_trunk_area_collision(projectile: Node2D):
	"""Handle tree trunk area collisions using proper Area2D detection"""
	print("=== HANDLING TREE TRUNK AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and tree heights
	var projectile_height = projectile.get_height()
	var tree_height = Global.get_object_height_from_marker(get_height_marker())
	
	print("Projectile height:", projectile_height)
	print("Tree height:", tree_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_trunk_area_collision(projectile, projectile_height, tree_height)
		return
	
	# Apply the collision logic:
	# If projectile height > tree height: allow entry and set ground level
	# If projectile height < tree height: reflect
	if projectile_height > tree_height:
		print("✓ Projectile is above tree - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, tree_height)
	else:
		print("✗ Projectile is below tree height - reflecting")
		_reflect_projectile(projectile)

func _handle_knife_trunk_area_collision(knife: Node2D, knife_height: float, tree_height: float):
	"""Handle knife collision with tree trunk area"""
	print("Handling knife tree trunk area collision")
	
	if knife_height > tree_height:
		print("✓ Knife is above tree - allowing entry and setting ground level")
		_allow_projectile_entry(knife, tree_height)
	else:
		print("✗ Knife is below tree height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, tree_height: float):
	"""Allow projectile to enter tree area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (TREE) ===")
	
	# Set the projectile's ground level to the tree height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(tree_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = tree_height
			print("✓ Set projectile ground level to tree height:", tree_height)
	
	# The projectile will now land on the tree trunk instead of passing through
	# When it exits the area, _on_trunk_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the tree trunk"""
	print("=== REFLECTING PROJECTILE (TREE) ===")
	
	# Play trunk thunk sound
	var thunk = get_node_or_null("TrunkThunk")
	if thunk:
		thunk.play()
		print("✓ TrunkThunk sound played")
	else:
		print("✗ TrunkThunk sound not found!")
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var tree_center = global_position
	
	# Calculate the direction from tree center to projectile
	var to_projectile_direction = (projectile_pos - tree_center).normalized()
	
	# Simple reflection: reflect the velocity across the tree center
	var reflected_velocity = projectile_velocity - 2 * projectile_velocity.dot(to_projectile_direction) * to_projectile_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity

func set_transparent(is_transparent: bool):
	var anim_player = get_node_or_null("Sprite2D/AnimationPlayer")
	if not anim_player:
		return

	if is_transparent:
		anim_player.play("hover_fade_in")
	else:
		anim_player.play_backwards("hover_fade_in")

func _setup_hitbox() -> void:
	"""Setup HitBox for gun collision detection"""
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		# Add to hitboxes group for weapon system detection
		hitbox.add_to_group("hitboxes")
		print("✓ Tree HitBox setup complete for gun collision (layer 2)")
	else:
		print("✗ ERROR: Tree HitBox not found!")

func _verify_collision_setup():
	"""Verify that collision layers are properly set up"""
	var trunk_base_area = get_node_or_null("TrunkBaseArea")
	if trunk_base_area:
		
		# Check collision shape
		var collision_shape = trunk_base_area.get_node_or_null("TrunkBase")
		if collision_shape:
			var actual_radius = collision_shape.shape.radius * collision_shape.scale.x

func set_tree_data(new_tree_data: TreeData):
	"""Set the TreeData for this tree and apply it immediately"""
	tree_data = new_tree_data
	_apply_tree_data()

func _apply_tree_data():
	"""Apply TreeData to change the tree sprite"""
	if not tree_data or not tree_data.sprite_texture:
		return
	
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = tree_data.sprite_texture

# OPTIMIZED: Tree collision detection moved to ball for better performance
# Trees no longer check for balls every frame - ball handles its own collision detection
func _process(delta):
	# Check if mouse is over the tree using the control node
	var mouse_control = get_node_or_null("MouseControl")
	if mouse_control:
		var mouse_pos = mouse_control.get_local_mouse_position()
		var tree_rect = Rect2(Vector2.ZERO, mouse_control.size)
		
		if tree_rect.has_point(mouse_pos):
			if not is_mouse_over:
				is_mouse_over = true
				_on_mouse_entered()
		else:
			if is_mouse_over:
				is_mouse_over = false
				_on_mouse_exited()

func _update_ysort():
	"""Update the Tree's z_index for proper Y-sorting"""
	if is_tree_cut:
		# When tree is cut, use the TreeTop's YSortPoint for Y-sorting
		var tree_top = get_node_or_null("TreeTop")
		if tree_top:
			var ysort_point = tree_top.get_node_or_null("YSortPoint")
			if ysort_point:
				Global.update_object_y_sort(ysort_point, "objects")
				return
	
	# Default: use the tree itself for Y-sorting
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this tree.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 120.0  # Tree trunk radius

func _setup_mouse_detection() -> void:
	"""Setup MouseDetectionArea for hover transparency effect"""
	var mouse_area = get_node_or_null("MouseDetectionArea")
	var mouse_control = get_node_or_null("MouseControl")
	
	# Setup Area2D mouse detection
	if mouse_area:
		# Enable mouse input detection
		mouse_area.input_pickable = true
		mouse_area.monitoring = true
		mouse_area.monitorable = true
		
		# Connect mouse enter/exit signals for transparency effect
		mouse_area.mouse_entered.connect(_on_mouse_entered)
		mouse_area.mouse_exited.connect(_on_mouse_exited)
		
		# Set collision layer to 0 (not used for physics)
		mouse_area.collision_layer = 0
		# Set collision mask to 0 (not used for physics)
		mouse_area.collision_mask = 0
		
		print("✓ Tree MouseDetectionArea setup complete for hover transparency")
		print("  - input_pickable:", mouse_area.input_pickable)
		print("  - monitoring:", mouse_area.monitoring)
		print("  - monitorable:", mouse_area.monitorable)
	else:
		print("✗ ERROR: MouseDetectionArea not found!")
	
	# Setup Control mouse detection as backup
	if mouse_control:
		# Connect gui_input for better mouse detection in camera container
		mouse_control.gui_input.connect(_on_mouse_control_input)
		
		print("✓ Tree MouseControl setup complete for hover transparency")
		print("  - mouse_filter:", mouse_control.mouse_filter)
	else:
		print("✗ ERROR: MouseControl not found!")

func _on_mouse_control_input(event: InputEvent) -> void:
	"""Handle mouse input events for the control node"""
	var mouse_control = get_node_or_null("MouseControl")
	if not mouse_control:
		return
		
	if event is InputEventMouseMotion:
		# Mouse is over the tree
		if not is_mouse_over:
			is_mouse_over = true
			_on_mouse_entered()
	elif event is InputEventMouseButton:
		# Mouse button event - check if mouse is still over
		var mouse_pos = mouse_control.get_local_mouse_position()
		var tree_rect = Rect2(Vector2.ZERO, mouse_control.size)
		if not tree_rect.has_point(mouse_pos):
			if is_mouse_over:
				is_mouse_over = false
				_on_mouse_exited()

var is_mouse_over: bool = false

func _on_mouse_entered() -> void:
	"""Handle mouse entering the tree area - make tree transparent"""
	set_transparent(true)

func _on_mouse_exited() -> void:
	"""Handle mouse exiting the tree area - restore tree opacity"""
	set_transparent(false)
