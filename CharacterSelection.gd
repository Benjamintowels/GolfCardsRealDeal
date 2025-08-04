extends Control

signal character_selected(character_id: int)

@onready var layla_button = $VBoxContainer/HBoxContainer/LaylaButton
@onready var benny_button = $VBoxContainer/HBoxContainer/BennyButton
@onready var clark_button = $VBoxContainer/HBoxContainer/ClarkButton
@onready var back_button = $VBoxContainer/BackButton

var save_file_manager: Node

func _ready():
	save_file_manager = get_node("/root/SaveFileManager")
	
	layla_button.pressed.connect(_on_layla_selected)
	benny_button.pressed.connect(_on_benny_selected)
	clark_button.pressed.connect(_on_clark_selected)
	back_button.pressed.connect(_on_back_pressed)
	
	# Set up character info
	setup_character_info()
	
	# Initially hide this component
	visible = false

func setup_character_info():
	"""Set up character button information"""
	layla_button.text = "Layla\nMobility: 3\nStrength: -1\nHP: 125\nSpeed Demon"
	benny_button.text = "Benny\nMobility: 2\nStrength: 0\nHP: 150\nBalanced"
	clark_button.text = "Clark\nMobility: 1\nStrength: 2\nHP: 200\nPowerhouse"

func _on_layla_selected():
	emit_signal("character_selected", 1)

func _on_benny_selected():
	emit_signal("character_selected", 2)

func _on_clark_selected():
	emit_signal("character_selected", 3)

func _on_back_pressed():
	visible = false

func reset_selection():
	"""Reset character selection and show the component"""
	visible = true
	# Reset button states if needed
	pass 
