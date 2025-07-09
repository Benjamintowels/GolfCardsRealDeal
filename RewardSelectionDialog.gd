extends Control

const BagData = preload("res://Bags/BagData.gd")

signal reward_selected(reward_data: Resource, reward_type: String)
signal advance_to_next_hole

@onready var reward_container: Control = $RewardContainer
@onready var left_reward_button: Button = $RewardContainer/LeftReward
@onready var right_reward_button: Button = $RewardContainer/RightReward

var left_reward_data: Resource
var right_reward_data: Resource
var left_reward_type: String
var right_reward_type: String

# Base cards for rewards (level 1)
var base_cards: Array[CardData] = [
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
	preload("res://Cards/Putter.tres"),
	preload("res://Cards/Wooden.tres"),
	preload("res://Cards/Iron.tres"),
	preload("res://Cards/Hybrid.tres"),
	preload("res://Cards/Driver.tres"),
	preload("res://Cards/PitchingWedge.tres"),
	preload("res://Cards/FireClub.tres"),
	preload("res://Cards/IceClub.tres")
]

# Available cards for rewards (includes all levels)
var available_cards: Array[CardData] = []

# Available equipment for rewards
var available_equipment: Array[EquipmentData] = [
	preload("res://Equipment/GolfShoes.tres"),
	preload("res://Equipment/Wand.tres"),
	preload("res://Equipment/Clothes/Cape.tres"),
	preload("res://Equipment/Clothes/TopHat.tres"),
	preload("res://Equipment/Clothes/Crown.tres"),
	preload("res://Equipment/Clothes/Halo.tres")
]

# Available bag upgrades for rewards (will be populated dynamically)
var available_bag_upgrades: Array[BagData] = []

func _ready():
	# Hide the dialog initially
	visible = false
	
	# Connect button signals
	left_reward_button.pressed.connect(_on_left_reward_selected)
	right_reward_button.pressed.connect(_on_right_reward_selected)
	
	# Initialize available cards with all levels
	initialize_available_cards()
	
	# Initialize bag upgrades
	initialize_bag_upgrades()
	
	# Load reward sound
	var reward_sound = AudioStreamPlayer.new()
	reward_sound.name = "RewardSound"
	reward_sound.stream = preload("res://Sounds/Reward.mp3")
	add_child(reward_sound)

func initialize_available_cards():
	"""Initialize available cards with base cards and theoretical upgraded versions"""
	available_cards.clear()
	
	# Add base cards (level 1)
	for base_card in base_cards:
		available_cards.append(base_card)
	
	# Generate theoretical upgraded versions for each base card
	for base_card in base_cards:
		# Create level 2 version if the card can be upgraded
		if base_card.max_level >= 2:
			var level_2_card = create_upgraded_card(base_card, 2)
			available_cards.append(level_2_card)
		
		# Create level 3 version if the card can be upgraded to level 3
		if base_card.max_level >= 3:
			var level_3_card = create_upgraded_card(base_card, 3)
			available_cards.append(level_3_card)
	
	print("=== AVAILABLE CARDS INITIALIZED ===")
	print("Base cards: ", base_cards.size())
	print("Total available cards (including upgrades): ", available_cards.size())
	
	# Show some examples
	var tier_1_count = 0
	var tier_2_count = 0
	var tier_3_count = 0
	for card in available_cards:
		var tier = card.get_reward_tier()
		match tier:
			1: tier_1_count += 1
			2: tier_2_count += 1
			3: tier_3_count += 1
	
	print("Tier 1 cards: ", tier_1_count)
	print("Tier 2 cards: ", tier_2_count)
	print("Tier 3 cards: ", tier_3_count)

func create_upgraded_card(base_card: CardData, level: int) -> CardData:
	"""Create an upgraded version of a base card"""
	var upgraded_card = CardData.new()
	
	# Copy base properties
	upgraded_card.name = base_card.name
	upgraded_card.effect_type = base_card.effect_type
	upgraded_card.effect_strength = base_card.effect_strength
	upgraded_card.image = base_card.image
	upgraded_card.max_level = base_card.max_level
	upgraded_card.upgrade_cost = base_card.upgrade_cost
	upgraded_card.default_tier = base_card.default_tier
	
	# Copy upgrade bonuses
	upgraded_card.movement_bonus = base_card.movement_bonus
	upgraded_card.attack_bonus = base_card.attack_bonus
	upgraded_card.weapon_shots_bonus = base_card.weapon_shots_bonus
	upgraded_card.effect_bonus = base_card.effect_bonus
	
	# Set the level
	upgraded_card.level = level
	
	return upgraded_card

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

func get_tiered_cards() -> Array[CardData]:
	"""Get cards filtered by current tier probabilities"""
	var probabilities = Global.get_tier_probabilities()
	var tier_1_cards: Array[CardData] = []
	var tier_2_cards: Array[CardData] = []
	var tier_3_cards: Array[CardData] = []
	
	# Categorize cards by their reward tier
	for card in available_cards:
		var tier = card.get_reward_tier()
		match tier:
			1:
				tier_1_cards.append(card)
			2:
				tier_2_cards.append(card)
			3:
				tier_3_cards.append(card)
	
	# Debug output
	print("=== TIERED CARD DEBUG ===")
	print("Current reward tier: ", Global.get_current_reward_tier())
	print("Probabilities: ", probabilities)
	print("Total available cards: ", available_cards.size())
	print("Tier 1 cards: ", tier_1_cards.size())
	print("Tier 2 cards: ", tier_2_cards.size())
	print("Tier 3 cards: ", tier_3_cards.size())
	
	# Show some example cards from each tier
	if tier_1_cards.size() > 0:
		print("Tier 1 examples: ", tier_1_cards[0].name, " (level: ", tier_1_cards[0].level, ")")
	if tier_2_cards.size() > 0:
		print("Tier 2 examples: ", tier_2_cards[0].name, " (level: ", tier_2_cards[0].level, ")")
	if tier_3_cards.size() > 0:
		print("Tier 3 examples: ", tier_3_cards[0].name, " (level: ", tier_3_cards[0].level, ")")
	
	# Use weighted random selection based on probabilities
	var selected_cards: Array[CardData] = []
	
	# Create a weighted pool of all cards
	var all_cards: Array[CardData] = []
	var weights: Array[float] = []
	
	# Add tier 1 cards with tier 1 weight
	for card in tier_1_cards:
		all_cards.append(card)
		weights.append(probabilities["tier_1"])
	
	# Add tier 2 cards with tier 2 weight
	for card in tier_2_cards:
		all_cards.append(card)
		weights.append(probabilities["tier_2"])
	
	# Add tier 3 cards with tier 3 weight
	for card in tier_3_cards:
		all_cards.append(card)
		weights.append(probabilities["tier_3"])
	
	# Select cards using weighted random selection
	var num_to_select = min(available_cards.size(), all_cards.size())
	for i in range(num_to_select):
		if all_cards.size() == 0:
			break
		
		# Calculate total weight
		var total_weight = 0.0
		for weight in weights:
			total_weight += weight
		
		# Select random card based on weights
		var random_value = randf() * total_weight
		var current_weight = 0.0
		var selected_index = 0
		
		for j in range(weights.size()):
			current_weight += weights[j]
			if random_value <= current_weight:
				selected_index = j
				break
		
		# Add selected card
		selected_cards.append(all_cards[selected_index])
		
		# Remove selected card from pool
		all_cards.remove_at(selected_index)
		weights.remove_at(selected_index)
	
	# Debug output for selected cards
	print("Selected cards: ", selected_cards.size())
	for i in range(min(5, selected_cards.size())):
		var card = selected_cards[i]
		print("  Selected: ", card.name, " (Tier: ", card.get_reward_tier(), ", Level: ", card.level, ")")
	
	return selected_cards

func get_tiered_equipment() -> Array[EquipmentData]:
	"""Get equipment filtered by current tier probabilities"""
	var probabilities = Global.get_tier_probabilities()
	var tier_1_equipment: Array[EquipmentData] = []
	var tier_2_equipment: Array[EquipmentData] = []
	var tier_3_equipment: Array[EquipmentData] = []
	
	# Categorize equipment by their reward tier
	for equipment in available_equipment:
		var tier = equipment.get_reward_tier()
		match tier:
			1:
				tier_1_equipment.append(equipment)
			2:
				tier_2_equipment.append(equipment)
			3:
				tier_3_equipment.append(equipment)
	
	# Select equipment based on probabilities
	var selected_equipment: Array[EquipmentData] = []
	
	# Add Tier 1 equipment
	var tier_1_count = int(probabilities["tier_1"] * available_equipment.size())
	for i in range(min(tier_1_count, tier_1_equipment.size())):
		selected_equipment.append(tier_1_equipment[randi() % tier_1_equipment.size()])
	
	# Add Tier 2 equipment
	var tier_2_count = int(probabilities["tier_2"] * available_equipment.size())
	for i in range(min(tier_2_count, tier_2_equipment.size())):
		selected_equipment.append(tier_2_equipment[randi() % tier_2_equipment.size()])
	
	# Add Tier 3 equipment
	var tier_3_count = int(probabilities["tier_3"] * available_equipment.size())
	for i in range(min(tier_3_count, tier_3_equipment.size())):
		selected_equipment.append(tier_3_equipment[randi() % tier_3_equipment.size()])
	
	# If we don't have enough equipment from higher tiers, fill with lower tiers
	while selected_equipment.size() < available_equipment.size():
		if tier_1_equipment.size() > 0:
			selected_equipment.append(tier_1_equipment[randi() % tier_1_equipment.size()])
		elif tier_2_equipment.size() > 0:
			selected_equipment.append(tier_2_equipment[randi() % tier_2_equipment.size()])
		elif tier_3_equipment.size() > 0:
			selected_equipment.append(tier_3_equipment[randi() % tier_3_equipment.size()])
		else:
			break
	
	return selected_equipment

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
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if not bag:
		return true  # Allow if bag not found
	
	if reward_type == "card":
		var card_data = reward_data as CardData
		# Check if it's a club card by name
		var club_names = ["Putter", "Wood", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club"]
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
			var equipment_data = reward_data as EquipmentData
			
			# For clothing, check if the specific slot is available
			if equipment_data.is_clothing:
				var clothing_slots = equipment_manager.get_clothing_slots()
				var slot_name = equipment_data.clothing_slot
				return not clothing_slots.has(slot_name) or clothing_slots[slot_name] == null
			else:
				# For regular equipment, check equipment slots
				# Only count non-clothing equipment for slot checking
				var equipped_items = equipment_manager.get_equipped_equipment()
				var regular_equipment_count = 0
				for equipped_item in equipped_items:
					if not equipped_item.is_clothing:
						regular_equipment_count += 1
				var equipment_slots = bag.get_equipment_slots()
				return regular_equipment_count < equipment_slots
	
	return true

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
	
	# Get tiered rewards
	var tiered_cards = get_tiered_cards()
	var tiered_equipment = get_tiered_equipment()
	
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
			# Two cards from tiered selection
			var card1 = tiered_cards[randi() % tiered_cards.size()]
			var card2 = tiered_cards[randi() % tiered_cards.size()]
			rewards = [card1, "card", card2, "card"]
		"equipment":
			# Two equipment from tiered selection (if we have enough)
			if tiered_equipment.size() >= 2:
				var equip1 = tiered_equipment[randi() % tiered_equipment.size()]
				var equip2 = tiered_equipment[randi() % tiered_equipment.size()]
				rewards = [equip1, "equipment", equip2, "equipment"]
			else:
				# Fallback to cards if not enough equipment
				var card1 = tiered_cards[randi() % tiered_cards.size()]
				var card2 = tiered_cards[randi() % tiered_cards.size()]
				rewards = [card1, "card", card2, "card"]
		"mixed":
			# One card, one equipment from tiered selection
			var card = tiered_cards[randi() % tiered_cards.size()]
			var equipment = tiered_equipment[randi() % tiered_equipment.size()]
			rewards = [card, "card", equipment, "equipment"]
		"bag_upgrade":
			# One bag upgrade, one card from tiered selection
			var bag_upgrade = available_bag_upgrades[randi() % available_bag_upgrades.size()]
			var card = tiered_cards[randi() % tiered_cards.size()]
			rewards = [bag_upgrade, "bag_upgrade", card, "card"]
		"mixed_bag":
			# One bag upgrade, one equipment from tiered selection
			var bag_upgrade = available_bag_upgrades[randi() % available_bag_upgrades.size()]
			var equipment = tiered_equipment[randi() % tiered_equipment.size()]
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
		
		# Use CardVisual for consistent upgrade display (same as bag)
		var card_scene = preload("res://CardVisual.tscn")
		var card_instance = card_scene.instantiate()
		card_instance.custom_minimum_size = Vector2(80, 100)
		card_instance.size = Vector2(80, 100)  # Set explicit size
		card_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Scale to fit the 80x100 container (original is 80x120) - same as bag
		card_instance.scale = Vector2(1.0, 100.0/120.0)  # Scale height to fit
		card_instance.position = Vector2(35, 0)  # Center in button
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
		
	elif reward_type == "equipment":
		var equip_data = reward_data as EquipmentData
		button.text = ""  # Clear button text since we're using custom display
		
		# Equipment image - use display_image for clothing if available, otherwise use regular image
		var image_rect = TextureRect.new()
		if equip_data.is_clothing and equip_data.display_image != null:
			image_rect.texture = equip_data.display_image
		else:
			image_rect.texture = equip_data.image
		image_rect.size = Vector2(60, 60)  # Square aspect ratio for equipment
		image_rect.position = Vector2(20, 7.125)  # Y offset -12.875 from original 20
		
		# Adjust scale based on equipment type - clothing items need different scaling
		if equip_data.is_clothing:
			image_rect.scale = Vector2(3.0, 3.0)  # Larger scale for clothing items
		else:
			image_rect.scale = Vector2(2.0, 2.0)  # Standard scale for regular equipment
		
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
	
	# Check if there are available slots in the bag
	var slots_available = check_bag_slots(reward_data, reward_type)
	
	if slots_available:
		# Clear both reward buttons
		clear_reward_buttons()
		
		# Add reward directly since slots are available
		add_reward_to_inventory(reward_data, reward_type)
		reward_selected.emit(reward_data, reward_type)
		visible = false
	else:
		# Bag is full - trigger replacement system
		print("RewardSelectionDialog: Bag is full, triggering replacement system")
		trigger_replacement_system(reward_data, reward_type)

func trigger_replacement_system(reward_data: Resource, reward_type: String):
	"""Trigger the replacement system when bag is full"""
	# Clear reward buttons
	clear_reward_buttons()
	
	# Create and show replacement dialog
	var replacement_dialog = preload("res://UI/CardReplacementDialog.tscn").instantiate()
	
	# Add to UI layer
	var ui_layer = get_tree().current_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(replacement_dialog)
	else:
		get_tree().current_scene.add_child(replacement_dialog)
	
	# Connect signals
	replacement_dialog.replacement_completed.connect(_on_replacement_completed)
	replacement_dialog.replacement_cancelled.connect(_on_replacement_cancelled)
	
	# Show the replacement dialog
	replacement_dialog.show_replacement_dialog(reward_data, reward_type)
	
	# Hide the reward selection dialog
	visible = false

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
	pass

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
	# Emit the reward selected signal
	reward_selected.emit(reward_data, reward_type)

	# Clear and disable left and right reward buttons
	clear_reward_buttons() 

func _on_replacement_cancelled():
	"""Called when replacement is cancelled"""
	print("RewardSelectionDialog: Replacement cancelled")
	# Show the reward selection dialog again
	visible = true
	# Re-enable reward buttons
	if left_reward_button:
		left_reward_button.disabled = false
	if right_reward_button:
		right_reward_button.disabled = false 
