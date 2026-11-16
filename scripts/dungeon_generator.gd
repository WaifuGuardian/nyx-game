class_name DungeonGenerator
## Room-based dungeon generator: shapes produce cell-sets, corridors connect
## them, room features are assigned by type. Pure function: depth -> MapData.

const MIN_ROOMS := 7
const MAX_ROOMS := 10


static func generate_floor(depth: int) -> MapData:
	var map_data := MapData.new()
	var size := Vector2i(48, 30)
	map_data.size = size
	for x in size.x:
		for y in size.y:
			map_data.tiles[Vector2i(x, y)] = "wall"

	# --- 1. Place rooms (cell-set based, no overlap) ---
	var rooms: Array = []   # each: {"cells": Array[Vector2i], "center": Vector2i}
	var attempts := 0
	while rooms.size() < randi_range(MIN_ROOMS, MAX_ROOMS) and attempts < 200:
		attempts += 1
		var cells := _make_room_cells(size, rooms)
		if cells.is_empty():
			continue
		rooms.append({"cells": cells, "center": cells[cells.size() / 2]})

	# --- 1.5 Carve the rooms themselves into the map ---
	for room in rooms:
		for c in room["cells"]:
			map_data.tiles[c] = "floor"

	if rooms.size() < 2:
		push_error("room generation failed — fallback blob")
		return _fallback_blob_floor(depth, size)

	# --- 2. Corridors: chain each room to the next ---
	for i in range(1, rooms.size()):
		_carve_corridor(map_data, rooms[i - 1]["center"], rooms[i]["center"])

	# --- 3. Sort rooms by distance from the first room: near = entrance ---
	var spawn_center: Vector2i = rooms[0]["center"]
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["center"].distance_squared_to(spawn_center) \
			< b["center"].distance_squared_to(spawn_center))
	var spawn_room: Dictionary = rooms[0]
	var far_room: Dictionary = rooms[rooms.size() - 1]
	map_data.player_spawn = spawn_room["center"]

	# --- 4. Room features ---
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var is_first := i == 0
		var is_last := i == rooms.size() - 1
		if is_first:
			map_data.tiles[_room_cell(room["cells"], map_data)] = "stairs_up"
		elif is_last:
			if depth >= 3:
				map_data.enemy_spawns.append({"pos": room["center"], "id": "warchief"})
				var hoard := _edge_cells(room["cells"])
				for j in mini(2, hoard.size()):
					map_data.tiles[hoard[j]] = "chest"
				var stairs := hoard[hoard.size() - 1] if hoard.size() > 2 \
					else _room_cell(room["cells"], map_data)
				map_data.tiles[stairs] = "stairs_down"
			else:
				map_data.tiles[_room_cell(room["cells"], map_data)] = "stairs_down"
		else:
			var roll := randf()
			if roll < 0.15:   # rest room
				map_data.tiles[_room_cell(room["cells"], map_data)] = "campfire"
			elif roll < 0.3:  # treasure room
				map_data.tiles[_room_cell(room["cells"], map_data)] = "chest"
			else:             # enemy room
				for j in randi_range(1, 3):
					var pool: Array[String] = ["goblin", "goblin", "archer"]
					if depth >= 3:
						pool.append("knight")
					map_data.enemy_spawns.append({
						"pos": _room_cell(room["cells"], map_data),
						"id": pool.pick_random()})

	# --- 5. Flavour ---
	if rooms.size() >= 6 and randf() < 0.4:
		var mid_room: Dictionary = rooms[randi_range(1, rooms.size() - 2)]
		map_data.tiles[_room_cell(mid_room["cells"], map_data)] = "stairs_down"
	if randf() < 0.3:
		var room: Dictionary = rooms[randi_range(1, rooms.size() - 1)]
		for c in room["cells"]:
			if randf() < 0.5:
				map_data.tiles[c] = "water_floor"
	if randf() < 0.25:
		var room: Dictionary = rooms[randi_range(1, rooms.size() - 1)]
		map_data.tiles[_room_cell(room["cells"], map_data)] = "lore_tablet"

	return map_data


# --- Room carving: shapes produce cell-sets ---------------------------------

static func _make_room_cells(size: Vector2i, existing: Array) -> Array[Vector2i]:
	var shape := randi_range(0, 2)   # 0 rect, 1 ellipse, 2 L-shape
	var w := randi_range(5, 9)
	var h := randi_range(4, 7)
	var origin := Vector2i(randi_range(2, size.x - w - 2), randi_range(2, size.y - h - 2))
	var cells: Array[Vector2i] = []
	var center := Vector2(origin) + Vector2(w, h) / 2.0
	for x in range(origin.x, origin.x + w):
		for y in range(origin.y, origin.y + h):
			var c := Vector2i(x, y)
			var inside := true
			match shape:
				1:
					var d := (Vector2(c) + Vector2(0.5, 0.5) - center) / Vector2(w / 2.0, h / 2.0)
					inside = d.dot(d) <= 1.0
				2:
					var fw := maxi(2, w / 2)
					var fh := maxi(2, h / 2)
					var in_foot := c.x <= origin.x + fw and c.y >= origin.y + h - fh
					inside = c.y <= origin.y + fh or in_foot
			if inside:
				cells.append(c)
	for room in existing:
		for c in room["cells"]:
			if cells.has(c):
				return []
	if cells.size() < 6:
		return []
	return cells


static func _carve_corridor(map_data: MapData, from: Vector2i, to: Vector2i) -> void:
	var c := from
	while c.x != to.x:
		map_data.tiles[c] = "floor"
		c.x += signi(to.x - c.x)
	while c.y != to.y:
		map_data.tiles[c] = "floor"
		c.y += signi(to.y - c.y)
	map_data.tiles[to] = "floor"


static func _room_cell(cells: Array[Vector2i], map_data: MapData) -> Vector2i:
	for i in 30:
		var c: Vector2i = cells.pick_random()
		if map_data.tiles.get(c, "wall") == "floor":
			return c
	return cells[cells.size() / 2]


static func _edge_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not cells.has(c + d):
				out.append(c)
				break
	return out


static func _fallback_blob_floor(depth: int, size: Vector2i) -> MapData:
	var map_data := MapData.new()
	map_data.size = size
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			var wall := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1 or randf() < 0.08
			map_data.tiles[cell] = "wall" if wall else "floor"
	map_data.player_spawn = Vector2i(2, 2)
	map_data.tiles[map_data.player_spawn] = "floor"
	map_data.tiles[random_open_cell(map_data)] = "stairs_down"
	map_data.tiles[random_open_cell(map_data)] = "stairs_up"
	var pool: Array[String] = ["goblin", "goblin", "archer"]
	if depth >= 3:
		pool.append("knight")
	for i in 5 + depth:
		map_data.enemy_spawns.append({"pos": random_open_cell(map_data), "id": pool.pick_random()})
	for i in 2:
		map_data.item_spawns.append({"pos": random_open_cell(map_data), "id": "potion", "quality": 2, "count": 1})
	map_data.item_spawns.append({"pos": random_open_cell(map_data), "id": "meat", "quality": 2, "count": 2})
	if depth >= 2:
		map_data.tiles[random_open_cell(map_data)] = "chest"
	return map_data


static func random_open_cell(map_data: MapData) -> Vector2i:
	for i in 200:
		var c := Vector2i(randi_range(1, map_data.size.x - 2), randi_range(2, map_data.size.y - 2))
		if map_data.tiles.get(c, "wall") == "floor" and c != map_data.player_spawn:
			return c
	return Vector2i.ZERO
