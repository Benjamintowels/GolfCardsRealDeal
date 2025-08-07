extends Node2D

#use for Course selection on Main.tscn

@onready var map_marker_front_9 = $MapMarkerFront9
@onready var map_marker_back_9 = $MapMarkerBack9
@onready var course_label = $Label

func _ready():
	# Connect the MapMarker button signals
	if map_marker_front_9:
		map_marker_front_9.pressed.connect(_on_map_marker_front_9_pressed)
	
	if map_marker_back_9:
		map_marker_back_9.pressed.connect(_on_map_marker_back_9_pressed)
	
	# Check if back 9 flag upgrade is purchased and show/hide MapMarkerBack9
	_update_back_9_flag_visibility()

func _update_back_9_flag_visibility():
	"""Update visibility of MapMarkerBack9 based on flag upgrade status"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and map_marker_back_9:
		var flag_purchased = save_file_manager.get_story_flag("back_9_flag_upgrade_purchased")
		map_marker_back_9.visible = flag_purchased
		print("MapMarkerBack9 visibility set to:", flag_purchased, "(flag upgrade purchased:", flag_purchased, ")")

func _on_map_marker_front_9_pressed():
	"""Handle MapMarkerFront9 button click"""
	print("MapMarkerFront9 clicked - Course: Front 9")
	# Update the label to show the selected course
	if course_label:
		course_label.text = "Course: Front 9"
	
	# Emit signal to Main.gd to handle the selection
	get_parent().get_parent()._on_map_marker_front_9_selected()

func _on_map_marker_back_9_pressed():
	"""Handle MapMarkerBack9 button click"""
	print("MapMarkerBack9 clicked - Course: Back 9")
	# Update the label to show the selected course
	if course_label:
		course_label.text = "Course: Back 9"
	
	# Emit signal to Main.gd to handle the selection
	get_parent().get_parent()._on_map_marker_back_9_selected()
