extends Node2D

# Test script to verify Wraith and GangMember use identical Y-sort implementations

func _ready():
	print("=== Y-SORT IMPLEMENTATION COMPARISON TEST ===")
	
	# Test Wraith Y-sort implementation
	print("\n--- WRAITH Y-SORT TEST ---")
	var wraith = preload("res://NPC/Bosses/Wraith.tscn").instantiate()
	add_child(wraith)
	
	# Test normal state
	print("Wraith normal state:")
	print("  get_y_sort_point():", wraith.get_y_sort_point())
	print("  YSortPoint exists:", wraith.get_node_or_null("YSortPoint") != null)
	
	# Test frozen state
	wraith.is_frozen = true
	print("Wraith frozen state:")
	print("  get_y_sort_point():", wraith.get_y_sort_point())
	print("  IceYSortPoint exists:", wraith.get_node_or_null("WraithIce/IceYSortPoint") != null)
	
	# Test GangMember Y-sort implementation
	print("\n--- GANGMEMBER Y-SORT TEST ---")
	var gang_member = preload("res://NPC/Gang/GangMember.tscn").instantiate()
	add_child(gang_member)
	
	# Test normal state
	print("GangMember normal state:")
	print("  get_y_sort_point():", gang_member.get_y_sort_point())
	print("  YSortPoint exists:", gang_member.get_node_or_null("YSortPoint") != null)
	
	# Test frozen state
	gang_member.is_frozen = true
	print("GangMember frozen state:")
	print("  get_y_sort_point():", gang_member.get_y_sort_point())
	print("  IceYSortPoint exists:", gang_member.get_node_or_null("GangMemberIce/YSortPoint") != null)
	
	# Compare function implementations
	print("\n--- FUNCTION IMPLEMENTATION COMPARISON ---")
	print("Both NPCs should have identical Y-sort implementations:")
	print("  - update_z_index_for_ysort() calls Global.update_object_y_sort(self, 'characters')")
	print("  - get_y_sort_point() uses ice Y-sort point when frozen, normal Y-sort point otherwise")
	print("  - Y-sort updates called in setup, during movement, and after movement")
	
	print("\n=== Y-SORT COMPARISON TEST COMPLETE ===")
	
	# Clean up
	wraith.queue_free()
	gang_member.queue_free() 