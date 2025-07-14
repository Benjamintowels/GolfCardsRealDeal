extends Control

signal card_selected(card_data: CardData)
signal dialog_closed

@onready var card_container: Control = $CardContainer
@onready var left_card_button: Button = $CardContainer/LeftCard
@onready var right_card_button: Button = $CardContainer/RightCard
@onready var title_label: Label = $CardContainer/Title

var left_card_data: CardData
var right_card_data: CardData

# Available cards for arrangement (excluding club cards)
var available_cards: Array[CardData] = [
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move3.tres"),
	preload("res://Cards/Move4.tres"),
	preload("res://Cards/Move5.tres"),
	preload("res://Cards/StickyShot.tres"),
	preload("res://Cards/Bouncey.tres"),
	preload("res://Cards/Dub.tres"),
	preload("res://Cards/RooBoostCard.tres"),
	preload("res://Cards/FloridaScramble.tres"),
	preload("res://Cards/KickB.tres"),
	preload("res://Cards/PunchB.tres"),
	preload("res://Cards/PistolCard.tres"),
	preload("res://Cards/BurstShot.tres"),
	preload("res://Cards/ShotgunCard.tres"),
	preload("res://Cards/SniperCard.tres"),
	preload("res://Cards/GrenadeCard.tres"),
	preload("res://Cards/ThrowingKnife.tres"),
	preload("res://Cards/TeleportCard.tres"),
	preload("res://Cards/Draw2.tres"),
	preload("res://Cards/CoffeeCard.tres"),
	preload("res://Cards/BlockB.tres"),
	preload("res://Cards/CallofthewildCard.tres"),
	preload("res://Cards/Dash.tres"),
	preload("res://Cards/FireBallCard.tres"),
	preload("res://Cards/IceBallCard.tres"),
	preload("res://Cards/ExtraBall.tres"),
	preload("res://Cards/Explosive.tres")
]

func _ready():
	# Hide the dialog initially
	visible = false
	
	# Connect button signals
	left_card_button.pressed.connect(_on_left_card_selected)
	right_card_button.pressed.connect(_on_right_card_selected)
	
	# Connect background click to close
	$Background.gui_input.connect(_on_background_clicked)

func show_arrange_dialog():
	"""Show the arrange dialog with two random cards"""
	# Generate two random cards
	generate_random_cards()
	
	# Set up the left card
	setup_card_button(left_card_button, left_card_data)
	
	# Set up the right card
	setup_card_button(right_card_button, right_card_data)
	
	# Show the dialog
	visible = true

func generate_random_cards():
	"""Generate two random cards from the action deck for the player to choose from"""
	# Get the course and deck manager
	var course = get_tree().current_scene
	if not course:
		print("ArrangeDialog: Warning - course not found")
		return
	
	var deck_manager = course.get("deck_manager")
	if not deck_manager:
		print("ArrangeDialog: Warning - deck_manager not found")
		return
	
	# Get remaining cards from the action deck
	var remaining_cards = deck_manager.get_action_deck_remaining_cards()
	print("ArrangeDialog: Remaining cards in deck:", remaining_cards.size())
	
	# If we don't have enough cards, reshuffle the discard pile
	if remaining_cards.size() < 2:
		print("ArrangeDialog: Not enough cards in deck, reshuffling discard pile")
		deck_manager.reshuffle_action_discard()
		remaining_cards = deck_manager.get_action_deck_remaining_cards()
	
	# Select two different cards from the remaining deck
	if remaining_cards.size() >= 2:
		left_card_data = remaining_cards[0]
		right_card_data = remaining_cards[1]
		
		# Remove these cards from the deck order (they're being "drawn" for arrangement)
		deck_manager.action_deck_order.remove_at(deck_manager.action_deck_index)
		deck_manager.action_deck_order.remove_at(deck_manager.action_deck_index)
		
		print("ArrangeDialog: Generated cards from deck - Left:", left_card_data.name, "Right:", right_card_data.name)
		print("ArrangeDialog: Remaining cards in deck:", deck_manager.get_action_deck_remaining_cards().size())
	else:
		print("ArrangeDialog: Error - not enough cards available for arrangement")
		# Fallback to predefined cards if no cards are available
		left_card_data = remaining_cards[0] if remaining_cards.size() > 0 else preload("res://Cards/Move1.tres")
		right_card_data = remaining_cards[1] if remaining_cards.size() > 1 else preload("res://Cards/Move2.tres")

func setup_card_button(button: Button, card_data: CardData):
	"""Set up a card button with the given card data"""
	# Clear existing children
	for child in button.get_children():
		child.queue_free()
	
	# Create a container for the button content
	var container = Control.new()
	container.size = button.size
	container.position = Vector2.ZERO
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(container)
	
	# Background panel
	var background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.2, 0.9)
	background.size = button.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(background)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.size = Vector2(button.size.x + 4, button.size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)
	border.z_index = -1
	
	# Use CardVisual for consistent upgrade display
	var card_scene = preload("res://CardVisual.tscn")
	var card_instance = card_scene.instantiate()
	card_instance.custom_minimum_size = Vector2(80, 100)
	card_instance.size = Vector2(80, 100)
	card_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_instance.scale = Vector2(1.336, 1.213)
	card_instance.position = Vector2(35, 0)
	card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set the card data to show upgrade indicators
	if card_instance.has_method("set_card_data") and card_data:
		card_instance.set_card_data(card_data)
	
	container.add_child(card_instance)
	
	# Card name
	var name_label = Label.new()
	name_label.text = card_data.get_upgraded_name()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.position = Vector2(5, 95)
	name_label.size = Vector2(140, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)
	
	# Add hover effect
	button.mouse_entered.connect(func(): _on_card_button_hover(button, true))
	button.mouse_exited.connect(func(): _on_card_button_hover(button, false))

func _on_card_button_hover(button: Button, is_hovering: bool):
	"""Handle card button hover effects"""
	var container = button.get_child(0)  # Container is first child
	if container and container.get_child_count() > 0:
		var background = container.get_child(0)  # Background is first child of container
		if is_hovering:
			background.color = Color(0.3, 0.3, 0.3, 0.9)
		else:
			background.color = Color(0.2, 0.2, 0.2, 0.9)

func _on_left_card_selected():
	"""Handle left card selection"""
	handle_card_selection(left_card_data)

func _on_right_card_selected():
	"""Handle right card selection"""
	handle_card_selection(right_card_data)

func handle_card_selection(selected_card: CardData):
	"""Handle card selection and add to hand"""
	print("ArrangeDialog: Player selected card:", selected_card.name)
	
	# Play card selection sound
	play_card_sound()
	
	# Get the course and deck manager
	var course = get_tree().current_scene
	if course:
		var deck_manager = course.get("deck_manager")
		if deck_manager:
			# Add the selected card to the player's hand
			deck_manager.hand.append(selected_card)
			print("ArrangeDialog: Added", selected_card.name, "to hand")
			
			# Put the unselected card on top of the action deck (so it's drawn next)
			var unselected_card = right_card_data if selected_card == left_card_data else left_card_data
			deck_manager.insert_card_at_top_of_action_deck(unselected_card)
			print("ArrangeDialog: Put", unselected_card.name, "on top of action deck")
			
			# Update the deck display
			if course.has_method("update_deck_display"):
				course.update_deck_display()
			
			# Update movement buttons
			if course.has_method("create_movement_buttons"):
				course.create_movement_buttons()
		else:
			print("ArrangeDialog: Warning - deck_manager not found")
	else:
		print("ArrangeDialog: Warning - course not found")
	
	# Emit signal
	card_selected.emit(selected_card)
	
	# Close the dialog
	visible = false
	dialog_closed.emit()

func play_card_sound():
	"""Play card selection sound effect"""
	# Try to find card sound in the scene
	var course = get_tree().current_scene
	if course:
		var card_sound = course.get_node_or_null("CardPlaySound")
		if card_sound:
			card_sound.play()
			print("ArrangeDialog: Playing card sound")
		else:
			# Create a temporary sound player
			var temp_sound = AudioStreamPlayer.new()
			temp_sound.stream = preload("res://Sounds/CardDraw.mp3")
			course.add_child(temp_sound)
			temp_sound.play()
			print("ArrangeDialog: Playing card sound (temporary)")
			# Remove after playing
			await temp_sound.finished
			temp_sound.queue_free()

func _on_background_clicked(event: InputEvent):
	"""Handle background click to close dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		visible = false
		dialog_closed.emit() 
