extends Node2D

# Simple test script to verify Wraith Y-sorting fix

func _ready():
	print("=== SIMPLE WRAITH Y-SORT TEST ===")
	
	# Find Wraith
	var wraiths = get_tree().get_nodes_in_group("bosses")
	print("Found", wraiths.size(), "bosses (Wraiths)")
	
	for wraith in wraiths:
		if is_instance_valid(wraith) and "Wraith" in wraith.name:
			print("=== WRAITH INFO ===")
			print("Wraith name:", wraith.name)
			print("Wraith position:", wraith.global_position)
			print("Wraith z_index:", wraith.z_index)
			
			# Check Y-sort point
			var ysort_point = wraith.get_node_or_null("YSortPoint")
			if ysort_point:
				print("YSortPoint found at:", ysort_point.global_position)
			else:
				print("YSortPoint not found!")
			
			# Check ice Y-sort point
			var ice_ysort_point = wraith.get_node_or_null("WraithIce/IceYSortPoint")
			if ice_ysort_point:
				print("IceYSortPoint found at:", ice_ysort_point.global_position)
			else:
				print("IceYSortPoint not found!")
			
			# Test get_y_sort_point method
			if wraith.has_method("get_y_sort_point"):
				var y_sort_value = wraith.get_y_sort_point()
				print("get_y_sort_point() returns:", y_sort_value)
			else:
				print("get_y_sort_point() method not found!")
	
	print("=== END SIMPLE WRAITH Y-SORT TEST ===") 