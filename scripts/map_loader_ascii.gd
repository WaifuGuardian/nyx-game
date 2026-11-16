class_name AsciiMapLoader
## Turns a text file into MapData. The legend is data — change it freely.

const TILE_CHARS := {
	"#": "wall", ".": "floor", "+": "door", ">": "stairs_down", "<": "stairs_up",
	"p": "plains", "w": "woods", "m": "mountain", "~": "water", "T": "town",
	"=": "chest",
}
const ENEMY_CHARS := {"g": "goblin", "a": "archer", "k": "knight", "B": "warchief"}
const NPC_CHARS := {"V": "elder", "S": "shopkeep", "P": "townsperson"}
const ITEM_CHARS := {"!": "potion", "?": "scroll_flames", ")": "sword", "[": "armor_leather", "%": "meat"}
const DUNGEON_CHARS := {
	"D": "woods_dungeon",
}


static func load(path: String) -> MapData:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open map file: %s" % path)
		return MapData.new()
	var lines: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.length() > 0:
			lines.append(line)
	f.close()
	# Pad ragged lines with wall so the grid is always rectangular.
	var width := 0
	for l in lines:
		width = maxi(width, l.length())
	for i in lines.size():
		while lines[i].length() < width:
			lines[i] += "#"
	var map := MapData.new()
	map.size = Vector2i(width, lines.size())
	for y in lines.size():
		var line := lines[y]
		for x in width:
			var ch := line[x]
			var pos := Vector2i(x, y)
			if TILE_CHARS.has(ch):
				map.tiles[pos] = TILE_CHARS[ch]
			elif ch == "@":
				map.tiles[pos] = "floor"
				map.player_spawn = pos
			elif ENEMY_CHARS.has(ch):
				map.tiles[pos] = "floor"
				map.enemy_spawns.append({"pos": pos, "id": ENEMY_CHARS[ch]})
			elif NPC_CHARS.has(ch):
				map.tiles[pos] = "floor"
				map.npc_spawns.append({"pos": pos, "id": NPC_CHARS[ch]})
			elif ITEM_CHARS.has(ch):
				map.tiles[pos] = "floor"
				map.item_spawns.append({"pos": pos, "id": ITEM_CHARS[ch], "quality": 2, "count": 1})
			elif DUNGEON_CHARS.has(ch):
				map.tiles[pos] = "dungeon_entrance"
				map.dungeon_entrances.append({"pos": pos, "dungeon_id": DUNGEON_CHARS[ch]})
			else:
				map.tiles[pos] = "wall"  # spaces and anything unknown
	return map
