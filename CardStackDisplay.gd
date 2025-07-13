# This is a sample GDScript for animating a card stack for draw/discard piles.
# You can plug this into a Control or Node2D scene called CardStackDisplay.tscn

extends Control

@onready var stack_root := $StackRoot
@onready var draw_stack := stack_root.get_node("DrawStack")
@onready var discard_stack := stack_root.get_node("DiscardStack")
@onready var card_scene := preload("res://CardVisual.tscn")
@onready var card_draw_sound: AudioStreamPlayer2D = $CardDraw

func _ready():
	# Set mouse filter to ignore since this is just a visual display
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set a very low z_index to ensure it doesn't interfere with grid tiles
	z_index = -1000
	
	# Also set StackRoot to ignore mouse to prevent blocking clicks
	if stack_root:
		stack_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set all child nodes to ignore mouse to prevent any blocking
	_set_all_children_mouse_filter_ignore(self)
	
	print("CardStackDisplay: Set mouse_filter=IGNORE and z_index=-1000")

func _set_all_children_mouse_filter_ignore(node: Node):
	"""Recursively set all Control children to ignore mouse"""
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Recursively set children of children
		_set_all_children_mouse_filter_ignore(child)


func update_draw_stack(count: int) -> void:
	clear_stack(draw_stack)
	for i in range(min(count, 5)):
		var card := card_scene.instantiate()
		card.position = Vector2(0, -i * 2)
		card.modulate = Color(1, 1, 1, 0.3 + 0.15 * i)
		# Hide the label on stack cards
		if card.has_node("Label"):
			card.get_node("Label").visible = false
		draw_stack.add_child(card)

func update_discard_stack(count: int) -> void:
	clear_stack(discard_stack)
	for i in range(min(count, 5)):
		var card := card_scene.instantiate()
		card.position = Vector2(0, -i * 2)
		card.modulate = Color(0.7, 0.3, 0.3, 0.3 + 0.15 * i)
		# Hide the label on stack cards
		if card.has_node("Label"):
			card.get_node("Label").visible = false
		discard_stack.add_child(card)

func animate_card_discard(card_label: String) -> void:
	var card := card_scene.instantiate()
	# Hide the label on animated cards
	if card.has_node("Label"):
		card.get_node("Label").visible = false
	card.position = draw_stack.global_position
	add_child(card)
	
	var tween := create_tween()
	tween.tween_property(card, "position", discard_stack.global_position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(card, "queue_free"))

func clear_stack(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()
		


func animate_card_recycle(count: int) -> void:
	var cards_to_animate: int = min(count, 5)
	if has_node("ShuffleSound"):
		$ShuffleSound.play()
		
	for i in range(cards_to_animate):
		var card: Control = card_scene.instantiate()
		# Hide the label on animated cards
		if card.has_node("Label"):
			card.get_node("Label").visible = false
		card.position = discard_stack.global_position
		add_child(card)
		card.move_to_front()

		var delay: float = randf_range(0.05, 0.3)
		var offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-5, 5))

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(card, "position", draw_stack.global_position + offset, 0.6).set_delay(delay)
		tween.tween_callback(Callable(card, "queue_free")).set_delay(delay + 0.6)
