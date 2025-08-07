extends Control

signal deck_selected(deck_type: String)
signal dialog_closed

@onready var starter_deck_button = $DialogContainer/DeckButtons/StarterDeckButton
@onready var fighter_deck_button = $DialogContainer/DeckButtons/FighterDeckButton
@onready var cancel_button = $DialogContainer/CancelButton
@onready var adventure_mode_button = $DialogContainer/GameModeContainer/GameModeButtons/AdventureModeButton
@onready var score_mode_button = $DialogContainer/GameModeContainer/GameModeButtons/ScoreModeButton

func _ready():
	# Hide dialog initially
	visible = false
	print("DeckSelectionDialog: _ready() called, dialog hidden")
	
	# Connect button signals
	starter_deck_button.pressed.connect(_on_starter_deck_selected)
	fighter_deck_button.pressed.connect(_on_fighter_deck_selected)
	cancel_button.pressed.connect(_on_cancel_pressed)
	adventure_mode_button.pressed.connect(_on_adventure_mode_selected)
	score_mode_button.pressed.connect(_on_score_mode_selected)
	print("DeckSelectionDialog: Button signals connected")
	
	# Connect background click to close
	$Background.gui_input.connect(_on_background_clicked)
	print("DeckSelectionDialog: Background click connected")
	
	# Set default game mode
	Global.score_only_mode = false
	_update_game_mode_buttons()

func show_dialog():
	"""Show the deck selection dialog"""
	print("DeckSelectionDialog: show_dialog() called")
	visible = true
	print("DeckSelectionDialog: Dialog made visible")
	# Focus the first button for keyboard navigation
	starter_deck_button.grab_focus()
	print("DeckSelectionDialog: Focus set to starter deck button")
	
	# Load saved game mode preference
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		var save_data = save_file_manager.current_save_data
		Global.score_only_mode = save_data.get("game_preferences", {}).get("score_only_mode", false)
		print("Loaded game mode preference - Score only mode:", Global.score_only_mode)
	
	# Update game mode buttons to reflect current state
	_update_game_mode_buttons()

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

func _on_adventure_mode_selected():
	"""Handle adventure mode selection"""
	print("Adventure mode selected")
	Global.score_only_mode = false
	_update_game_mode_buttons()
	_save_game_mode_preference()
	
	# Reset bag level to default for adventure mode
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		var deck_state = save_file_manager.current_save_data.get("deck_state", {})
		deck_state["bag_level"] = 1
		save_file_manager.current_save_data["deck_state"] = deck_state
		save_file_manager.save_current_game()
		print("🎯 ADVENTURE MODE: Reset save file bag level to 1")

func _on_score_mode_selected():
	"""Handle score mode selection"""
	print("Score mode selected")
	Global.score_only_mode = true
	_update_game_mode_buttons()
	_save_game_mode_preference()
	
	# Update bag level to 4 for score mode to hold more club cards
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		var deck_state = save_file_manager.current_save_data.get("deck_state", {})
		deck_state["bag_level"] = 4
		save_file_manager.current_save_data["deck_state"] = deck_state
		save_file_manager.save_current_game()
		print("🎯 SCORE MODE: Updated save file bag level to 4")

func _update_game_mode_buttons():
	"""Update button states to show selected game mode"""
	adventure_mode_button.button_pressed = not Global.score_only_mode
	score_mode_button.button_pressed = Global.score_only_mode
	print("Game mode updated - Score only mode:", Global.score_only_mode)

func _on_cancel_pressed():
	"""Handle cancel button press"""
	print("Deck selection cancelled")
	emit_signal("dialog_closed")
	hide_dialog()
	
	# Get the parent Main scene and call its reverse animation function
	var main_scene = get_parent()
	if main_scene and main_scene.has_method("_reverse_select_benny_animation_internal"):
		main_scene._reverse_select_benny_animation_internal()

func _on_background_clicked(event):
	"""Handle background click to close dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_pressed()

func update_available_decks():
	"""Update deck buttons based on unlocked decks in save data"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if not save_file_manager:
		return
	
	# Show/hide deck buttons based on unlocks
	starter_deck_button.visible = save_file_manager.is_deck_unlocked("starter")
	fighter_deck_button.visible = save_file_manager.is_deck_unlocked("fighter")
	
	# If no decks are unlocked, show at least the starter deck
	if not starter_deck_button.visible and not fighter_deck_button.visible:
		starter_deck_button.visible = true 

func _save_game_mode_preference():
	"""Save the current game mode preference"""
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager and save_file_manager.current_save_slot > 0:
		save_file_manager.save_current_game()
		print("Game mode preference saved") 
