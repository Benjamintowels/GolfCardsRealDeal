extends Control

signal perk_selected(perk_type: String)
signal dialog_closed

@onready var perk_button_1 = $DialogContainer/PerkButtons/PerkButton1
@onready var perk_button_2 = $DialogContainer/PerkButtons/PerkButton2
@onready var perk_button_3 = $DialogContainer/PerkButtons/PerkButton3
@onready var cancel_button = $DialogContainer/CancelButton
@onready var flippy_speech_bubble = $FlippySpeechBubble

var available_perks = [
	"start_with_200_looty",
	"upgrade_card",
	"random_rare_action",
	"random_equipment", 
	"random_club_card",
	"receive_bounty"
]

var perk_descriptions = {
	"start_with_200_looty": "Start with 200 extra $Looty",
	"upgrade_card": "Upgrade a card in your deck",
	"random_rare_action": "Receive a random rare action card",
	"random_equipment": "Receive a random equipment",
	"random_club_card": "Receive a random club card", 
	"receive_bounty": "Receive a bounty (placeholder)"
}

var start_round_phrases = [
	"But before you go...",
	"Its dangerous to go alone...",
	"Take a perk on me",
	"One of these might be what you're missing",
	"That looked rough last time",
	"I'm not saying you need it..."
]

var selected_perks = []

func _ready():
	# Hide dialog initially
	visible = false
	print("PerkSelectionDialog: _ready() called, dialog hidden")
	
	# Connect button signals
	perk_button_1.pressed.connect(_on_perk_1_selected)
	perk_button_2.pressed.connect(_on_perk_2_selected)
	perk_button_3.pressed.connect(_on_perk_3_selected)
	cancel_button.pressed.connect(_on_cancel_pressed)
	print("PerkSelectionDialog: Button signals connected")
	
	# Connect background click to close
	$Background.gui_input.connect(_on_background_clicked)
	print("PerkSelectionDialog: Background click connected")

func show_dialog():
	"""Show the perk selection dialog"""
	print("PerkSelectionDialog: show_dialog() called")
	visible = true
	
	# Generate random perks
	_generate_random_perks()
	
	# Show random Flippy speech bubble
	_show_flippy_speech()
	
	print("PerkSelectionDialog: Dialog made visible")
	# Focus the first button for keyboard navigation
	perk_button_1.grab_focus()
	print("PerkSelectionDialog: Focus set to first perk button")

func hide_dialog():
	"""Hide the perk selection dialog"""
	visible = false
	flippy_speech_bubble.visible = false

func _generate_random_perks():
	"""Generate 3 random perks for selection"""
	selected_perks.clear()
	var shuffled_perks = available_perks.duplicate()
	shuffled_perks.shuffle()
	
	# Take first 3 perks
	for i in range(min(3, shuffled_perks.size())):
		selected_perks.append(shuffled_perks[i])
	
	# Update button texts
	if selected_perks.size() >= 1:
		perk_button_1.text = perk_descriptions[selected_perks[0]]
		perk_button_1.visible = true
	else:
		perk_button_1.visible = false
		
	if selected_perks.size() >= 2:
		perk_button_2.text = perk_descriptions[selected_perks[1]]
		perk_button_2.visible = true
	else:
		perk_button_2.visible = false
		
	if selected_perks.size() >= 3:
		perk_button_3.text = perk_descriptions[selected_perks[2]]
		perk_button_3.visible = true
	else:
		perk_button_3.visible = false

func _show_flippy_speech():
	"""Show Flippy's speech bubble with random phrase"""
	if flippy_speech_bubble:
		flippy_speech_bubble.visible = true
		var random_phrase = start_round_phrases[randi() % start_round_phrases.size()]
		flippy_speech_bubble.set_text(random_phrase)
		print("Flippy says: ", random_phrase)
		
		# Animate Flippy talking when speech bubble appears
		_animate_flippy_talking()

func _animate_flippy_talking():
	"""Animate Flippy talking when speech bubble appears"""
	var main_scene = get_parent()
	if main_scene:
		var flippy = main_scene.get_node_or_null("FlippyTheDolphin")
		if flippy:
			# Get the FlippySprite (AnimatedSprite2D)
			var sprite = flippy.get_node_or_null("FlippySprite")
			if sprite and sprite is AnimatedSprite2D:
				# Store original frame
				var original_frame = sprite.frame
				
				# Play talking animation (frame 1 or 2 randomly)
				var talking_frame = randi() % 2 + 1  # Randomly choose frame 1 or 2 (which are frames 2 and 3 in 0-based indexing)
				sprite.frame = talking_frame
				
				# Play random talking sound
				var talk_sounds = ["talk1", "talk2", "talk3"]
				var random_sound = talk_sounds[randi() % talk_sounds.size()]
				var audio_player = flippy.get_node_or_null(random_sound)
				if audio_player and audio_player is AudioStreamPlayer2D:
					audio_player.play()
				
				# Return to default frame after a short delay
				await get_tree().create_timer(0.3).timeout
				sprite.frame = 0  # Return to default pose (frame 0)
			else:
				print("No FlippySprite found or not AnimatedSprite2D")
		else:
			print("No FlippyTheDolphin found in main scene")
	else:
		print("No main scene found")

func _on_perk_1_selected():
	"""Handle first perk selection"""
	if selected_perks.size() >= 1:
		print("Perk 1 selected: ", selected_perks[0])
		emit_signal("perk_selected", selected_perks[0])
		hide_dialog()

func _on_perk_2_selected():
	"""Handle second perk selection"""
	if selected_perks.size() >= 2:
		print("Perk 2 selected: ", selected_perks[1])
		emit_signal("perk_selected", selected_perks[1])
		hide_dialog()

func _on_perk_3_selected():
	"""Handle third perk selection"""
	if selected_perks.size() >= 3:
		print("Perk 3 selected: ", selected_perks[2])
		emit_signal("perk_selected", selected_perks[2])
		hide_dialog()

func _on_cancel_pressed():
	"""Handle cancel button press"""
	print("Perk selection cancelled")
	emit_signal("dialog_closed")
	hide_dialog()

func _on_background_clicked(event):
	"""Handle background click to close dialog"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_pressed() 