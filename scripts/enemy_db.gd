class_name EnemyDB

## role: how it behaves. morale: 0-100; below 30% HP, rout chance = 100 - morale.
## drops: [{"id": String, "chance": float}] rolled on death.
const DEFS: Dictionary = {
	"goblin": {
		"name": "goblin", "role": "melee", "morale": 30, "xp": 10,
		"color": Color(0.5, 0.75, 0.3),
		"attributes": {"STR": 8, "CON": 8, "DEX": 14, "PER": 10,
			"WIL": 6, "MAG": 2, "LUCK": 8, "CHA": 4},
		"drops": [{"id": "meat", "chance": 0.5}, {"id": "potion", "chance": 0.15}],
	},
	"archer": {
		"name": "archer", "role": "ranged", "morale": 50, "xp": 15,
		"color": Color(0.85, 0.65, 0.3),
		"attributes": {"STR": 8, "CON": 10, "DEX": 14, "PER": 14,
			"WIL": 8, "MAG": 2, "LUCK": 8, "CHA": 6},
		"drops": [{"id": "meat", "chance": 0.35}, {"id": "scroll_flames", "chance": 0.1}],
	},
	"knight": {
		"name": "knight", "role": "melee", "morale": 90, "xp": 25,
		"color": Color(0.55, 0.6, 0.8),
		"attributes": {"STR": 16, "CON": 12, "DEX": 8, "PER": 8,
			"WIL": 12, "MAG": 2, "LUCK": 6, "CHA": 8},
		"drops": [{"id": "potion", "chance": 0.3}, {"id": "armor_leather", "quality": 3, "chance": 0.2}],
	},
	"warchief": {
		"name": "Gorehorn the Warchief", "role": "melee", "morale": 100, "xp": 80,
		"color": Color(0.75, 0.25, 0.2),
		"token_size": 2.0, "ring_color": Color(0.9, 0.3, 0.2),
		"attributes": {"STR": 20, "CON": 18, "DEX": 10, "PER": 10,
			"WIL": 14, "MAG": 4, "LUCK": 10, "CHA": 12},
		"drops": [
			{"id": "sword", "quality": 4, "chance": 1.0},
			{"id": "potion_major", "quality": 3, "chance": 0.6},
			{"id": "scroll_flames", "chance": 0.35},
		],
	},
}


static func make(id: String) -> Enemy:
	var d: Dictionary = DEFS[id]
	var e := Enemy.new()
	e.def = d.duplicate()
	e.def["id"] = id
	e.display_name = d["name"]
	e.color = d["color"]
	e.attributes = d["attributes"].duplicate()
	e.hp = e.max_hp()
	e.mana = e.max_mana()
	e.token_size = d.get("token_size", 1.0)
	e.ring_color = d.get("ring_color", Color(0.4, 0.4, 0.45))
	e.set_face("res://art/faces/%s.png" % id)
	return e
