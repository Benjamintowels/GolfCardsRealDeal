extends Node2D

# Simple electric chain lightning system
var area2d: Area2D
var electric_start_sound: AudioStreamPlayer2D
var chain_lightning_active: bool = false
var monitoring_timer: Timer
var max_monitoring_time: float = 15.0  # Monitor for up to 15 seconds (longer flight time)

func _ready():
	area2d = $Area2D
	electric_start_sound = $ElectricStart
	
	# Ensure the ElectricArea is properly set up for collision detection
	if area2d:
		# Set collision layer to 1 (same as golf balls)
		area2d.collision_layer = 1
		# Set collision mask to 1 (to detect objects on layer 1)
		area2d.collision_mask = 1
		print("ElectricArea: Collision layer set to", area2d.collision_layer, "mask set to", area2d.collision_mask)
	
	# Create monitoring timer
	monitoring_timer = Timer.new()
	monitoring_timer.one_shot = true
	monitoring_timer.wait_time = max_monitoring_time
	monitoring_timer.timeout.connect(_on_monitoring_timeout)
	add_child(monitoring_timer)

func activate_electric_area():
	"""Activate the electric area and start chain lightning"""
	if chain_lightning_active:
		return
		
	chain_lightning_active = true
	
	# Make the ElectricArea visible for debugging
	visible = true
	
	# Play electric start sound
	if electric_start_sound:
		electric_start_sound.play()
		print("Playing ElectricStart sound")
	
	# Start continuous monitoring for targets
	_start_continuous_monitoring()

func _start_continuous_monitoring():
	"""Start continuously monitoring for targets while ball is in flight"""
	print("=== STARTING CONTINUOUS ELECTRIC MONITORING ===")
	monitoring_timer.start()
	
	# Check for targets immediately
	_check_for_targets()
	
	# Set up a repeating timer to check every 0.1 seconds
	var check_timer = Timer.new()
	check_timer.wait_time = 0.1
	check_timer.timeout.connect(_check_for_targets)
	add_child(check_timer)
	check_timer.start()

func _check_for_targets():
	"""Check for valid targets and apply chain lightning if found"""
	if not chain_lightning_active:
		return
		
	print("=== CHECKING FOR ELECTRIC TARGETS ===")
	print("ElectricArea global position:", global_position)
	print("ElectricArea local position:", position)
	print("ElectricArea scale:", scale)
	
	# Get all overlapping bodies and areas
	var targets = []
	
	# Check bodies
	var overlapping_bodies = area2d.get_overlapping_bodies()
	print("ElectricArea: Found", overlapping_bodies.size(), "overlapping bodies")
	for body in overlapping_bodies:
		print("  Body:", body.name, "Type:", body.get_class(), "Groups:", body.get_groups())
		if _is_valid_target(body):
			targets.append(body)
			print("  ✓ Valid target found:", body.name)
		else:
			print("  ✗ Invalid target:", body.name)
	
	# Check areas
	var overlapping_areas = area2d.get_overlapping_areas()
	print("ElectricArea: Found", overlapping_areas.size(), "overlapping areas")
	for area in overlapping_areas:
		print("  Area:", area.name, "Parent:", area.get_parent().name if area.get_parent() else "None", "Groups:", area.get_groups())
		if _is_valid_target(area):
			targets.append(area)
			print("  ✓ Valid target found:", area.name)
		else:
			print("  ✗ Invalid target:", area.name)
	
	print("ElectricArea: Total valid targets found:", targets.size())
	
	# Process each valid target
	for target in targets:
		_create_electric_arc_to_target(target)
		_apply_electric_shock_to_target(target)
	
	if targets.size() > 0:
		print("✓ Chain lightning applied to", targets.size(), "targets")
		# Don't stop monitoring - keep going for more targets
		# The monitoring will continue until the ball lands or timeout occurs

func _on_monitoring_timeout():
	"""Called when monitoring time expires"""
	print("=== ELECTRIC MONITORING TIMEOUT ===")
	deactivate_electric_area()

func _is_valid_target(target) -> bool:
	"""Check if a target can be electrified"""
	# For Area2D nodes, check their parent for groups
	var target_to_check = target
	if target is Area2D and target.get_parent():
		target_to_check = target.get_parent()
	
	# Exclude the player from being a target
	if target_to_check.is_in_group("players"):
		return false
	
	# Check if target is in valid groups
	if target_to_check.is_in_group("NPC") or target_to_check.is_in_group("Character"):
		return true
	
	# Check by name for specific objects
	if target_to_check.name.contains("OilDrum") or target_to_check.name.contains("LightPole"):
		return true
	
	return false

func _create_electric_arc_to_target(target):
	"""Create an electric arc from this area to the target"""
	print("=== CREATING ELECTRIC ARC ===")
	print("Target:", target.name)
	print("From position:", global_position)
	print("To position:", target.global_position)
	
	var electric_arc_scene = preload("res://Particles/ElectricArc.tscn")
	if not electric_arc_scene:
		print("✗ Failed to preload ElectricArc scene")
		return
		
	var electric_arc = electric_arc_scene.instantiate()
	if not electric_arc:
		print("✗ Failed to instantiate ElectricArc")
		return
	
	# Position the arc at the origin (GolfBall position)
	electric_arc.global_position = global_position
	
	# Calculate direction to target
	var direction = (target.global_position - global_position).normalized()
	var angle = direction.angle()
	
	# Rotate the arc to face the target
	electric_arc.rotation = angle
	
	# Add to scene
	get_tree().current_scene.add_child(electric_arc)
	
	print("✓ Created ElectricArc to target: ", target.name)
	print("Arc position:", electric_arc.global_position)
	print("Arc rotation:", electric_arc.rotation)

func _apply_electric_shock_to_target(target):
	"""Apply electric shock effect to the target"""
	print("=== APPLYING ELECTRIC SHOCK ===")
	print("Target:", target.name)
	print("Target position:", target.global_position)
	
	var electric_shock_scene = preload("res://Particles/ElectricShock.tscn")
	if not electric_shock_scene:
		print("✗ Failed to preload ElectricShock scene")
		return
		
	var electric_shock = electric_shock_scene.instantiate()
	if not electric_shock:
		print("✗ Failed to instantiate ElectricShock")
		return
	
	# Add the shock to the target's scene tree
	if target.has_method("add_child"):
		target.add_child(electric_shock)
		print("✓ Added ElectricShock as child of target")
	else:
		# Fallback: add to target's parent
		target.get_parent().add_child(electric_shock)
		electric_shock.global_position = target.global_position
		print("✓ Added ElectricShock to target's parent")
	
	print("✓ Applied ElectricShock to target: ", target.name)
	print("Shock position:", electric_shock.global_position)
	
	# Apply damage to target if it has a take_damage method
	if target.has_method("take_damage"):
		target.take_damage(20)
		print("Applied 20 damage to target: ", target.name)

func deactivate_electric_area():
	"""Deactivate the electric area - called when ball lands"""
	print("=== ELECTRIC AREA DEACTIVATED ===")
	chain_lightning_active = false
	visible = false
	if monitoring_timer:
		monitoring_timer.stop() 
