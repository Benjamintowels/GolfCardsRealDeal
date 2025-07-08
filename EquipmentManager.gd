extends Node
class_name EquipmentManager

signal equipment_updated

# Current equipped items
var equipped_equipment: Array[EquipmentData] = []

# Clothing slots
var head_slot: EquipmentData = null
var neck_slot: EquipmentData = null
var body_slot: EquipmentData = null

# Equipment effects
var mobility_bonus: int = 0
var strength_bonus: int = 0
var card_draw_bonus: int = 0

# Player reference for clothing visualization
var player: Node2D = null

func _ready():
	print("EquipmentManager: _ready() called")

func add_equipment(equipment: EquipmentData):
	"""Add equipment and apply its effects"""
	if equipment.is_clothing:
		_equip_clothing(equipment)
	else:
		equipped_equipment.append(equipment)
		apply_equipment_effects(equipment)
	
	emit_signal("equipment_updated")
	print("EquipmentManager: Added", equipment.name, "to equipment. Total equipment:", equipped_equipment.size())

func remove_equipment(equipment: EquipmentData):
	"""Remove equipment and remove its effects"""
	if equipment.is_clothing:
		_unequip_clothing(equipment)
	else:
		if equipped_equipment.has(equipment):
			equipped_equipment.erase(equipment)
			remove_equipment_effects(equipment)
	
	emit_signal("equipment_updated")
	print("EquipmentManager: Removed", equipment.name, "from equipment. Total equipment:", equipped_equipment.size())

func _equip_clothing(clothing: EquipmentData):
	"""Equip clothing to the appropriate slot"""
	match clothing.clothing_slot:
		"head":
			if head_slot:
				remove_equipment_effects(head_slot)
			head_slot = clothing
			print("EquipmentManager: Equipped", clothing.name, "to head slot")
		"neck":
			if neck_slot:
				remove_equipment_effects(neck_slot)
			neck_slot = clothing
			print("EquipmentManager: Equipped", clothing.name, "to neck slot")
		"body":
			if body_slot:
				remove_equipment_effects(body_slot)
			body_slot = clothing
			print("EquipmentManager: Equipped", clothing.name, "to body slot")
	
	apply_equipment_effects(clothing)
	_update_player_clothing()

func _unequip_clothing(clothing: EquipmentData):
	"""Unequip clothing from the appropriate slot"""
	match clothing.clothing_slot:
		"head":
			if head_slot == clothing:
				head_slot = null
				print("EquipmentManager: Unequipped", clothing.name, "from head slot")
		"neck":
			if neck_slot == clothing:
				neck_slot = null
				print("EquipmentManager: Unequipped", clothing.name, "from neck slot")
		"body":
			if body_slot == clothing:
				body_slot = null
				print("EquipmentManager: Unequipped", clothing.name, "from body slot")
	
	_update_player_clothing()

func _update_player_clothing():
	"""Update the player's visual clothing"""
	if not player:
		# Try to find the player - check multiple possible locations
		player = get_tree().current_scene.get_node_or_null("Player")
		if not player:
			# Try looking in the course scene
			var course = get_tree().current_scene
			if course:
				player = course.get_node_or_null("Player")
		if not player:
			# Try searching recursively through the scene tree
			player = _find_player_recursive(get_tree().current_scene)
		if not player:
			print("EquipmentManager: Player not found for clothing update")
			print("EquipmentManager: Current scene name:", get_tree().current_scene.name)
			print("EquipmentManager: Current scene children:", get_tree().current_scene.get_children().map(func(child): return child.name))
			return
		else:
			print("EquipmentManager: Found player for clothing update:", player.name)
	
	# Debug: Check if Marker2D nodes exist
	var head_marker = _find_marker_in_character("HeadClothes")
	var neck_marker = _find_marker_in_character("NeckClothes")
	var body_marker = _find_marker_in_character("BodyClothes")
	
	print("EquipmentManager: Marker2D check - HeadClothes:", head_marker != null, "NeckClothes:", neck_marker != null, "BodyClothes:", body_marker != null)
	
	# Remove existing clothing nodes
	_remove_existing_clothing()
	
	# Add new clothing nodes
	print("EquipmentManager: Equipping clothing items...")
	if head_slot and head_slot.clothing_scene_path:
		print("EquipmentManager: Equipping head item:", head_slot.name)
		_add_clothing_to_player(head_slot, "HeadClothing")
	
	if neck_slot and neck_slot.clothing_scene_path:
		print("EquipmentManager: Equipping neck item:", neck_slot.name)
		_add_clothing_to_player(neck_slot, "NeckClothing")
	
	if body_slot and body_slot.clothing_scene_path:
		print("EquipmentManager: Equipping body item:", body_slot.name)
		_add_clothing_to_player(body_slot, "BodyClothing")

func _remove_existing_clothing():
	"""Remove existing clothing nodes from player's Marker2D nodes"""
	if not player:
		return
	
	# Remove clothing nodes from Marker2D children
	var marker_names = ["HeadClothes", "NeckClothes", "BodyClothes"]
	for marker_name in marker_names:
		var marker = _find_marker_in_character(marker_name)
		if marker:
			# Remove all children from the marker
			for child in marker.get_children():
				child.queue_free()
				print("EquipmentManager: Removed existing clothing from", marker_name)
		else:
			print("EquipmentManager: Marker2D", marker_name, "not found for clothing removal")

func _find_player_recursive(node: Node) -> Node2D:
	"""Recursively search for a Player node in the scene tree"""
	if node.name == "Player":
		return node as Node2D
	
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result:
			return result
	
	return null

func _add_clothing_to_player(clothing_data: EquipmentData, node_name: String):
	"""Add clothing scene to player at the appropriate Marker2D position"""
	if not player:
		print("EquipmentManager: No player reference for clothing addition")
		return
	if not clothing_data.clothing_scene_path:
		print("EquipmentManager: No clothing scene path for", clothing_data.name)
		return
	
	print("EquipmentManager: Loading clothing scene from:", clothing_data.clothing_scene_path)
	
	# Find the appropriate Marker2D based on clothing slot
	var marker_name = ""
	match clothing_data.clothing_slot:
		"head":
			marker_name = "HeadClothes"
		"neck":
			marker_name = "NeckClothes"
		"body":
			marker_name = "BodyClothes"
		_:
			print("EquipmentManager: Unknown clothing slot:", clothing_data.clothing_slot)
			return
	
	# Find the Marker2D in the character scene
	var marker = _find_marker_in_character(marker_name)
	if not marker:
		print("EquipmentManager: Marker2D", marker_name, "not found in character scene")
		return
	
	# Load and instantiate the clothing scene
	var clothing_scene = load(clothing_data.clothing_scene_path)
	if clothing_scene:
		var clothing_instance = clothing_scene.instantiate()
		clothing_instance.name = node_name
		
		# Add the clothing as a child of the Marker2D
		marker.add_child(clothing_instance)
		
		# Set up clothing sprite flipping to match player sprite
		setup_clothing_sprite_flipping(clothing_instance)
		
		print("EquipmentManager: Added", clothing_data.name, "to", marker_name, "marker")
		print("EquipmentManager: Marker children count:", marker.get_child_count())
	else:
		print("EquipmentManager: Failed to load clothing scene:", clothing_data.clothing_scene_path)

func _find_marker_in_character(marker_name: String) -> Marker2D:
	"""Find a Marker2D in the character scene"""
	if not player:
		return null
	
	# Search recursively through the player and its children
	return _find_marker_recursive(player, marker_name)

func _find_marker_recursive(node: Node, marker_name: String) -> Marker2D:
	"""Recursively search for a Marker2D with the given name"""
	if node is Marker2D and node.name == marker_name:
		return node as Marker2D
	
	for child in node.get_children():
		var result = _find_marker_recursive(child, marker_name)
		if result:
			return result
	
	return null

func setup_clothing_sprite_flipping(clothing_instance: Node2D):
	"""Set up clothing sprite to flip horizontally with the player sprite"""
	if not clothing_instance:
		return
	
	# Find the Sprite2D in the clothing instance
	var clothing_sprite = clothing_instance.get_node_or_null("Sprite2D")
	if not clothing_sprite:
		print("EquipmentManager: No Sprite2D found in clothing instance")
		return
	
	# Get the player's character sprite
	var player_sprite = player.get_character_sprite()
	if not player_sprite:
		print("EquipmentManager: No player character sprite found")
		return
	
	# Set up the clothing sprite to match the player sprite's flip state
	clothing_sprite.flip_h = player_sprite.flip_h
	
	# Set up clothing positioning with proper offsets
	setup_clothing_positioning(clothing_instance)
	
	print("EquipmentManager: Set up clothing sprite flipping for", clothing_instance.name)

func setup_clothing_positioning(clothing_instance: Node2D):
	"""Set up clothing positioning with proper offsets based on clothing type"""
	if not clothing_instance:
		return
	
	# Get the clothing slot from the parent marker name
	var marker = clothing_instance.get_parent()
	if not marker:
		return
	
	var slot_name = marker.name
	var clothing_sprite = clothing_instance.get_node_or_null("Sprite2D")
	if not clothing_sprite:
		return
	
	# Set up positioning based on clothing slot
	match slot_name:
		"HeadClothes":
			# Head clothing (Top Hat) - minimal offset needed
			clothing_sprite.position = Vector2(0, 0)
		"NeckClothes":
			# Neck clothing (Cape) - needs X offset of ±12 (inverse)
			clothing_sprite.position = Vector2(-12, 0)
		"BodyClothes":
			# Body clothing - minimal offset needed
			clothing_sprite.position = Vector2(0, 0)
		_:
			clothing_sprite.position = Vector2(0, 0)

func update_all_clothing_flip():
	"""Update all clothing sprites to match the player sprite's flip state"""
	if not player:
		return
	
	var player_sprite = player.get_character_sprite()
	if not player_sprite:
		return
	
	# Update all clothing sprites in all markers
	var marker_names = ["HeadClothes", "NeckClothes", "BodyClothes"]
	for marker_name in marker_names:
		var marker = _find_marker_in_character(marker_name)
		if marker:
			for child in marker.get_children():
				var clothing_sprite = child.get_node_or_null("Sprite2D")
				if clothing_sprite:
					# Update flip state
					clothing_sprite.flip_h = player_sprite.flip_h
					
					# Update positioning based on flip state and clothing slot
					update_clothing_position(clothing_sprite, marker_name, player_sprite.flip_h)

func update_clothing_position(clothing_sprite: Sprite2D, marker_name: String, is_flipped: bool):
	"""Update clothing sprite position based on flip state and clothing slot"""
	if not clothing_sprite:
		return
	
	match marker_name:
		"HeadClothes":
			# Head clothing (Top Hat) - minimal offset needed
			clothing_sprite.position = Vector2(0, 0)
		"NeckClothes":
			# Neck clothing (Cape) - needs X offset of ±12 based on flip (inverse)
			if is_flipped:
				clothing_sprite.position = Vector2(12, 0)   # Facing left
			else:
				clothing_sprite.position = Vector2(-12, 0)  # Facing right
		"BodyClothes":
			# Body clothing - minimal offset needed
			clothing_sprite.position = Vector2(0, 0)
		_:
			clothing_sprite.position = Vector2(0, 0)

func apply_equipment_effects(equipment: EquipmentData):
	"""Apply the effects of a piece of equipment"""
	match equipment.buff_type:
		"mobility":
			mobility_bonus += equipment.buff_value
			print("EquipmentManager: Applied mobility bonus +", equipment.buff_value, "from", equipment.name)
		"strength":
			strength_bonus += equipment.buff_value
			print("EquipmentManager: Applied strength bonus +", equipment.buff_value, "from", equipment.name)
		"card_draw":
			card_draw_bonus += equipment.buff_value
			print("EquipmentManager: Applied card draw bonus +", equipment.buff_value, "from", equipment.name)

func remove_equipment_effects(equipment: EquipmentData):
	"""Remove the effects of a piece of equipment"""
	match equipment.buff_type:
		"mobility":
			mobility_bonus -= equipment.buff_value
			print("EquipmentManager: Removed mobility bonus -", equipment.buff_value, "from", equipment.name)
		"strength":
			strength_bonus -= equipment.buff_value
			print("EquipmentManager: Removed strength bonus -", equipment.buff_value, "from", equipment.name)
		"card_draw":
			card_draw_bonus -= equipment.buff_value
			print("EquipmentManager: Removed card draw bonus -", equipment.buff_value, "from", equipment.name)

func get_mobility_bonus() -> int:
	"""Get the total mobility bonus from all equipped items"""
	return mobility_bonus

func get_strength_bonus() -> int:
	"""Get the total strength bonus from all equipped items"""
	return strength_bonus

func get_card_draw_bonus() -> int:
	"""Get the total card draw bonus from all equipped items"""
	return card_draw_bonus

func get_equipped_equipment() -> Array[EquipmentData]:
	"""Get all currently equipped equipment (including clothing)"""
	var all_equipment = equipped_equipment.duplicate()
	
	# Add clothing items
	if head_slot:
		all_equipment.append(head_slot)
	if neck_slot:
		all_equipment.append(neck_slot)
	if body_slot:
		all_equipment.append(body_slot)
	
	return all_equipment

func get_clothing_slots() -> Dictionary:
	"""Get the current clothing slots"""
	return {
		"head": head_slot,
		"neck": neck_slot,
		"body": body_slot
	}

func has_equipment(equipment_name: String) -> bool:
	"""Check if a specific piece of equipment is equipped"""
	for equipment in equipped_equipment:
		if equipment.name == equipment_name:
			return true
	
	# Check clothing slots
	if head_slot and head_slot.name == equipment_name:
		return true
	if neck_slot and neck_slot.name == equipment_name:
		return true
	if body_slot and body_slot.name == equipment_name:
		return true
	
	return false

func get_equipment_count() -> int:
	"""Get the total number of equipped items (including clothing)"""
	var count = equipped_equipment.size()
	if head_slot:
		count += 1
	if neck_slot:
		count += 1
	if body_slot:
		count += 1
	return count

func clear_all_equipment():
	"""Clear all equipped equipment and reset bonuses"""
	equipped_equipment.clear()
	head_slot = null
	neck_slot = null
	body_slot = null
	mobility_bonus = 0
	strength_bonus = 0
	card_draw_bonus = 0
	
	# Remove clothing from player
	_update_player_clothing()
	
	emit_signal("equipment_updated")
	print("EquipmentManager: Cleared all equipment and reset bonuses")

func force_update_player_clothing():
	"""Force update player clothing - useful for testing"""
	print("EquipmentManager: Force updating player clothing")
	player = null  # Reset player reference to force re-finding
	_update_player_clothing()

func force_update_clothing_flip():
	"""Force update all clothing sprites to match player sprite flip"""
	print("EquipmentManager: Force updating clothing flip")
	update_all_clothing_flip() 