extends Control

# Shop items
var available_equipment: Array[EquipmentData] = []
var available_cards: Array[CardData] = []
var current_shop_items: Array = []  # Mix of equipment and cards

# Shop display - using manual containers
var shop_item_containers: Array[Control] = []
var manual_containers: Array[Control] = []

func _ready():
	# Ensure ReturnButton is always on top
	$ReturnButton.z_index = 100
	
	# Connect the return button
	$ReturnButton.pressed.connect(_on_return_button_pressed)
	
	# Play the shop music/sound when entering
	play_shop_sound()
	
	# Get manual containers
	get_manual_containers()
	
	# Load available equipment and cards
	load_shop_items()
	
	# Generate random shop items
	generate_shop_items()
	
	# Display shop items
	display_shop_items()

func get_manual_containers():
	"""Get the manually positioned containers from the scene"""
	manual_containers.clear()
	
	# Get ItemContainer1 and ItemContainer2
	var container1 = $ShopItems/ItemContainer1
	var container2 = $ShopItems/ItemContainer2
	
	if container1:
		manual_containers.append(container1)
	if container2:
		manual_containers.append(container2)

func load_shop_items():
	"""Load all available equipment and cards for the shop"""
	# Load equipment from Equipment folder
	available_equipment = [
		preload("res://Equipment/GolfShoes.tres")
	]
	
	# Load cards from Cards folder (excluding club cards for now)
	available_cards = [
		preload("res://Cards/StickyShot.tres"),
		preload("res://Cards/Bouncey.tres"),
		preload("res://Cards/FireClub.tres"),
		preload("res://Cards/IceClub.tres")
	]

func generate_shop_items():
	"""Generate random shop items (1 equipment + 1 card)"""
	current_shop_items.clear()
	
	# Randomly select 1 equipment item
	if available_equipment.size() > 0:
		var random_equipment = available_equipment[randi() % available_equipment.size()]
		current_shop_items.append(random_equipment)
	
	# Randomly select 1 card
	if available_cards.size() > 0:
		var random_card = available_cards[randi() % available_cards.size()]
		current_shop_items.append(random_card)

func display_shop_items():
	"""Display shop items in the manual containers"""
	# Clear existing shop items
	for container in shop_item_containers:
		if container and is_instance_valid(container):
			container.queue_free()
	shop_item_containers.clear()
	
	# Clear manual containers
	for manual_container in manual_containers:
		for child in manual_container.get_children():
			child.queue_free()
	
	# Create shop item displays in manual containers
	for i in range(current_shop_items.size()):
		if i >= manual_containers.size():
			break
		
		var item = current_shop_items[i]
		var manual_container = manual_containers[i]
		var item_display = create_shop_item_display(item, manual_container.size)
		manual_container.add_child(item_display)
		shop_item_containers.append(item_display)

func create_shop_item_display(item, container_size: Vector2) -> Control:
	"""Create a display for a shop item (equipment or card)"""
	var container = Control.new()
	container.size = container_size
	container.position = Vector2.ZERO
	container.mouse_filter = Control.MOUSE_FILTER_STOP  # Only this is clickable
	
	# Background panel
	var background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.2, 0.9)
	background.size = container_size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(background)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
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
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	desc_label.position = Vector2(10, 210)
	desc_label.size = Vector2(180, 30)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(desc_label)
	
	# Make container clickable
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_shop_item_clicked.bind(item))
	
	# Add hover effect
	container.mouse_entered.connect(_on_shop_item_hover.bind(container, true))
	container.mouse_exited.connect(_on_shop_item_hover.bind(container, false))
	
	return container

func _on_shop_item_clicked(event: InputEvent, item):
	"""Handle shop item clicks"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item is EquipmentData:
			# Add equipment to inventory
			Global.add_equipment(item)
			show_purchase_message("Purchased " + item.name + "!")
		else:
			# Add card to deck (we'll need to implement this)
			show_purchase_message("Card added to deck!")
		
		# Remove item from shop
		current_shop_items.erase(item)
		display_shop_items()

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
	var trinkets_sound = $Trinkets
	if trinkets_sound and trinkets_sound.stream:
		trinkets_sound.play()

func _on_return_button_pressed():
	"""Return to the course scene"""
	# Use FadeManager for smooth transition
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5) 
