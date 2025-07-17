extends Control

func _ready():
	print("🔧 TEST_COURSE_DIRECT: Starting direct course load")
	
	# Set up the global variables needed for the course
	Global.selected_character = 2  # Benny
	Global.putt_putt_mode = false
	
	print("🔧 TEST_COURSE_DIRECT: Global.selected_character =", Global.selected_character)
	print("🔧 TEST_COURSE_DIRECT: Global.putt_putt_mode =", Global.putt_putt_mode)
	
	# Wait a frame to ensure everything is set up
	await get_tree().process_frame
	
	# Change directly to the course scene
	print("🔧 TEST_COURSE_DIRECT: Changing to Course1.tscn")
	get_tree().change_scene_to_file("res://Course1.tscn") 