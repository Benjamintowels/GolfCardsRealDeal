extends Node

# Script to integrate FileLevelManager progression with Course1
# This should be attached to Course1 or its UIManager

var file_level_manager: Node

func _ready():
	# Get the FileLevelManager from the main scene
	file_level_manager = get_node("/root/Main/FileLevelManager")
	if not file_level_manager:
		print("ERROR: FileLevelManager not found in Course1 progression integration!")
		return
	
	print("FileLevelManager found in Course1 - progression integration ready")

func on_hole_completed(hole_number: int):
	"""Called when a hole is completed in Course1"""
	if not file_level_manager:
		return
	
	print("Course1: Hole ", hole_number, " completed - adding experience")
	file_level_manager.complete_hole(hole_number)

func on_course_completed():
	"""Called when the entire course is completed (hole 18)"""
	print("Course1: Course completed - showing final score display")
	
	# Show the final score display
	var main_scene = get_node("/root/Main")
	if main_scene and main_scene.has_method("show_final_score_display"):
		main_scene.show_final_score_display()
	else:
		print("ERROR: Main scene not found or missing show_final_score_display method!")

# Integration with existing Course1 hole completion system
# This function should be called from Course1's hole completion logic
func integrate_with_hole_completion(current_hole: int, is_course_complete: bool = false):
	"""Main integration function to be called from Course1's hole completion"""
	if is_course_complete:
		on_course_completed()
	else:
		on_hole_completed(current_hole)

# Example of how to integrate with Course1's existing hole completion dialog
# This could be called from the hole completion dialog's close_dialog() function
func on_hole_completion_dialog_closed(current_hole: int, is_final_hole: bool = false):
	"""Called when the hole completion dialog is closed"""
	if is_final_hole:
		on_course_completed()
	else:
		on_hole_completed(current_hole) 