extends Resource
class_name DialogScript

signal dialog_advance(line_index: int)
signal dialog_complete

var dialog_lines: Array[Dictionary] = []
var current_line_index: int = 0
var is_complete: bool = false

func _init():
	_setup_dialog()

func _setup_dialog():
	"""Override this in subclasses to set up dialog lines"""
	pass

func get_current_line() -> Dictionary:
	"""Get the current dialog line"""
	if current_line_index < dialog_lines.size():
		return dialog_lines[current_line_index]
	return {}

func advance_dialog():
	"""Advance to the next dialog line"""
	current_line_index += 1
	emit_signal("dialog_advance", current_line_index)
	
	if current_line_index >= dialog_lines.size():
		is_complete = true
		emit_signal("dialog_complete")

func reset_dialog():
	"""Reset dialog to beginning"""
	current_line_index = 0
	is_complete = false

func get_total_lines() -> int:
	return dialog_lines.size()

func is_dialog_finished() -> bool:
	return is_complete
