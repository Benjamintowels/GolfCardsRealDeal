extends Node2D

var stall_time := 0.05
var drop_speed := 200.0
var is_dropping := false
var fade_time := 0.3
var fade_timer := 0.0
var sprite: Sprite2D = null

func _ready():
	sprite = get_node_or_null("FireParticleSprite")
	await get_tree().create_timer(stall_time).timeout
	is_dropping = true

func _process(delta):
	if is_dropping:
		if drop_speed > 0.0:
			position.y += drop_speed * delta
		if sprite:
			fade_timer += delta
			var alpha = 1.0 - (fade_timer / fade_time)
			alpha = clamp(alpha, 0.0, 1.0)
			sprite.modulate.a = alpha
			if alpha <= 0.0:
				queue_free()
		else:
			# Fallback: just queue_free after fade_time
			fade_timer += delta
			if fade_timer >= fade_time:
				queue_free()
