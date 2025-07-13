extends Node2D

# Test script to verify Wraith Y-sorting with other objects
# This will help debug the Y-sorting issue

func _ready():
	print("=== WRAITH Y-SORT TEST ===")
	
	# Find Wraith
	var wraiths = get_tree().get_nodes_in_group("bosses")
	print("Found", wraiths.size(), "bosses (Wraiths)")
	
	# Find other objects for comparison
	var trees = get_tree().get_nodes_in_group("trees")
	var players = get_tree().get_nodes_in_group("player")
	var gang_members = get_tree().get_nodes_in_group("NPC")
	
	print("Found", trees.size(), "trees")
	print("Found", players.size(), "players")
	print("Found", gang_members.size(), "NPCs")
	
	# Check Y-sorting for Wraith
	for wraith in wraiths:
		if is_instance_valid(wraith) and "Wraith" in wraith.name:
			var wraith_pos = wraith.global_position
			var wraith_z_index = wraith.z_index
			var wraith_ysort_point = wraith.get_y_sort_point() if wraith.has_method("get_y_sort_point") else wraith_pos.y
			
			print("=== WRAITH Y-SORT INFO ===")
			print("Wraith name:", wraith.name)
			print("Wraith position:", wraith_pos)
			print("Wraith z_index:", wraith_z_index)
			print("Wraith ysort_point:", wraith_ysort_point)
			print("Wraith is_frozen:", wraith.is_frozen if "is_frozen" in wraith else "N/A")
			
			# Check ice references
			if wraith.has_method("_setup_ice_references"):
				var ice_ysort_point = wraith.get_node_or_null("WraithIce/IceYSortPoint")
				var normal_ysort_point = wraith.get_node_or_null("YSortPoint")
				
				print("Ice Y-sort point exists:", ice_ysort_point != null)
				if ice_ysort_point:
					print("Ice Y-sort point position:", ice_ysort_point.global_position)
				print("Normal Y-sort point exists:", normal_ysort_point != null)
				if normal_ysort_point:
					print("Normal Y-sort point position:", normal_ysort_point.global_position)
	
	# Check Y-sorting for comparison objects
	print("=== COMPARISON OBJECTS ===")
	
	# Check trees
	for tree in trees:
		if is_instance_valid(tree):
			var tree_pos = tree.global_position
			var tree_z_index = tree.z_index
			var tree_ysort_point = tree.get_y_sort_point() if tree.has_method("get_y_sort_point") else tree_pos.y
			
			print("Tree at", tree_pos, "z_index:", tree_z_index, "ysort_point:", tree_ysort_point)
	
	# Check players
	for player in players:
		if is_instance_valid(player):
			var player_pos = player.global_position
			var player_z_index = player.z_index
			var player_ysort_point = player.get_y_sort_point() if player.has_method("get_y_sort_point") else player_pos.y
			
			print("Player at", player_pos, "z_index:", player_z_index, "ysort_point:", player_ysort_point)
	
	# Check gang members
	for gang_member in gang_members:
		if is_instance_valid(gang_member) and "GangMember" in gang_member.name:
			var gang_pos = gang_member.global_position
			var gang_z_index = gang_member.z_index
			var gang_ysort_point = gang_member.get_y_sort_point() if gang_member.has_method("get_y_sort_point") else gang_pos.y
			
			print("GangMember at", gang_pos, "z_index:", gang_z_index, "ysort_point:", gang_ysort_point)
	
	print("=== END WRAITH Y-SORT TEST ===")

func _process(delta):
	# Update Y-sorting for all objects every few seconds
	if Time.get_ticks_msec() % 5000 < 16:  # Every 5 seconds
		print("=== UPDATING Y-SORT ===")
		
		# Force update Y-sorting for all objects
		var course = get_tree().current_scene
		if course and course.has_method("update_all_ysort_z_indices"):
			course.update_all_ysort_z_indices()
			print("✓ Updated all Y-sort indices")
		
		# Update individual Wraith Y-sorting
		var wraiths = get_tree().get_nodes_in_group("bosses")
		for wraith in wraiths:
			if is_instance_valid(wraith) and "Wraith" in wraith.name and wraith.has_method("update_z_index_for_ysort"):
				wraith.update_z_index_for_ysort()
				print("✓ Updated Wraith Y-sort") 