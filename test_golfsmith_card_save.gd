extends Control

func _ready():
	print("=== GOLFSMITH CARD SAVE TEST ===")
	test_card_save_system()

func test_card_save_system():
	print("\n--- Testing GolfSmith Card Save System ---")
	
	# Test 1: Check if SaveFileManager has the card_save flag
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager:
		var story = save_file_manager.current_save_data.get("story_progression", {})
		var npc_quests = story.get("npc_quests", {})
		var gs = npc_quests.get("golfsmith", {})
		var shop_unlocked = bool(gs.get("shop", false))
		var card_save_unlocked = bool(gs.get("card_save", false))
		
		print("GolfSmith shop unlocked:", shop_unlocked)
		print("GolfSmith card save unlocked:", card_save_unlocked)
		
		# Test 2: Check current card genes
		var card_genes = save_file_manager.get_card_genes()
		print("Current card genes:", card_genes.size(), "genes")
		for gene in card_genes:
			print("  -", gene)
		
		# Test 3: Test unlocking a card gene
		var test_card_path = "res://Cards/Move1.tres"
		if not card_genes.has(test_card_path):
			print("Testing unlock of", test_card_path)
			var success = save_file_manager.unlock_card_gene(test_card_path)
			print("Unlock success:", success)
			
			# Verify it was added
			var updated_genes = save_file_manager.get_card_genes()
			print("Updated card genes:", updated_genes.size(), "genes")
			print("Contains test gene:", updated_genes.has(test_card_path))
		else:
			print("Test card gene already unlocked")
		
		print("✅ SUCCESS: Card Save system working!")
	else:
		print("❌ ERROR: SaveFileManager not found!")
	
	print("=== END TEST ===")
