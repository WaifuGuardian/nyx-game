class_name NpcDB

const DEFS: Dictionary = {
	"elder": {
		"name": "Elder Mira",
		"color": Color(0.55, 0.8, 0.9),
		"face": "res://art/faces/elder.png",
		"root": {
			"text": "Nyx. I wondered when you'd climb my stairs.",
			"options": [
				{"label": "Flirt", "effect": "flirt"},
				{"label": "Ask about the woods", "effect": "lines",
					"lines": [
						"The dark in those hills is older than this town, child.",
						"The bells ring when the woods move. Lately, they ring at night.",
					], "then": "root"},
				{"label": "Ask for work", "effect": "quest_stub"},
				{"label": "Leave", "effect": "end"},
			],
		},
	},
	"shopkeep": {
		"name": "Bram the Trader",
		"color": Color(0.9, 0.7, 0.4),
		"face": "res://art/faces/bram.png",
		"root": {
			"text": "Steel, potions, supplies. If you've coin, I've goods.",
			"options": [
				{"label": "Trade", "effect": "shop"},
				{"label": "Ask about the road", "effect": "lines",
					"lines": [
						"Roads are fine by day. By night, the woods walk.",
						"Something's been eating my caravans. Buy a sword — you'll understand.",
					], "then": "root"},
				{"label": "Leave", "effect": "end"},
			],
		},
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
		"random_talk": true,
		"dialogue": [
			"Another outsider. Word of the fires in the north reached us days ago.",
			"Mind the woods after dark. The bells don't ring for nothing.",
			"You're the one fleeing the north, aren't I? Don't answer.",
			"Bram overcharges, but he's the only Bram we've got.",
		],
	},
}
