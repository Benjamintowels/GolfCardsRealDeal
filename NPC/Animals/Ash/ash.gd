extends Node2D

# Item pickup functionality for Ash dog
signal item_pickup_triggered(item: Node)

func _ready():
	# Set up the ItemPickUpArea2D for item detection
	var item_pickup_area = get_node_or_null("ItemPickUpArea2D")
	if item_pickup_area:
		# Set collision layer to 0 (not detected by other objects)
		item_pickup_area.collision_layer = 0
		# Set collision mask to 4 (detect items on layer 4)
		item_pickup_area.collision_mask = 4
		
		# Connect to area entered signal for item pickup
		if not item_pickup_area.area_entered.is_connected(_on_item_pickup_area_entered):
			item_pickup_area.area_entered.connect(_on_item_pickup_area_entered)
		
		print("✓ Ash ItemPickUpArea2D configured for item detection")
	else:
		print("✗ ERROR: ItemPickUpArea2D not found in Ash scene")

func _on_item_pickup_area_entered(area: Area2D):
	"""Handle collision with items for pickup"""
	print("🔍 ASH ITEM PICKUP: Area entered -", area.name if area else "null")
	
	# Get the parent of the area (the actual item)
	var item = area.get_parent()
	if not item:
		print("❌ ASH ITEM PICKUP: No parent object found for area")
		return
	
	print("🔍 ASH ITEM PICKUP: Item name:", item.name, "Type:", item.get_class())
	
	# Check if this is an item that can be picked up
	if _is_pickupable_item(item):
		print("✅ ASH ITEM PICKUP: Found pickupable item:", item.name)
		_handle_item_pickup(item)
	else:
		print("❌ ASH ITEM PICKUP: Not a pickupable item")

func _is_pickupable_item(item: Node) -> bool:
	"""Check if the item can be picked up by Ash"""
	# Check if this is a Key
	if item.name == "Key" or item.get_script() and "Key" in str(item.get_script()):
		return true
	
	# Add more item types here as needed
	# if item.name == "OtherItem" or item.get_script() and "OtherItem" in str(item.get_script()):
	#     return true
	
	return false

func _handle_item_pickup(item: Node):
	"""Handle the actual item pickup logic"""
	print("🗝️ ASH ITEM PICKUP: Processing pickup for item:", item.name)
	
	# Emit signal to notify the attack strategy that an item was picked up
	item_pickup_triggered.emit(item)
	
	# The actual pickup logic will be handled by the course (same as player pickup)
	var course = get_tree().current_scene
	if course and course.has_method("_on_key_area_entered"):
		# Find the player node to pass to the key pickup method
		var player_node = _find_player_node()
		if player_node:
			print("✅ ASH ITEM PICKUP: Triggering course key pickup for player:", player_node.name)
			course._on_key_area_entered(player_node)
		else:
			print("❌ ASH ITEM PICKUP: Could not find player node for key pickup")
					# Fallback: try to get player from course's player_manager property
		if "player_manager" in course:
			var player_manager = course.player_manager
			if player_manager and player_manager.has_method("get_player_node"):
				var fallback_player = player_manager.get_player_node()
				if fallback_player:
					print("✅ ASH ITEM PICKUP: Using fallback player from player_manager:", fallback_player.name)
					course._on_key_area_entered(fallback_player)
				else:
					print("❌ ASH ITEM PICKUP: Fallback player_manager.get_player_node() returned null")
			else:
				print("❌ ASH ITEM PICKUP: Course player_manager does not have get_player_node method")
		else:
			print("❌ ASH ITEM PICKUP: Course does not have player_manager property")
	else:
		print("❌ ASH ITEM PICKUP: Course does not have _on_key_area_entered method")

func _find_player_node() -> Node:
	"""Find the player node in the scene"""
	# Look for the Player node in the scene
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return player
	
	# Fallback: search by name
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		return player_nodes[0]
	
	# Another fallback: search by name pattern
	for node in get_tree().get_nodes_in_group("player"):
		if node.name == "Player" or node.name.contains("Player"):
			return node
	
	# Additional fallback: search for PlayerManager
	var player_manager = get_tree().get_first_node_in_group("player_manager")
	if player_manager and player_manager.has_method("get_player_node"):
		var player_node = player_manager.get_player_node()
		if player_node:
			return player_node
	
	# Last fallback: search for any node with "Player" in the name
	for node in get_tree().get_nodes_in_group("player"):
		if node.name.contains("Player"):
			return node
	
	# Search all nodes in the scene for Player
	var all_nodes = get_tree().get_nodes_in_group("player")
	for node in all_nodes:
		if node.name == "Player" or node.name.contains("Player"):
			return node
	
	print("❌ ASH ITEM PICKUP: Could not find any player node in scene")
	return null
