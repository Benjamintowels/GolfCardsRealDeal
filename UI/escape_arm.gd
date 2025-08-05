extends Node2D

#use for animating a character arm appearing in screen to display the escape key dialog for quitting round or game

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var screen_animation_player: AnimationPlayer = $ScreenAnimationPlayer
@onready var dialog_placement: Node2D = $DialogPlacement
@onready var escape_dialog: Control = $DialogPlacement/EscapeDialog
@onready var end_round_button: Button = $DialogPlacement/EscapeDialog/ButtonContainer/EndRoundButton
@onready var quit_game_button: Button = $DialogPlacement/EscapeDialog/ButtonContainer/QuitGameButton
@onready var cancel_button: Button = $DialogPlacement/EscapeDialog/ButtonContainer/CancelButton

var is_escape_menu_open: bool = false

func _ready():
	# Connect animation finished signals
	animation_player.animation_finished.connect(_on_arm_animation_finished)
	screen_animation_player.animation_finished.connect(_on_screen_animation_finished)
	
	# Connect button signals
	end_round_button.pressed.connect(_on_end_round_pressed)
	quit_game_button.pressed.connect(_on_quit_game_pressed)
	cancel_button.pressed.connect(close_escape_menu)
	
	# Start in hidden state (RESET animation)
	animation_player.play("RESET")

func _input(event):
	# Only handle input when escape menu is open
	if not is_escape_menu_open:
		return
		
	# Handle escape key or right click to close menu
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or \
	   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		close_escape_menu()

func show_escape_menu():
	"""Show the escape menu by animating the arm up"""
	if is_escape_menu_open:
		return
		
	print("Showing escape menu")
	is_escape_menu_open = true
	
	# Reset dialog modulate to invisible so screen_on animation can fade it in
	escape_dialog.modulate = Color(1, 1, 1, 0)
	escape_dialog.visible = true  # Make sure dialog is visible
	print("Reset dialog modulate to alpha 0 and made dialog visible")
	
	animation_player.play("escape_arm")
	
	# Switch Benny character to escape sprite
	var course = get_tree().current_scene
	if course and course.has_method("get_player_manager"):
		var player_manager = course.get_player_manager()
		if player_manager and player_manager.has_method("switch_to_escape_sprite"):
			player_manager.switch_to_escape_sprite()

func close_escape_menu():
	"""Close the escape menu by hiding dialog and reversing animation"""
	if not is_escape_menu_open:
		return
		
	print("Closing escape menu")
	is_escape_menu_open = false
	
	# Play the screen_on animation in reverse to fade out the dialog
	print("Playing screen_on animation backwards")
	screen_animation_player.play_backwards("screen_on")
	
	# Play the animation in reverse (from end to start)
	animation_player.play_backwards("escape_arm")
	
	# Switch Benny character back to normal sprite
	var course = get_tree().current_scene
	if course and course.has_method("get_player_manager"):
		var player_manager = course.get_player_manager()
		if player_manager and player_manager.has_method("switch_from_escape_sprite"):
			player_manager.switch_from_escape_sprite()

func _on_arm_animation_finished(anim_name: String):
	"""Called when arm animation finishes"""
	print("Arm animation finished:", anim_name, "is_escape_menu_open:", is_escape_menu_open)
	if anim_name == "escape_arm" and is_escape_menu_open:
		# Arm animation finished, play screen_on animation to fade in dialog
		print("Playing screen_on animation")
		print("Dialog modulate before screen animation:", escape_dialog.modulate)
		screen_animation_player.play("screen_on")
	elif anim_name == "escape_arm" and not is_escape_menu_open:
		# Arm animation finished going back down, hide dialog
		print("Arm animation finished going back down")
		escape_dialog.visible = false

func _on_screen_animation_finished(anim_name: String):
	"""Called when screen animation finishes"""
	print("Screen animation finished:", anim_name, "is_escape_menu_open:", is_escape_menu_open)
	print("Dialog modulate after animation:", escape_dialog.modulate)
	print("Dialog visible property:", escape_dialog.visible)
	if anim_name == "screen_on" and is_escape_menu_open:
		# Screen_on animation finished, dialog is now visible
		print("Screen_on animation finished, dialog should be visible")
	elif anim_name == "screen_on" and not is_escape_menu_open:
		# Screen_on animation finished going backwards, dialog should be hidden
		print("Screen_on animation finished going backwards, dialog should be hidden")

func show_escape_dialog():
	"""Show the escape dialog on the iPod screen"""
	escape_dialog.visible = true

func _on_end_round_pressed():
	"""Handle End Round button press"""
	close_escape_menu()
	# Call the course's end round function
	var course = get_tree().current_scene
	if course.has_method("_on_end_round_pressed"):
		course._on_end_round_pressed()

func _on_quit_game_pressed():
	"""Handle Quit Game button press"""
	get_tree().quit()
