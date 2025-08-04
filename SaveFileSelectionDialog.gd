extends Control

signal save_file_selected(slot_id: int)
signal new_game_requested(slot_id: int, character_id: int)
signal dialog_closed

@onready var slot1_button = $VBoxContainer/Slot1Button
@onready var slot2_button = $VBoxContainer/Slot2Button
@onready var slot3_button = $VBoxContainer/Slot3Button
@onready var back_button = $VBoxContainer/BackButton
@onready var character_selection = $CharacterSelection

var save_file_manager: Node
var selected_slot: int = 0
var selected_character: int = 1

func _ready():
	save_file_manager = get_node("/root/SaveFileManager")
	
	# Connect button signals
	slot1_button.pressed.connect(_on_slot1_pressed)
	slot2_button.pressed.connect(_on_slot2_pressed)
	slot3_button.pressed.connect(_on_slot3_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect right-click signals for delete functionality
	slot1_button.gui_input.connect(_on_slot1_input)
	slot2_button.gui_input.connect(_on_slot2_input)
	slot3_button.gui_input.connect(_on_slot3_input)
	
	# Connect character selection
	character_selection.character_selected.connect(_on_character_selected)
	
	# Connect save file manager signals
	save_file_manager.save_file_deleted.connect(_on_save_file_deleted)
	
	# Initially hide character selection
	character_selection.visible = false
	
	# Add instruction label
	add_instruction_label()
	
	# Update slot displays
	update_slot_displays()

func add_instruction_label():
	"""Add instruction label for delete functionality"""
	var instruction_label = Label.new()
	instruction_label.text = "Right-click existing saves to delete them"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.modulate = Color.GRAY
	instruction_label.add_theme_font_size_override("font_size", 14)
	
	# Position it at the bottom of the VBoxContainer
	var vbox = get_node("VBoxContainer")
	if vbox:
		vbox.add_child(instruction_label)
		# Move it to the bottom (before the back button)
		vbox.move_child(instruction_label, vbox.get_child_count() - 2)

func update_slot_displays():
	"""Update the display of all save slots"""
	update_slot_display(1, slot1_button)
	update_slot_display(2, slot2_button)
	update_slot_display(3, slot3_button)

func update_slot_display(slot_id: int, button: Button):
	"""Update a single slot's display"""
	var save_info = save_file_manager.get_save_file_info(slot_id)
	
	if save_info["exists"]:
		# Existing save file
		var last_played = save_info["last_played"]
		if last_played.length() > 10:
			last_played = last_played.substr(0, 10)  # Just show date
		
		button.text = "Slot " + str(slot_id) + "\n" + \
					 save_info["character_name"] + "\n" + \
					 "Score: " + str(save_info["total_score"]) + "\n" + \
					 "Holes: " + str(save_info["total_holes_played"]) + "\n" + \
					 "ClubHouse Lv." + str(save_info["clubhouse_level"]) + "\n" + \
					 "Last: " + last_played
		button.modulate = Color.WHITE
		button.tooltip_text = "Left Click: Load • Right Click: Delete"
	else:
		# Empty slot
		button.text = "Slot " + str(slot_id) + "\n[Empty]\nCreate New Save File"
		button.modulate = Color.GRAY
		button.tooltip_text = "Create new save file"

func _on_slot1_pressed():
	handle_slot_pressed(1)

func _on_slot2_pressed():
	handle_slot_pressed(2)

func _on_slot3_pressed():
	handle_slot_pressed(3)

# Input handlers for right-click delete functionality
func _on_slot1_input(event: InputEvent):
	handle_slot_input(event, 1)

func _on_slot2_input(event: InputEvent):
	handle_slot_input(event, 2)

func _on_slot3_input(event: InputEvent):
	handle_slot_input(event, 3)

func handle_slot_input(event: InputEvent, slot_id: int):
	"""Handle input events for slot buttons (right-click to delete)"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click to delete existing save file
			var save_info = save_file_manager.get_save_file_info(slot_id)
			if save_info["exists"]:
				show_delete_confirmation(slot_id)

func show_delete_confirmation(slot_id: int):
	"""Show confirmation dialog for deleting save file"""
	# Create a simple confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Delete Save File"
	dialog.dialog_text = "Are you sure you want to delete Slot " + str(slot_id) + "?\nThis action cannot be undone."
	dialog.add_button("Delete", true, "delete")
	dialog.add_button("Cancel", true, "cancel")
	
	# Connect signals
	dialog.confirmed.connect(_on_delete_confirmed.bind(slot_id))
	dialog.custom_action.connect(_on_delete_custom_action.bind(slot_id, dialog))
	
	# Add to scene and show
	add_child(dialog)
	dialog.popup_centered()

func _on_delete_confirmed(slot_id: int):
	"""Handle delete confirmation"""
	delete_save_file(slot_id)

func _on_delete_custom_action(action: String, slot_id: int, dialog: AcceptDialog):
	"""Handle custom dialog actions"""
	if action == "delete":
		delete_save_file(slot_id)
	
	# Remove dialog
	dialog.queue_free()

func delete_save_file(slot_id: int):
	"""Delete the save file for the given slot"""
	print("Attempting to delete save file: Slot ", slot_id)
	if save_file_manager.delete_save_file(slot_id):
		print("Save file deleted successfully: Slot ", slot_id)
		# The display will be updated via the save_file_deleted signal
	else:
		print("ERROR: Failed to delete save file: Slot ", slot_id)

func _on_save_file_deleted(slot_id: int):
	"""Handle save file deleted signal from SaveFileManager"""
	print("Received save_file_deleted signal for slot: ", slot_id)
	# Add a small delay to ensure file system has updated
	await get_tree().create_timer(0.1).timeout
	# Force refresh all slot displays
	update_slot_displays()
	print("Slot displays updated after delete for slot: ", slot_id)

func handle_slot_pressed(slot_id: int):
	"""Handle slot button press"""
	var save_info = save_file_manager.get_save_file_info(slot_id)
	
	if save_info["exists"]:
		# Load existing save
		if save_file_manager.load_save_file(slot_id):
			emit_signal("save_file_selected", slot_id)
			hide()
	else:
		# Create new save - go directly to Main scene (no character selection)
		selected_slot = slot_id
		# Create new save with default character (Benny - character 2)
		if save_file_manager.create_new_save_file(slot_id, 2):
			emit_signal("new_game_requested", slot_id, 2)
			hide()
		else:
			print("ERROR: Failed to create save file")

func _on_character_selected(character_id: int):
	"""Handle character selection for new save"""
	selected_character = character_id
	
	# Create new save file
	if save_file_manager.create_new_save_file(selected_slot, selected_character):
		emit_signal("new_game_requested", selected_slot, selected_character)
		hide()
	else:
		print("ERROR: Failed to create save file")

func _on_back_pressed():
	"""Handle back button press"""
	emit_signal("dialog_closed")
	hide()

func _input(event):
	"""Handle input events"""
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed() 
