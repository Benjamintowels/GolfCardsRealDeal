extends Control

signal dialog_closed

@onready var background: ColorRect = $Background
@onready var title_label: Label = $DialogBox/TitleLabel
@onready var distance_label: Label = $DialogBox/DistanceLabel
@onready var record_label: Label = $DialogBox/RecordLabel
@onready var shot_label: Label = $DialogBox/ShotLabel
@onready var instruction_label: Label = $DialogBox/InstructionLabel

func _ready():
	# Hide initially
	visible = false
	
	# Connect background click to close
	background.gui_input.connect(_on_background_input)

func set_distance(distance: float):
	"""Set the distance value"""
	distance_label.text = "%d pixels" % distance

func set_record_message(is_new_record: bool):
	"""Set the record message visibility"""
	record_label.visible = is_new_record

func set_shot_counter(shot_number: int, max_shots: int):
	"""Set the shot counter"""
	shot_label.text = "Shot %d of %d" % [shot_number, max_shots]

func set_continue_instruction():
	"""Set the continue instruction"""
	instruction_label.text = "Click anywhere to continue"

func show_dialog(distance: float, is_new_record: bool, shot_number: int, max_shots: int):
	"""Show the distance dialog with the given information"""
	visible = true
	z_index = 500
	
	# Update all labels
	set_distance(distance)
	set_record_message(is_new_record)
	set_shot_counter(shot_number, max_shots)
	set_continue_instruction()

func _on_background_input(event: InputEvent):
	"""Handle background click to close dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()

func close_dialog():
	"""Close the dialog"""
	visible = false
	dialog_closed.emit() 