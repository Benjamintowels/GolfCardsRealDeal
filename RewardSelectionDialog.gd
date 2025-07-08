extends Control

const BagData = preload("res://Bags/BagData.gd")
const CardReplacementDialog = preload("res://UI/card_replacement_dialog.gd")

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
	preload("res://Cards/ThrowingKnife.tres"),
	preload("res://Cards/TeleportCard.tres"),
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

# Available bag upgrades for rewards (will be populated dynamically)
var available_bag_upgrades: Array[BagData] = []

func _ready():
	# Hide the dialog initially
	visible = false
	
	# Connect button signals
	left_reward_button.pressed.connect(_on_left_reward_selected)
	right_reward_button.pressed.connect(_on_right_reward_selected)
	
	# Initialize bag upgrades
	initialize_bag_upgrades()
	
	# Load reward sound
	var reward_sound = AudioStreamPlayer.new()
	reward_sound.name = "RewardSound"
	reward_sound.stream = preload("res://Sounds/Reward.mp3")
	add_child(reward_sound)

func initialize_bag_upgrades():
	"""Initialize available bag upgrades based on current character and bag level"""
	available_bag_upgrades.clear()
	
	# Get current character and bag level
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if not bag:
		return
	
	var current_character = bag.character_name
	var current_bag_level = bag.bag_level
	
	# Create bag upgrades for higher levels only
	for level in range(current_bag_level + 1, 5):  # Levels 2-4
		var bag_upgrade = BagData.new()
		bag_upgrade.name = "Bag Upgrade"
		bag_upgrade.level = level
		bag_upgrade.character = current_character
		bag_upgrade.description = "Upgrade your bag to level %d" % level
		
		# Set the appropriate image based on character and level
		if bag.character_bag_textures.has(current_character) and bag.character_bag_textures[current_character].has(level):
			bag_upgrade.image = bag.character_bag_textures[current_character][level]
		else:
			pass
		
		available_bag_upgrades.append(bag_upgrade)

func show_reward_selection():
	# Initialize bag upgrades before generating rewards
	initialize_bag_upgrades()
	
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
	# Use the shared static function from CardReplacementDialog
	return CardReplacementDialog.check_bag_slots(reward_data, reward_type)

func show_card_replacement_dialog(reward_data: Resource, reward_type: String):
	"""Show dialog for replacing a card when bag is full"""
	pending_reward = reward_data
	pending_reward_type = reward_type
	
	# Create shared replacement dialog
	var dialog_scene = preload("res://UI/CardReplacementDialog.tscn")
	card_replacement_dialog = dialog_scene.instantiate()
	
	# Connect signals
	card_replacement_dialog.replacement_completed.connect(_on_shared_replacement_completed)
	card_replacement_dialog.replacement_cancelled.connect(_on_shared_replacement_cancelled)
	
	# Add dialog to scene
	get_tree().current_scene.add_child(card_replacement_dialog)
	
	# Show the dialog
	card_replacement_dialog.show_replacement_dialog(pending_reward, pending_reward_type)

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

func _on_shared_replacement_completed(reward_data: Resource, reward_type: String):
	"""Handle shared replacement dialog completion"""
	
	# Emit the reward selected signal
	reward_selected.emit(reward_data, reward_type)
	
	# Reset pending reward
	pending_reward = null
	pending_reward_type = ""
	
	# Clean up dialog
	if card_replacement_dialog and is_instance_valid(card_replacement_dialog):
		card_replacement_dialog.queue_free()
		card_replacement_dialog = null
	
	# Clear and disable left and right reward buttons
	clear_reward_buttons()
	
	# Hide the dialog
	visible = false

func _on_shared_replacement_cancelled():
	"""Handle shared replacement dialog cancellation"""
	
	# Reset pending reward
	pending_reward = null
	pending_reward_type = ""
	
	# Clean up dialog
	if card_replacement_dialog and is_instance_valid(card_replacement_dialog):
		card_replacement_dialog.queue_free()
		card_replacement_dialog = null

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
	
	# Check if bag upgrades are available
	var has_bag_upgrades = available_bag_upgrades.size() > 0
	
	# Randomly decide reward types (now including bag upgrades)
	var reward_options = []
	reward_options.append("cards")  # 2 cards
	reward_options.append("equipment")  # 2 equipment
	reward_options.append("mixed")  # 1 card, 1 equipment
	
	if has_bag_upgrades:
		reward_options.append("bag_upgrade")  # 1 bag upgrade
		reward_options.append("mixed_bag")  # 1 bag upgrade, 1 other
	
	var reward_type = reward_options[randi() % reward_options.size()]
	
	match reward_type:
		"cards":
			# Two cards
			var card1 = available_cards[randi() % available_cards.size()]
			var card2 = available_cards[randi() % available_cards.size()]
			rewards = [card1, "card", card2, "card"]
		"equipment":
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
		"mixed":
			# One card, one equipment
			var card = available_cards[randi() % available_cards.size()]
			var equipment = available_equipment[randi() % available_equipment.size()]
			rewards = [card, "card", equipment, "equipment"]
		"bag_upgrade":
			# One bag upgrade, one card
			var bag_upgrade = available_bag_upgrades[randi() % available_bag_upgrades.size()]
			var card = available_cards[randi() % available_cards.size()]
			rewards = [bag_upgrade, "bag_upgrade", card, "card"]
		"mixed_bag":
			# One bag upgrade, one equipment
			var bag_upgrade = available_bag_upgrades[randi() % available_bag_upgrades.size()]
			var equipment = available_equipment[randi() % available_equipment.size()]
			rewards = [bag_upgrade, "bag_upgrade", equipment, "equipment"]
	
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
		
	elif reward_type == "bag_upgrade":
		var bag_data = reward_data as BagData
		button.text = ""  # Clear button text since we're using custom display
		
		# Bag image
		var image_rect = TextureRect.new()
		image_rect.texture = bag_data.image
		image_rect.size = Vector2(80, 80)  # Square aspect ratio for bag
		image_rect.position = Vector2(10, 10)
		image_rect.scale = Vector2(1.0, 1.0)  # Full scale for bags
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(image_rect)
		
		# Bag upgrade name
		var name_label = Label.new()
		name_label.text = "Bag Upgrade"
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_constant_override("outline_size", 1)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.position = Vector2(5, 95)
		name_label.size = Vector2(90, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(name_label)
		
		# Level indicator
		var level_label = Label.new()
		level_label.text = "Level " + str(bag_data.level)
		level_label.add_theme_font_size_override("font_size", 10)
		level_label.add_theme_color_override("font_color", Color.YELLOW)
		level_label.add_theme_constant_override("outline_size", 1)
		level_label.add_theme_color_override("font_outline_color", Color.BLACK)
		level_label.position = Vector2(5, 110)
		level_label.size = Vector2(90, 15)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(level_label)
	
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
	# Play reward sound
	var reward_sound = get_node_or_null("RewardSound")
	if reward_sound:
		reward_sound.play()
	
	# Clear both reward buttons
	clear_reward_buttons()
	
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
	elif reward_type == "equipment":
		add_equipment_to_manager(reward_data)
	elif reward_type == "bag_upgrade":
		apply_bag_upgrade(reward_data)

func add_card_to_current_deck(card_data: CardData):
	"""Add a card to the CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.add_card_to_deck(card_data)

func add_equipment_to_manager(equipment_data: EquipmentData):
	"""Add equipment to the EquipmentManager"""
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		equipment_manager.add_equipment(equipment_data)

func apply_bag_upgrade(bag_data: BagData):
	"""Apply a bag upgrade to the current bag"""
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if bag:
		bag.set_bag_level(bag_data.level)

func _exit_tree():
	"""Clean up when the dialog is removed"""
	if card_replacement_dialog and is_instance_valid(card_replacement_dialog):
		card_replacement_dialog.queue_free()

func clear_reward_buttons():
	"""Clear both left and right reward buttons"""
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
	clear_reward_buttons() 
