extends Node

# Example script showing how to integrate the FileLevelManager with a golf course scene
# This demonstrates how to call the progression system when holes are completed

# Example function to call when a hole is completed in your golf course
func on_hole_completed(hole_number: int):
	"""Called when a player completes a hole"""
	print("Hole ", hole_number, " completed!")
	
	# Get the FileLevelManager and add experience
	var file_level_manager = get_node("/root/Main/FileLevelManager")
	if file_level_manager:
		file_level_manager.complete_hole(hole_number)
		print("Experience added for hole ", hole_number)
	else:
		print("ERROR: FileLevelManager not found!")

# Example function to call when the course is completed (hole 18)
func on_course_completed():
	"""Called when the entire course is completed"""
	print("Course completed!")
	
	# Show the final score display
	var main_scene = get_node("/root/Main")
	if main_scene:
		main_scene.show_final_score_display()
	else:
		print("ERROR: Main scene not found!")

# Example function to call when the player dies/restarts
func on_player_died():
	"""Called when the player dies and needs to return to clubhouse"""
	print("Player died - showing final score display")
	
	# Show the final score display before returning to clubhouse
	var main_scene = get_node("/root/Main")
	if main_scene:
		main_scene.show_final_score_display()
	else:
		print("ERROR: Main scene not found!")

# Example usage in a golf course scene:
# 
# 1. When a hole is completed:
#    on_hole_completed(current_hole_number)
#
# 2. When the course is finished (hole 18):
#    on_course_completed()
#
# 3. When the player dies/restarts:
#    on_player_died()
#
# 4. To manually test progression:
#    var test_script = preload("res://test_progression.gd").new()
#    test_script.test_progression() 