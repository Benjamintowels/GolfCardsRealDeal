extends Node2D

# Test script to debug attack system issues
# Add this to your scene to test if attacks are working

func _ready():
	print("=== ATTACK SYSTEM TEST SCRIPT LOADED ===")
	print("This script will help debug attack system issues")
	print("Check the console for debug information when using attack cards")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			test_attack_system()
		elif event.keycode == KEY_F2:
			test_npc_detection()
		elif event.keycode == KEY_F3:
			test_card_handling()
		elif event.keycode == KEY_F4:
			test_entities_system()

func test_attack_system():
	print("=== TESTING ATTACK SYSTEM ===")
	
	# Find the course
	var course = get_tree().current_scene
	if not course:
		print("✗ No course found")
		return
	
	print("✓ Course found:", course.name)
	
	# Check attack handler
	var attack_handler = course.get_node_or_null("AttackHandler")
	if not attack_handler:
		print("✗ No AttackHandler found")
		return
	
	print("✓ AttackHandler found")
	print("Attack mode:", attack_handler.is_in_attack_mode())
	print("Valid attack tiles:", attack_handler.get_valid_attack_tiles())
	
	# Check movement controller
	var movement_controller = course.get_node_or_null("MovementController")
	if not movement_controller:
		print("✗ No MovementController found")
		return
	
	print("✓ MovementController found")
	
	# Check deck manager
	var deck_manager = course.get_node_or_null("DeckManager")
	if not deck_manager:
		print("✗ No DeckManager found")
		return
	
	print("✓ DeckManager found")
	print("Hand size:", deck_manager.hand.size())
	
	# Check for attack cards in hand
	var attack_cards = []
	for card in deck_manager.hand:
		if card.effect_type == "Attack":
			attack_cards.append(card)
	
	print("Attack cards in hand:", attack_cards.size())
	for card in attack_cards:
		print("  -", card.name, "(effect_type:", card.effect_type, ")")
	
	print("=== END ATTACK SYSTEM TEST ===")

func test_npc_detection():
	print("=== TESTING NPC DETECTION ===")
	
	# Find the course
	var course = get_tree().current_scene
	if not course:
		print("✗ No course found")
		return
	
	# Check entities
	var entities = course.get_node_or_null("Entities")
	if not entities:
		print("✗ No Entities node found")
		return
	
	print("✓ Entities found")
	
	# Get NPCs
	var npcs = entities.get_npcs()
	print("Total NPCs:", npcs.size())
	
	for npc in npcs:
		if is_instance_valid(npc):
			print("=== NPC DETAILS ===")
			print("  Name:", npc.name)
			print("  Class:", npc.get_class())
			print("  Script:", npc.get_script().resource_path if npc.get_script() else "No script")
			print("  Global position:", npc.global_position)
			
			# Check for different position methods
			var pos = Vector2i.ZERO
			var pos_method = "None"
			
			if npc.has_method("get_grid_position"):
				pos = npc.get_grid_position()
				pos_method = "get_grid_position()"
			elif "grid_position" in npc:
				pos = npc.grid_position
				pos_method = "grid_position property"
			elif "grid_pos" in npc:
				pos = npc.grid_pos
				pos_method = "grid_pos property"
			else:
				# Calculate from world position
				pos = Vector2i(floor(npc.global_position.x / 48), floor(npc.global_position.y / 48))
				pos_method = "calculated from world position"
			
			print("  Grid position:", pos, "(using", pos_method, ")")
			print("  Has take_damage:", npc.has_method("take_damage"))
			print("  Has get_is_dead:", npc.has_method("get_is_dead"))
			print("  Has is_dead:", npc.has_method("is_dead"))
			print("  Is dead property:", "is_dead" in npc)
			print("=== END NPC DETAILS ===")
		else:
			print("  - Invalid NPC")
	
	print("=== END NPC DETECTION TEST ===")

func test_card_handling():
	print("=== TESTING CARD HANDLING ===")
	
	# Find the course
	var course = get_tree().current_scene
	if not course:
		print("✗ No course found")
		return
	
	# Check card effect handler
	var card_effect_handler = course.get_node_or_null("CardEffectHandler")
	if not card_effect_handler:
		print("✗ No CardEffectHandler found")
		return
	
	print("✓ CardEffectHandler found")
	
	# Check deck manager
	var deck_manager = course.get_node_or_null("DeckManager")
	if not deck_manager:
		print("✗ No DeckManager found")
		return
	
	print("✓ DeckManager found")
	
	# Check all cards in hand
	print("All cards in hand:")
	for card in deck_manager.hand:
		print("  -", card.name, "(effect_type:", card.effect_type, ", effect_strength:", card.effect_strength, ")")
	
	print("=== END CARD HANDLING TEST ===")

func test_entities_system():
	print("=== TESTING ENTITIES SYSTEM ===")
	
	# Find the course
	var course = get_tree().current_scene
	if not course:
		print("✗ No course found")
		return
	
	# Check entities
	var entities = course.get_node_or_null("Entities")
	if not entities:
		print("✗ No Entities node found")
		return
	
	print("✓ Entities found")
	
	# Get raw NPCs list before cleanup
	var raw_npcs = entities.npcs if "npcs" in entities else []
	print("Raw NPCs in Entities (before cleanup):", raw_npcs.size())
	
	for i in range(raw_npcs.size()):
		var npc = raw_npcs[i]
		print("  Raw NPC", i, ":", npc, "Valid:", is_instance_valid(npc))
		if is_instance_valid(npc):
			print("    Name:", npc.name, "Class:", npc.get_class())
	
	# Get NPCs after cleanup
	var npcs = entities.get_npcs()
	print("NPCs after cleanup:", npcs.size())
	
	for i in range(npcs.size()):
		var npc = npcs[i]
		print("  Clean NPC", i, ":", npc, "Valid:", is_instance_valid(npc))
		if is_instance_valid(npc):
			print("    Name:", npc.name, "Class:", npc.get_class())
	
	print("=== END ENTITIES SYSTEM TEST ===") 