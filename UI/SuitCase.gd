extends Control

signal suitcase_opened

@onready var closed_sprite: Sprite2D = $Closed
@onready var open_sprite: Sprite2D = $Open

func _ready():
	print("SuitCase script loaded and ready")
	
	# Make sure the closed sprite is visible and open sprite is hidden
	closed_sprite.visible = true
	open_sprite.visible = false
	
	# Connect the control's gui_input signal
	gui_input.connect(_on_gui_input)
	
	print("SuitCase GUI input connected")

func _on_gui_input(event: InputEvent):
	print("SuitCase GUI input received:", event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("SuitCase clicked! Opening...")
		open_suitcase()

func open_suitcase():
	print("Suitcase opened!")
	closed_sprite.visible = false
	open_sprite.visible = true
	suitcase_opened.emit() 
