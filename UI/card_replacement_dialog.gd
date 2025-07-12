extends Control
class_name CardReplacementDialog

signal replacement_completed(reward_data: Resource, reward_type: String)
signal replacement_cancelled

var pending_reward: Resource = null
var pending_reward_type: String = ""
var card_replacement_dialog: Control = null
var is_dialog_active: bool = false

# UI Elements
@onready var background: ColorRect = $Background
@onready var main_container: Control = $MainContainer
@onready var title_label: Label = $MainContainer/Title
@onready var new_item_label: Label = $MainContainer/NewItemLabel
@onready var new_item_display: Control = $MainContainer/NewItemDisplay
@onready var instructions_label: Label = $MainContainer/Instructions
@onready var cancel_button: Button = $MainContainer/CancelButton

func _ready():
	# Hide initially
	visible = false
	is_dialog_active = false
	
	# Connect cancel button
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func show_replacement_dialog(reward_data: Resource, reward_type: String):
	"""Show the replacement dialog for the given reward"""
	
	pending_reward = reward_data
	pending_reward_type = reward_type
	is_dialog_active = true
	
	# Update UI based on reward type
	_update_dialog_content()
	
	# Show the dialog
	visible = true
	
	# Open bag in replacement mode
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if bag:
		bag.show_inventory_replacement_mode(pending_reward, pending_reward_type)
		# Connect to bag's replacement completion signal
		bag.replacement_completed.connect(_on_bag_replacement_completed)

func _update_dialog_content():
	"""Update the dialog content based on the pending reward"""
	if not pending_reward:
		return
	
	# Update title
	if title_label:
		if pending_reward_type == "equipment":
			title_label.text = "Bag Full - Select Equipment to Replace"
		else:
			title_label.text = "Bag Full - Select Card to Replace"
	
	# Update new item label
	if new_item_label:
		if pending_reward_type == "equipment":
			new_item_label.text = "New Equipment:"
		else:
			new_item_label.text = "New Card:"
	
	# Update new item display
	if new_item_display:
		# Clear existing display
		for child in new_item_display.get_children():
			child.queue_free()
		
		# Create new display
		var display = _create_item_display(pending_reward, pending_reward_type)
		if display:
			new_item_display.add_child(display)
	
	# Update instructions
	if instructions_label:
		if pending_reward_type == "equipment":
			instructions_label.text = "Click on equipment in your bag to replace it with the new equipment."
		else:
			instructions_label.text = "Click on a card in your bag to replace it with the new card."

func _create_item_display(item: Resource, item_type: String) -> Control:
	"""Create a display for the item being replaced"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if item_type == "card":
		var card_data = item as CardData
		if card_data:
			# Use CardVisual for consistent upgrade display
			var card_scene = preload("res://CardVisual.tscn")
			var card_instance = card_scene.instantiate()
			card_instance.size = Vector2(80, 100)
			card_instance.position = Vector2(0, 0)
			card_instance.scale = Vector2(1.236, 1.113)
			card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			# Set the card data to show upgrade indicators
			if card_instance.has_method("set_card_data") and card_data:
				card_instance.set_card_data(card_data)
			
			container.add_child(card_instance)
	
	elif item_type == "equipment":
		var equipment_data = item as EquipmentData
		if equipment_data:
			# Equipment background
			var equip_bg = ColorRect.new()
			equip_bg.color = Color(0.3, 0.3, 0.3, 0.9)
			equip_bg.size = Vector2(180, 60)
			equip_bg.position = Vector2(0, 0)
			equip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(image_rect)
			
			# Equipment name
			var name_label = Label.new()
			name_label.text = equipment_data.name
			name_label.add_theme_font_size_override("font_size", 12)
			name_label.add_theme_color_override("font_color", Color.WHITE)
			name_label.position = Vector2(60, 10)
			name_label.size = Vector2(110, 20)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(name_label)
	
	return container

func _on_cancel_pressed():
	"""Handle cancel button press"""
	close_dialog()
	replacement_cancelled.emit()

func close_dialog():
	"""Close the replacement dialog and clean up"""
	
	visible = false
	is_dialog_active = false
	
	# Close bag replacement mode
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if bag:
		bag.close_inventory()
	
	# Reset state
	pending_reward = null
	pending_reward_type = ""
	
	# Stop processing
	set_process(false)

func _on_bag_replacement_completed(reward_data: Resource, reward_type: String):
	"""Called when bag replacement is completed"""
	close_dialog()
	replacement_completed.emit(reward_data, reward_type)

func _process(_delta):
	"""Process function to check for replacement completion (fallback)"""
	if not is_dialog_active:
		return
	
	# Check if bag has completed replacement (fallback method)
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if bag and not bag.is_replacement_mode:
		# Bag is no longer in replacement mode, assume completion
		_on_bag_replacement_completed(pending_reward, pending_reward_type)

func _exit_tree():
	"""Clean up when the dialog is removed"""
	close_dialog()

# Static utility functions for slot checking
static func check_bag_slots(item: Resource, item_type: String) -> bool:
	"""Check if there are available slots in the bag for the item"""
	var bag = Engine.get_main_loop().current_scene.get_node_or_null("UILayer/Bag")
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
		var equipment_manager = Engine.get_main_loop().current_scene.get_node_or_null("EquipmentManager")
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

static func add_item_to_inventory(item: Resource, item_type: String):
	"""Add item to the appropriate inventory"""
	if item_type == "card":
		var card_data = item as CardData
		var current_deck_manager = Engine.get_main_loop().current_scene.get_node_or_null("CurrentDeckManager")
		if current_deck_manager:
			current_deck_manager.add_card_to_deck(card_data)
	elif item_type == "equipment":
		var equipment_data = item as EquipmentData
		var equipment_manager = Engine.get_main_loop().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.add_equipment(equipment_data)
