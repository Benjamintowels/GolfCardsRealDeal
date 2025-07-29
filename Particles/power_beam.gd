extends Node2D

# Damage amount for PowerBeam
const POWER_BEAM_DAMAGE = 75

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

func _on_area_entered(area: Area2D):
	"""Handle collisions with objects when PowerBeam enters their collision area"""
	var object = area.get_parent()
	if not object:
		return
	
	# Prevent duplicate damage to the same object
	if object in hit_objects:
		return
	
	# Track this object to prevent duplicate hits
	hit_objects.append(object)
	
	print("=== POWERBEAM COLLISION ===")
	print("Object name:", object.name)
	print("Object type:", object.get_class())
	print("Area name:", area.name)
	
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
	else:
		# Default: just pass damage amount
		object.take_damage(POWER_BEAM_DAMAGE)
	
	print("✓ Damage applied successfully")
