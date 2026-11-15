class_name Villager
extends Entity

var npc_id := ""
var def: Dictionary = {}
var stock: Array = []


func take_turn() -> int:
	return 100


func _draw() -> void:
	super._draw()
	var marker: String = Game.quest_marker_for(npc_id)
	if marker == "":
		return
	var col := Color(1, 1, 1)
	if marker == "!":
		col = Color(0.3, 1.0, 0.3)
	elif marker == "…":
		col = Color(0.6, 0.6, 0.6)
	var r := 5.0 * token_size
	draw_string(ThemeDB.fallback_font, Vector2(-3, -r - 5), marker,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
