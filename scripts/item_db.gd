class_name ItemDB

## Quality ladder: index into these arrays. Common = default.
const QUALITY_NAMES: Array[String] = [
	"Broken", "Shoddy", "Common", "Fine", "Superior", "Masterwork", "Legendary",
]
const QUALITY_MULT: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

## kind: potion | weapon | armor | scroll | material | food | supply
const DEFS: Dictionary = {
	"potion": {
		"name": "Potion", "kind": "potion", "heal": 12,
		"value": 30, "weight": 1, "stack": true,
		"color": Color(0.95, 0.4, 0.4),
	},
	"potion_major": {
		"name": "Major Potion", "kind": "potion", "heal": 30,
		"value": 90, "weight": 1, "stack": true,
		"color": Color(0.85, 0.2, 0.5),
	},
	"scroll_flames": {
		"name": "Scroll of Flames", "kind": "scroll", "power": 10,
		"value": 60, "weight": 1, "stack": true,
		"color": Color(0.95, 0.75, 0.4),
	},
	"sword": {
		"name": "Sword", "kind": "weapon", "atk": 3,
		"value": 150, "weight": 20, "stack": false,
		"color": Color(0.75, 0.78, 0.85),
	},
	"armor_leather": {
		"name": "Leather Armor", "kind": "armor", "def": 2,
		"value": 100, "weight": 15, "stack": false,
		"color": Color(0.55, 0.4, 0.25),
	},
	"meat": {
		"name": "Meat", "kind": "food", "nutrition": 25,
		"value": 5, "weight": 2, "stack": true,
		"color": Color(0.8, 0.45, 0.45),
	},
	"camp_supplies": {
		"name": "Camp Supplies", "kind": "supply",
		"value": 20, "weight": 3, "stack": true,
		"color": Color(0.75, 0.65, 0.45),
	},
	"cloth_top": {
		"name": "Nyx's Blouse", "kind": "armor", "def": 1,
		"value": 5, "weight": 1, "stack": false,
		"slot": "chest",
		"doll_layer": "res://art/doll/nyxs_blouse.png",
		"color": Color(0.6, 0.3, 0.3),
	},
	"cloth_legs": {
		"name": "Nyx's Skirt", "kind": "armor", "def": 0,
		"value": 5, "weight": 1, "stack": false,
		"slot": "legs",
		"doll_layer": "res://art/doll/nyxs_skirt.png",
		"color": Color(0.55, 0.35, 0.3),
	},
}


## Factory: quality is an index into QUALITY_NAMES (2 = Common).
static func make(id: String, quality := 2, count := 1) -> Item:
	var it := Item.new()
	it.id = id
	it.def = DEFS[id]
	it.quality = clampi(quality, 0, QUALITY_NAMES.size() - 1)
	it.count = maxi(count, 1)
	return it
