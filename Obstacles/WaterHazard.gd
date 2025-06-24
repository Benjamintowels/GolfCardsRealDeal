extends BaseObstacle
@onready var sprite = $Sprite2D
func _ready():
	#super()
	# Add splash, sound, etc.
	pass
	
func on_player_interact():
	print("Splash! Player stepped in water at", grid_position)
