extends Node2D

func _ready():
	print("=== CLOTHING SYSTEM TEST ===")
	
	# Test equipment data creation
	var cape = preload("res://Equipment/Clothes/Cape.tres")
	var top_hat = preload("res://Equipment/Clothes/TopHat.tres")
	var wand = preload("res://Equipment/Wand.tres")
	
	print("Cape loaded:", cape.name, "is_clothing:", cape.is_clothing, "slot:", cape.clothing_slot)
	print("Top Hat loaded:", top_hat.name, "is_clothing:", top_hat.is_clothing, "slot:", top_hat.clothing_slot)
	print("Wand loaded:", wand.name, "is_clothing:", wand.is_clothing, "slot:", wand.clothing_slot)
	
	# Test display images
	print("Cape display_image:", cape.display_image != null)
	print("Top Hat display_image:", top_hat.display_image != null)
	print("Wand display_image:", wand.display_image != null)
	
	# Test equipment manager
	var equipment_manager = EquipmentManager.new()
	add_child(equipment_manager)
	
	# Test player finding
	print("Testing player finding...")
	equipment_manager.force_update_player_clothing()
	
	# Test adding clothing
	print("Adding Cape...")
	equipment_manager.add_equipment(cape)
	print("Adding Top Hat...")
	equipment_manager.add_equipment(top_hat)
	print("Adding Wand...")
	equipment_manager.add_equipment(wand)
	
	# Check clothing slots
	var clothing_slots = equipment_manager.get_clothing_slots()
	print("Head slot:", clothing_slots["head"].name if clothing_slots["head"] else "empty")
	print("Neck slot:", clothing_slots["neck"].name if clothing_slots["neck"] else "empty")
	print("Body slot:", clothing_slots["body"].name if clothing_slots["body"] else "empty")
	
	# Check bonuses
	print("Mobility bonus:", equipment_manager.get_mobility_bonus())
	print("Strength bonus:", equipment_manager.get_strength_bonus())
	print("Card draw bonus:", equipment_manager.get_card_draw_bonus())
	
	# Test getting all equipped equipment
	var all_equipment = equipment_manager.get_equipped_equipment()
	print("Total equipped items:", all_equipment.size())
	for item in all_equipment:
		print("  -", item.name, "(clothing:" + str(item.is_clothing) + ")")
	
	print("=== CLOTHING SYSTEM TEST COMPLETE ===") 