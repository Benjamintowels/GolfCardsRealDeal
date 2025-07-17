extends Control

signal puzzle_type_selected(puzzle_type: String)

@onready var background: ColorRect = $Background
@onready var title_label: Label = $DialogContainer/TitleLabel
@onready var description_label: Label = $DialogContainer/DescriptionLabel
@onready var left_button: TextureButton = $DialogContainer/ButtonContainer/LeftButton
@onready var right_button: TextureButton = $DialogContainer/ButtonContainer/RightButton
@onready var left_symbol: TextureRect = $DialogContainer/ButtonContainer/LeftButton/Symbol
@onready var right_symbol: TextureRect = $DialogContainer/ButtonContainer/RightButton/Symbol
@onready var left_label: Label = $DialogContainer/ButtonContainer/LeftButton/Label
@onready var right_label: Label = $DialogContainer/ButtonContainer/RightButton/Label

# Puzzle type definitions
var puzzle_types = {
	"score": {
		"name": "Score Challenge",
		"description": "Traditional golf scoring - only squirrels spawn",
		"symbol_scene": preload("res://UI/PuzzleSymbols/ScoreSymbol.tscn")
	},
	"generator": {
		"name": "Generator Puzzle", 
		"description": "Hit the generator switch to deactivate force fields",
		"symbol_scene": preload("res://UI/PuzzleSymbols/GeneratorSymbol.tscn")
	},
	"mob": {
		"name": "Mob Encounter",
		"description": "Double the normal NPCs based on difficulty tier",
		"symbol_scene": preload("res://UI/PuzzleSymbols/MobSymbol.tscn")
	},
	"miniboss": {
		"name": "MiniBoss Battle",
		"description": "Face a Wraith boss with force field dome protection",
		"symbol_scene": preload("res://UI/PuzzleSymbols/MinibossSymbol.tscn")
	}
}

var available_puzzle_types: Array = []
var selected_left_type: String = ""
var selected_right_type: String = ""

func _ready():
	# Hide dialog initially
	visible = false
	
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Connect button signals when they're available
	if left_button:
		left_button.pressed.connect(_on_left_button_pressed)
		print("🎯 PUZZLE SELECTION: Left button connected")
	else:
		print("🎯 PUZZLE SELECTION: ERROR - Left button not found!")
		
	if right_button:
		right_button.pressed.connect(_on_right_button_pressed)
		print("🎯 PUZZLE SELECTION: Right button connected")
	else:
		print("🎯 PUZZLE SELECTION: ERROR - Right button not found!")

func show_puzzle_selection():
	"""Show the puzzle type selection dialog with 2 random puzzle types"""
	
	print("🎯 PUZZLE SELECTION: show_puzzle_selection() called")
	
	# Safety check for required nodes
	if not title_label:
		print("🎯 PUZZLE SELECTION: ERROR - title_label not found!")
		return
	if not description_label:
		print("🎯 PUZZLE SELECTION: ERROR - description_label not found!")
		return
	if not left_label:
		print("🎯 PUZZLE SELECTION: ERROR - left_label not found!")
		return
	if not right_label:
		print("🎯 PUZZLE SELECTION: ERROR - right_label not found!")
		return
	if not left_symbol:
		print("🎯 PUZZLE SELECTION: ERROR - left_symbol not found!")
		return
	if not right_symbol:
		print("🎯 PUZZLE SELECTION: ERROR - right_symbol not found!")
		return
	if not left_button:
		print("🎯 PUZZLE SELECTION: ERROR - left_button not found!")
		return
	if not right_button:
		print("🎯 PUZZLE SELECTION: ERROR - right_button not found!")
		return
	
	print("🎯 PUZZLE SELECTION: All required nodes found")
	
	# Get all available puzzle types
	available_puzzle_types = puzzle_types.keys()
	print("🎯 PUZZLE SELECTION: Available puzzle types:", available_puzzle_types)
	
	# Randomly select 2 different puzzle types
	available_puzzle_types.shuffle()
	selected_left_type = available_puzzle_types[0]
	selected_right_type = available_puzzle_types[1]
	
	print("🎯 PUZZLE SELECTION: Selected types - Left:", selected_left_type, "Right:", selected_right_type)
	
	# Set up the dialog
	title_label.text = "Choose Next Hole's Puzzle Type"
	description_label.text = "Select which type of challenge you want for the next hole:"
	
	# Set up left button
	var left_puzzle = puzzle_types[selected_left_type]
	left_label.text = left_puzzle.name
	print("🎯 PUZZLE SELECTION: Left label set to:", left_puzzle.name)
	
	# Load left symbol
	if left_puzzle.symbol_scene:
		var symbol_instance = left_puzzle.symbol_scene.instantiate()
		# Look for the Sprite2D node (it might be named after the symbol type)
		var sprite_node = null
		if symbol_instance.has_node("Sprite2D"):
			sprite_node = symbol_instance.get_node("Sprite2D")
		elif symbol_instance.has_node("ScoreSymbol"):
			sprite_node = symbol_instance.get_node("ScoreSymbol")
		elif symbol_instance.has_node("GeneratorSymbol"):
			sprite_node = symbol_instance.get_node("GeneratorSymbol")
		elif symbol_instance.has_node("MobSymbol"):
			sprite_node = symbol_instance.get_node("MobSymbol")
		elif symbol_instance.has_node("MinibossSymbol"):
			sprite_node = symbol_instance.get_node("MinibossSymbol")
		
		if sprite_node and sprite_node.texture:
			left_symbol.texture = sprite_node.texture
			print("🎯 PUZZLE SELECTION: Left symbol loaded - texture size:", sprite_node.texture.get_size())
		else:
			print("🎯 PUZZLE SELECTION: ERROR - Left symbol has no valid sprite node or texture!")
		symbol_instance.queue_free()
	else:
		print("🎯 PUZZLE SELECTION: ERROR - Left puzzle has no symbol_scene!")
	
	# Set up right button
	var right_puzzle = puzzle_types[selected_right_type]
	right_label.text = right_puzzle.name
	print("🎯 PUZZLE SELECTION: Right label set to:", right_puzzle.name)
	
	# Load right symbol
	if right_puzzle.symbol_scene:
		var symbol_instance = right_puzzle.symbol_scene.instantiate()
		# Look for the Sprite2D node (it might be named after the symbol type)
		var sprite_node = null
		if symbol_instance.has_node("Sprite2D"):
			sprite_node = symbol_instance.get_node("Sprite2D")
		elif symbol_instance.has_node("ScoreSymbol"):
			sprite_node = symbol_instance.get_node("ScoreSymbol")
		elif symbol_instance.has_node("GeneratorSymbol"):
			sprite_node = symbol_instance.get_node("GeneratorSymbol")
		elif symbol_instance.has_node("MobSymbol"):
			sprite_node = symbol_instance.get_node("MobSymbol")
		elif symbol_instance.has_node("MinibossSymbol"):
			sprite_node = symbol_instance.get_node("MinibossSymbol")
		
		if sprite_node and sprite_node.texture:
			right_symbol.texture = sprite_node.texture
			print("🎯 PUZZLE SELECTION: Right symbol loaded - texture size:", sprite_node.texture.get_size())
		else:
			print("🎯 PUZZLE SELECTION: ERROR - Right symbol has no valid sprite node or texture!")
		symbol_instance.queue_free()
	else:
		print("🎯 PUZZLE SELECTION: ERROR - Right puzzle has no symbol_scene!")
	
	# Ensure buttons are enabled and clickable
	left_button.disabled = false
	right_button.disabled = false
	left_button.mouse_filter = Control.MOUSE_FILTER_STOP
	right_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	print("🎯 PUZZLE SELECTION: Buttons enabled and clickable")
	
	# Show the dialog
	visible = true
	
	print("🎯 PUZZLE SELECTION: Dialog made visible")
	print("🎯 PUZZLE SELECTION: Showing options - Left:", selected_left_type, "Right:", selected_right_type)

func _on_left_button_pressed():
	"""Handle left button press"""
	if selected_left_type.is_empty():
		print("🎯 PUZZLE SELECTION: ERROR - No left type selected!")
		return
	print("🎯 PUZZLE SELECTION: Left button pressed - Selected:", selected_left_type)
	puzzle_type_selected.emit(selected_left_type)
	visible = false

func _on_right_button_pressed():
	"""Handle right button press"""
	if selected_right_type.is_empty():
		print("🎯 PUZZLE SELECTION: ERROR - No right type selected!")
		return
	print("🎯 PUZZLE SELECTION: Right button pressed - Selected:", selected_right_type)
	puzzle_type_selected.emit(selected_right_type)
	visible = false

func get_puzzle_description(puzzle_type: String) -> String:
	"""Get the description for a puzzle type"""
	if puzzle_types.has(puzzle_type):
		return puzzle_types[puzzle_type].description
	return "Unknown puzzle type" 
