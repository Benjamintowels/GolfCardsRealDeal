extends Control

signal upgrade_completed
signal dialog_closed

# These nodes will be retrieved in _ready()
var flippy_upgrade_button: Button
var flippy_level_label: Label
var flippy_cost_label: Label
var close_button: Button
var clubhouse_looty_label: Label

var clubhouse_upgrade_manager: Node
var golfsmith_upgrade_button: Button
var golfsmith_cost_label: Label

func _ready():
	# Hide dialog initially
	visible = false
	
	# Get the UI nodes
	flippy_upgrade_button = get_node_or_null("DialogContainer/UpgradeOptions/FlippySection/FlippyUpgradeButton")
	flippy_level_label = get_node_or_null("DialogContainer/UpgradeOptions/FlippySection/FlippyLevelLabel")
	flippy_cost_label = get_node_or_null("DialogContainer/UpgradeOptions/FlippySection/FlippyCostLabel")
	close_button = get_node_or_null("DialogContainer/CloseButton")
	clubhouse_looty_label = get_node_or_null("DialogContainer/ClubHouseLootyLabel")
	golfsmith_upgrade_button = get_node_or_null("DialogContainer/UpgradeOptions/GolfsmithSection/GolfsmithUpgradeButton")
	golfsmith_cost_label = get_node_or_null("DialogContainer/UpgradeOptions/GolfsmithSection/GolfsmithCostLabel")
	
	# Get the ClubHouse upgrade manager
	clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	if not clubhouse_upgrade_manager:
		print("ERROR: ClubHouseUpgradeManager not found!")
		return
	
	# Connect signals with safety checks
	if flippy_upgrade_button and is_instance_valid(flippy_upgrade_button):
		flippy_upgrade_button.pressed.connect(_on_flippy_upgrade_pressed)
		print("✅ Flippy upgrade button connected")
	
	if close_button and is_instance_valid(close_button):
		close_button.pressed.connect(_on_close_pressed)
		print("✅ Close button connected")
	
	if golfsmith_upgrade_button and is_instance_valid(golfsmith_upgrade_button):
		golfsmith_upgrade_button.pressed.connect(_on_golfsmith_upgrade_pressed)
	
	# Connect to manager signals
	clubhouse_upgrade_manager.flippy_level_changed.connect(_on_flippy_level_changed)
	clubhouse_upgrade_manager.looty_changed.connect(_on_looty_changed)
	
	# Connect background click to close
	$Background.gui_input.connect(_on_background_clicked)

func show_dialog():
	"""Show the ClubHouse upgrade dialog"""
	visible = true
	update_display()
	flippy_upgrade_button.grab_focus()

func hide_dialog():
	"""Hide the ClubHouse upgrade dialog"""
	visible = false

func update_display():
	"""Update all display elements"""
	if not clubhouse_upgrade_manager:
		return
	
	# Update Flippy level and cost
	var flippy_level = clubhouse_upgrade_manager.get_flippy_level()
	var flippy_cost = clubhouse_upgrade_manager.get_flippy_upgrade_cost()
	var can_upgrade = clubhouse_upgrade_manager.can_upgrade_flippy()
	
	if flippy_level_label and is_instance_valid(flippy_level_label):
		flippy_level_label.text = "Flippy Level: " + str(flippy_level)
	
	if flippy_cost_label and is_instance_valid(flippy_cost_label):
		flippy_cost_label.text = "Cost: " + str(flippy_cost) + " $Looty"
	
	# Update button state
	if flippy_upgrade_button and is_instance_valid(flippy_upgrade_button):
		flippy_upgrade_button.disabled = not can_upgrade
		if flippy_level >= 6:
			flippy_upgrade_button.text = "Flippy Max Level"
			if flippy_cost_label and is_instance_valid(flippy_cost_label):
				flippy_cost_label.text = "Max Level Reached"
		else:
			flippy_upgrade_button.text = "Upgrade Flippy"
	
	# Update Golfsmith shop upgrade state
	var save_file_manager = get_node("/root/SaveFileManager")
	if save_file_manager:
		var story = save_file_manager.current_save_data.get("story_progression", {})
		var npc_quests = story.get("npc_quests", {})
		var gs = npc_quests.get("golfsmith", {})
		var already_unlocked: bool = bool(gs.get("shop", false))
		if golfsmith_upgrade_button and is_instance_valid(golfsmith_upgrade_button):
			golfsmith_upgrade_button.disabled = already_unlocked or clubhouse_upgrade_manager.get_clubhouse_looty() < 250
			golfsmith_upgrade_button.text = "Golfsmith Hired" if already_unlocked else "Hire Golfsmith for Shop"
		if golfsmith_cost_label and is_instance_valid(golfsmith_cost_label):
			golfsmith_cost_label.text = "Cost: 250 $Looty" if not already_unlocked else "Unlocked"

	# Update ClubHouse Looty display
	var clubhouse_looty = clubhouse_upgrade_manager.get_clubhouse_looty()
	if clubhouse_looty_label and is_instance_valid(clubhouse_looty_label):
		clubhouse_looty_label.text = "ClubHouse $Looty: " + str(clubhouse_looty)

func _on_flippy_upgrade_pressed():
	"""Handle Flippy upgrade button press"""
	if not clubhouse_upgrade_manager:
		return
	
	if clubhouse_upgrade_manager.upgrade_flippy():
		# Play upgrade sound or effect
		print("Flippy upgraded successfully!")
		update_display()
		upgrade_completed.emit()
	else:
		print("Failed to upgrade Flippy")

func _on_golfsmith_upgrade_pressed():
	"""Handle Golfsmith shop upgrade purchase"""
	var clubhouse_upgrade_manager = get_node("/root/ClubHouseUpgradeManager")
	var save_file_manager = get_node("/root/SaveFileManager")
	if not clubhouse_upgrade_manager or not save_file_manager:
		return
	# Cost 250 $Looty from ClubHouse wallet
	if clubhouse_upgrade_manager.spend_clubhouse_looty(250):
		# Set shop flag
		var story = save_file_manager.current_save_data.get("story_progression", {})
		var npc_quests = story.get("npc_quests", {})
		if not npc_quests.has("golfsmith"):
			npc_quests["golfsmith"] = {"appear": false, "shop": false, "quest_completed": false, "quest_progress": 0}
		npc_quests["golfsmith"]["shop"] = true
		story["npc_quests"] = npc_quests
		save_file_manager.current_save_data["story_progression"] = story
		save_file_manager.save_current_game()
		print("✅ Golfsmith shop unlocked for 250 $Looty")
		update_display()

func _on_close_pressed():
	"""Handle close button press"""
	hide_dialog()
	dialog_closed.emit()

func _on_background_clicked(event: InputEvent):
	"""Handle background click to close dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_dialog()
		dialog_closed.emit()

func _on_flippy_level_changed(new_level: int):
	"""Handle Flippy level change"""
	update_display()

func _on_looty_changed(new_amount: int):
	"""Handle Looty amount change"""
	update_display()
