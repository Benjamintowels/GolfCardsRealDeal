extends Node2D

@onready var info_label: Label = $InfoLabel

# Animation properties
var is_animating: bool = false
var target_position: Vector2
var start_position: Vector2
var animation_duration: float = 0.3

# Hover management
var hover_delay_timer: Timer
var is_hovering: bool = false
var hover_delay: float = 1.5

func _ready():
	# Hide the infobox by default
	hide()
	# Position at bottom center of screen, off-screen initially
	position = Vector2(get_viewport().size.x / 2, get_viewport().size.y + 100)
	
	# Create hover delay timer
	hover_delay_timer = Timer.new()
	hover_delay_timer.wait_time = hover_delay
	hover_delay_timer.one_shot = true
	hover_delay_timer.timeout.connect(_on_hover_delay_timeout)
	add_child(hover_delay_timer)

func show_info(text: String):
	"""Show the infobox with the specified text and animate it up from bottom"""
	info_label.text = text
	
	# If this is the first hover (infobox not visible), animate it up
	if not visible:
		# Set target position (bottom center, just above where cards are displayed)
		target_position = Vector2(get_viewport().size.x / 2, get_viewport().size.y - 150)
		start_position = Vector2(get_viewport().size.x / 2, get_viewport().size.y + 100)
		
		# Start position (off-screen)
		position = start_position
		show()
		
		# Animate to target position
		animate_to_position(target_position)
	else:
		# If already visible, just update the text without animation
		info_label.text = text
	
	# Mark as hovering and stop any pending hide timer
	is_hovering = true
	if hover_delay_timer.time_left > 0:
		hover_delay_timer.stop()

func hide_info():
	"""Start the hover delay timer - InfoBox will hide after delay if no new hover occurs"""
	if not visible:
		return
	
	is_hovering = false
	
	# Start the delay timer
	hover_delay_timer.start()

func _on_hover_delay_timeout():
	"""Called when the hover delay timer expires - actually hide the infobox"""
	if not is_hovering and visible:
		# Animate back to off-screen position
		animate_to_position(start_position)
		
		# Hide after animation completes
		var tween = create_tween()
		tween.tween_callback(hide).set_delay(animation_duration)

func update_text(text: String):
	"""Update the text without showing/hiding the infobox"""
	info_label.text = text

func is_infobox_visible() -> bool:
	"""Check if the infobox is currently visible"""
	return visible

func animate_to_position(target_pos: Vector2):
	"""Animate the infobox to a specific position"""
	if is_animating:
		return
		
	is_animating = true
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, animation_duration)
	tween.tween_callback(func(): is_animating = false)

func _notification(what):
	"""Handle viewport size changes"""
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		# Update positions when viewport size changes
		if visible:
			target_position = Vector2(get_viewport().size.x / 2, get_viewport().size.y - 150)
			start_position = Vector2(get_viewport().size.x / 2, get_viewport().size.y + 100) 
