extends Node2D

func _ready():
	print("=== DEBUG OUTPUT TEST ===")
	print("This is a test of debug output")
	print("If you see this, debug output is working")
	print("=== END DEBUG TEST ===")
	
	# Quit after a short delay
	get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit()) 