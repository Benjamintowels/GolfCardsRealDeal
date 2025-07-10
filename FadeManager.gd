extends CanvasLayer

var fade_rect: ColorRect
var fade_time := 0.5
var is_fading := false
var is_black := false  # Track if screen is currently black

# Signals for coordinating with other systems
signal fade_to_black_complete
signal fade_from_black_complete

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
	is_black = true
	is_fading = false
	fade_to_black_complete.emit()
	if callback:
		callback.call()

func fade_from_black(duration: float = -1.0):
	if is_fading:
		return
	is_fading = true
	var t = fade_time if duration < 0 else duration
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, t)
	tween.tween_callback(Callable(self, "_on_fade_out_complete"))

func _on_fade_out_complete():
	is_black = false
	is_fading = false
	fade_from_black_complete.emit()

# New methods for round management
func start_round_black_screen():
	"""Start with a black screen for round initialization"""
	fade_rect.modulate.a = 1.0
	is_black = true
	is_fading = false
	print("✓ Round started with black screen")

func stay_black():
	"""Keep the screen black (no fade)"""
	fade_rect.modulate.a = 1.0
	is_black = true
	is_fading = false
	print("✓ Screen kept black")

func fade_from_black_when_ready():
	"""Fade from black when map building and parallax effects are complete"""
	if is_black and not is_fading:
		fade_from_black(1.0)  # 1 second fade
		print("✓ Fading from black - round ready")

func is_screen_black() -> bool:
	"""Check if the screen is currently black"""
	return is_black

func is_currently_fading() -> bool:
	"""Check if a fade is currently in progress"""
	return is_fading 
