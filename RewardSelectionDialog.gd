extends Control

signal reward_selected(reward_data: Resource, reward_type: String)
signal advance_to_next_hole

@onready var reward_container: Control = $RewardContainer
@onready var left_reward_button: Button = $RewardContainer/LeftReward
@onready var right_reward_button: Button = $RewardContainer/RightReward

var left_reward_data: Resource
var right_reward_data: Resource
var left_reward_type: String
var right_reward_type: String
var pending_reward: Resource
var pending_reward_type: String
var card_replacement_dialog: Control = null

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
	
	# Add Advance button
	add_advance_button()
	
	# Show the dialog
	visible = true

func add_advance_button():
	"""Add an Advance button to the reward dialog"""
	# Remove existing advance button if it exists
	var existing_advance = reward_container.get_node_or_null("AdvanceButton")
	if existing_advance:
		existing_advance.queue_free()
	
	# Create new advance button
	var advance_button = Button.new()
	advance_button.name = "AdvanceButton"
	advance_button.text = "Advance to Next Hole"
	advance_button.position = Vector2(400, 300)
	advance_button.size = Vector2(200, 50)
	advance_button.pressed.connect(_on_advance_pressed)
	reward_container.add_child(advance_button)

func _on_advance_pressed():
	"""Handle advance button press"""
	advance_to_next_hole.emit()
	visible = false

func check_bag_slots(reward_data: Resource, reward_type: String) -> bool:
	"""Check if there are available slots in the bag for the reward"""
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if not bag:
		print("Warning: Bag not found")
		return true  # Allow if bag not found
	
	if reward_type == "card":
		var card_data = reward_data as CardData
		# Check if it's a club card by name (more reliable than effect_type)
		var club_names = ["Putter", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "FireClub", "IceClub"]
		if club_names.has(card_data.name):
			# Check club card slots
			var club_cards = bag.get_club_cards()
			var club_slots = bag.get_club_slots()
			return club_cards.size() < club_slots
		else:
			# Check movement card slots
			var movement_cards = bag.get_movement_cards()
			var movement_slots = bag.get_movement_slots()
			return movement_cards.size() < movement_slots
	elif reward_type == "equipment":
		# Check equipment slots
		var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			var equipped_items = equipment_manager.get_equipped_equipment()
			var equipment_slots = bag.get_equipment_slots()
			return equipped_items.size() < equipment_slots
	
	return true

func show_card_replacement_dialog(reward_data: Resource, reward_type: String):
	"""Show dialog for replacing a card when bag is full"""
	pending_reward = reward_data
	pending_reward_type = reward_type
	
	# Create replacement dialog
	card_replacement_dialog = Control.new()
	card_replacement_dialog.name = "CardReplacementDialog"
	card_replacement_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_replacement_dialog.z_index = 1000
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	card_replacement_dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(800, 500)
	main_container.position = Vector2(-400, -250)
	card_replacement_dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(panel)
	
	# Title
	var title = Label.new()
	title.text = "Bag Full - Select Card to Replace"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(20, 20)
	title.size = Vector2(760, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# New card preview
	var new_card_label = Label.new()
	new_card_label.text = "New Card:"
	new_card_label.add_theme_font_size_override("font_size", 16)
	new_card_label.add_theme_color_override("font_color", Color.WHITE)
	new_card_label.position = Vector2(20, 80)
	new_card_label.size = Vector2(200, 30)
	main_container.add_child(new_card_label)
	
	var new_card_display = create_card_display(pending_reward, 1)
	new_card_display.position = Vector2(20, 120)
	main_container.add_child(new_card_display)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Click on a card in your bag to replace it with the new card."
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	instructions.position = Vector2(20, 240)
	instructions.size = Vector2(760, 30)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(instructions)
	
	# Cancel button
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(350, 420)
	cancel_button.size = Vector2(100, 40)
	cancel_button.pressed.connect(_on_cancel_replacement)
	main_container.add_child(cancel_button)
	
	# Add dialog to scene
	get_tree().current_scene.add_child(card_replacement_dialog)
	
	# Open bag in replacement mode
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if bag:
		bag.show_inventory_replacement_mode(pending_reward, pending_reward_type)

func _on_cancel_replacement():
	"""Cancel the card replacement process"""
	if card_replacement_dialog:
		card_replacement_dialog.queue_free()
		card_replacement_dialog = null
	
	# Close bag replacement mode
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if bag:
		bag.close_inventory()
	
	pending_reward = null
	pending_reward_type = ""

func create_card_display(card_data: CardData, count: int) -> Control:
	"""Create a display for a single card with count"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Card image
	var image_rect = TextureRect.new()
	image_rect.texture = card_data.image
	image_rect.size = Vector2(80, 100)
	image_rect.position = Vector2(0, 0)
	image_rect.scale = Vector2(0.075, 0.075)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(image_rect)
	
	return container

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
		name_label.position = Vector2(5, 15)
		name_label.size = Vector2(90, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(name_label)
	
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
	handle_reward_selection(left_reward_data, left_reward_type)

func _on_right_reward_selected():
	handle_reward_selection(right_reward_data, right_reward_type)

func handle_reward_selection(reward_data: Resource, reward_type: String):
	"""Handle reward selection with bag slot checking"""
	if check_bag_slots(reward_data, reward_type):
		# Slot available, add directly
		add_reward_to_inventory(reward_data, reward_type)
		reward_selected.emit(reward_data, reward_type)
		visible = false
	else:
		# No slot available, show replacement dialog
		show_card_replacement_dialog(reward_data, reward_type)

func add_reward_to_inventory(reward_data: Resource, reward_type: String):
	"""Add reward to the appropriate inventory"""
	if reward_type == "card":
		add_card_to_current_deck(reward_data)
		print("Added", reward_data.name, "to current deck")
	elif reward_type == "equipment":
		add_equipment_to_manager(reward_data)
		print("Added", reward_data.name, "to equipment")

func add_card_to_current_deck(card_data: CardData):
	"""Add a card to the CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.add_card_to_deck(card_data)
		print("RewardSelectionDialog: Added", card_data.name, "to CurrentDeckManager")
	else:
		print("RewardSelectionDialog: Warning - CurrentDeckManager not found")

func add_equipment_to_manager(equipment_data: EquipmentData):
	"""Add equipment to the EquipmentManager"""
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		equipment_manager.add_equipment(equipment_data)
		print("RewardSelectionDialog: Added", equipment_data.name, "to EquipmentManager")
	else:
		print("RewardSelectionDialog: Warning - EquipmentManager not found")

func _exit_tree():
	"""Clean up when the dialog is removed"""
	if card_replacement_dialog and is_instance_valid(card_replacement_dialog):
		card_replacement_dialog.queue_free()

func _on_replacement_completed(reward_data: Resource, reward_type: String):
	"""Called when a card replacement is completed"""
	# Close the replacement dialog
	if card_replacement_dialog:
		card_replacement_dialog.queue_free()
		card_replacement_dialog = null
	
	# Emit the reward selected signal
	reward_selected.emit(reward_data, reward_type)
	
	# Reset pending reward
	pending_reward = null
	pending_reward_type = ""

	# Clear and disable left and right reward buttons
	if left_reward_button:
		left_reward_button.text = ""
		for child in left_reward_button.get_children():
			child.queue_free()
		left_reward_button.disabled = true
	if right_reward_button:
		right_reward_button.text = ""
		for child in right_reward_button.get_children():
			child.queue_free()
		right_reward_button.disabled = true 
