extends Node2D

func _ready():
	print("=== TESTING PUNCH NODE FINDER ===")
	
	# Find the Player node
	var player = get_node_or_null("Player")
	if not player:
		print("✗ Player node not found")
		return
	
	print("✓ Found Player node:", player)
	print("Player children:", player.get_children())
	
	# Look for BennyChar
	for child in player.get_children():
		print("Checking child:", child.name, "Type:", child.get_class())
		if child.name == "BennyChar":
			print("✓ Found BennyChar!")
			print("BennyChar children:", child.get_children())
			
			# Look for BennyPunch
			var benny_punch = child.get_node_or_null("BennyPunch")
			if benny_punch:
				print("✓ Found BennyPunch node!")
				print("BennyPunch type:", benny_punch.get_class())
				print("BennyPunch visible:", benny_punch.visible)
				if benny_punch is AnimatedSprite2D:
					print("✓ BennyPunch is AnimatedSprite2D!")
					print("BennyPunch animation:", benny_punch.animation)
					print("BennyPunch sprite_frames:", benny_punch.sprite_frames)
				else:
					print("✗ BennyPunch is not AnimatedSprite2D")
			else:
				print("✗ BennyPunch node not found in BennyChar")
				print("Available nodes in BennyChar:")
				for benny_child in child.get_children():
					print("  -", benny_child.name, "Type:", benny_child.get_class())
		else:
			print("  Not BennyChar, checking children...")
			for grandchild in child.get_children():
				print("    Grandchild:", grandchild.name, "Type:", grandchild.get_class())
	
	print("=== TEST COMPLETE ===") 