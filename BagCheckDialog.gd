extends Control

signal club_selected(club_data: CardData)
signal dialog_closed

@onready var card_container: Control = $CardContainer
@onready var left_card_button: Button = $CardContainer/LeftCard
@onready var right_card_button: Button = $CardContainer/RightCard
@onready var title_label: Label = $CardContainer/Title

var left_card_data: CardData
var right_card_data: CardData

# All available club cards for random selection
var available_club_cards: Array[CardData] = [
	preload("res://Cards/Putter.tres"),
	preload("res://Cards/Wood.tres"),
	preload("res://Cards/Wooden.tres"),
	preload("res://Cards/Iron.tres"),
	preload("res://Cards/Hybrid.tres"),
	preload("res://Cards/Driver.tres"),
	preload("res://Cards/PitchingWedge.tres"),
	preload("res://Cards/FireClub.tres"),
	preload("res://Cards/IceClub.tres"),
	preload("res://Cards/GrenadeLauncherClubCard.tres")
]

func _ready():
	# Hide the dialog initially
	visible = false
	
	# Connect button signals
	left_card_button.pressed.connect(_on_left_card_selected)
	right_card_button.pressed.connect(_on_right_card_selected)
	
	# Connect background click to close
	$Background.gui_input.connect(_on_background_clicked)

func show_bag_check_dialog():
	"""Show the BagCheck dialog with 2 random club cards"""
	visible = true
	
	# Set high z_index to ensure dialog appears on top
	z_index = 3000
	
	# Generate 2 random club cards
	var remaining_cards = available_club_cards.duplicate()
	
	if remaining_cards.size() >= 2:
		# Select first random card
		var first_index = randi() % remaining_cards.size()
		left_card_data = remaining_cards[first_index]
		remaining_cards.remove_at(first_index)
		
		# Select second random card
		var second_index = randi() % remaining_cards.size()
		right_card_data = remaining_cards[second_index]
		
		print("BagCheckDialog: Generated club cards:", left_card_data.name, "and", right_card_data.name)
	else:
		print("BagCheckDialog: Error - not enough club cards available")
		# Fallback to predefined cards if no cards are available
		left_card_data = remaining_cards[0] if remaining_cards.size() > 0 else preload("res://Cards/Putter.tres")
		right_card_data = remaining_cards[1] if remaining_cards.size() > 1 else preload("res://Cards/Wood.tres")
	
	# Set up the card buttons
	setup_card_button(left_card_button, left_card_data)
	setup_card_button(right_card_button, right_card_data)
	
	# Update title
	title_label.text = "Select a Club to Use for This Shot"

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

func _on_left_card_selected():
	"""Handle left card selection"""
	handle_club_selection(left_card_data)

func _on_right_card_selected():
	"""Handle right card selection"""
	handle_club_selection(right_card_data)

func _on_background_clicked(event: InputEvent):
	"""Handle background click to close dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()

func handle_club_selection(selected_club: CardData):
	"""Handle club selection"""
	print("BagCheckDialog: Player selected club:", selected_club.name)
	
	# Play bag sound
	play_bag_sound()
	
	# Emit signal
	club_selected.emit(selected_club)
	
	# Close the dialog
	close_dialog()

func close_dialog():
	"""Close the dialog"""
	visible = false
	dialog_closed.emit()

func play_bag_sound():
	"""Play bag sound effect"""
	# Try to find bag sound in the scene
	var course = get_tree().current_scene
	if course:
		var bag = course.get_node_or_null("UILayer/Bag")
		if bag:
			var bag_sound = bag.get_node_or_null("BagSound")
			if bag_sound:
				bag_sound.play()
				print("BagCheckDialog: Playing bag sound")
			else:
				# Create a temporary sound player
				var temp_sound = AudioStreamPlayer.new()
				temp_sound.stream = preload("res://Sounds/BagSound.mp3")
				course.add_child(temp_sound)
				temp_sound.play()
				print("BagCheckDialog: Playing bag sound (temporary)")
				# Remove after playing
				await temp_sound.finished
				temp_sound.queue_free() 