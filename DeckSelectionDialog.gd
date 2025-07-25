extends Control

signal deck_selected(deck_type: String)
signal dialog_closed

@onready var starter_deck_button = $DialogContainer/DeckButtons/StarterDeckButton
@onready var fighter_deck_button = $DialogContainer/DeckButtons/FighterDeckButton
@onready var cancel_button = $DialogContainer/CancelButton

func _ready():
	# Hide dialog initially
	visible = false
	print("DeckSelectionDialog: _ready() called, dialog hidden")
	
	# Connect button signals
	starter_deck_button.pressed.connect(_on_starter_deck_selected)
	fighter_deck_button.pressed.connect(_on_fighter_deck_selected)
	cancel_button.pressed.connect(_on_cancel_pressed)
	print("DeckSelectionDialog: Button signals connected")
	
	# Connect background click to close
	$Background.gui_input.connect(_on_background_clicked)
	print("DeckSelectionDialog: Background click connected")

func show_dialog():
	"""Show the deck selection dialog"""
	print("DeckSelectionDialog: show_dialog() called")
	visible = true
	print("DeckSelectionDialog: Dialog made visible")
	# Focus the first button for keyboard navigation
	starter_deck_button.grab_focus()
	print("DeckSelectionDialog: Focus set to starter deck button")

func hide_dialog():
	"""Hide the deck selection dialog"""
	visible = false

func _on_starter_deck_selected():
	"""Handle starter deck selection"""
	print("Starter deck selected")
	CurrentDeckManager.switch_to_starter_deck()
	emit_signal("deck_selected", "starter")
	hide_dialog()

func _on_fighter_deck_selected():
	"""Handle fighter deck selection"""
	print("Fighter deck selected")
	CurrentDeckManager.switch_to_fighter_deck()
	emit_signal("deck_selected", "fighter")
	hide_dialog()

func _on_cancel_pressed():
	"""Handle cancel button press"""
	print("Deck selection cancelled")
	emit_signal("dialog_closed")
	hide_dialog()

func _on_background_clicked(event):
	"""Handle background click to close dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_pressed() 
