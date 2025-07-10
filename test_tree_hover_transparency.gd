extends Node2D

func _ready():
	print("=== TREE HOVER TRANSPARENCY TEST ===")
	print("Move your mouse over the tree to see transparency effect")
	print("The tree should become transparent (40% opacity) when hovered")
	print("and return to full opacity when mouse leaves")
	print("Check the console for debug output from the tree")
	print("=== END TEST INFO ===")
	
	# Add a simple instruction label
	var instruction_label = Label.new()
	instruction_label.text = "Hover over the tree to test transparency effect"
	instruction_label.position = Vector2(10, 10)
	instruction_label.add_theme_font_size_override("font_size", 16)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(instruction_label) 