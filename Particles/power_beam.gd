extends Node2D

# Damage amount for PowerBeam
const POWER_BEAM_DAMAGE = 75

# GolfBall launch parameters
const GOLFBALL_LAUNCH_POWER = 1500.0  # High velocity
const GOLFBALL_LAUNCH_HEIGHT = 400.0  # High arc
const GOLFBALL_LAUNCH_SPIN = 200.0    # Add some spin for dramatic effect

# Track objects we've already hit to prevent multiple damage
var hit_objects = []

func _ready():
	# Connect to the Area2D's area_entered signal for collision detection
	var area2d = get_node_or_null("Pivot/Sprite2D/Area2D")
	if area2d:
		# Connect to area_entered signal for collision detection
		if not area2d.area_entered.is_connected(_on_area_entered):
			area2d.area_entered.connect(_on_area_entered)
		
		# Set collision layer to 1 so objects can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect objects on layer 1
		area2d.collision_mask = 1
		
		print("✓ PowerBeam Area2D collision detection setup complete")
	else:
		print("✗ ERROR: PowerBeam Area2D not found!")

func reset_hit_objects():
	"""Reset the hit objects list to allow new collisions"""
	hit_objects.clear()
	print("✓ PowerBeam hit_objects list reset")

func _on_visibility_changed():
	"""Called when the PowerBeam becomes visible or invisible"""
	if visible:
		# Reset hit objects when becoming visible to allow new collisions
		reset_hit_objects()
		print("✓ PowerBeam became visible - reset hit objects")

func _on_area_entered(area: Area2D):
	"""Handle collisions with objects when PowerBeam enters their collision area"""
	print("=== POWERBEAM AREA ENTERED ===")
	print("Area name:", area.name)
	print("Area parent:", area.get_parent().name if area.get_parent() else "None")
	print("Hit objects count:", hit_objects.size())
	
	var object = area.get_parent()
	if not object:
		print("✗ No parent object found")
		return
	
	# Prevent duplicate damage to the same object
	if object in hit_objects:
		print("✗ Object already hit, skipping:", object.name)
		return
	
	# Track this object to prevent duplicate hits
	hit_objects.append(object)
	print("✓ Added object to hit list:", object.name)
	
	print("=== POWERBEAM COLLISION ===")
	print("Object name:", object.name)
	print("Object type:", object.get_class())
	print("Area name:", area.name)
	
	# Check if this is a GolfBall collision first
	if object.has_method("launch") and (object.name == "GolfBall" or object.is_in_group("golf_balls")):
		print("✓ GolfBall collision detected - launching ball!")
		_launch_golfball(object)
		return
	
	# Check if this object has a take_damage method (indicating it has health)
	if not object.has_method("take_damage"):
		print("✗ Object does not have take_damage method")
		return
	
	# Check for various collision area names used in the codebase
	var valid_collision_areas = [
		"BaseCollisionArea",  # Used by GangMember, Police, ZombieGolfer
		"BodyArea2D",         # Used by newer NPCs like Wraith, OilDrum
		"Area2D",             # Used by Player characters
		"TrunkBaseArea",      # Used by Trees
		"BaseArea",           # Used by Shop
		"BonfireArea2D",      # Used by Bonfire
		"HoleArea",           # Used by Pin
		"FlagArea"            # Used by Pin flag
	]
	
	if area.name in valid_collision_areas:
		print("✓ Valid collision area detected:", area.name)
		_deal_damage_to_object(object)
	else:
		print("✗ Unknown collision area:", area.name, "- ignoring collision")

func _launch_golfball(golfball: Node):
	"""Launch the golf ball with high velocity and height"""
	print("=== LAUNCHING GOLFBALL WITH POWERBEAM ===")
	print("GolfBall position:", golfball.global_position)
	print("PowerBeam position:", global_position)
	
	# Calculate launch direction from PowerBeam to GolfBall
	var launch_direction = (golfball.global_position - global_position).normalized()
	
	# Add some randomness to make it more dramatic
	var random_angle = randf_range(-0.2, 0.2)  # ±11.5 degrees
	launch_direction = launch_direction.rotated(random_angle)
	
	# Add some upward bias to make the launch more dramatic
	launch_direction.y = min(launch_direction.y - 0.3, -0.1)  # Bias upward but not too much
	launch_direction = launch_direction.normalized()
	
	print("Launch direction:", launch_direction)
	print("Launch power:", GOLFBALL_LAUNCH_POWER)
	print("Launch height:", GOLFBALL_LAUNCH_HEIGHT)
	print("Launch spin:", GOLFBALL_LAUNCH_SPIN)
	
	# Launch the golf ball with high velocity and height
	golfball.launch(launch_direction, GOLFBALL_LAUNCH_POWER, GOLFBALL_LAUNCH_HEIGHT, GOLFBALL_LAUNCH_SPIN, 2)  # Category 2 = high spin
	
	print("✓ GolfBall launched successfully!")
	
	# Play a sound effect if available
	var launch_sound = get_node_or_null("LaunchSound")
	if launch_sound and launch_sound.stream:
		launch_sound.play()

func _deal_damage_to_object(object: Node):
	"""Deal damage to the specified object"""
	print("Dealing", POWER_BEAM_DAMAGE, "damage to", object.name)
	
	# Check what type of object this is and call take_damage with appropriate parameters
	if object.get_script() and object.get_script().resource_path.ends_with("oil_drum.gd"):
		# Oil drum only takes damage amount
		object.take_damage(POWER_BEAM_DAMAGE)
	elif object.get_script() and object.get_script().resource_path.ends_with("GangMember.gd"):
		# GangMember takes damage, is_headshot, and weapon_position
		object.take_damage(POWER_BEAM_DAMAGE, false, global_position)
	elif object.get_script() and object.get_script().resource_path.ends_with("Player.gd"):
		# Player takes damage and is_headshot
		object.take_damage(POWER_BEAM_DAMAGE, false)
	elif object.get_script() and object.get_script().resource_path.ends_with("police.gd"):
		# Police takes damage, is_headshot, and weapon_position
		object.take_damage(POWER_BEAM_DAMAGE, false, global_position)
	elif object.get_script() and object.get_script().resource_path.ends_with("ZombieGolfer.gd"):
		# ZombieGolfer takes damage and is_headshot
		object.take_damage(POWER_BEAM_DAMAGE, false)
	elif object.get_script() and object.get_script().resource_path.ends_with("wraith.gd"):
		# Wraith takes damage and is_headshot
		object.take_damage(POWER_BEAM_DAMAGE, false)
	elif object.get_script() and object.get_script().resource_path.ends_with("Tree.gd"):
		# Tree takes damage with power_beam attack type
		object.take_damage(POWER_BEAM_DAMAGE, "power_beam")
	else:
		# Default: just pass damage amount
		object.take_damage(POWER_BEAM_DAMAGE)
	
	print("✓ Damage applied successfully")
