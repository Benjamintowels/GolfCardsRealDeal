extends Node2D
#if needed

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var mouse_area: Area2D = $MouseDetectionArea2D
@onready var sprite_left: Sprite2D = $TreeLineVertSpriteLeft
@onready var sprite_left2: Sprite2D = $TreeLineVertSpriteLeft2

var is_hovering = false
var tween: Tween

func _ready():
	mouse_area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	mouse_area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func _on_mouse_entered():
	if not is_hovering:
		is_hovering = true
		# Stop any existing tween
		if tween:
			tween.kill()
		
		# Create new tween for fade out
		tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_left, "modulate", Color(1, 1, 1, 0.254902), 1.5)
		tween.tween_property(sprite_left2, "modulate", Color(1, 1, 1, 0.254902), 1.5)

func _on_mouse_exited():
	if is_hovering:
		is_hovering = false
		# Stop any existing tween
		if tween:
			tween.kill()
		
		# Create new tween for fade in
		tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_left, "modulate", Color(1, 1, 1, 1), 1.5)
		tween.tween_property(sprite_left2, "modulate", Color(1, 1, 1, 1), 1.5)
