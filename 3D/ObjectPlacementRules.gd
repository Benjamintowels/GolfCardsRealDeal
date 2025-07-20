extends Resource
class_name ObjectPlacementRules

# ObjectPlacementRules - Resource for configuring 3D object placement rules
# This allows easy modification of placement rules without changing code

@export var placement_rules: Dictionary = {
	"pin": {
		"allowed_tiles": ["G"],  # Only on green tiles
		"min_spacing": 8,
		"max_per_hole": 2,
		"avoid_tiles": ["T", "P", "W", "S"],  # Avoid trees, tees, water, sand
		"height": 1.0,
		"pixel_size": 0.08
	},
	"boulder": {
		"allowed_tiles": ["Base", "B"],  # Only on base grass tiles
		"min_spacing": 6,
		"max_per_hole": 5,
		"avoid_tiles": ["T", "P", "G", "W", "S", "F", "R"],  # Avoid all special tiles
		"height": 0.3,
		"pixel_size": 0.12
	},
	"tree": {
		"allowed_tiles": ["Base", "B"],  # Only on base grass tiles
		"min_spacing": 8,
		"max_per_hole": 10,
		"avoid_tiles": ["T", "P", "G", "W", "S", "F", "R"],  # Avoid all special tiles
		"height": 0.8,
		"pixel_size": 0.15
	}
}

func get_rules_for_object_type(object_type: String) -> Dictionary:
	"""Get placement rules for a specific object type"""
	if placement_rules.has(object_type):
		return placement_rules[object_type]
	return {}

func set_rules_for_object_type(object_type: String, rules: Dictionary):
	"""Set placement rules for a specific object type"""
	placement_rules[object_type] = rules

func get_all_rules() -> Dictionary:
	"""Get all placement rules"""
	return placement_rules

func set_all_rules(rules: Dictionary):
	"""Set all placement rules"""
	placement_rules = rules 