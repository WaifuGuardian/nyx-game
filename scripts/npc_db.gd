class_name NpcDB

const DEFS: Dictionary = {
	"elder": {
		"name": "Elder Mira",
		"color": Color(0.75, 0.095, 0.685, 1.0),
		"face": "res://art/faces/elder.png",
		"dialogue": [
			"Nyx... so the stories were true. You fled north.",
			"The woods will hide you for now, child. But the dark in those hills is older than this town.",
			"Go carefully. And come back alive — you are the most interesting thing to happen here in years.",
		],
	},
	"shopkeep": {
		"name": "Bram the Trader",
		"color": Color(0.992, 0.659, 0.054, 1.0),
		"face": "res://art/faces/bram.png",
		"dialogue": [
			"Steel, potions, supplies. If you've coin, I've goods.",
		],
		"stock": [
			{"id": "potion", "quality": 2, "count": 5},
			{"id": "potion_major", "quality": 2, "count": 2},
			{"id": "sword", "quality": 3, "count": 1},
			{"id": "armor_leather", "quality": 2, "count": 1},
			{"id": "camp_supplies", "quality": 2, "count": 5},
			{"id": "scroll_flames", "quality": 2, "count": 2},
		],
	},
	"townsperson": {
		"name": "Townsperson",
		"color": Color(0.7, 0.7, 0.65),
		"face": "res://art/faces/townsperson.png",
		"dialogue": [
			"Another outsider. Word of the fires in the north reached us days ago.",
			"Mind the woods after dark. The bells don't ring for nothing.",
		],
	},
}
