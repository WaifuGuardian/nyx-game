class_name SkillDB

## kind: melee (facing cell) | aoe8 (all 8 neighbors) | bolt (raycast, ranged) | heal
const DEFS: Dictionary = {
	"power_strike": {
		"name": "Power Strike", "kind": "melee",
		"cost_type": "stamina", "cost": 25, "cooldown": 3, "mult": 2.5,
	},
	"cleave": {
		"name": "Cleave", "kind": "aoe8",
		"cost_type": "stamina", "cost": 35, "cooldown": 4, "mult": 1.5,
	},
	"firebolt": {
		"name": "Firebolt", "kind": "bolt",
		"cost_type": "mana", "cost": 15, "cooldown": 2, "mult": 2.0, "range": 5,
	},
	"mend": {
		"name": "Mend", "kind": "heal",
		"cost_type": "mana", "cost": 20, "cooldown": 5, "amount": 20,
	},
}
