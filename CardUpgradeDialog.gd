extends Control

signal card_upgraded(card: CardData)
signal card_pruned(card: CardData)
signal dialog_closed

@onready var background: ColorRect = $Background
@onready var title_label: Label = $DialogBox/TitleLabel
@onready var card_container: GridContainer = $DialogBox/CardContainer
@onready var close_button: Button = $DialogBox/CloseButton
@onready var upgrade_sound: AudioStreamPlayer2D = $UpgradeSound
@onready var bag_sound: AudioStreamPlayer2D = $BagSound

var current_deck_manager: CurrentDeckManager
var selected_card: CardData = null
var card_buttons: Array[Button] = []
var is_prune_mode: bool = false
var prune_cost: int = 25  # Cost to remove a card

func _ready():
	# Connect signals
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Get reference to current deck manager
	current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if not current_deck_manager:
		print("CardUpgradeDialog: ERROR - CurrentDeckManager not found!")
		return
	
	# Initially hide the dialog
	visible = false

func show_dialog():
	"""Show the card upgrade dialog"""
	visible = true
	is_prune_mode = false
	
	# Set high z_index to ensure dialog appears on top
	z_index = 3000
	
	# Hide any existing reward dialogs that might interfere
	hide_existing_reward_dialogs()
	
	# Hide ShopItems to prevent them from appearing on top
	hide_shop_items()
	
	load_player_deck()
	update_title_and_buttons()
	
	# Play sound when showing upgrade dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()

func hide_existing_reward_dialogs():
	"""Hide any existing reward dialogs that might be on top"""
	# Check for RewardSelectionDialog in UILayer
	var ui_layer = get_tree().current_scene.get_node_or_null("UILayer")
	if ui_layer:
		var reward_dialog = ui_layer.get_node_or_null("RewardSelectionDialog")
		if reward_dialog and reward_dialog.visible:
			reward_dialog.visible = false
			print("CardUpgradeDialog: Hidden existing RewardSelectionDialog")
	
	# Check for any other reward dialogs in the scene
	var reward_dialogs = get_tree().get_nodes_in_group("reward_dialogs")
	for dialog in reward_dialogs:
		if dialog.visible:
			dialog.visible = false
			print("CardUpgradeDialog: Hidden reward dialog:", dialog.name)

func hide_shop_items():
	"""Hide ShopItems to prevent them from appearing on top of the dialog"""
	var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
	if shop_interior:
		var shop_items = shop_interior.get_node_or_null("ShopItems")
		if shop_items and shop_items.visible:
			shop_items.visible = false
			print("CardUpgradeDialog: Hidden ShopItems")

func show_shop_items():
	"""Show ShopItems when dialog closes"""
	var shop_interior = get_tree().current_scene.get_node_or_null("UILayer/ShopInterior")
	if shop_interior:
		var shop_items = shop_interior.get_node_or_null("ShopItems")
		if shop_items and not shop_items.visible:
			shop_items.visible = true
			print("CardUpgradeDialog: Shown ShopItems")

func hide_dialog():
	"""Hide the card upgrade dialog"""
	visible = false
	clear_card_buttons()
	
	# Show ShopItems again when dialog closes
	show_shop_items()
	
	emit_signal("dialog_closed")
	
	# Play sound when closing upgrade dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()

func update_title_and_buttons():
	"""Update the title and mode toggle button based on current mode"""
	if is_prune_mode:
		title_label.text = "Select a Card to Remove (Cost: " + str(prune_cost) + " coins)"
	else:
		title_label.text = "Select a Card to Upgrade"
	
	# Update or create mode toggle button
	update_mode_toggle_button()

func update_mode_toggle_button():
	"""Create or update the mode toggle button"""
	# Remove existing toggle button if it exists
	var existing_toggle = $DialogBox/ModeToggleButton
	if existing_toggle:
		existing_toggle.queue_free()
	
	# Create new toggle button
	var toggle_button = Button.new()
	toggle_button.name = "ModeToggleButton"
	toggle_button.text = "Switch to Prune Mode" if not is_prune_mode else "Switch to Upgrade Mode"
	toggle_button.size = Vector2(150, 40)
	toggle_button.position = Vector2(20, 20)
	toggle_button.pressed.connect(_on_mode_toggle_pressed)
	$DialogBox.add_child(toggle_button)

func _on_mode_toggle_pressed():
	"""Handle mode toggle button press"""
	is_prune_mode = !is_prune_mode
	update_title_and_buttons()
	load_player_deck()  # Reload to show different cards based on mode
	
	# Play sound when switching modes
	if bag_sound and bag_sound.stream:
		bag_sound.play()

func load_player_deck():
	"""Load and display the player's current deck"""
	clear_card_buttons()
	
	if not current_deck_manager:
		print("CardUpgradeDialog: ERROR - CurrentDeckManager not found!")
		return
	
	var deck = current_deck_manager.get_current_deck()
	var card_summary = current_deck_manager.get_deck_summary()
	
	print("CardUpgradeDialog: Loading deck with", deck.size(), "cards")
	
	# Create a set of unique cards to avoid duplicates
	var unique_cards: Array[CardData] = []
	var seen_cards: Dictionary = {}
	
	for card in deck:
		if not seen_cards.has(card.name):
			unique_cards.append(card)
			seen_cards[card.name] = true
	
	# Create card buttons based on mode
	for card in unique_cards:
		if is_prune_mode:
			# In prune mode, show all cards that can be removed (more than 1 copy)
			if card_summary[card.name] > 1:
				create_card_button(card, card_summary[card.name])
		else:
			# In upgrade mode, show cards that can be upgraded
			if card.can_upgrade():
				create_card_button(card, card_summary[card.name])

func create_card_button(card: CardData, count: int):
	"""Create a button for a card in the upgrade dialog"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 160)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Create card display
	var card_display = create_card_display(card, count)
	button.add_child(card_display)
	
	# Connect button signal
	button.pressed.connect(_on_card_button_pressed.bind(card))
	
	# Add to container and tracking array
	card_container.add_child(button)
	card_buttons.append(button)

func create_card_display(card: CardData, count: int) -> Control:
	"""Create a visual display for a card"""
	var container = Control.new()
	container.size = Vector2(120, 160)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.2, 0.9)
	background.size = container.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(background)
	
	# Border - orange for upgraded cards, normal for base cards
	var border = ColorRect.new()
	if card.is_upgraded():
		border.color = Color(1.0, 0.5, 0.0, 0.8)  # Orange border for upgraded
	else:
		border.color = Color(0.8, 0.8, 0.8, 0.6)  # Normal border
	border.size = Vector2(container.size.x + 4, container.size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)
	border.z_index = -1
	
	# Card image
	var image_rect = TextureRect.new()
	image_rect.texture = card.image
	image_rect.size = Vector2(80, 120)
	image_rect.position = Vector2(20, 10)
	image_rect.scale = Vector2(0.1, 0.1)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(image_rect)
	
	# Card name
	var name_label = Label.new()
	name_label.text = card.get_upgraded_name()
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.position = Vector2(5, 135)
	name_label.size = Vector2(110, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)
	
	# Level indicator for upgraded cards
	if card.is_upgraded():
		var level_label = Label.new()
		level_label.text = "Lvl " + str(card.level)
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.add_theme_color_override("font_color", Color.GREEN)
		level_label.add_theme_constant_override("outline_size", 2)
		level_label.add_theme_color_override("font_outline_color", Color.BLACK)
		level_label.position = Vector2(85, 5)
		level_label.size = Vector2(30, 20)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(level_label)
	
	# Count indicator
	var count_label = Label.new()
	count_label.text = "x" + str(count)
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.YELLOW)
	count_label.add_theme_constant_override("outline_size", 1)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.position = Vector2(5, 5)
	count_label.size = Vector2(30, 20)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(count_label)
	
	return container

func clear_card_buttons():
	"""Clear all card buttons"""
	for button in card_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	card_buttons.clear()

func _on_card_button_pressed(card: CardData):
	"""Handle card button press - show upgrade or prune confirmation"""
	selected_card = card
	if is_prune_mode:
		show_prune_confirmation(card)
	else:
		show_upgrade_confirmation(card)

func show_upgrade_confirmation(card: CardData):
	"""Show confirmation dialog for upgrading a card"""
	# Play sound when showing upgrade confirmation dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()
	
	# Create confirmation dialog
	var confirmation_dialog = Control.new()
	confirmation_dialog.name = "UpgradeConfirmation"
	confirmation_dialog.size = get_viewport_rect().size
	confirmation_dialog.z_index = 2000
	confirmation_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var dialog_bg = ColorRect.new()
	dialog_bg.color = Color(0, 0, 0, 0.8)
	dialog_bg.size = confirmation_dialog.size
	dialog_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_dialog.add_child(dialog_bg)
	
	var dialog_box = ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.95)
	dialog_box.size = Vector2(400, 300)
	dialog_box.position = (confirmation_dialog.size - dialog_box.size) / 2
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirmation_dialog.add_child(dialog_box)
	
	# Title
	var title = Label.new()
	title.text = "Upgrade Card"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.YELLOW)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.position = Vector2(150, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title)
	
	# Card display
	var card_display = create_card_display(card, 1)
	card_display.position = Vector2(140, 60)
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(card_display)
	
	# Upgrade description
	var desc_label = Label.new()
	desc_label.text = card.get_upgrade_description()
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	desc_label.add_theme_constant_override("outline_size", 1)
	desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	desc_label.position = Vector2(50, 180)
	desc_label.size = Vector2(300, 40)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(desc_label)
	
	# Cost
	var cost_label = Label.new()
	cost_label.text = "Cost: " + str(card.upgrade_cost) + " coins"
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color.GOLD)
	cost_label.add_theme_constant_override("outline_size", 1)
	cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_label.position = Vector2(150, 220)
	cost_label.size = Vector2(200, 30)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(cost_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(100, 250)
	button_container.size = Vector2(200, 40)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(button_container)
	
	var yes_button = Button.new()
	yes_button.text = "Upgrade"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_confirm_upgrade.bind(card, confirmation_dialog))
	button_container.add_child(yes_button)
	
	var no_button = Button.new()
	no_button.text = "Cancel"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(func(): 
		# Play sound when canceling upgrade confirmation
		if bag_sound and bag_sound.stream:
			bag_sound.play()
		confirmation_dialog.queue_free()
	)
	button_container.add_child(no_button)
	
	add_child(confirmation_dialog)

func show_prune_confirmation(card: CardData):
	"""Show confirmation dialog for removing a card"""
	# Play sound when showing prune confirmation dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()
	
	# Check if player can afford the cost using Global functions
	if not Global.can_afford(prune_cost):
		show_insufficient_funds_message()
		return
	
	# Create confirmation dialog
	var confirmation_dialog = Control.new()
	confirmation_dialog.name = "PruneConfirmation"
	confirmation_dialog.size = get_viewport_rect().size
	confirmation_dialog.z_index = 2000
	confirmation_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var dialog_bg = ColorRect.new()
	dialog_bg.color = Color(0, 0, 0, 0.8)
	dialog_bg.size = confirmation_dialog.size
	dialog_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_dialog.add_child(dialog_bg)
	
	var dialog_box = ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.95)
	dialog_box.size = Vector2(400, 300)
	dialog_box.position = (confirmation_dialog.size - dialog_box.size) / 2
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirmation_dialog.add_child(dialog_box)
	
	# Title
	var title = Label.new()
	title.text = "Remove Card"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.RED)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.position = Vector2(150, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title)
	
	# Card display
	var card_display = create_card_display(card, current_deck_manager.get_card_count(card.name))
	card_display.position = Vector2(140, 60)
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(card_display)
	
	# Warning message
	var warning_label = Label.new()
	warning_label.text = "This will permanently remove one copy of " + card.name + " from your deck."
	warning_label.add_theme_font_size_override("font_size", 14)
	warning_label.add_theme_color_override("font_color", Color.YELLOW)
	warning_label.add_theme_constant_override("outline_size", 1)
	warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	warning_label.position = Vector2(50, 180)
	warning_label.size = Vector2(300, 40)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(warning_label)
	
	# Cost
	var cost_label = Label.new()
	cost_label.text = "Cost: " + str(prune_cost) + " coins"
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color.GOLD)
	cost_label.add_theme_constant_override("outline_size", 1)
	cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_label.position = Vector2(150, 220)
	cost_label.size = Vector2(200, 30)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(cost_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(100, 250)
	button_container.size = Vector2(200, 40)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(button_container)
	
	var yes_button = Button.new()
	yes_button.text = "Remove"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_confirm_prune.bind(card, confirmation_dialog))
	button_container.add_child(yes_button)
	
	var no_button = Button.new()
	no_button.text = "Cancel"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(func(): 
		# Play sound when canceling prune confirmation
		if bag_sound and bag_sound.stream:
			bag_sound.play()
		confirmation_dialog.queue_free()
	)
	button_container.add_child(no_button)
	
	add_child(confirmation_dialog)

func show_insufficient_funds_message():
	"""Show a message when player doesn't have enough money"""
	var message_dialog = Control.new()
	message_dialog.name = "InsufficientFunds"
	message_dialog.size = get_viewport_rect().size
	message_dialog.z_index = 2000
	message_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = message_dialog.size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	message_dialog.add_child(bg)
	
	var message = Label.new()
	message.text = "Not enough coins! You need " + str(prune_cost) + " coins to remove a card."
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color.RED)
	message.add_theme_constant_override("outline_size", 2)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.position = (message_dialog.size - Vector2(400, 50)) / 2
	message.size = Vector2(400, 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_dialog.add_child(message)
	
	add_child(message_dialog)
	
	# Remove after 3 seconds
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func(): 
		if message_dialog and is_instance_valid(message_dialog):
			message_dialog.queue_free()
	)

func _on_confirm_upgrade(card: CardData, confirmation_dialog: Control):
	"""Confirm and perform the card upgrade"""
	# Remove confirmation dialog
	confirmation_dialog.queue_free()
	
	# Perform upgrade
	upgrade_card(card)
	
	# Play upgrade sound from shop if available
	var shop_interior = get_tree().current_scene.get_node_or_null("ShopInterior")
	if shop_interior:
		var shop_upgrade_sound = shop_interior.get_node_or_null("UpgradeSound")
		if shop_upgrade_sound and shop_upgrade_sound.stream:
			shop_upgrade_sound.play()
	
	# Show success message
	show_upgrade_success(card)
	
	# Reload the deck display
	load_player_deck()

func upgrade_card(card: CardData):
	"""Upgrade a card by increasing its level"""
	card.level += 1
	print("CardUpgradeDialog: Upgraded", card.name, "to level", card.level)
	
	# Emit signal for other systems to handle
	emit_signal("card_upgraded", card)

func show_upgrade_success(card: CardData):
	"""Show a success message for the upgrade"""
	var success_dialog = Control.new()
	success_dialog.name = "UpgradeSuccess"
	success_dialog.size = get_viewport_rect().size
	success_dialog.z_index = 2000
	success_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = success_dialog.size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	success_dialog.add_child(bg)
	
	var message = Label.new()
	message.text = card.name + " upgraded to Level " + str(card.level) + "!"
	message.add_theme_font_size_override("font_size", 20)
	message.add_theme_color_override("font_color", Color.GREEN)
	message.add_theme_constant_override("outline_size", 2)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.position = (success_dialog.size - Vector2(400, 50)) / 2
	message.size = Vector2(400, 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	success_dialog.add_child(message)
	
	add_child(success_dialog)
	
	# Remove after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if success_dialog and is_instance_valid(success_dialog):
			success_dialog.queue_free()
	)

func _on_confirm_prune(card: CardData, confirmation_dialog: Control):
	"""Confirm and perform the card removal"""
	# Remove confirmation dialog
	confirmation_dialog.queue_free()
	
	# Spend the money using Global functions
	if Global.spend_looty(prune_cost):
		# Perform removal
		prune_card(card)
		
		# Play sound
		if bag_sound and bag_sound.stream:
			bag_sound.play()
		
		# Show success message
		show_prune_success(card)
		
		# Reload the deck display
		load_player_deck()
	else:
		show_insufficient_funds_message()

func prune_card(card: CardData):
	"""Remove a card from the deck"""
	current_deck_manager.remove_card_from_deck(card)
	print("CardUpgradeDialog: Removed", card.name, "from deck")
	
	# Emit signal for other systems to handle
	emit_signal("card_pruned", card)

func show_prune_success(card: CardData):
	"""Show a success message for the card removal"""
	var success_dialog = Control.new()
	success_dialog.name = "PruneSuccess"
	success_dialog.size = get_viewport_rect().size
	success_dialog.z_index = 2000
	success_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = success_dialog.size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	success_dialog.add_child(bg)
	
	var message = Label.new()
	message.text = "Removed " + card.name + " from your deck!"
	message.add_theme_font_size_override("font_size", 20)
	message.add_theme_color_override("font_color", Color.ORANGE)
	message.add_theme_constant_override("outline_size", 2)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.position = (success_dialog.size - Vector2(400, 50)) / 2
	message.size = Vector2(400, 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	success_dialog.add_child(message)
	
	add_child(success_dialog)
	
	# Remove after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if success_dialog and is_instance_valid(success_dialog):
			success_dialog.queue_free()
	)

func _on_close_button_pressed():
	"""Handle close button press"""
	hide_dialog() 
