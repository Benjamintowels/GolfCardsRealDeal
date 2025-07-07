extends Node

# Test script to verify Ice Club is in the starter deck

func _ready():
	print("=== TESTING ICE CLUB IN STARTER DECK ===")
	
	# Create a CurrentDeckManager instance
	var deck_manager = CurrentDeckManager.new()
	add_child(deck_manager)
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	# Check the deck contents
	var deck = deck_manager.get_current_deck()
	print("Starter deck size:", deck.size())
	print("Starter deck contents:")
	
	var has_ice_club = false
	var has_fire_club = false
	
	for card in deck:
		print("  -", card.name)
		if card.name == "Ice Club":
			has_ice_club = true
		if card.name == "Fire Club":
			has_fire_club = true
	
	print("\n=== VERIFICATION RESULTS ===")
	print("Ice Club found:", has_ice_club)
	print("Fire Club found:", has_fire_club)
	
	if has_ice_club and has_fire_club:
		print("✅ SUCCESS: Both Ice Club and Fire Club are in the starter deck!")
	else:
		print("❌ ERROR: Missing clubs in starter deck")
	
	# Clean up
	deck_manager.queue_free()
	
	# Quit after a short delay
	await get_tree().create_timer(1.0).timeout
	get_tree().quit() 