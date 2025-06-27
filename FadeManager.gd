extends CanvasLayer

var fade_rect: ColorRect
var fade_time := 0.5
var is_fading := false

func _ready():
	# Set the layer to be on top of everything
	layer = 128  # Highest layer value
	
	# Create and configure the fade rect
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate.a = 0.0
	fade_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fade_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fade_rect.anchor_left = 0
	fade_rect.anchor_top = 0
	fade_rect.anchor_right = 1
	fade_rect.anchor_bottom = 1
	fade_rect.z_index = 9999
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	add_child(fade_rect)
	set_process(false)

func fade_to_black(callback: Variant = null, duration: float = -1.0):
	if is_fading:
		return
	is_fading = true
	var t = fade_time if duration < 0 else duration
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, t)
	tween.tween_callback(Callable(self, "_on_fade_in_complete").bind(callback))

func _on_fade_in_complete(callback):
	if callback:
		callback.call()
	fade_from_black()

func fade_from_black(duration: float = -1.0):
	var t = fade_time if duration < 0 else duration
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, t)
	tween.tween_callback(Callable(self, "_on_fade_out_complete"))

func _on_fade_out_complete():
	is_fading = false 
