extends Node
class_name BossFight

const LAYOUT := [
	["Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base"],
	["Base", "Base", "Base", "Base", "Base", "Base", "Base", "Base", "R", "R", "R", "R", "R", "Base", "Base", "Base", "Base", "Base", "Base", "Base"],
	["Base", "Base", "Base", "Base", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "Base", "Base", "Base"],
	["Base", "Base", "Base", "Base", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "Base", "Base", "Base"],
	["Base", "Base", "Base", "R", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "G", "R", "Base", "Base"],
	["Base", "Base", "Base", "R", "R", "G", "G", "G", "G", "G", "BOSSEYE", "G", "G", "G", "G", "G", "R", "R", "Base", "Base"],
	["Base", "Base", "R", "R", "S", "S", "R", "G", "G", "G", "G", "G", "G", "G", "R", "S", "S", "R", "R", "Base"],
	["Base", "Base", "R", "R", "S", "S", "R", "R", "F", "G", "G", "G", "F", "R", "R", "S", "S", "R", "R", "Base"],
	["Base", "R", "R", "R", "R", "R", "R", "Base", "Base", "F", "F", "F", "F", "R", "R", "R", "R", "R", "R", "Base"],
	["Base", "R", "R", "R", "R", "R", "R", "Base", "Base", "F", "F", "F", "F", "R", "R", "R", "R", "R", "R", "Base"],
	["Base", "R", "R", "Base", "Base", "R", "R", "R", "F", "F", "F", "F", "F", "R", "Base", "Base", "R", "R", "R", "Base"],
	["Base", "R", "R", "Base", "Base", "R", "R", "R", "F", "F", "F", "F", "F", "R", "Base", "Base", "R", "R", "R", "Base"],
	["Base", "R", "R", "R", "R", "R", "R", "R", "F", "F", "F", "F", "F", "R", "R", "R", "R", "R", "R", "Base"],
	["Base", "R", "R", "R", "R", "R", "R", "R", "F", "F", "F", "F", "F", "R", "R", "R", "R", "R", "R", "Base"],
	["Base", "R", "R", "R", "R", "R", "R", "R", "F", "F", "F", "F", "F", "R", "R", "R", "R", "R", "R", "Base"],
	["Base", "R", "R", "R", "R", "R", "R", "R", "R", "Tee", "Tee", "Tee", "R", "R", "R", "R", "R", "R", "R", "Base"],
	["Base", "R", "R", "R", "R", "R", "F", "F", "F", "F", "F", "F", "F", "F", "F", "R", "R", "R", "R", "Base"],
	["F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F"],
	["F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F"],
	["F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F", "F"]
]
