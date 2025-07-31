extends Node
class_name Pseudo3DEffect

# 3D Effect Configuration
const COURSE_Y_SCALE_TARGET: float = 0.25
const OBJECTS_Y_SCALE_TARGET: float = 3.63
const ANIMATION_DURATION: float = 1.5
const ANIMATION_TRANSITION: Tween.TransitionType = Tween.TRANS_SINE
const ANIMATION_EASE: Tween.EaseType = Tween.EASE_IN_OUT

# References
var course_node: Node = null
var animation_tween: Tween = null
var is_3d_effect_active: bool = false
var smart_optimizer: Node = null

# Object groups to scale
var object_groups: Array[String] = [
	"players",
	"trees", 
	"bushes",
	"grass_elements",
	"obstacles",
	"NPC",
	"balls"
]

# Store original scales for restoration
var original_course_scale: Vector2 = Vector2.ONE
var original_object_scales: Dictionary = {}

func _ready():
	# This script should be attached to the Course1 node
	course_node = get_parent()
	print("Pseudo3DEffect: Initialized for course node:", course_node.name if course_node else "null")
	
	# Find the smart optimizer to control Y-sorting
	smart_optimizer = course_node.get_node_or_null("SmartPerformanceOptimizer")
	if smart_optimizer:
		print("Pseudo3DEffect: Found SmartPerformanceOptimizer for Y-sort control")
	else:
		print("Pseudo3DEffect: Warning - SmartPerformanceOptimizer not found")

func trigger_3d_effect():
	"""Trigger the 3D flattening effect for hole completion"""
	if is_3d_effect_active:
		print("Pseudo3DEffect: 3D effect already active, skipping")
		return
	
	print("Pseudo3DEffect: Triggering 3D flattening effect")
	is_3d_effect_active = true
	
	# Disable Y-sorting updates during 3D effect
	disable_ysort_updates()
	
	# Store original course scale
	original_course_scale = course_node.scale
	
	# Store original scales of all objects
	store_original_object_scales()
	
	# Create animation tween
	create_3d_animation_tween()

func reverse_3d_effect():
	"""Reverse the 3D effect back to normal for next hole"""
	if not is_3d_effect_active:
		print("Pseudo3DEffect: 3D effect not active, skipping reverse")
		return
	
	print("Pseudo3DEffect: Reversing 3D effect back to normal")
	
	# Create reverse animation tween
	create_reverse_3d_animation_tween()

func instant_reverse_3d_effect():
	"""Instantly reverse the 3D effect without animation (for map clearing)"""
	if not is_3d_effect_active:
		print("Pseudo3DEffect: 3D effect not active, skipping instant reverse")
		return
	
	print("Pseudo3DEffect: Instantly reversing 3D effect")
	
	# Kill any existing animation
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()
		animation_tween = null
	
	# Instantly restore course scale
	course_node.scale = original_course_scale
	
	# Instantly restore all object scales
	for obj in original_object_scales.keys():
		if is_instance_valid(obj):
			var original_scale = original_object_scales[obj]
			obj.scale = original_scale
	
	# Reset state
	is_3d_effect_active = false
	original_object_scales.clear()
	
	# Re-enable Y-sorting updates
	enable_ysort_updates()
	
	print("Pseudo3DEffect: Instant reverse completed")

func store_original_object_scales():
	"""Store the original scale of all objects that need to be scaled"""
	original_object_scales.clear()
	
	for group_name in object_groups:
		var group_objects = get_tree().get_nodes_in_group(group_name)
		for obj in group_objects:
			if is_instance_valid(obj) and obj.has_method("get_scale"):
				original_object_scales[obj] = obj.scale
			elif is_instance_valid(obj) and "scale" in obj:
				original_object_scales[obj] = obj.scale
	
	print("Pseudo3DEffect: Stored original scales for", original_object_scales.size(), "objects")

func create_3d_animation_tween():
	"""Create the tween animation for the 3D flattening effect"""
	# Kill any existing tween
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()
	
	animation_tween = create_tween()
	animation_tween.set_trans(ANIMATION_TRANSITION)
	animation_tween.set_ease(ANIMATION_EASE)
	
	# Animate course node Y scale down
	var target_course_scale = Vector2(original_course_scale.x, original_course_scale.y * COURSE_Y_SCALE_TARGET)
	animation_tween.parallel().tween_property(course_node, "scale", target_course_scale, ANIMATION_DURATION)
	
	# Animate all objects Y scale up
	for obj in original_object_scales.keys():
		if is_instance_valid(obj):
			var original_scale = original_object_scales[obj]
			var target_scale = Vector2(original_scale.x, original_scale.y * OBJECTS_Y_SCALE_TARGET)
			animation_tween.parallel().tween_property(obj, "scale", target_scale, ANIMATION_DURATION)
	
	# Connect completion signal
	animation_tween.finished.connect(_on_3d_effect_complete)
	
	print("Pseudo3DEffect: Started 3D flattening animation")

func create_reverse_3d_animation_tween():
	"""Create the tween animation to reverse the 3D effect"""
	# Kill any existing tween
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()
	
	animation_tween = create_tween()
	animation_tween.set_trans(ANIMATION_TRANSITION)
	animation_tween.set_ease(ANIMATION_EASE)
	
	# Animate course node back to original scale
	animation_tween.parallel().tween_property(course_node, "scale", original_course_scale, ANIMATION_DURATION)
	
	# Animate all objects back to original scale
	for obj in original_object_scales.keys():
		if is_instance_valid(obj):
			var original_scale = original_object_scales[obj]
			animation_tween.parallel().tween_property(obj, "scale", original_scale, ANIMATION_DURATION)
	
	# Connect completion signal
	animation_tween.finished.connect(_on_reverse_3d_effect_complete)
	
	print("Pseudo3DEffect: Started 3D effect reverse animation")

func _on_3d_effect_complete():
	"""Called when the 3D flattening effect animation completes"""
	print("Pseudo3DEffect: 3D flattening effect animation completed")
	animation_tween = null

func _on_reverse_3d_effect_complete():
	"""Called when the 3D effect reverse animation completes"""
	print("Pseudo3DEffect: 3D effect reverse animation completed")
	is_3d_effect_active = false
	animation_tween = null
	original_object_scales.clear()
	
	# Re-enable Y-sorting updates after effect is completely reversed
	enable_ysort_updates()

func disable_ysort_updates():
	"""Disable Y-sorting updates during 3D effect"""
	if smart_optimizer and smart_optimizer.has_method("disable_ysort_updates"):
		smart_optimizer.disable_ysort_updates()
		print("Pseudo3DEffect: Disabled Y-sort updates")
	elif smart_optimizer:
		# Fallback: set a flag to disable Y-sorting
		smart_optimizer.set_meta("ysort_disabled", true)
		print("Pseudo3DEffect: Set Y-sort disabled flag")

func enable_ysort_updates():
	"""Re-enable Y-sorting updates after 3D effect"""
	if smart_optimizer and smart_optimizer.has_method("enable_ysort_updates"):
		smart_optimizer.enable_ysort_updates()
		print("Pseudo3DEffect: Re-enabled Y-sort updates")
	elif smart_optimizer:
		# Fallback: remove the flag to enable Y-sorting
		smart_optimizer.remove_meta("ysort_disabled")
		print("Pseudo3DEffect: Removed Y-sort disabled flag")

func is_effect_active() -> bool:
	"""Check if the 3D effect is currently active"""
	return is_3d_effect_active

func cleanup():
	"""Clean up any ongoing animations"""
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()
		animation_tween = null
	
	is_3d_effect_active = false
	original_object_scales.clear()
	
	# Re-enable Y-sorting when cleaning up
	enable_ysort_updates() 