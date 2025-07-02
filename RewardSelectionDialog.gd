extends Control

signal reward_selected(reward_data: Resource, reward_type: String)

@onready var reward_container: Control = $RewardContainer
@onready var left_reward_button: Button = $RewardContainer/LeftReward
@onready var right_reward_button: Button = $RewardContainer/RightReward

var left_reward_data: Resource
var right_reward_data: Resource
var left_reward_type: String
var right_reward_type: String

# Available cards for rewards
var available_cards: Array[CardData] = [
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move3.tres"),
	preload("res://Cards/Move4.tres"),
	preload("res://Cards/Move5.tres"),
	preload("res://Cards/StickyShot.tres"),
	preload("res://Cards/Bouncey.tres"),
	preload("res://Cards/Dub.tres"),
	preload("res://Cards/FloridaScramble.tres"),
	preload("res://Cards/KickB.tres"),
	preload("res://Cards/PistolCard.tres"),
	preload("res://Cards/Putter.tres"),
	preload("res://Cards/Wooden.tres"),
	preload("res://Cards/Iron.tres"),
	preload("res://Cards/Hybrid.tres"),
	preload("res://Cards/Driver.tres"),
	preload("res://Cards/PitchingWedge.tres"),
	preload("res://Cards/FireClub.tres"),
	preload("res://Cards/IceClub.tres")
]

# Available equipment for rewards
var available_equipment: Array[EquipmentData] = [
	preload("res://Equipment/GolfShoes.tres")
]

func _ready():
	# Hide the dialog initially
	visible = false
	
	# Connect button signals
	left_reward_button.pressed.connect(_on_left_reward_selected)
	right_reward_button.pressed.connect(_on_right_reward_selected)

func show_reward_selection():
	# Generate two random rewards
	var rewards = generate_random_rewards()
	
	# Set up the left reward
	left_reward_data = rewards[0]
	left_reward_type = rewards[1]
	setup_reward_button(left_reward_button, left_reward_data, left_reward_type)
	
	# Set up the right reward
	right_reward_data = rewards[2]
	right_reward_type = rewards[3]
	setup_reward_button(right_reward_button, right_reward_data, right_reward_type)
	
	# Show the dialog
	visible = true

func generate_random_rewards() -> Array:
	var rewards = []
	
	# Randomly decide if we want 2 cards, 2 equipment, or 1 of each
	var reward_type = randi() % 3  # 0 = 2 cards, 1 = 2 equipment, 2 = 1 of each
	
	if reward_type == 0:
		# Two cards
		var card1 = available_cards[randi() % available_cards.size()]
		var card2 = available_cards[randi() % available_cards.size()]
		rewards = [card1, "card", card2, "card"]
	elif reward_type == 1:
		# Two equipment (if we have enough)
		if available_equipment.size() >= 2:
			var equip1 = available_equipment[randi() % available_equipment.size()]
			var equip2 = available_equipment[randi() % available_equipment.size()]
			rewards = [equip1, "equipment", equip2, "equipment"]
		else:
			# Fallback to cards if not enough equipment
			var card1 = available_cards[randi() % available_cards.size()]
			var card2 = available_cards[randi() % available_cards.size()]
			rewards = [card1, "card", card2, "card"]
	else:
		# One card, one equipment
		var card = available_cards[randi() % available_cards.size()]
		var equipment = available_equipment[randi() % available_equipment.size()]
		rewards = [card, "card", equipment, "equipment"]
	
	return rewards

func setup_reward_button(button: Button, reward_data: Resource, reward_type: String):
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
	
	if reward_type == "card":
		var card_data = reward_data as CardData
		button.text = ""  # Clear button text since we're using custom display
		
		# Card image
		var image_rect = TextureRect.new()
		image_rect.texture = card_data.image
		image_rect.size = Vector2(80, 120)  # Card aspect ratio
		image_rect.position = Vector2(10, 10)
		image_rect.scale = Vector2(0.12, 0.12)
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(image_rect)
		
		# Card name
		var name_label = Label.new()
		name_label.text = card_data.name
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_constant_override("outline_size", 1)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.position = Vector2(5, 140)
		name_label.size = Vector2(90, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(name_label)
		
	elif reward_type == "equipment":
		var equip_data = reward_data as EquipmentData
		button.text = ""  # Clear button text since we're using custom display
		
		# Equipment image
		var image_rect = TextureRect.new()
		image_rect.texture = equip_data.image
		image_rect.size = Vector2(60, 60)  # Square aspect ratio for equipment
		image_rect.position = Vector2(20, 7.125)  # Y offset -12.875 from original 20
		image_rect.scale = Vector2(2.0, 2.0)
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(image_rect)
		
		# Equipment name
		var name_label = Label.new()
		name_label.text = equip_data.name
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_constant_override("outline_size", 1)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.position = Vector2(5, 90)
		name_label.size = Vector2(90, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(name_label)
		
		# Equipment description
		var desc_label = Label.new()
		desc_label.text = equip_data.description
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		desc_label.add_theme_constant_override("outline_size", 1)
		desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
		desc_label.position = Vector2(5, 110)
		desc_label.size = Vector2(90, 30)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(desc_label)
	
	# Add hover effect
	button.mouse_entered.connect(_on_reward_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_reward_button_hover.bind(button, false))

func _on_reward_button_hover(button: Button, is_hovering: bool):
	"""Handle reward button hover effects"""
	var container = button.get_child(0)  # Container is first child
	if container and container.get_child_count() > 0:
		var background = container.get_child(0)  # Background is first child of container
		if is_hovering:
			background.color = Color(0.3, 0.3, 0.3, 0.9)
		else:
			background.color = Color(0.2, 0.2, 0.2, 0.9)

func _on_left_reward_selected():
	if left_reward_type == "card":
		# Add card to CurrentDeckManager
		add_card_to_current_deck(left_reward_data)
		print("Added", left_reward_data.name, "to current deck")
	
	reward_selected.emit(left_reward_data, left_reward_type)
	visible = false

func _on_right_reward_selected():
	if right_reward_type == "card":
		# Add card to CurrentDeckManager
		add_card_to_current_deck(right_reward_data)
		print("Added", right_reward_data.name, "to current deck")
	
	reward_selected.emit(right_reward_data, right_reward_type)
	visible = false

func add_card_to_current_deck(card_data: CardData):
	"""Add a card to the CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.add_card_to_deck(card_data)
		print("RewardSelectionDialog: Added", card_data.name, "to CurrentDeckManager")
	else:
		print("RewardSelectionDialog: Warning - CurrentDeckManager not found") 