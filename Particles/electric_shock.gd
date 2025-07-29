extends AnimatedSprite2D

# Simple electric shock effect for electrified objects
var shock_duration: float = 2.0
var shock_timer: float = 0.0
var damage_applied: bool = false
var area2d: Area2D
var shock_sound: AudioStreamPlayer2D

func _ready():
	area2d = $Area2D
	shock_sound = $Shock
	
	# Start the shock animation
	play("default")
	
	# Apply damage to the parent object
	_apply_damage_to_parent()

func _process(delta):
	# Timer for auto-cleanup
	shock_timer += delta
	if shock_timer >= shock_duration:
		queue_free()

func _apply_damage_to_parent():
	"""Apply damage to the parent object if it has a take_damage method"""
	if damage_applied:
		return
		
	var parent = get_parent()
	if not parent:
		print("✗ No parent found for ElectricShock")
		return
		
	print("=== APPLYING ELECTRIC DAMAGE ===")
	print("ElectricShock parent:", parent.name, "Type:", parent.get_class())
	
	# Check if the parent itself has take_damage method (like ZombieGolfer)
	if parent.has_method("take_damage"):
		parent.take_damage(5)
		print("✓ Applied 5 electric damage to parent:", parent.name)
		damage_applied = true
		return
	
	# If parent doesn't have take_damage, look for the actual NPC in the scene tree
	# The parent might be a collision area, so we need to find the main NPC node
	var npc_node = _find_npc_node(parent)
	if npc_node and npc_node.has_method("take_damage"):
		npc_node.take_damage(5)
		print("✓ Applied 5 electric damage to NPC:", npc_node.name)
		damage_applied = true
		return
	
	print("✗ No valid target found for electric damage")
	print("Parent groups:", parent.get_groups())
	print("Parent children:")
	for child in parent.get_children():
		print("  -", child.name, "Type:", child.get_class())

func _find_npc_node(start_node: Node) -> Node:
	"""Find the actual NPC node by traversing up the scene tree"""
	var current_node = start_node
	
	# Look up the scene tree for a node with take_damage method
	while current_node:
		print("Checking node:", current_node.name, "Type:", current_node.get_class())
		print("  Groups:", current_node.get_groups())
		print("  Has take_damage:", current_node.has_method("take_damage"))
		
		if current_node.has_method("take_damage"):
			print("✓ Found NPC node with take_damage:", current_node.name)
			return current_node
		
		# Check if this node is in NPC-related groups
		if current_node.is_in_group("NPC") or current_node.is_in_group("Character"):
			print("✓ Found NPC node in groups:", current_node.name)
			return current_node
		
		current_node = current_node.get_parent()
	
	print("✗ No NPC node found in scene tree")
	return null
