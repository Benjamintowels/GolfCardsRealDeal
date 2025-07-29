extends BaseObstacle

# LightPole collision and Y-sort system
# Uses the same roof bounce system as trees and other obstacles

var animation_player: AnimationPlayer

func _ready():
	# Add to groups for collision detection and optimization
	add_to_group("collision_objects")
	add_to_group("light_poles")
	
	# Get the animation player for electric flash effects
	animation_player = get_node_or_null("AnimationPlayer")
	
	# Connect to child_entered_tree signal to detect when ElectricShock is added
	child_entered_tree.connect(_on_child_entered_tree)
	
	# Set up Area2D collision detection
	var area2d = get_node_or_null("Area2D")
	if area2d:
		# Set collision layer to 1 so golf balls can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		area2d.collision_mask = 1
		
		# Connect to area entered and exited signals for collision detection
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)

func _process(delta):
	# Update Y-sort for proper layering
	_update_ysort()

func _update_ysort():
	"""Update the LightPole's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this light pole.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 20.0  # LightPole collision radius (smaller than boulder since it's skinnier)

func get_height() -> float:
	"""Get the height of this light pole for collision detection"""
	return Global.get_object_height_from_marker(self)

func _play_trunk_thunk_sound():
	"""Play the TrunkThunk sound when ball collides with the light pole"""
	# The ball will handle playing its own TrunkThunk sound
	# This method exists for compatibility with the collision system
	pass

func _on_area_entered(area: Area2D):
	"""Handle collisions with the light pole area using proper height-based detection"""
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_roof_bounce_collision on the light pole
		pass

func _on_area_exited(area: Area2D):
	"""Handle when objects exit the light pole area"""
	pass

func _handle_area_collision(projectile: Node2D):
	"""Handle collision with projectiles like throwing knives"""
	if not projectile:
		return
	
	# Check height difference for collision
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	
	var pole_height = get_height()
	
	# If projectile is below pole height, reflect it
	if projectile_height < pole_height:
		# Let the projectile handle its own reflection (and sound)
		if projectile.has_method("_reflect_off_object"):
			projectile._reflect_off_object(self)

func _on_child_entered_tree(node: Node):
	"""Called when a child is added to this light pole"""
	print("🔍 LightPole: Child added -", node.name, "Type:", node.get_class())
	
	# Check if the added child is an ElectricShock effect
	if node.name == "ElectricShock" or node.get_script() and "electric_shock.gd" in str(node.get_script().get_path()):
		print("⚡ LightPole: ElectricShock detected!")
		_play_electric_flash_animation()
	else:
		print("🔍 LightPole: Not an ElectricShock - checking script path...")
		if node.get_script():
			print("🔍 LightPole: Script path:", node.get_script().get_path())

func _play_electric_flash_animation():
	"""Play the electric flash animation when the light pole gets electrified"""
	print("🔍 LightPole: Attempting to play electric_flash animation")
	print("🔍 LightPole: AnimationPlayer found:", animation_player != null)
	
	if animation_player:
		print("🔍 LightPole: AnimationPlayer has electric_flash animation:", animation_player.has_animation("electric_flash"))
		print("🔍 LightPole: Available animations:", animation_player.get_animation_list())
	
	if animation_player and animation_player.has_animation("electric_flash"):
		print("⚡ LightPole electrified - playing electric_flash animation")
		animation_player.play("electric_flash")
	else:
		print("✗ LightPole: AnimationPlayer or electric_flash animation not found")
		if not animation_player:
			print("✗ LightPole: AnimationPlayer is null")
		elif not animation_player.has_animation("electric_flash"):
			print("✗ LightPole: electric_flash animation not found in AnimationPlayer")
