# CardVisual.gd
extends Control

@onready var label = $Label
@onready var icon = $TextureRect

var data: CardData
var level_label: Label
var border_rect: ColorRect

func _ready():
	# Ensure UI elements are properly initialized
	if not label:
		label = $Label
	if not icon:
		icon = $TextureRect
	
	# Debug output to check initialization
	print("CardVisual _ready: label=", label, "icon=", icon)

func setup(card_data: CardData) -> void:
	if not card_data:
		print("Warning: setup called with null card_data")
		return
		
	data = card_data
	
	# Add null checks for UI elements
	if not label:
		label = $Label
	if not icon:
		icon = $TextureRect
	
	if label:
		label.text = card_data.get_upgraded_name()
	if card_data.image and icon:
		icon.texture = card_data.image
	
	# Add upgrade visual indicators
	update_upgrade_visuals()

func set_card_data(card_data: CardData) -> void:
	if not card_data:
		print("Warning: set_card_data called with null card_data")
		return
		
	data = card_data
	
	# Add null checks for UI elements
	if not label:
		label = $Label
		print("CardVisual: Found label node:", label)
	if not icon:
		icon = $TextureRect
		print("CardVisual: Found icon node:", icon)
	
	if label:
		label.text = card_data.get_upgraded_name()
		print("CardVisual: Set label text to:", card_data.get_upgraded_name())
	if card_data.image and icon:
		icon.texture = card_data.image
		print("CardVisual: Set icon texture for:", card_data.name)
	else:
		print("CardVisual: No image or icon for:", card_data.name, "image:", card_data.image, "icon:", icon)
	
	# Add upgrade visual indicators
	update_upgrade_visuals()

func update_upgrade_visuals():
	"""Update the visual appearance based on card upgrade status"""
	if not data:
		return
	
	# Ensure we're in the scene tree before adding children
	if not is_inside_tree():
		# If not in scene tree, wait until we are
		await ready
		# Re-check data after waiting
		if not data:
			return
	
	# Remove existing upgrade visuals
	if level_label and is_instance_valid(level_label):
		level_label.queue_free()
		level_label = null
	
	if border_rect and is_instance_valid(border_rect):
		border_rect.queue_free()
		border_rect = null
	
	# Add upgrade visuals if card is upgraded
	if data.is_upgraded():
		# Add orange border
		border_rect = ColorRect.new()
		border_rect.color = Color(1.0, 0.5, 0.0, 0.8)  # Orange border
		border_rect.size = Vector2(size.x + 4, size.y + 4)
		border_rect.position = Vector2(-2, -2)
		border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border_rect.z_index = -1
		add_child(border_rect)
		
		# Add green level label
		level_label = Label.new()
		level_label.text = "Lvl " + str(data.level)
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.add_theme_color_override("font_color", Color.GREEN)
		level_label.add_theme_constant_override("outline_size", 2)
		level_label.add_theme_color_override("font_outline_color", Color.BLACK)
		level_label.position = Vector2(size.x - 35, 5)
		level_label.size = Vector2(30, 20)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.z_index = 10
		add_child(level_label)
