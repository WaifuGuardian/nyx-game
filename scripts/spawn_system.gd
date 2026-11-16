class_name SpawnSystem
## Random encounters, ambush maps, and loot rolls.

const AMBUSH_CHANCE := 0.12


static func maybe_travel_encounter(g: GameState) -> void:
	if g.current_depth != 0 or g.current_map.is_ambush or g.current_map.is_threshold:
		return
	if randf() > AMBUSH_CHANCE:
		return
	var roll := randi_range(0, 2)
	if roll < 2:
		start_ambush(g)
	else:
		var finds: Array[String] = ["potion", "meat"]
		g._spawn_ground_item(ItemDB.make(finds.pick_random(), 2, 1), g.player.grid_pos)
		g.post_message("You spot something half-buried here.")


static func start_ambush(g: GameState) -> void:
	g.layer_stack.append({"map": g.current_map, "depth": g.current_depth, "return_cell": g.player.grid_pos})
	var map_data := MapData.new()
	map_data.is_ambush = true
	var size := Vector2i(14, 11)
	map_data.size = size
	for x in size.x:
		for y in size.y:
			var edge := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			map_data.tiles[Vector2i(x, y)] = "wall" if edge else "floor"
	for i in 4:
		var c := random_open_cell(g, map_data)
		if c != Vector2i.ZERO:
			map_data.tiles[c] = "wall"
	map_data.player_spawn = Vector2i(size.x / 2, size.y / 2)
	map_data.tiles[map_data.player_spawn] = "floor"
	var ids: Array[String] = ["goblin", "goblin", "archer"]
	for i in randi_range(2, 3):
		map_data.enemy_spawns.append({"pos": rim_cell(g, map_data), "id": ids.pick_random()})
	g.post_message("Ambush! Hostiles close in from all sides!")
	g.enter_map(map_data, g.current_depth)


static func rim_cell(g: GameState, map_data: MapData) -> Vector2i:
	for i in 100:
		var side := randi_range(0, 3)
		var c := Vector2i.ZERO
		match side:
			0: c = Vector2i(randi_range(1, map_data.size.x - 2), 1)
			1: c = Vector2i(randi_range(1, map_data.size.x - 2), map_data.size.y - 2)
			2: c = Vector2i(1, randi_range(1, map_data.size.y - 2))
			3: c = Vector2i(map_data.size.x - 2, randi_range(1, map_data.size.y - 2))
		if GameState.WALKABLE.has(map_data.tiles.get(c, "wall")) and g.entity_at(c) == null:
			return c
	return Vector2i(1, 1)


static func try_flee_ambush(g: GameState) -> bool:
	if g.layer_stack.is_empty() or not g.current_map.is_ambush:
		return false
	var on_edge := false
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if g.tile_at(g.player.grid_pos + d) == "wall":
			on_edge = true
			break
	if not on_edge:
		return false
	g.exit_layer()
	g.post_message("Nyx slips away from the ambush!")
	return true


## Loot on death: roll each entry in the def's drops table.
static func roll_loot(g: GameState, e: Enemy) -> void:
	var cell := e.grid_pos
	for d in e.def.get("drops", []):
		if randf() < d["chance"]:
			var item := ItemDB.make(d["id"], int(d.get("quality", 2)), 1)
			var drop_cell := cell
			if g.ground_items.has(cell) or (cell == g.player.grid_pos):
				var spots := free_adjacent_cells(g, cell, 1)
				if spots.size() > 0:
					drop_cell = spots[0]
			g._spawn_ground_item(item, drop_cell)
			g.post_message("The %s drops %s." % [e.display_name, item.display_name()])


## Up to `count` free cells adjacent to `center` (8-directional).
static func free_adjacent_cells(g: GameState, center: Vector2i, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var c: Vector2i = center + d
		if g.is_walkable(c) and g.entity_at(c) == null and not g.ground_items.has(c):
			out.append(c)
			if out.size() >= count:
				break
	return out


static func random_open_cell(g: GameState, map_data: MapData) -> Vector2i:
	for i in 200:
		var c := Vector2i(randi_range(1, map_data.size.x - 2), randi_range(1, map_data.size.y - 2))
		if GameState.WALKABLE.has(map_data.tiles.get(c, "wall")) and g.entity_at(c) == null \
				and not g.ground_items.has(c) and c != map_data.player_spawn:
			return c
	push_error("no open cell found")
	return Vector2i.ZERO
