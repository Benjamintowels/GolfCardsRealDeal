extends Control

#an upgrade for the Clubhouse that lets you access a dialog for printing cards based on which ones you've collected the CardGene of 
#CardGenes are the essence of a card and when collected will allow you to load it into the 3D printer and select that card as a printable option
#When a card is printed from the 3DPrinter the player is allowed to decide to take it with them the next time they load into a Course or to discard it.
#It should cost 25 looty to print a card. 
#it should be selectable as an upgrade for the ClubhouseUpgrade dialog after the ClubHouse is level 4 or higher
#The upgrade should cost 300 looty
#after upgraded it should always appear on the table

func _ready():
	# Ensure it can receive clicks; Main.gd wires the logic
	mouse_filter = Control.MOUSE_FILTER_STOP
