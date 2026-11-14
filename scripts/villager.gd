class_name Villager
extends Entity

var npc_id := ""
var def: Dictionary = {}
var stock: Array = []  # live shop stock, only used by shopkeeps


func take_turn() -> int:
	return 100  # stands around; schedules come later
