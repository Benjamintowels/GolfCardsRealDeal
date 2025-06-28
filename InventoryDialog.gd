extends Control

signal inventory_closed

@onready var movement_cards_button: Button = $DialogBox/VBoxContainer/ButtonContainer/MovementCardsButton
@onready var club_cards_button: Button = $DialogBox/VBoxContainer/ButtonContainer/ClubCardsButton
@onready var close_button: Button = $DialogBox/VBoxContainer/CloseButton
@onready var card_row: HBoxContainer = $DialogBox/VBoxContainer/CardDisplayArea/CardRow
@onready var background: ColorRect = $Background

var card_scene = preload("res://CardVisual.tscn")
var current_cards: Array[CardData] = []

# These will be set by the course script
var get_movement_cards: Callable
var get_club_cards: Callable

func _ready():
	# Connect button signals
	movement_cards_button.pressed.connect(_on_movement_cards_pressed)
	club_cards_button.pressed.connect(_on_club_cards_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Make background clickable to close
	background.gui_input.connect(_on_background_input)
	
	# Initially hide the dialog
	visible = false

func show_inventory():
	visible = true
	# Clear any existing cards
	clear_cards()

func hide_inventory():
	visible = false
	inventory_closed.emit()

func _on_movement_cards_pressed():
	display_movement_cards()

func _on_club_cards_pressed():
	display_club_cards()

func _on_close_pressed():
	hide_inventory()

func _on_background_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_inventory()

func display_movement_cards():
	clear_cards()
	
	# Get movement cards from the course
	var movement_cards: Array[CardData] = []
	if get_movement_cards.is_valid():
		movement_cards = get_movement_cards.call()
	
	for card_data in movement_cards:
		create_card_display(card_data)

func display_club_cards():
	clear_cards()
	
	# Get club cards from the course
	var club_cards: Array[CardData] = []
	if get_club_cards.is_valid():
		club_cards = get_club_cards.call()
	
	for card_data in club_cards:
		create_card_display(card_data)

func create_card_display(card_data: CardData):
	var card_instance = card_scene.instantiate()
	card_row.add_child(card_instance)
	
	# Set the card data
	if card_instance.has_method("set_card_data"):
		card_instance.set_card_data(card_data)
	
	# Scale down the card for inventory display
	card_instance.scale = Vector2(0.5, 0.5)
	
	# Make it non-interactive in inventory
	card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	current_cards.append(card_data)

func clear_cards():
	# Remove all existing card displays
	for child in card_row.get_children():
		child.queue_free()
	current_cards.clear() 