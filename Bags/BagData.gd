extends Resource
class_name BagData

@export var name: String = "Bag Upgrade"
@export var level: int = 2
@export var character: String = "Benny"
@export var image: Texture2D
@export var description: String = "Upgrade your bag to level %d"

func _init():
	# Set default description based on level
	description = "Upgrade your bag to level %d" % level 