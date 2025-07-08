extends Control

# Shop items
var available_equipment: Array[EquipmentData] = []
var available_cards: Array[CardData] = []
var current_shop_items: Array = []  # Mix of equipment and cards

# Shop display - using manual containers
var shop_item_containers: Array[Control] = []
var manual_containers: Array[Control] = []

# Shop input control
var shop_input_enabled: bool = true  # Track if shop input should be enabled

signal shop_closed

func _ready():
	# Set the shop to process input even when the game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Ensure ReturnButton is always on top
	$ReturnButton.z_index = 1000
	
	# Connect the return button with debugging
	var return_button = $ReturnButton
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)
		
		# Add a test to make sure the button is visible and clickable
		return_button.mouse_filter = Control.MOUSE_FILTER_STOP
		
	else:
		print("ShopInterior: ERROR - Return button not found!")
	
	# Connect input events to the main container for debugging
	gui_input.connect(_on_shop_input)
	
	# Add debug input handler to see if main shop container is blocking clicks
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			print("ShopInterior: Main shop container received mouse input at", event.position, "event type:", event.get_class())
			print("ShopInterior: Main shop container z_index:", z_index, "mouse_filter:", mouse_filter)
	)
	
	# Play the shop music/sound when entering
	play_shop_sound()
	
	# Get manual containers
	get_manual_containers()
	print("ShopInterior: Found", manual_containers.size(), "manual containers")
	
	# Load available equipment and cards
	load_shop_items()
	print("ShopInterior: Loaded", available_equipment.size(), "equipment and", available_cards.size(), "cards")
	
	# Generate random shop items
	generate_shop_items()
	print("ShopInterior: Generated", current_shop_items.size(), "shop items")
	
	# Display shop items
	display_shop_items()
	print("ShopInterior: Shop setup complete")

func get_manual_containers():
	"""Get the manually positioned containers from the scene"""
	manual_containers.clear()
	
	# Get ItemContainer1, ItemContainer2, ItemContainer3, and ItemContainer4
	var container1 = $ShopItems/ItemContainer1
	var container2 = $ShopItems/ItemContainer2
	var container3 = $ShopItems/ItemContainer3
	var container4 = $ShopItems/ItemContainer4
	
	if container1:
		manual_containers.append(container1)
	if container2:
		manual_containers.append(container2)
	if container3:
		manual_containers.append(container3)
	if container4:
		manual_containers.append(container4)

func load_shop_items():
	"""Load all available equipment and cards for the shop"""
	# Load equipment from Equipment folder
	available_equipment = [
		preload("res://Equipment/GolfShoes.tres"),
		preload("res://Equipment/Wand.tres"),
		preload("res://Equipment/Clothes/Cape.tres"),
		preload("res://Equipment/Clothes/TopHat.tres"),
		preload("res://Equipment/Clothes/Crown.tres"),
		preload("res://Equipment/Clothes/Halo.tres")
	]
	
	# Load cards from Cards folder - expanded pool
	available_cards = [
		# Action cards
		preload("res://Cards/StickyShot.tres"),
		preload("res://Cards/Bouncey.tres"),
		preload("res://Cards/TeleportCard.tres"),
		preload("res://Cards/KickB.tres"),
		preload("res://Cards/ThrowingKnife.tres"),
		preload("res://Cards/PistolCard.tres"),
		preload("res://Cards/BurstShot.tres"),
		preload("res://Cards/ShotgunCard.tres"),
		preload("res://Cards/SniperCard.tres"),
		preload("res://Cards/GrenadeCard.tres"),
		preload("res://Cards/FireBallCard.tres"),
		preload("res://Cards/IceBallCard.tres"),
		preload("res://Cards/ExtraBall.tres"),
		preload("res://Cards/FloridaScramble.tres"),
		preload("res://Cards/Dub.tres"),
		preload("res://Cards/Draw2.tres"),
		preload("res://Cards/CoffeeCard.tres"),
		
		# Movement cards
		preload("res://Cards/Move1.tres"),
		preload("res://Cards/Move2.tres"),
		preload("res://Cards/Move3.tres"),
		preload("res://Cards/Move4.tres"),
		preload("res://Cards/Move5.tres"),
		
		# Club cards
		preload("res://Cards/FireClub.tres"),
		preload("res://Cards/IceClub.tres"),
		preload("res://Cards/Putter.tres"),
		preload("res://Cards/Iron.tres"),
		preload("res://Cards/Wood.tres"),
		preload("res://Cards/Hybrid.tres"),
		preload("res://Cards/Driver.tres"),
		preload("res://Cards/PitchingWedge.tres"),
		preload("res://Cards/Wooden.tres")
	]

func generate_shop_items():
	"""Generate random shop items with more variety"""
	current_shop_items.clear()
	
	# Randomly decide what type of items to show - now supporting up to 4 items
	var shop_configs = [
		{"equipment": 1, "cards": 1},      # 1 equipment + 1 card
		{"equipment": 0, "cards": 2},      # 2 cards
		{"equipment": 1, "cards": 0},      # 1 equipment only
		{"equipment": 0, "cards": 1},      # 1 card only
		{"equipment": 0, "cards": 3},      # 3 cards
		{"equipment": 1, "cards": 2},      # 1 equipment + 2 cards
		{"equipment": 0, "cards": 4},      # 4 cards
		{"equipment": 1, "cards": 3},      # 1 equipment + 3 cards
		{"equipment": 2, "cards": 1},      # 2 equipment + 1 card
		{"equipment": 2, "cards": 2}       # 2 equipment + 2 cards
	]
	
	var selected_config = shop_configs[randi() % shop_configs.size()]
	print("ShopInterior: Selected config:", selected_config)
	
	# Add equipment items
	for i in range(selected_config.equipment):
		if available_equipment.size() > 0:
			var random_equipment = available_equipment[randi() % available_equipment.size()]
			current_shop_items.append(random_equipment)
			print("ShopInterior: Added equipment:", random_equipment.name)
	
	# Add card items
	for i in range(selected_config.cards):
		if available_cards.size() > 0:
			var random_card = available_cards[randi() % available_cards.size()]
			current_shop_items.append(random_card)
			print("ShopInterior: Added card:", random_card.name)
	
	print("ShopInterior: Generated shop config:", selected_config, "with", current_shop_items.size(), "items")
	print("ShopInterior: Final items list:", current_shop_items.map(func(item): return item.name))

func display_shop_items():
	"""Display shop items in the manual containers"""
	print("ShopInterior: Starting display_shop_items()")
	print("ShopInterior: current_shop_items size:", current_shop_items.size())
	print("ShopInterior: manual_containers size:", manual_containers.size())
	
	# Clear existing shop items
	for container in shop_item_containers:
		if container and is_instance_valid(container):
			container.queue_free()
	shop_item_containers.clear()
	
	# Clear manual containers
	for manual_container in manual_containers:
		for child in manual_container.get_children():
			child.queue_free()
	
	print("ShopInterior: Cleared existing items, creating new ones...")
	
	# Create shop item displays in manual containers
	for i in range(current_shop_items.size()):
		if i >= manual_containers.size():
			print("ShopInterior: WARNING - More items than containers! Item", i, "cannot be displayed")
			break
		
		var item = current_shop_items[i]
		var manual_container = manual_containers[i]
		
		print("ShopInterior: Creating item", i, ":", item.name, "in container", manual_container.name)
		
		# Get the actual size of the container (accounting for scale)
		var container_size = manual_container.size * manual_container.scale
		var item_display = create_shop_item_display(item, container_size)
		
		# Position the item display to fill the container
		item_display.size = container_size
		item_display.position = Vector2.ZERO
		
		manual_container.add_child(item_display)
		shop_item_containers.append(item_display)
		
		print("ShopInterior: Added", item.name, "to", manual_container.name, "with size", container_size)
	
	print("ShopInterior: Display complete, total shop items:", shop_item_containers.size())

func create_shop_item_display(item, container_size: Vector2) -> Control:
	"""Create a display for a shop item (equipment or card)"""
	var container = Control.new()
	container.size = container_size
	container.position = Vector2.ZERO
	container.mouse_filter = Control.MOUSE_FILTER_STOP  # Make this clickable
	
	# Background panel - make it more visible for debugging
	var background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.2, 0.9)
	background.size = container_size
	background.position = Vector2.ZERO
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(background)
	
	# Border - make it more visible
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)  # Normal border
	border.size = Vector2(container_size.x + 4, container_size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)
	border.z_index = -1
	
	# Item image - adjust size based on item type
	var image_rect = TextureRect.new()
	image_rect.texture = item.image
	if item is EquipmentData:
		image_rect.size = Vector2(150, 150)
		image_rect.position = Vector2(25, 20)
	else:
		image_rect.size = Vector2(1024, 1536)
		image_rect.position = Vector2(32.985, 39.87)
		image_rect.scale = Vector2(0.14, 0.14)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(image_rect)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.position = Vector2(10, 180)
	name_label.size = Vector2(180, 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)
	
	# Item description or effect
	var desc_label = Label.new()
	if item is EquipmentData:
		desc_label.text = item.description
	else:
		desc_label.text = "Add to deck"
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.add_theme_constant_override("outline_size", 1)
	desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	desc_label.position = Vector2(10, 210)
	desc_label.size = Vector2(180, 30)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(desc_label)
	
	# Connect the click event to the container itself
	container.gui_input.connect(_on_shop_item_clicked.bind(item))
	
	# Add hover effect
	container.mouse_entered.connect(_on_shop_item_hover.bind(container, true))
	container.mouse_exited.connect(_on_shop_item_hover.bind(container, false))
	
	# Store reference to container for potential input disabling
	container.set_meta("shop_item_container", true)
	
	print("ShopInterior: Created shop item display for", item.name, "with size", container_size)
	
	return container

func _on_shop_item_clicked(event: InputEvent, item):
	print("ShopInterior: Shop item clicked - event type:", event.get_class())
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("ShopInterior: Left mouse button pressed on item:", item.name)
		
		# Determine item type
		var item_type = "card" if item is CardData else "equipment"
		
		# Check if there are available slots
		print("ShopInterior: Checking bag slots for", item.name, "type:", item_type)
		var slots_available = check_bag_slots(item, item_type)
		print("ShopInterior: Slots available:", slots_available)
		
		if slots_available:
			# Add item directly since slots are available
			print("ShopInterior: Adding item directly to inventory")
			add_item_to_inventory(item, item_type)
			show_purchase_message("Purchased " + item.name + "!")
			play_cat_happy()
			# Remove item from shop only after successful purchase
			current_shop_items.erase(item)
			display_shop_items()
		else:
			# Bag is full - trigger replacement system
			print("ShopInterior: Bag is full, triggering replacement system")
			trigger_replacement_system(item, item_type)

func add_item_to_inventory(item: Resource, item_type: String):
	"""Add item to the appropriate inventory - matching RewardSelectionDialog logic"""
	if item_type == "card":
		var card_data = item as CardData
		var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
		if current_deck_manager:
			current_deck_manager.add_card_to_deck(card_data)
	elif item_type == "equipment":
		var equipment_data = item as EquipmentData
		var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.add_equipment(equipment_data)

func _on_shop_item_hover(container: Control, is_hovering: bool):
	"""Handle shop item hover effects"""
	var background = container.get_child(0)  # Background is first child
	if is_hovering:
		background.color = Color(0.3, 0.3, 0.3, 0.9)
	else:
		background.color = Color(0.2, 0.2, 0.2, 0.9)

func show_purchase_message(message: String):
	"""Show a purchase confirmation message"""
	var message_label = Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color.GREEN)
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.position = Vector2(400, 200)
	message_label.z_index = 1000
	add_child(message_label)
	
	# Remove message after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if message_label and is_instance_valid(message_label):
			message_label.queue_free()
	)

func play_shop_sound():
	"""Play the shop trinkets sound"""
	var trinkets_sound = get_node_or_null("Trinkets")
	if trinkets_sound:
		if trinkets_sound.stream:
			trinkets_sound.play()
		else:
			print("Trinkets sound stream is null")
	else:
		print("Trinkets AudioStreamPlayer2D not found")

func _on_return_button_pressed():
	print("ShopInterior: Return button pressed!")
	
	# Clean up any replacement dialogs
	cleanup_replacement_dialogs()
	
	emit_signal("shop_closed")
	print("ShopInterior: shop_closed signal emitted")

func cleanup_replacement_dialogs():
	"""Clean up when closing the shop"""
	# Re-enable shop input
	shop_input_enabled = true
	enable_shop_item_containers()
	
	# Restore ReturnButton z-index
	var return_button = $ReturnButton
	if return_button:
		return_button.z_index = 1000  # Restore original z-index

func disable_shop_item_containers():
	"""Disable input for all shop item containers"""
	for container in shop_item_containers:
		if container and is_instance_valid(container):
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func enable_shop_item_containers():
	"""Enable input for all shop item containers"""
	for container in shop_item_containers:
		if container and is_instance_valid(container):
			container.mouse_filter = Control.MOUSE_FILTER_STOP

func play_cat_happy():
	var cat_happy = get_node_or_null("CatHappy")
	if cat_happy and cat_happy.stream:
		cat_happy.play()

func _on_shop_input(event: InputEvent):
	"""Debug input handler for the main shop container"""
	# Only process input if shop input is enabled
	if not shop_input_enabled:
		return
		
	if event is InputEventMouseButton and event.pressed:
		print("ShopInterior: Main shop container received mouse input at", event.position)

func is_club_card(card_data: CardData) -> bool:
	"""Check if a card is a club card - matching RewardSelectionDialog logic"""
	# Check if the card has club-related properties
	if card_data.has_method("is_club_card"):
		return card_data.is_club_card()
	# Use the same club names list as RewardSelectionDialog
	var club_names = ["Putter", "Wood", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club"]
	return club_names.has(card_data.name)



func create_card_display(card_data: CardData, count: int) -> Control:
	"""Create a display for a single card with count"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	
	# Card image
	var image_rect = TextureRect.new()
	image_rect.texture = card_data.image
	image_rect.size = Vector2(80, 100)
	image_rect.position = Vector2(0, 0)
	image_rect.scale = Vector2(0.075, 0.075)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	container.add_child(image_rect)
	
	return container

func create_equipment_display(equipment_data: EquipmentData) -> Control:
	"""Create a display for a single piece of equipment"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(180, 60)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	
	# Equipment background
	var equip_bg = ColorRect.new()
	equip_bg.color = Color(0.3, 0.3, 0.3, 0.9)
	equip_bg.size = Vector2(180, 60)
	equip_bg.position = Vector2(0, 0)
	equip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	container.add_child(equip_bg)
	
	# Equipment image - use display_image for clothing if available, otherwise use regular image
	var image_rect = TextureRect.new()
	if equipment_data.is_clothing and equipment_data.display_image != null:
		image_rect.texture = equipment_data.display_image
	else:
		image_rect.texture = equipment_data.image
	# Adjust size and position based on equipment type - clothing items need different sizing
	if equipment_data.is_clothing:
		image_rect.size = Vector2(50, 50)  # Larger size for clothing items
		image_rect.position = Vector2(5, 5)  # Adjusted position for larger size
	else:
		image_rect.size = Vector2(40, 40)  # Standard size for regular equipment
		image_rect.position = Vector2(10, 10)  # Standard position
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	container.add_child(image_rect)
	
	# Equipment name
	var name_label = Label.new()
	name_label.text = equipment_data.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.position = Vector2(60, 10)
	name_label.size = Vector2(110, 20)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	container.add_child(name_label)
	
	return container

func _exit_tree():
	"""Clean up when the shop is removed from the scene"""
	cleanup_replacement_dialogs()



func check_bag_slots(item: Resource, item_type: String) -> bool:
	"""Check if there are available slots in the bag for the item"""
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if not bag:
		return true  # Allow if bag not found
	
	if item_type == "card":
		var card_data = item as CardData
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
	elif item_type == "equipment":
		# Check equipment slots
		var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			var equipment_data = item as EquipmentData
			
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

 

func trigger_replacement_system(item: Resource, item_type: String):
	"""Trigger the replacement system when bag is full"""
	print("ShopInterior: trigger_replacement_system called for", item.name, "type:", item_type)
	
	# Disable shop input to prevent multiple clicks
	shop_input_enabled = false
	disable_shop_item_containers()
	print("ShopInterior: Shop input disabled")
	
	# Instead of using the CardReplacementDialog, use the Bag's replacement system
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if bag and bag.has_method("show_inventory_replacement_mode"):
		print("ShopInterior: Using Bag's replacement system")
		bag.show_inventory_replacement_mode(item, item_type)
	else:
		print("ShopInterior: ERROR - Bag not found or missing show_inventory_replacement_mode method")
		# Fallback to re-enabling shop input
		shop_input_enabled = true
		enable_shop_item_containers()

func _on_replacement_completed(reward_data: Resource, reward_type: String):
	"""Called when replacement is completed"""
	print("ShopInterior: Replacement completed for", reward_data.name if reward_data else "null")
	
	# Show purchase message
	show_purchase_message("Purchased " + (reward_data.name if reward_data else "item") + "!")
	play_cat_happy()
	
	# Remove item from shop
	if reward_data in current_shop_items:
		current_shop_items.erase(reward_data)
		display_shop_items()
	
	# Re-enable shop input
	shop_input_enabled = true
	enable_shop_item_containers()

func _on_replacement_cancelled():
	"""Called when replacement is cancelled"""
	print("ShopInterior: Replacement cancelled")
	
	# Re-enable shop input
	shop_input_enabled = true
	enable_shop_item_containers()

func on_replacement_completed(reward_data: Resource, reward_type: String):
	"""Called when replacement is completed from shop context"""
	print("ShopInterior: on_replacement_completed called with", reward_data.name if reward_data else "null", "type:", reward_type)
	
	# Show purchase message
	show_purchase_message("Purchased " + (reward_data.name if reward_data else "item") + "!")
	play_cat_happy()
	
	# Remove item from shop
	if reward_data in current_shop_items:
		current_shop_items.erase(reward_data)
		display_shop_items()
	
	# Re-enable shop input
	shop_input_enabled = true
	enable_shop_item_containers()

 
