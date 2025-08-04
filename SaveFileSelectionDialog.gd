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
	
	# Connect character selection
	character_selection.character_selected.connect(_on_character_selected)
	
	# Initially hide character selection
	character_selection.visible = false
	
	# Update slot displays
	update_slot_displays()

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
		button.tooltip_text = "Load existing save file"
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

func handle_slot_pressed(slot_id: int):
	"""Handle slot button press"""
	var save_info = save_file_manager.get_save_file_info(slot_id)
	
	if save_info["exists"]:
		# Load existing save
		if save_file_manager.load_save_file(slot_id):
			emit_signal("save_file_selected", slot_id)
			hide()
	else:
		# Create new save - show character selection
		selected_slot = slot_id
		character_selection.visible = true
		character_selection.reset_selection()

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
