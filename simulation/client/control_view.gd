extends Control

var boat_data: Dictionary = {}

@onready var boat_title: Label = $BoatTitle
@onready var info_label: Label = $InfoLabel

func setup(data: Dictionary) -> void:
	boat_data = data
	var boat_id: String = boat_data.get("id", "")
	boat_title.text = "Piloting Boat #" + boat_id
	info_label.text = "Boat is active in the archipelago simulation."