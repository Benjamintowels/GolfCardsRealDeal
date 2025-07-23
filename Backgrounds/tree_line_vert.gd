extends Node2D
#if needed

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var mouse_area: Area2D = $MouseDetectionArea2D

func _ready():
	mouse_area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	mouse_area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func _on_mouse_entered():
	anim_player.speed_scale = 1.0
	anim_player.play("hover_fade")

func _on_mouse_exited():
	# Play in reverse from current position
	var pos = anim_player.current_animation_position
	anim_player.speed_scale = -1.0
	anim_player.play("hover_fade")
	anim_player.seek(pos, true)
