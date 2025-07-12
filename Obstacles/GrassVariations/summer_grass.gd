extends Node2D

# Import GrassData for grass variations
const GrassData = preload("res://Obstacles/GrassData.gd")

# Grass visual element with Y-sorting - no gameplay effects
# Uses GrassData for variations like bushes and boulders
# PERFORMANCE OPTIMIZED: Minimal processing, static after placement

# GrassData for this specific grass instance
var grass_data: GrassData = null

# Performance optimization: Only update Y-sort when needed
var last_ysort_update: float = 0.0
var ysort_update_cooldown: float = 0.1  # Update every 0.1 seconds max (reduced from 0.5)
var is_ysort_initialized: bool = false

func _ready():
	# Add to groups for optimization
	add_to_group("grass_elements")
	add_to_group("visual_objects")
	
	# Grass data will be applied externally via set_grass_data()
	
	# Initialize Y-sort once on ready
	_initialize_ysort()

func _process(delta):
	# PERFORMANCE OPTIMIZED: Only update Y-sort occasionally
	var current_time = Time.get_ticks_msec() / 1000.0
	if not is_ysort_initialized or (current_time - last_ysort_update >= ysort_update_cooldown):
		_update_ysort()
		last_ysort_update = current_time
		is_ysort_initialized = true

func set_grass_data(data: GrassData):
	"""Set the GrassData for this grass instance"""
	grass_data = data
	_apply_grass_data()

func _apply_grass_data():
	"""Apply the GrassData properties to this grass instance"""
	if not grass_data:
		return
	
	# Update sprite texture
	var sprite = get_node_or_null("GrassSprite")
	if sprite and grass_data.sprite_texture:
		sprite.texture = grass_data.sprite_texture

func _initialize_ysort():
	"""Initialize Y-sort once on ready"""
	_update_ysort()

func _update_ysort():
	"""Update the Grass's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_y_sort_point() -> float:
	"""Get the Y-sort point for this grass (uses YsortPoint marker)"""
	var ysort_point = get_node_or_null("YsortPoint")
	if ysort_point:
		return ysort_point.global_position.y
	else:
		# Fallback to global position if no YsortPoint marker
		return global_position.y

func get_height() -> float:
	"""Get the height of this grass for Y-sorting"""
	if grass_data:
		return grass_data.get_height()
	return 15.0  # Default grass height
