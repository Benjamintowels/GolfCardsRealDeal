extends Control

signal suitcase_opened

@onready var closed_sprite: Sprite2D = $Closed
@onready var open_sprite: Sprite2D = $Open

func _ready():
	# Make sure the closed sprite is visible and open sprite is hidden
	closed_sprite.visible = true
	open_sprite.visible = false
	
	# Connect the control's gui_input signal
	gui_input.connect(_on_gui_input)
	
	# Load suitcase opening sound
	var suitcase_sound = AudioStreamPlayer.new()
	suitcase_sound.name = "SuitcaseSound"
	suitcase_sound.stream = preload("res://Sounds/Suitcase.mp3")
	suitcase_sound.volume_db = -8.0  # Lower volume by -8 dB
	add_child(suitcase_sound)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_suitcase()

func open_suitcase():
	# Play suitcase opening sound
	var suitcase_sound = get_node_or_null("SuitcaseSound")
	if suitcase_sound:
		suitcase_sound.play()
	
	closed_sprite.visible = false
	open_sprite.visible = true
	suitcase_opened.emit() 
