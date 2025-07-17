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
	if distance_label:
		distance_label.text = "%d pixels" % distance
	else:
		print("ERROR: distance_label is null in set_distance")
		# Try to get the node manually as fallback
		var fallback_label = get_node_or_null("DialogBox/DistanceLabel")
		if fallback_label:
			fallback_label.text = "%d pixels" % distance
		else:
			print("ERROR: Could not find DistanceLabel node")

func set_record_message(is_new_record: bool):
	"""Set the record message visibility"""
	if record_label:
		record_label.visible = is_new_record
	else:
		print("ERROR: record_label is null in set_record_message")
		# Try to get the node manually as fallback
		var fallback_label = get_node_or_null("DialogBox/RecordLabel")
		if fallback_label:
			fallback_label.visible = is_new_record
		else:
			print("ERROR: Could not find RecordLabel node")

func set_shot_counter(shot_number: int, max_shots: int):
	"""Set the shot counter"""
	if shot_label:
		shot_label.text = "Shot %d of %d" % [shot_number, max_shots]
	else:
		print("ERROR: shot_label is null in set_shot_counter")
		# Try to get the node manually as fallback
		var fallback_label = get_node_or_null("DialogBox/ShotLabel")
		if fallback_label:
			fallback_label.text = "Shot %d of %d" % [shot_number, max_shots]
		else:
			print("ERROR: Could not find ShotLabel node")

func set_continue_instruction():
	"""Set the continue instruction"""
	if instruction_label:
		instruction_label.text = "Click anywhere to continue"
	else:
		print("ERROR: instruction_label is null in set_continue_instruction")
		# Try to get the node manually as fallback
		var fallback_label = get_node_or_null("DialogBox/InstructionLabel")
		if fallback_label:
			fallback_label.text = "Click anywhere to continue"
		else:
			print("ERROR: Could not find InstructionLabel node")

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
