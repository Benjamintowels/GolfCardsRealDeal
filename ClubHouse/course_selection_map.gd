extends Node2D

#use for Course selection on Main.tscn

@onready var map_marker = $MapMarker
@onready var course_label = $Label

func _ready():
	# Connect the MapMarker button signal
	if map_marker:
		map_marker.pressed.connect(_on_map_marker_pressed)

func _on_map_marker_pressed():
	"""Handle MapMarker button click"""
	print("MapMarker clicked - Course: Golf Island")
	# Update the label to show the selected course
	if course_label:
		course_label.text = "Course: Golf Island"
