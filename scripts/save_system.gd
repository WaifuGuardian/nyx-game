class_name SaveSystem
## All persistence: save/load, and the game->JSON dict converters.

const SAVE_PATH := "user://savegame.json"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


static func save_game(g: GameState) -> void:
	if not is_instance_valid(g.player):
		return
	var data := {
		"day": g.day,
		"minutes": g.world_minutes,
		"depth": g.current_depth,
		"player": _player_to_dict(g),
		"current_map": _map_to_dict(g, g.current_map),
		"layer_stack": _stack_to_dicts(g),
		"affinity": g.affinity,
		"quests": g.quests,
		"quests_done": g.quests_done,
		"dungeon_cache": _cache_to_dicts(g),
		"dungeon_instance": g.dungeon_instance,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("save failed")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	g.post_message("(Game saved.)")


static func load_game(g: GameState) -> void:
	if g.busy:
		return
	if not has_save():
		g.post_message("No save to load.")
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null:
		push_error("save file corrupt")
		return
	if not is_instance_valid(g.player) or not g.player.alive:
		g.player = Player.new()
		g.player.color = Color(0.9, 0.9, 1.0)
		g._register(g.player)
	g.day = int(data["day"])
	g.world_minutes = int(data["minutes"])
	g.affinity = data.get("affinity", {})
	g.quests = {}
	for k in data.get("quests", {}):
		g.quests[k] = int(data["quests"][k])
	g.quests_done = []
	for q in data.get("quests_done", []):
		g.quests_done.append(q)
	_cache_from_dicts(g, data.get("dungeon_cache", {}))
	g.dungeon_instance = data.get("dungeon_instance", "")
	g.layer_stack = _stack_from_dicts(g, data["layer_stack"])
	g.enter_map(_dict_to_map(g, data["current_map"]), int(data["depth"]))
	_player_from_dict(g, data["player"])
	g.post_message("The world returns to Nyx, as she left it.")


static func _item_to_dict(it: Item) -> Dictionary:
	return {"id": it.id, "quality": it.quality, "count": it.count}


static func _map_to_dict(g: GameState, m: MapData) -> Dictionary:
	var tiles := {}
	for c in m.tiles:
		tiles["%d,%d" % [c.x, c.y]] = m.tiles[c]
	var enemies := []
	for e in g.entities:
		if is_instance_valid(e) and e != g.player and e is Enemy:
			enemies.append({"pos": [e.grid_pos.x, e.grid_pos.y], "id": e.def["id"]})
	var npcs := []
	for s in m.npc_spawns:
		npcs.append({"pos": [s["pos"].x, s["pos"].y], "id": s["id"]})
	var dungeons := []
	for e in m.dungeon_entrances:
		dungeons.append({"pos": [e["pos"].x, e["pos"].y], "id": e["dungeon_id"]})
	var items := []
	for cell in g.ground_items:
		var gr: GroundItem = g.ground_items[cell]
		var d: Dictionary = _item_to_dict(gr.item)
		d["pos"] = [cell.x, cell.y]
		items.append(d)
	return {
		"size": [m.size.x, m.size.y],
		"tiles": tiles,
		"player_spawn": [m.player_spawn.x, m.player_spawn.y],
		"enemy_spawns": enemies,
		"npc_spawns": npcs,
		"dungeon_entrances": dungeons,
		"item_spawns": items,
		"is_ambush": m.is_ambush,
	}


static func _dict_to_map(g: GameState, d: Dictionary) -> MapData:
	var m := MapData.new()
	m.size = Vector2i(int(d["size"][0]), int(d["size"][1]))
	for k in d["tiles"]:
		var parts := (k as String).split(",")
		m.tiles[Vector2i(int(parts[0]), int(parts[1]))] = d["tiles"][k]
	var ps: Array = d["player_spawn"]
	m.player_spawn = Vector2i(int(ps[0]), int(ps[1]))
	m.is_ambush = d.get("is_ambush", false)
	for s in d["enemy_spawns"]:
		m.enemy_spawns.append({"pos": Vector2i(int(s["pos"][0]), int(s["pos"][1])), "id": s["id"]})
	for s in d.get("npc_spawns", []):
		m.npc_spawns.append({"pos": Vector2i(int(s["pos"][0]), int(s["pos"][1])), "id": s["id"]})
	for s in d.get("dungeon_entrances", []):
		m.dungeon_entrances.append({
			"pos": Vector2i(int(s["pos"][0]), int(s["pos"][1])),
			"dungeon_id": s["id"],
		})
	for s in d["item_spawns"]:
		m.item_spawns.append({
			"pos": Vector2i(int(s["pos"][0]), int(s["pos"][1])),
			"id": s["id"], "quality": int(s["quality"]), "count": int(s["count"])})
	return m


static func _player_to_dict(g: GameState) -> Dictionary:
	var equipped_dict := {}
	for slot in g.player.equipped:
		equipped_dict[slot] = _item_to_dict(g.player.equipped[slot])
	return {
		"grid_pos": [g.player.grid_pos.x, g.player.grid_pos.y],
		"level": g.player.level, "xp": g.player.xp,
		"hp": g.player.hp, "stamina": g.player.stamina, "mana": g.player.mana,
		"hunger": g.player.hunger, "gold": g.player.gold,
		"attributes": g.player.attributes,
		"inventory": g.player.inventory.map(_item_to_dict),
		"equipped": equipped_dict,
		"hotbar": g.player.hotbar,
	}


static func _player_from_dict(g: GameState, d: Dictionary) -> void:
	g.player.level = int(d["level"])
	g.player.xp = int(d["xp"])
	var attrs: Dictionary = {}
	for k in d["attributes"]:
		attrs[k] = int(d["attributes"][k])
	g.player.attributes = attrs
	g.player.hunger = float(d["hunger"])
	g.player.stamina = float(d["stamina"])
	g.player.mana = float(d["mana"])
	g.player.gold = int(d.get("gold", 50))
	g.player.hp = int(d["hp"])
	g.player.inventory.clear()
	for itd in d["inventory"]:
		g.player.inventory.append(ItemDB.make(itd["id"], int(itd["quality"]), int(itd["count"])))
	g.player.equipped.clear()
	for slot in d["equipped"]:
		var itd: Dictionary = d["equipped"][slot]
		g.player.equipped[slot] = ItemDB.make(itd["id"], int(itd["quality"]), int(itd["count"]))
	g.player.hotbar.clear()
	for slot in d.get("hotbar", []):
		g.player.hotbar.append(slot)
	g.player.grid_pos = Vector2i(int(d["grid_pos"][0]), int(d["grid_pos"][1]))
	g.player.snap()


static func _stack_to_dicts(g: GameState) -> Array:
	var out := []
	for layer in g.layer_stack:
		out.append({
			"map": _map_to_dict(g, layer["map"]),
			"depth": layer["depth"],
			"return_cell": [layer["return_cell"].x, layer["return_cell"].y],
		})
	return out


static func _stack_from_dicts(g: GameState, arr: Array) -> Array:
	var out := []
	for layer in arr:
		out.append({
			"map": _dict_to_map(g, layer["map"]),
			"depth": int(layer["depth"]),
			"return_cell": Vector2i(int(layer["return_cell"][0]), int(layer["return_cell"][1])),
		})
	return out


static func _cache_to_dicts(g: GameState) -> Dictionary:
	var out := {}
	for id in g.dungeon_cache:
		var floors := {}
		for depth in g.dungeon_cache[id]["floors"]:
			floors[str(depth)] = _map_to_dict(g, g.dungeon_cache[id]["floors"][depth])
		out[id] = {"floors": floors, "stamp": g.dungeon_cache[id]["stamp"]}
	return out


static func _cache_from_dicts(g: GameState, d: Dictionary) -> void:
	g.dungeon_cache = {}
	for id in d:
		var floors := {}
		for depth in d[id]["floors"]:
			floors[int(depth)] = _dict_to_map(g, d[id]["floors"][depth])
		g.dungeon_cache[id] = {"floors": floors, "stamp": int(d[id]["stamp"])}
