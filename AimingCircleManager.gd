extends Node2D
class_name AimingCircleManager

# Aiming circle properties
var aiming_circle: Control
var circle_visual: TextureRect
var distance_label: Label
var is_visible: bool = false

# Default reticle texture
var default_reticle_texture: Texture2D

func _ready():
	# Load default reticle texture
	default_reticle_texture = preload("res://UI/Reticle.png")

func create_aiming_circle(position: Vector2, max_distance: int = 100) -> void:
	"""Create the aiming circle at the specified position"""
	# Remove existing circle if it exists
	if aiming_circle:
		aiming_circle.queue_free()
	
	# Create new aiming circle
	aiming_circle = Control.new()
	aiming_circle.name = "AimingCircle"
	aiming_circle.position = position - Vector2(25, 25)  # Center the circle
	aiming_circle.z_index = 100
	add_child(aiming_circle)
	
	# Create circle visual with TextureRect
	circle_visual = TextureRect.new()
	circle_visual.name = "CircleVisual"
	circle_visual.size = Vector2(50, 50)
	circle_visual.texture = default_reticle_texture
	circle_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(circle_visual)
	
	# Add distance label
	distance_label = Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.text = str(max_distance) + "px"
	distance_label.add_theme_font_size_override("font_size", 12)
	distance_label.add_theme_color_override("font_color", Color.WHITE)
	distance_label.position = Vector2(0, 55)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(distance_label)
	
	# Initially hide the circle
	aiming_circle.visible = false
	is_visible = false

func show_aiming_circle() -> void:
	"""Show the aiming circle"""
	if aiming_circle:
		aiming_circle.visible = true
		is_visible = true

func hide_aiming_circle() -> void:
	"""Hide the aiming circle"""
	if aiming_circle:
		aiming_circle.visible = false
		is_visible = false

func update_aiming_circle_position(position: Vector2) -> void:
	"""Update the aiming circle position"""
	if aiming_circle:
		aiming_circle.position = position - Vector2(25, 25)

func update_aiming_circle_rotation(rotation: float) -> void:
	"""Update the aiming circle rotation"""
	if aiming_circle:
		aiming_circle.rotation = rotation

func update_distance_label(distance: int) -> void:
	"""Update the distance label text"""
	if distance_label:
		distance_label.text = str(distance) + "px"

func set_reticle_texture(texture: Texture2D) -> void:
	"""Set the reticle texture for the aiming circle"""
	if circle_visual:
		circle_visual.texture = texture

func get_aiming_circle() -> Control:
	"""Get the aiming circle node"""
	return aiming_circle

func is_aiming_circle_visible() -> bool:
	"""Check if the aiming circle is visible"""
	return is_visible

func destroy_aiming_circle() -> void:
	"""Destroy the aiming circle"""
	if aiming_circle:
		aiming_circle.queue_free()
		aiming_circle = null
		circle_visual = null
		distance_label = null
		is_visible = false 