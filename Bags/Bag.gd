extends Control
class_name Bag

signal bag_clicked

@onready var texture_rect: TextureRect = $TextureRect

var bag_level: int = 1
var character_name: String = "Benny"  # Default character

# Character-specific bag textures
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
	# Set up the bag texture based on character and level
	set_bag_level(bag_level)
	
	# Make the bag clickable
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_bag_input_event)

func set_character(character: String):
	character_name = character
	set_bag_level(bag_level)  # Update texture with new character

func set_bag_level(level: int):
	bag_level = level
	if character_bag_textures.has(character_name) and character_bag_textures[character_name].has(level):
		texture_rect.texture = character_bag_textures[character_name][level]

func _on_bag_input_event(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		bag_clicked.emit() 
