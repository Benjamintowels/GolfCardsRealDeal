extends Control
class_name Bag

signal bag_clicked
signal replacement_completed(reward_data: Resource, reward_type: String)

@onready var texture_rect: TextureRect = $TextureRect
@onready var bag_sound: AudioStreamPlayer2D = $BagSound

var bag_level: int = 1
var character_name: String = "Benny"  # Default character
var inventory_dialog: Control = null
var is_inventory_open: bool = false
var is_replacement_mode: bool = false
var pending_reward: Resource = null
var pending_reward_type: String = ""
var replacement_confirmation_dialog: Control = null

# Character-specific bag textures (make it accessible)
var character_bag_textures = {
	"Layla": {
		1: preload("res://Bags/LaylaBag1.png"),
		2: preload("res://Bags/LaylaBag2.png"),
		3: preload("res://Bags/LaylaBag3.png"),
		4: preload("res://Bags/LaylaBag4.png")
	},
	"Benny": {
		1: preload("res://Bags/BennyBag1.png"),
		2: preload("res://Bags/BennyBag2.png"),
		3: preload("res://Bags/BennyBag3.png"),
		4: preload("res://Bags/BennyBag4.png")
	},
	"Clark": {
		1: preload("res://Bags/ClarkBag1.png"),
		2: preload("res://Bags/ClarkBag2.png"),
		3: preload("res://Bags/ClarkBag3.png"),
		4: preload("res://Bags/ClarkBag4.png")
	}
}

func _ready():
	process_mode = Node.PROCESS_MODE_INHERIT  # Change to inherit to ensure it processes input
	# Set up the bag texture based on character and level
	set_bag_level(bag_level)
	
	# Make the bag clickable
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_bag_input_event)
	
	# Check TextureRect settings
	if texture_rect:
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Also connect input to the TextureRect to see if events are reaching it
	if texture_rect:
		texture_rect.gui_input.connect(_on_texture_rect_input_event)
	

	


func _connect_to_managers():
	"""Connect to equipment and deck managers when needed"""
	# Connect to equipment manager signals to refresh display when equipment changes
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager and not equipment_manager.equipment_updated.is_connected(_on_equipment_updated):
		equipment_manager.equipment_updated.connect(_on_equipment_updated)
	
	# Connect to current deck manager signals to refresh display when deck changes
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager and not current_deck_manager.deck_updated.is_connected(_on_deck_updated):
		current_deck_manager.deck_updated.connect(_on_deck_updated)

func _input(event):
	"""Handle input for closing inventory with escape key"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_inventory_open:
			close_inventory()
	


func set_character(character: String):
	character_name = character
	set_bag_level(bag_level)  # Update texture with new character

func set_bag_level(level: int):
	bag_level = level
	if character_bag_textures.has(character_name) and character_bag_textures[character_name].has(level):
		texture_rect.texture = character_bag_textures[character_name][level]
		# Play sound when bag is upgraded
		if bag_sound and bag_sound.stream:
			bag_sound.play()

func _on_bag_input_event(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_inventory()
		bag_clicked.emit()

func _on_texture_rect_input_event(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Forward the event to the bag's input handler
		_on_bag_input_event(event)

func toggle_inventory():
	"""Toggle the inventory dialog on/off"""
	if is_inventory_open:
		close_inventory()
	else:
		show_inventory()

func close_inventory():
	"""Close the inventory dialog"""
	if inventory_dialog and is_instance_valid(inventory_dialog):
		# If in shop, restore DeckDialog mouse_filter
		var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
		if shop_interior:
			var shop_deck_dialog = shop_interior.get_node_or_null("DeckDialog")
			if shop_deck_dialog:
				shop_deck_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventory_dialog.queue_free()
		inventory_dialog = null
	is_inventory_open = false
	is_replacement_mode = false
	pending_reward = null
	pending_reward_type = ""
	# Ensure bag is clickable and reset any child-related issues
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Clear any replacement confirmation dialog that might be affecting the bag
	if replacement_confirmation_dialog and is_instance_valid(replacement_confirmation_dialog):
		replacement_confirmation_dialog.queue_free()
		replacement_confirmation_dialog = null
	
	# Play sound when closing inventory
	if bag_sound and bag_sound.stream:
		bag_sound.play()
	


func show_inventory():
	"""Show the inventory dialog"""
	if is_inventory_open:
		return
	
	# Connect to managers when first used
	_connect_to_managers()
	
	show_deck_dialog()
	is_inventory_open = true
	
	# Play sound when opening inventory
	if bag_sound and bag_sound.stream:
		bag_sound.play()

func show_inventory_replacement_mode(reward_data: Resource, reward_type: String):
	if is_inventory_open:
		return
	
	pending_reward = reward_data
	pending_reward_type = reward_type
	is_replacement_mode = true
	
	show_deck_dialog()
	is_inventory_open = true
	
	# Play sound when opening inventory in replacement mode
	if bag_sound and bag_sound.stream:
		bag_sound.play()

func show_deck_dialog():
	"""Show a dialog displaying all cards and equipment"""
	print("Bag: show_deck_dialog called - is_replacement_mode:", is_replacement_mode, "pending_reward:", pending_reward.name if pending_reward else "null")
	
	# Create the dialog
	var dialog = Control.new()
	dialog.name = "DeckDialog"
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.z_index = 999
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	background.z_index = 999
	background.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close_inventory()
	)
	dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(1000, 600)
	main_container.position = Vector2(-500, -300)
	main_container.z_index = 999
	dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = -1
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	if is_replacement_mode:
		title.text = "Select Card to Replace"
	else:
		title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(20, 20)
	title.size = Vector2(960, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(450, 540)
	close_button.size = Vector2(100, 40)
	close_button.pressed.connect(close_inventory)
	main_container.add_child(close_button)
	
	# Equipment section (left side - single column)
	var equipment_label = Label.new()
	equipment_label.text = "Equipment"
	equipment_label.add_theme_font_size_override("font_size", 18)
	equipment_label.add_theme_color_override("font_color", Color.WHITE)
	equipment_label.position = Vector2(40, 80)
	equipment_label.size = Vector2(120, 30)
	main_container.add_child(equipment_label)
	
	var equipment_container = VBoxContainer.new()
	equipment_container.position = Vector2(40, 120)
	equipment_container.size = Vector2(120, 200)
	main_container.add_child(equipment_container)
	
	# Get and display regular equipment
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	var equipped_items: Array[EquipmentData] = []
	if equipment_manager:
		equipped_items = equipment_manager.get_equipped_equipment()
	
	# Filter out clothing items for regular equipment display
	var regular_equipment: Array[EquipmentData] = []
	for item in equipped_items:
		if not item.is_clothing:
			regular_equipment.append(item)
	
	# Add equipment slots with placeholder for empty slots
	var equipment_slots = get_equipment_slots()
	for i in range(equipment_slots):
		var slot_container = create_slot_container()
		equipment_container.add_child(slot_container)
		
		# Add placeholder as background
		var placeholder = create_placeholder_slot()
		slot_container.add_child(placeholder)
		
		# Add actual equipment on top if available
		if i < regular_equipment.size():
			var should_be_clickable = is_replacement_mode and pending_reward_type == "equipment" and pending_reward
			var equipment_display = create_equipment_display(regular_equipment[i], should_be_clickable)
			slot_container.add_child(equipment_display)
			# Ensure equipment appears on top by setting z_index
			equipment_display.z_index = 1
		elif is_replacement_mode and pending_reward_type == "equipment" and pending_reward:
			# Empty slot but we're in equipment replacement mode - make placeholder clickable
			var should_be_clickable = true
			var equipment_display = create_empty_equipment_slot_display(should_be_clickable)
			slot_container.add_child(equipment_display)
			equipment_display.z_index = 1
	
	# Clothing section (left side - below equipment)
	var clothing_label = Label.new()
	clothing_label.text = "Clothing"
	clothing_label.add_theme_font_size_override("font_size", 18)
	clothing_label.add_theme_color_override("font_color", Color.WHITE)
	clothing_label.position = Vector2(40, 340)
	clothing_label.size = Vector2(120, 30)
	main_container.add_child(clothing_label)
	
	var clothing_container = VBoxContainer.new()
	clothing_container.position = Vector2(40, 380)
	clothing_container.size = Vector2(120, 140)
	main_container.add_child(clothing_container)
	
	# Display clothing slots
	if equipment_manager:
		var clothing_slots = equipment_manager.get_clothing_slots()
		print("Bag: Clothing slots - Head:", clothing_slots["head"].name if clothing_slots["head"] else "empty", "Neck:", clothing_slots["neck"].name if clothing_slots["neck"] else "empty")
		
		# Head slot
		var head_container = create_slot_container()
		clothing_container.add_child(head_container)
		var head_placeholder = create_placeholder_slot()
		head_container.add_child(head_placeholder)
		
		if clothing_slots["head"]:
			var should_be_clickable = is_replacement_mode and pending_reward_type == "equipment" and pending_reward
			print("Bag: Creating head clothing display for:", clothing_slots["head"].name)
			var head_display = create_equipment_display(clothing_slots["head"], should_be_clickable)
			head_container.add_child(head_display)
			head_display.z_index = 1
		elif is_replacement_mode and pending_reward_type == "equipment" and pending_reward:
			var should_be_clickable = true
			var head_display = create_empty_equipment_slot_display(should_be_clickable)
			head_container.add_child(head_display)
			head_display.z_index = 1
		
		# Neck slot
		var neck_container = create_slot_container()
		clothing_container.add_child(neck_container)
		var neck_placeholder = create_placeholder_slot()
		neck_container.add_child(neck_placeholder)
		
		if clothing_slots["neck"]:
			var should_be_clickable = is_replacement_mode and pending_reward_type == "equipment" and pending_reward
			print("Bag: Creating neck clothing display for:", clothing_slots["neck"].name)
			var neck_display = create_equipment_display(clothing_slots["neck"], should_be_clickable)
			neck_container.add_child(neck_display)
			neck_display.z_index = 1
		elif is_replacement_mode and pending_reward_type == "equipment" and pending_reward:
			var should_be_clickable = true
			var neck_display = create_empty_equipment_slot_display(should_be_clickable)
			neck_container.add_child(neck_display)
			neck_display.z_index = 1
	
	# --- DYNAMIC MOVEMENT GRID LAYOUT ---
	# Determine columns based on bag level
	var movement_columns = 4
	match bag_level:
		1:
			movement_columns = 4
		2:
			movement_columns = 5
		3:
			movement_columns = 6
		4:
			movement_columns = 7
	var movement_slots = get_movement_slots()
	var movement_rows = int(ceil(float(movement_slots) / movement_columns))
	var slot_width = 80 + 12  # slot + h_separation
	var grid_width = movement_columns * slot_width - 12  # last column no separation
	var grid_height = movement_rows * (100 + 12) - 12
	var grid_x = 200  # left margin
	var grid_y = 70
	# Movement cards section (middle - dynamic grid)
	var movement_label = Label.new()
	movement_label.text = "Movement Cards"
	movement_label.add_theme_font_size_override("font_size", 18)
	movement_label.add_theme_color_override("font_color", Color.WHITE)
	movement_label.position = Vector2(grid_x, 50)
	movement_label.size = Vector2(grid_width, 30)
	main_container.add_child(movement_label)
	var movement_grid = GridContainer.new()
	movement_grid.columns = movement_columns
	movement_grid.position = Vector2(grid_x, grid_y)
	movement_grid.size = Vector2(grid_width, grid_height)
	movement_grid.add_theme_constant_override("h_separation", 12)
	movement_grid.add_theme_constant_override("v_separation", 12)
	main_container.add_child(movement_grid)
	# Get movement cards and display them
	var movement_cards = get_movement_cards()
	# Add movement card slots with placeholder for empty slots
	for i in range(movement_slots):
		var slot_container = create_slot_container()
		movement_grid.add_child(slot_container)
		# Add placeholder as background
		var placeholder = create_placeholder_slot()
		slot_container.add_child(placeholder)
		# Add actual card on top if available
		if i < movement_cards.size():
			print("Bag: Creating movement card display for:", movement_cards[i].name)
			var should_be_clickable = is_replacement_mode and pending_reward_type == "card" and pending_reward and not is_club_card(pending_reward)
			var card_display = create_card_display(movement_cards[i], 1, should_be_clickable)
			slot_container.add_child(card_display)
			card_display.z_index = 10
			# Move card display to front to ensure it's clickable
			slot_container.move_child(card_display, slot_container.get_child_count() - 1)
			print("Bag: Movement card display created and added to slot")
		else:
			print("Bag: No movement card for slot", i, "(cards available:", movement_cards.size(), ")")
	# --- END DYNAMIC MOVEMENT GRID LAYOUT ---
	# Club cards section (right side - single column, dynamic position)
	var club_label = Label.new()
	club_label.text = "Club Cards"
	club_label.add_theme_font_size_override("font_size", 18)
	club_label.add_theme_color_override("font_color", Color.WHITE)
	# Place club section 40px right of movement grid, but not past dialog edge
	var club_x = min(grid_x + grid_width + 40, 1000 - 160)  # 120px wide + margin
	var club_label_y = 80
	var club_container_y = 120
	if bag_level == 4:
		club_label_y = 10
		club_container_y = 50
	club_label.position = Vector2(club_x, club_label_y)
	club_label.size = Vector2(120, 30)
	main_container.add_child(club_label)
	var club_container = VBoxContainer.new()
	club_container.position = Vector2(club_x, club_container_y)
	club_container.size = Vector2(120, 400)
	main_container.add_child(club_container)
	
	# Get club cards and display them
	var club_cards = get_club_cards()
	var club_slots = get_club_slots()
	
	# Add club card slots with placeholder for empty slots
	for i in range(club_slots):
		var slot_container = create_slot_container()
		club_container.add_child(slot_container)
		
		# Add placeholder as background
		var placeholder = create_placeholder_slot()
		slot_container.add_child(placeholder)
		
		# Add actual card on top if available
		if i < club_cards.size():
			print("Bag: Creating club card display for:", club_cards[i].name)
			var should_be_clickable = is_replacement_mode and pending_reward_type == "card" and pending_reward and is_club_card(pending_reward)
			var card_display = create_card_display(club_cards[i], 1, should_be_clickable)
			slot_container.add_child(card_display)
			# Ensure card appears on top by setting z_index
			card_display.z_index = 100
			# Move card display to front to ensure it's clickable
			slot_container.move_child(card_display, slot_container.get_child_count() - 1)
			print("Bag: Club card display created and added to slot")
		else:
			print("Bag: No club card for slot", i, "(cards available:", club_cards.size(), ")")
	# Add dialog to UI layer (parent of the bag)
	var ui_layer = get_parent()
	var shop_deck_dialog = null
	var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
	if shop_interior:
		shop_deck_dialog = shop_interior.get_node_or_null("DeckDialog")
	if shop_deck_dialog:
		shop_deck_dialog.add_child(dialog)
		shop_deck_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
		inventory_dialog = dialog
		print("Bag: Dialog added to Shop DeckDialog node")
	else:
		if ui_layer:
			ui_layer.add_child(dialog)
			inventory_dialog = dialog
			print("Bag: Dialog added to UI layer:", ui_layer.name)
		else:
			get_tree().current_scene.add_child(dialog)
			inventory_dialog = dialog
			print("Bag: Dialog added to current scene:", get_tree().current_scene.name)
	
	# Test if buttons are receiving input after dialog is added
	if is_replacement_mode:
		print("Bag: Testing button input handling after dialog creation")
		# Find all TextureButtons in the dialog and test their input
		var buttons = dialog.find_children("*", "TextureButton", true, false)
		for button in buttons:
			print("Bag: Found TextureButton:", button.name, "in tree:", button.is_inside_tree())
			print("Bag: Button mouse_filter:", button.mouse_filter, "z_index:", button.z_index)
			print("Bag: Button parent mouse_filter:", button.get_parent().mouse_filter if button.get_parent() else "N/A")

func create_card_display(card_data: CardData, count: int, clickable: bool = false) -> Control:
	if clickable:
		# Use TextureButton for clickable cards - this is specifically designed for clickable images
		var button = TextureButton.new()
		button.name = "CardButton"
		button.custom_minimum_size = Vector2(80, 100)
		button.size = Vector2(80, 100)  # Set explicit size
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.mouse_filter = Control.MOUSE_FILTER_STOP  # Make this clickable
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # Show pointer cursor
		button.z_index = 100  # Higher z_index to ensure it's clickable
		button.focus_mode = Control.FOCUS_NONE  # Disable focus to prevent focus issues
		button.process_mode = Node.PROCESS_MODE_INHERIT  # Use inherit instead of when paused
		button.scale = Vector2(0.075, 0.075) # Ensure correct scale in all contexts
		button.pressed.connect(func():
			print("Bag: Button pressed signal triggered for", card_data.name)
			_on_card_button_pressed(card_data)
		)
		# Set the texture directly on the TextureButton
		button.texture_normal = card_data.image
		button.texture_hover = card_data.image  # Same texture for hover
		button.texture_pressed = card_data.image  # Same texture for pressed
		button.texture_focused = card_data.image  # Same texture for focused
		
		# Add upgrade indicators if card is upgraded
		if card_data and card_data.is_upgraded():
			# Add orange border
			var border_rect = ColorRect.new()
			border_rect.color = Color(1.0, 0.5, 0.0, 0.8)  # Orange border
			border_rect.size = Vector2(button.size.x + 4, button.size.y + 4)
			border_rect.position = Vector2(-2, -2)
			border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			border_rect.z_index = -1
			button.add_child(border_rect)
			
			# Add green level label
			var level_label = Label.new()
			level_label.text = "Lvl " + str(card_data.level)
			level_label.add_theme_font_size_override("font_size", 10)
			level_label.add_theme_color_override("font_color", Color.GREEN)
			level_label.add_theme_constant_override("outline_size", 2)
			level_label.add_theme_color_override("font_outline_color", Color.BLACK)
			level_label.position = Vector2(button.size.x - 25, 2)
			level_label.size = Vector2(25, 15)
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			level_label.z_index = 10
			button.add_child(level_label)
		# Don't scale the button - this makes the clickable area too small
		# The texture will be automatically scaled to fit the button size
		# Add hover effect as a separate overlay
		var hover_overlay = ColorRect.new()
		hover_overlay.color = Color(1, 1, 0, 0.3)  # Yellow highlight
		hover_overlay.size = Vector2(80, 100)
		hover_overlay.visible = false
		hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(hover_overlay)
		button.mouse_entered.connect(func(): 
			hover_overlay.visible = true
		)
		button.mouse_exited.connect(func(): 
			hover_overlay.visible = false
		)
		# Add debug output to see if the button is being clicked
		button.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_button_pressed(card_data)
		)
		
		# Debug: Check if button is properly set up for input
		print("Bag: Button input setup for", card_data.name, "- mouse_filter:", button.mouse_filter, "process_mode:", button.process_mode)
		
		# Also connect the pressed signal as a fallback
		button.pressed.connect(func():
			_on_card_button_pressed(card_data)
		)
		print("Bag: Button created successfully for", card_data.name)
		print("Bag: Button size:", button.size, "position:", button.position)
		print("Bag: Button mouse_filter:", button.mouse_filter, "z_index:", button.z_index)
		print("Bag: Button visible:", button.visible, "modulate:", button.modulate)
		print("Bag: Button process_mode:", button.process_mode)
		# Ensure the button is properly set up for input
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.process_mode = Node.PROCESS_MODE_INHERIT
		
		# Add a simple test to verify the button is working
		button.mouse_entered.connect(func():
			print("Bag: TEST - Mouse entered button for", card_data.name)
		)
		button.mouse_exited.connect(func():
			print("Bag: TEST - Mouse exited button for", card_data.name)
		)
		return button
	else:
		print("Bag: Creating regular Control for", card_data.name)
		# Use CardVisual for consistent upgrade display
		var card_scene = preload("res://CardVisual.tscn")
		var card_instance = card_scene.instantiate()
		card_instance.custom_minimum_size = Vector2(80, 100)
		card_instance.size = Vector2(80, 100)  # Set explicit size
		card_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Scale to specified dimensions
		card_instance.scale = Vector2(1.236, 1.113)
		
		# Set the card data to show upgrade indicators
		if card_instance.has_method("set_card_data") and card_data:
			card_instance.set_card_data(card_data)
			print("Bag: CardVisual data set for", card_data.name)
		else:
			print("Bag: Failed to set card data for", card_data.name)
		
		print("Bag: CardVisual created - size:", card_instance.size, "scale:", card_instance.scale, "visible:", card_instance.visible)
		return card_instance

func _on_card_button_pressed(card_data: CardData):
	print("Bag: Card button pressed for", card_data.name if card_data else "null")
	print("Bag: is_replacement_mode:", is_replacement_mode, "pending_reward:", pending_reward.name if pending_reward else "null")
	print("Bag: pending_reward_type:", pending_reward_type)
	if is_replacement_mode and pending_reward:
		print("Bag: Showing replacement confirmation for", card_data.name)
		show_replacement_confirmation(card_data)
	else:
		print("Bag: Not in replacement mode or no pending reward")
		print("Bag: is_replacement_mode =", is_replacement_mode)
		print("Bag: pending_reward =", pending_reward)

func show_replacement_confirmation(card_to_replace: CardData):
	# Close any existing confirmation dialog first
	if replacement_confirmation_dialog and is_instance_valid(replacement_confirmation_dialog):
		replacement_confirmation_dialog.queue_free()
	
	# Play sound when showing replacement confirmation dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()
	
	replacement_confirmation_dialog = Control.new()
	replacement_confirmation_dialog.name = "ReplacementConfirmationDialog"
	replacement_confirmation_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replacement_confirmation_dialog.z_index = 2000  # Set to 2000 for topmost
	replacement_confirmation_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	replacement_confirmation_dialog.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.9)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.z_index = 2000
	replacement_confirmation_dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(600, 300)
	main_container.position = Vector2(-300, -150)
	main_container.z_index = 2000
	replacement_confirmation_dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.z_index = 2000
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = 2000
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	title.text = "Replace Card"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(20, 20)
	title.size = Vector2(560, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.z_index = 2000
	main_container.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = "Are you sure you want to replace '" + (card_to_replace.name if card_to_replace else "null") + "' with '" + (pending_reward.name if pending_reward else "null") + "'?"
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.position = Vector2(20, 80)
	message.size = Vector2(560, 60)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.z_index = 2000
	main_container.add_child(message)
	
	# Card comparison
	var card_comparison = HBoxContainer.new()
	card_comparison.position = Vector2(150, 160)
	card_comparison.size = Vector2(300, 80)
	card_comparison.z_index = 2000
	main_container.add_child(card_comparison)
	
	# Old card
	var old_card_label = Label.new()
	old_card_label.text = "Old: " + (card_to_replace.name if card_to_replace else "null")
	old_card_label.add_theme_font_size_override("font_size", 12)
	old_card_label.add_theme_color_override("font_color", Color.RED)
	old_card_label.z_index = 2000
	card_comparison.add_child(old_card_label)
	
	# Arrow
	var arrow_label = Label.new()
	arrow_label.text = " → "
	arrow_label.add_theme_font_size_override("font_size", 16)
	arrow_label.add_theme_color_override("font_color", Color.WHITE)
	arrow_label.z_index = 2000
	card_comparison.add_child(arrow_label)
	
	# New card
	var new_card_label = Label.new()
	new_card_label.text = "New: " + (pending_reward.name if pending_reward else "null")
	new_card_label.add_theme_font_size_override("font_size", 12)
	new_card_label.add_theme_color_override("font_color", Color.GREEN)
	new_card_label.z_index = 2000
	card_comparison.add_child(new_card_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(200, 220)
	button_container.size = Vector2(200, 40)
	button_container.z_index = 2000
	main_container.add_child(button_container)
	
	# Yes button
	var yes_button = Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_confirm_replacement.bind(card_to_replace))
	yes_button.z_index = 2000
	yes_button.process_mode = Node.PROCESS_MODE_INHERIT
	# Add fallback input handling
	yes_button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_confirm_replacement(card_to_replace)
	)
	button_container.add_child(yes_button)
	
	# No button
	var no_button = Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(_on_cancel_replacement_confirmation)
	no_button.z_index = 2000
	no_button.process_mode = Node.PROCESS_MODE_INHERIT
	# Add fallback input handling
	no_button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel_replacement_confirmation()
	)
	button_container.add_child(no_button)
	
	# Add dialog to UI layer as last child to ensure it's on top
	var shop_replacement = null
	var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
	if shop_interior:
		shop_replacement = shop_interior.get_node_or_null("ReplacementConfirmation")
	if shop_replacement:
		shop_replacement.add_child(replacement_confirmation_dialog)
		shop_replacement.mouse_filter = Control.MOUSE_FILTER_STOP
		replacement_confirmation_dialog.visible = true
		# Lower the z_index of the Bag inventory dialog if it exists
		if inventory_dialog and is_instance_valid(inventory_dialog):
			inventory_dialog.z_index = 1000
		print("Bag: Replacement confirmation added to Shop ReplacementConfirmation node")
	else:
		var ui_layer = get_tree().current_scene.get_node_or_null("UILayer")
		if ui_layer:
			ui_layer.add_child(replacement_confirmation_dialog)
			ui_layer.move_child(replacement_confirmation_dialog, ui_layer.get_child_count() - 1)
			replacement_confirmation_dialog.visible = true
			# Lower the z_index of the Bag inventory dialog if it exists
			if inventory_dialog and is_instance_valid(inventory_dialog):
				inventory_dialog.z_index = 1000
			print("Bag: Replacement confirmation added to UI layer")
		else:
			get_tree().current_scene.add_child(replacement_confirmation_dialog)
			replacement_confirmation_dialog.visible = true
			print("Bag: Replacement confirmation added to current scene")

func _on_confirm_replacement(card_to_replace: CardData):
	"""Confirm the card replacement"""
	print("Bag: _on_confirm_replacement called with card_to_replace:", card_to_replace.name if card_to_replace else "null")
	print("Bag: pending_reward:", pending_reward.name if pending_reward else "null")
	
	if not pending_reward or not card_to_replace:
		print("Bag: Missing data for replacement, closing confirmation")
		close_replacement_confirmation()
		return
	
	# Store the reward data before closing inventory (which clears these variables)
	var reward_data = pending_reward
	var reward_type = pending_reward_type
	
	# Remove the old card
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.remove_card_from_deck(card_to_replace)
		print("Bag: Removed card:", card_to_replace.name)
	
	# Add the new card
	if reward_type == "card":
		var card_data = reward_data as CardData
		current_deck_manager.add_card_to_deck(card_data)
		print("Bag: Added card:", card_data.name)
	elif reward_type == "equipment":
		var equipment_data = reward_data as EquipmentData
		var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.add_equipment(equipment_data)
		print("Bag: Added equipment:", equipment_data.name)
	
	# Sync the DeckManager with the updated CurrentDeckManager
	var deck_manager = get_tree().current_scene.get_node_or_null("DeckManager")
	if deck_manager and deck_manager.has_method("sync_with_current_deck"):
		deck_manager.sync_with_current_deck()
		print("Bag: Synced DeckManager")
	else:
		# Try to find DeckManager as a child of the current scene
		var scene = get_tree().current_scene
		for child in scene.get_children():
			if child.get_script() and "DeckManager" in child.get_script().resource_path:
				if child.has_method("sync_with_current_deck"):
					child.sync_with_current_deck()
					print("Bag: Synced DeckManager (found as child)")
					break
	
	# Emit replacement completed signal BEFORE closing inventory
	print("Bag: Emitting replacement_completed signal with reward:", reward_data.name if reward_data else "null", "type:", reward_type)
	replacement_completed.emit(reward_data, reward_type)
	
	# Notify shop if replacement was completed from shop context
	var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
	if shop_interior and shop_interior.has_method("on_replacement_completed"):
		print("Bag: Notifying shop of replacement completion (card)")
		shop_interior.on_replacement_completed(reward_data, reward_type)
	else:
		print("Bag: Shop interior not found or missing on_replacement_completed method (card)")
	
	# Close dialogs AFTER emitting signal
	close_replacement_confirmation()
	close_inventory()

func _on_cancel_replacement_confirmation():
	"""Cancel the replacement confirmation"""
	print("Bag: _on_cancel_replacement_confirmation called")
	close_replacement_confirmation()

func close_replacement_confirmation():
	"""Close the replacement confirmation dialog"""
	if replacement_confirmation_dialog and is_instance_valid(replacement_confirmation_dialog):
		# If in shop, restore ReplacementConfirmation mouse_filter
		var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
		if shop_interior:
			var shop_replacement = shop_interior.get_node_or_null("ReplacementConfirmation")
			if shop_replacement:
				shop_replacement.mouse_filter = Control.MOUSE_FILTER_IGNORE
		replacement_confirmation_dialog.queue_free()
		replacement_confirmation_dialog = null
	
	# Play sound when closing replacement confirmation dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()

func get_deck_size() -> int:
	"""Get the current deck size from CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		return current_deck_manager.get_deck_size()
	return 0

func get_current_deck() -> Array[CardData]:
	"""Get the current deck from CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		var deck = current_deck_manager.get_current_deck()
		return deck
	else:
		print("Bag: CurrentDeckManager not found! Available nodes:")
		for child in get_tree().current_scene.get_children():
			print("  -", child.name)
	return []

func get_deck_summary() -> Dictionary:
	"""Get the deck summary from CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		return current_deck_manager.get_deck_summary()
	return {}

func get_card_by_name(card_name: String) -> CardData:
	"""Get a card by name from the current deck"""
	var current_deck = get_current_deck()
	for card in current_deck:
		if card.name == card_name:
			return card
	return null

func create_equipment_display(equipment_data: EquipmentData, clickable: bool = false) -> Control:
	"""Create a display for a single piece of equipment"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(180, 60)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Equipment background
	var equip_bg = ColorRect.new()
	equip_bg.color = Color(0.3, 0.3, 0.3, 0.9)
	equip_bg.size = Vector2(180, 60)
	equip_bg.position = Vector2(0, 0)
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
	container.add_child(image_rect)
	
	# Equipment name
	var name_label = Label.new()
	name_label.text = equipment_data.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.position = Vector2(60, 10)
	name_label.size = Vector2(110, 20)
	container.add_child(name_label)
	
	# Equipment description (hidden by default)
	var desc_label = Label.new()
	desc_label.text = equipment_data.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.position = Vector2(65, 30)
	desc_label.size = Vector2(310, 20)
	desc_label.visible = false  # Hidden by default
	
	# Add black background to description for better readability
	var desc_bg = ColorRect.new()
	desc_bg.color = Color(0, 0, 0, 0.8)
	desc_bg.size = Vector2(220, 24)
	desc_bg.position = Vector2(60, 28)
	desc_bg.visible = false  # Hidden by default
	container.add_child(desc_bg)
	container.add_child(desc_label)
	
	# Make container mouse filterable for hover detection
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect mouse enter/exit signals for hover effect
	container.mouse_entered.connect(func():
		desc_bg.visible = true
		desc_label.visible = true
		# Ensure description appears on top by setting high z_index
		desc_bg.z_index = 1000
		desc_label.z_index = 1001
	)
	
	container.mouse_exited.connect(func():
		desc_bg.visible = false
		desc_label.visible = false
	)
	
	# If clickable, add click functionality
	if clickable:
		container.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_equipment_clicked(equipment_data)
		)
		
		# Add hover effect for clickable equipment
		container.mouse_entered.connect(func():
			equip_bg.color = Color(0.5, 0.5, 0.3, 0.9)  # Yellow highlight
		)
		
		container.mouse_exited.connect(func():
			equip_bg.color = Color(0.3, 0.3, 0.3, 0.9)  # Normal color
		)
	
	return container

func create_empty_equipment_slot_display(clickable: bool = false) -> Control:
	"""Create a display for an empty equipment slot"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(180, 60)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Empty slot background
	var empty_bg = ColorRect.new()
	empty_bg.color = Color(0.2, 0.2, 0.2, 0.5)  # Semi-transparent
	empty_bg.size = Vector2(180, 60)
	empty_bg.position = Vector2(0, 0)
	container.add_child(empty_bg)
	
	# Empty slot text
	var empty_label = Label.new()
	empty_label.text = "Empty Slot"
	empty_label.add_theme_font_size_override("font_size", 12)
	empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	empty_label.position = Vector2(60, 20)
	empty_label.size = Vector2(110, 20)
	container.add_child(empty_label)
	
	# Make container clickable if needed
	if clickable:
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		container.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_empty_equipment_slot_clicked()
		)
		
		# Add hover effect for clickable empty slots
		container.mouse_entered.connect(func():
			empty_bg.color = Color(0.3, 0.5, 0.3, 0.7)  # Green highlight
		)
		
		container.mouse_exited.connect(func():
			empty_bg.color = Color(0.2, 0.2, 0.2, 0.5)  # Normal color
		)
	else:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return container

func get_movement_cards() -> Array[CardData]:
	"""Get all non-club cards from the current deck"""
	var current_deck = get_current_deck()
	var movement_cards: Array[CardData] = []
	for card in current_deck:
		if not is_club_card(card):
			movement_cards.append(card)
	return movement_cards

func get_club_cards() -> Array[CardData]:
	"""Get all club cards from the current deck"""
	var current_deck = get_current_deck()
	var club_cards: Array[CardData] = []
	
	for card in current_deck:
		if is_club_card(card):
			club_cards.append(card)
	
	return club_cards

func _exit_tree():
	"""Clean up when the bag is removed from the scene"""
	close_inventory()
	close_replacement_confirmation()

func get_equipment_slots() -> int:
	"""Get the number of equipment slots based on bag level"""
	match bag_level:
		1: return 1
		2: return 2
		3: return 3
		4: return 4
		_: return 1

func get_movement_slots() -> int:
	"""Get the number of movement card slots based on bag level"""
	match bag_level:
		1: return 16  # 4x4 grid
		2: return 20  # 4x5 grid
		3: return 24  # 4x6 grid
		4: return 28  # 4x7 grid
		_: return 16

func get_club_slots() -> int:
	"""Get the number of club card slots based on bag level"""
	match bag_level:
		1: return 2
		2: return 3
		3: return 4
		4: return 5
		_: return 2

func create_slot_container() -> Control:
	"""Create a container for a slot that can hold both placeholder and actual item"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Allow mouse events in replacement mode, ignore otherwise
	if is_replacement_mode:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events for buttons
	else:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	return container

func is_club_card(card_data: CardData) -> bool:
	"""Check if a card is a club card based on its name"""
	var club_names = ["Putter", "Wood", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club", "GrenadeLauncherClubCard"]
	return club_names.has(card_data.name)

func create_placeholder_slot() -> Control:
	"""Create a placeholder slot using CardSlot.png"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	
	# Placeholder slot image
	var slot_image = TextureRect.new()
	slot_image.texture = preload("res://Cards/CardSlot.png")
	slot_image.size = Vector2(80, 100)
	slot_image.position = Vector2(0, 0)
	slot_image.scale = Vector2(0.75, 0.75)
	slot_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_image.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	container.add_child(slot_image)
	
	return container

func _on_equipment_clicked(equipment_data: EquipmentData):
	"""Handle equipment click in replacement mode"""
	if is_replacement_mode and pending_reward_type == "equipment" and pending_reward:
		show_equipment_replacement_confirmation(equipment_data)

func _on_empty_equipment_slot_clicked():
	"""Handle empty equipment slot click in replacement mode"""
	if is_replacement_mode and pending_reward_type == "equipment" and pending_reward:
		# Add equipment directly to empty slot
		var equipment_data = pending_reward as EquipmentData
		var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.add_equipment(equipment_data)
		close_inventory()

func show_equipment_replacement_confirmation(equipment_to_replace: EquipmentData):
	"""Show confirmation dialog for equipment replacement"""
	
	# Close any existing confirmation dialog first
	if replacement_confirmation_dialog and is_instance_valid(replacement_confirmation_dialog):
		replacement_confirmation_dialog.queue_free()
	
	# Play sound when showing equipment replacement confirmation dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()
	
	replacement_confirmation_dialog = Control.new()
	replacement_confirmation_dialog.name = "EquipmentReplacementConfirmationDialog"
	replacement_confirmation_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replacement_confirmation_dialog.z_index = 2000  # Set to 2000 for topmost
	replacement_confirmation_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	replacement_confirmation_dialog.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.9)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.z_index = 2000
	replacement_confirmation_dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(600, 300)
	main_container.position = Vector2(-300, -150)
	main_container.z_index = 2000
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	replacement_confirmation_dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.z_index = 2000
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = 2000
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	title.text = "Replace Equipment"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(20, 20)
	title.size = Vector2(560, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.z_index = 2000
	main_container.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = "Are you sure you want to replace '" + (equipment_to_replace.name if equipment_to_replace else "null") + "' with '" + (pending_reward.name if pending_reward else "null") + "'?"
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.position = Vector2(20, 80)
	message.size = Vector2(560, 60)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.z_index = 2000
	main_container.add_child(message)
	
	# Equipment comparison
	var equipment_comparison = HBoxContainer.new()
	equipment_comparison.position = Vector2(150, 160)
	equipment_comparison.size = Vector2(300, 80)
	equipment_comparison.z_index = 2000
	main_container.add_child(equipment_comparison)
	
	# Old equipment
	var old_equipment_label = Label.new()
	old_equipment_label.text = "Old: " + (equipment_to_replace.name if equipment_to_replace else "null")
	old_equipment_label.add_theme_font_size_override("font_size", 12)
	old_equipment_label.add_theme_color_override("font_color", Color.RED)
	old_equipment_label.z_index = 2000
	equipment_comparison.add_child(old_equipment_label)
	
	# Arrow
	var arrow_label = Label.new()
	arrow_label.text = " → "
	arrow_label.add_theme_font_size_override("font_size", 16)
	arrow_label.add_theme_color_override("font_color", Color.WHITE)
	arrow_label.z_index = 2000
	equipment_comparison.add_child(arrow_label)
	
	# New equipment
	var new_equipment_label = Label.new()
	new_equipment_label.text = "New: " + (pending_reward.name if pending_reward else "null")
	new_equipment_label.add_theme_font_size_override("font_size", 12)
	new_equipment_label.add_theme_color_override("font_color", Color.GREEN)
	new_equipment_label.z_index = 2000
	equipment_comparison.add_child(new_equipment_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(200, 220)
	button_container.size = Vector2(200, 40)
	button_container.z_index = 2000
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	main_container.add_child(button_container)
	
	# Yes button
	var yes_button = Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_confirm_equipment_replacement.bind(equipment_to_replace))
	yes_button.z_index = 2000
	yes_button.process_mode = Node.PROCESS_MODE_INHERIT
	# Add fallback input handling
	yes_button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_confirm_equipment_replacement(equipment_to_replace)
	)
	button_container.add_child(yes_button)
	
	# No button
	var no_button = Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(_on_cancel_replacement_confirmation)
	no_button.z_index = 2000
	no_button.process_mode = Node.PROCESS_MODE_INHERIT
	# Add fallback input handling
	no_button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel_replacement_confirmation()
	)
	button_container.add_child(no_button)
	
	# Add dialog to UI layer as last child to ensure it's on top
	var shop_replacement = null
	var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
	if shop_interior:
		shop_replacement = shop_interior.get_node_or_null("ReplacementConfirmation")
	if shop_replacement:
		shop_replacement.add_child(replacement_confirmation_dialog)
		shop_replacement.mouse_filter = Control.MOUSE_FILTER_STOP
		replacement_confirmation_dialog.visible = true
		# Lower the z_index of the Bag inventory dialog if it exists
		if inventory_dialog and is_instance_valid(inventory_dialog):
			inventory_dialog.z_index = 1000
		print("Bag: Replacement confirmation added to Shop ReplacementConfirmation node")
	else:
		var ui_layer = get_tree().current_scene.get_node_or_null("UILayer")
		if ui_layer:
			ui_layer.add_child(replacement_confirmation_dialog)
			ui_layer.move_child(replacement_confirmation_dialog, ui_layer.get_child_count() - 1)
			replacement_confirmation_dialog.visible = true
			# Lower the z_index of the Bag inventory dialog if it exists
			if inventory_dialog and is_instance_valid(inventory_dialog):
				inventory_dialog.z_index = 1000
			print("Bag: Replacement confirmation added to UI layer")
		else:
			get_tree().current_scene.add_child(replacement_confirmation_dialog)
			replacement_confirmation_dialog.visible = true
			print("Bag: Replacement confirmation added to current scene")

func _on_confirm_equipment_replacement(equipment_to_replace: EquipmentData):
	"""Confirm the equipment replacement"""
	print("Bag: _on_confirm_equipment_replacement called with equipment_to_replace:", equipment_to_replace.name if equipment_to_replace else "null")
	print("Bag: pending_reward:", pending_reward.name if pending_reward else "null")
	
	if not pending_reward or not equipment_to_replace:
		print("Bag: Missing data for replacement, closing confirmation")
		close_replacement_confirmation()
		return
	
	# Store the reward data before closing inventory (which clears these variables)
	var reward_data = pending_reward
	var reward_type = pending_reward_type
	
	# Remove the old equipment
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		equipment_manager.remove_equipment(equipment_to_replace)
		print("Bag: Removed equipment:", equipment_to_replace.name)
	
	# Add the new equipment
	if reward_type == "equipment":
		var equipment_data = reward_data as EquipmentData
		equipment_manager.add_equipment(equipment_data)
		print("Bag: Added equipment:", equipment_data.name)
	
	# Emit replacement completed signal BEFORE closing inventory
	print("Bag: Emitting replacement_completed signal with reward:", reward_data.name if reward_data else "null", "type:", reward_type)
	replacement_completed.emit(reward_data, reward_type)
	
	# Notify shop if replacement was completed from shop context
	var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
	if shop_interior and shop_interior.has_method("on_replacement_completed"):
		shop_interior.on_replacement_completed(reward_data, reward_type)
	
	# Close dialogs AFTER emitting signal
	close_replacement_confirmation()
	close_inventory()

func _on_equipment_updated():
	"""Called when equipment is updated - refresh the bag display if open"""
	if is_inventory_open and inventory_dialog:
		# Refresh the inventory display
		close_inventory()
		show_inventory()

func _on_deck_updated():
	"""Called when deck is updated - refresh the bag display if open"""
	if is_inventory_open and inventory_dialog:
		# Refresh the inventory display
		close_inventory()
		show_inventory()
