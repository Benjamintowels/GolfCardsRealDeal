extends Control

signal dialog_closed

var genes_list: ItemList
var print_button: Button
var close_button: Button
var looty_label: Label
var confirm_row: HBoxContainer
var bring_button: Button
var discard_button: Button
var sfx: AudioStreamPlayer

var clubhouse_upgrade_manager: Node

func _ready():
	visible = false
	genes_list = get_node_or_null("Panel/GenesList")
	print_button = get_node_or_null("Panel/Buttons/PrintButton")
	close_button = get_node_or_null("Panel/Buttons/CloseButton")
	looty_label = get_node_or_null("Panel/LootyLabel")
	confirm_row = get_node_or_null("Panel/ConfirmRow")
	bring_button = get_node_or_null("Panel/ConfirmRow/BringButton")
	discard_button = get_node_or_null("Panel/ConfirmRow/DiscardButton")
	sfx = get_node_or_null("Sfx")

	clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")

	if print_button:
		print_button.pressed.connect(_on_print_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if genes_list:
		genes_list.item_selected.connect(_on_gene_selected)
	if bring_button:
		bring_button.pressed.connect(_on_bring_pressed)
	if discard_button:
		discard_button.pressed.connect(_on_discard_pressed)

	# Connect background safely if it exists
	var bg = get_node_or_null("Background")
	if bg:
		bg.gui_input.connect(_on_background_clicked)

	_refresh()

func show_dialog():
	visible = true
	_refresh()
	if confirm_row:
		confirm_row.visible = false

func hide_dialog():
	visible = false

func _refresh():
	var save_file_manager = get_node("/root/SaveFileManager")
	if not save_file_manager:
		return
	# Update looty label
	var clubhouse_looty: int = clubhouse_upgrade_manager.get_clubhouse_looty() if clubhouse_upgrade_manager else 0
	var player_looty: int = Global.get_looty()
	if looty_label:
		looty_label.text = "$Looty — ClubHouse: %d | Player: %d (Cost to print: 25)" % [clubhouse_looty, player_looty]
	_update_print_button_state()
	# Populate list
	if genes_list:
		genes_list.clear()
		for path in save_file_manager.get_card_genes():
			var card: Resource = load(path)
			var display = path.get_file()
			if card and card.has_method("get"):
				var card_name = card.get("name") if card.get("name") != null else display
				display = card_name
			genes_list.add_item(display)
			genes_list.set_item_metadata(genes_list.item_count - 1, path)
		# Auto-select the first gene if none selected to make printing straightforward
		if genes_list.item_count > 0 and genes_list.get_selected_items().is_empty():
			genes_list.select(0)
	_update_print_button_state()

func _on_background_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_dialog()
		dialog_closed.emit()

func _on_close_pressed():
	hide_dialog()
	dialog_closed.emit()

func _on_print_pressed():
	clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	var save_file_manager = get_node("/root/SaveFileManager")
	if not clubhouse_upgrade_manager or not save_file_manager:
		return
	var selected = genes_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = int(selected[0])
	var card_path: String = String(genes_list.get_item_metadata(idx))
	# Cost 25 from ClubHouse wallet
	var paid: bool = clubhouse_upgrade_manager.spend_clubhouse_looty(25)
	if not paid:
		# Fallback to player's personal $Looty if ClubHouse wallet can't cover it
		if Global.spend_looty(25):
			paid = true
	if not paid:
		return
	# Play SFX
	if sfx:
		sfx.play()
	# Show confirmation row and stash pending choice in metadata
	if confirm_row:
		confirm_row.visible = true
		confirm_row.set_meta("pending_card_path", card_path)
	_refresh()
	_update_print_button_state()

func _on_bring_pressed():
	var save_file_manager = get_node("/root/SaveFileManager")
	if not save_file_manager or not confirm_row:
		return
	var card_path = String(confirm_row.get_meta("pending_card_path"))
	if card_path != "":
		save_file_manager.queue_printed_card(card_path)
		save_file_manager.save_current_game()
	confirm_row.visible = false
	confirm_row.set_meta("pending_card_path", "")
	_refresh()
	_update_print_button_state()

func _on_discard_pressed():
	if confirm_row:
		confirm_row.visible = false
		confirm_row.set_meta("pending_card_path", "")
	_update_print_button_state()

func _on_gene_selected(_index: int):
	_update_print_button_state()

func _update_print_button_state():
	if not print_button:
		return
	var can_select := genes_list and genes_list.get_selected_items().size() > 0
	var clubhouse_looty: int = clubhouse_upgrade_manager.get_clubhouse_looty() if clubhouse_upgrade_manager else 0
	var player_looty: int = Global.get_looty()
	var can_afford := (clubhouse_looty >= 25) or (player_looty >= 25)
	print_button.disabled = not (can_select and can_afford)
