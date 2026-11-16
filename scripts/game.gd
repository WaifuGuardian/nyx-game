class_name GameState
extends Node
## Autoload "Game": maps, entities, items, skills, time, survival, turns.

const TILE := 16
const TILE_ATLAS := {"floor": 0, "wall": 1, "door": 2, "stairs_down": 3, "stairs_up": 4,
	"grass": 0, "plains": 5, "woods": 6, "mountain": 7, "water": 8, "dungeon_entrance": 9,
	"town": 10, "chest": 11, "chest_open": 12, "campfire": 13, "water_floor": 14,
	"lore_tablet": 15,  "vault_door": 16, "vault_open": 17}
const WALKABLE: Array[String] = ["floor", "door", "stairs_down", "stairs_up",
	"grass", "plains", "woods", "dungeon_entrance", "town",
	"campfire", "water_floor", "lore_tablet"]
const SLOW_TILES: Array[String] = ["woods", "plains"]
const BASE_HIT := 75
const CRIT_DIVISOR := 3  # LUCK / this = crit chance %
const SAVE_PATH := "user://savegame.json"
const LORE_LINES: Array[String] = [
	"\"...the woods breathe when the bell rings. Count the breaths.\"",
	"Scratched into the stone: \"DEEPER = RICHER. ALSO DEADLIER. - a previous delve\"",
	"\"The bone merchant prices in your survival, not your gold.\"",
	"Someone tall, in charcoal: \"Nine rooms, nine doors, one way out.\"",
]
const DUNGEON_GRACE_MINUTES := 1440   # 24 in-game hours before the dungeon forgets

signal message_posted(text: String)
signal time_passed(minutes: int)

var turn := 0
var busy := false
var inventory_open := false
var dialogue_open := false
var affinity: Dictionary = {}  # npc_id -> int, -100..100
var current_map: MapData
var current_depth := 0
var layer_stack: Array = []
var map: TileMapLayer
var entities: Array[Entity] = []
var ground_items: Dictionary = {}
var player: Player
var message_log: Array[String] = []
var world_minutes: int = 8 * 60
var day := 1
var dialogue_ui: DialogueUi
var shop_ui: ShopUi
var quests: Dictionary = {}       # quest_id -> progress
var quests_done: Array[String] = []
var dungeon_cache: Dictionary = {}   # instance_id -> {"floors": {depth: MapData}, "stamp": int}
var dungeon_instance := ""           # id of the dungeon we're currently inside ("" = surface)
var _fast := false   # true while the enemy phase resolves: minimal animation waits

func post_message(text: String) -> void:
	message_log.append(text)
	if message_log.size() > 50:
		message_log.pop_front()
	message_posted.emit(text)


# --- Delegated systems (see save_system.gd / time_system.gd) -----------------

func advance_time(minutes: int) -> void:
	TimeSystem.advance_time(self, minutes)

func clock_text() -> String:
	return TimeSystem.clock_text(self)
	
func _abs_time() -> int:
	return TimeSystem.abs_time(self)

func new_game() -> void:
	player = Player.new()
	player.color = Color(0.9, 0.9, 1.0)
	_register(player)
	player.inventory.append(ItemDB.make("camp_supplies", 2, 2))
	enter_overworld()
	post_message("Nyx sets out. (Arrows: move, 1-9: hotbar, R: rest, Enter: interact)")


func start_new_game() -> void:
	delete_save()
	new_game()


# --- Skills / hotbar ---------------------------------------------------------

func use_hotbar(index: int) -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	if index >= player.hotbar.size():
		return
	var slot: Dictionary = player.hotbar[index]
	if slot["kind"] == "skill":
		_cast_skill(slot["id"])
	elif slot["kind"] == "item":
		for i in player.inventory.size():
			if player.inventory[i].id == slot["id"]:
				player_use_item(i)
				return
		post_message("Nothing left of that.")


func _cast_skill(id: String) -> void:
	var def: Dictionary = SkillDB.DEFS[id]
	if player.skill_cooldowns.get(id, 0) > 0:
		post_message("%s is not ready. (%d turns)" % [def["name"], player.skill_cooldowns[id]])
		return
	var cost: int = def["cost"]
	if def["cost_type"] == "stamina":
		if player.stamina < cost:
			post_message("Not enough stamina for %s." % def["name"])
			return
		player.stamina -= cost
	else:
		if player.mana < cost:
			post_message("Not enough mana for %s." % def["name"])
			return
		player.mana -= cost
	player.skill_cooldowns[id] = def["cooldown"]
	busy = true
	if player.meditating:
		player.meditating = false
		post_message("Nyx breaks her meditation.")
	player.guarding = false
	match def["kind"]:
		"melee":
			var target_cell: Vector2i = player.grid_pos + player.facing
			var t := entity_at(target_cell)
			if t != null and t.hostile:
				_strike(player, t, def["mult"])
			else:
				post_message("%s strikes the air!" % def["name"])
		"aoe8":
			var hit_any := false
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
					Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var t := entity_at(player.grid_pos + d)
				if t != null and t.hostile:
					_strike(player, t, def["mult"])
					hit_any = true
			if not hit_any:
				post_message("%s whirls through empty air!" % def["name"])
		"bolt":
			var hit_any := false
			for i in int(def["range"]):
				var cell: Vector2i = player.grid_pos + player.facing * (i + 1)
				if not is_walkable(cell):
					post_message("The bolt splashes against a wall.")
					break
				var t := entity_at(cell)
				if t != null and t.hostile:
					_strike(player, t, def["mult"], true)
					hit_any = true
					break
			if not hit_any:
				post_message("The bolt flies into the dark.")
		"heal":
			player.hp = mini(player.hp + int(def["amount"]), player.max_hp())
			post_message("Mend knits Nyx's wounds. (+%d HP)" % int(def["amount"]))
	await get_tree().create_timer(0.08).timeout
	player.tick_resources()
	player.tick_skill_cooldowns()
	await _resolve_enemy_turns()
	turn += 1
	busy = false


## A damage roll at a multiplier; shared by melee skills. Can crit.
func _strike(a: Entity, t: Entity, mult: float, is_bolt := false) -> void:
	var verb := "bolt" if is_bolt else "strike"
	var chance: int = clampi(BASE_HIT + a.accuracy() - t.evasion(), 35, 95)
	if randi_range(0, 99) >= chance:
		post_message("%s's %s misses the %s." % [a.display_name, verb, t.display_name])
		return
	var dmg := randi_range(1, a.attack_power())
	dmg = int(dmg * mult)
	dmg = maxi(1, dmg - t.defense())
	if randi_range(0, 99) < int(a.attributes.get("LUCK", 10)) / CRIT_DIVISOR:
		dmg *= 2
		post_message("CRITICAL! %s's %s crushes the %s for %d!" % [a.display_name, verb, t.display_name, dmg])
	else:
		post_message("%s's %s hits the %s for %d." % [a.display_name, verb, t.display_name, dmg])
	t.take_damage(dmg)


## Loot on death: roll each entry in the def's drops table.
func roll_loot(e: Enemy) -> void:
	var cell := e.grid_pos
	for d in e.def.get("drops", []):
		if randf() < d["chance"]:
			var item := ItemDB.make(d["id"], int(d.get("quality", 2)), 1)
			var drop_cell := cell
			if ground_items.has(cell) or (cell == player.grid_pos):
				var spots := _free_adjacent_cells(cell, 1)
				if spots.size() > 0:
					drop_cell = spots[0]
			_spawn_ground_item(item, drop_cell)
			post_message("The %s drops %s." % [e.display_name, item.display_name()])
## Up to `count` free cells adjacent to `center` (8-directional).
func _free_adjacent_cells(center: Vector2i, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var c: Vector2i = center + d
		if is_walkable(c) and entity_at(c) == null and not ground_items.has(c):
			out.append(c)
			if out.size() >= count:
				break
	return out

# --- Save / load ---------------------------------------------------------


func save_game() -> void:
	SaveSystem.save_game(self)

func load_game() -> void:
	SaveSystem.load_game(self)

func has_save() -> bool:
	return SaveSystem.has_save()

func delete_save() -> void:
	SaveSystem.delete_save()

# --- Map handling ---------------------------------------------------------

func enter_overworld() -> void:
	var overworld := AsciiMapLoader.load("res://maps/overworld.txt")
	enter_map(overworld, 0)


func enter_dungeon(path: String, instance_id := "") -> void:
	layer_stack.append({"map": current_map, "depth": current_depth, "return_cell": player.grid_pos})
	if instance_id != "":
		dungeon_instance = instance_id
		var inst: Dictionary = dungeon_cache.get(instance_id, {})
		if inst.is_empty():
			var merchant_floor := -1
			var vault_floor := -1
			if randf() < 0.4:
				merchant_floor = randi_range(3, 7)
				if randf() < 0.5:
					vault_floor = merchant_floor + randi_range(0, 2)
			inst = {"floors": {}, "stamp": 0, "merchant_floor": merchant_floor, "vault_floor": vault_floor}
			dungeon_cache[instance_id] = inst
			post_message("A fresh darkness. This dungeon is new to you.")
		elif _abs_time() - int(inst.get("stamp", 0)) > DUNGEON_GRACE_MINUTES:
			dungeon_cache.erase(instance_id)
			post_message("The entrance has shifted. This is not the same dungeon you left.")
		else:
			post_message("The dungeon remembers you.")
	var dungeon := AsciiMapLoader.load(path)
	enter_map(dungeon, 1)


func exit_layer() -> void:
	if layer_stack.is_empty():
		return
	var layer: Dictionary = layer_stack.pop_back()
	enter_map(layer["map"], layer["depth"])
	player.grid_pos = layer["return_cell"]
	player.snap()
	if layer["depth"] == 0 and dungeon_instance != "":
		if dungeon_cache.has(dungeon_instance):
			dungeon_cache[dungeon_instance]["stamp"] = _abs_time()
		dungeon_instance = ""
	post_message("Nyx returns to the surface.")


func enter_map(map_data: MapData, depth: int) -> void:
	current_map = map_data
	current_depth = depth
	_clear_world()
	_render_map(map_data)
	for s in map_data.enemy_spawns:
		var e := EnemyDB.make(s["id"])
		e.grid_pos = s["pos"]
		_register(e)
	for s in map_data.npc_spawns:
		var v := Villager.new()
		v.npc_id = s["id"]
		v.def = NpcDB.DEFS[s["id"]]
		v.display_name = v.def["name"]
		v.color = v.def.get("color", Color(0.6, 0.8, 0.9))
		v.set_face(v.def.get("face", ""))
		if v.def.has("stock"):
			v.stock = v.def["stock"].duplicate(true)
		if v.npc_id == "bone_merchant":          # <- add these two
			v.stock = _bone_merchant_stock()    # <- (his stock is dynamic)
		v.grid_pos = s["pos"]
		_register(v)
	for s in map_data.item_spawns:
		var g := GroundItem.new()
		g.item = ItemDB.make(s["id"], s["quality"], s["count"])
		g.grid_pos = s["pos"]
		ground_items[g.grid_pos] = g
		add_child(g)
	
	player.grid_pos = map_data.player_spawn
	player.snap()


func _clear_world() -> void:
	for e in entities:
		if e != player and is_instance_valid(e):
			e.queue_free()
	entities.clear()
	if is_instance_valid(player):
		entities.append(player)
	for g in ground_items.values():
		if is_instance_valid(g):
			g.queue_free()
	ground_items.clear()
	if map != null and is_instance_valid(map):
		map.queue_free()


func _render_map(map_data: MapData) -> void:
	map = TileMapLayer.new()
	map.tile_set = _make_tileset()
	add_child(map)
	for cell in map_data.tiles:
		var id: String = map_data.tiles[cell]
		map.set_cell(cell, 0, Vector2i(TILE_ATLAS.get(id, 0), 0))   # .get with default


func tile_at(cell: Vector2i) -> String:
	return current_map.tiles.get(cell, "wall")
func _dungeon_id_at(cell: Vector2i) -> String:
	for e in current_map.dungeon_entrances:
		if e["pos"] == cell:
			return e["dungeon_id"]
	return ""

func is_walkable(cell: Vector2i) -> bool:
	return WALKABLE.has(tile_at(cell))

func random_open_cell(map_data: MapData) -> Vector2i:
	for i in 200:
		var c := Vector2i(randi_range(1, map_data.size.x - 2), randi_range(1, map_data.size.y - 2))
		if WALKABLE.has(map_data.tiles.get(c, "wall")) and entity_at(c) == null \
				and not ground_items.has(c) and c != map_data.player_spawn:
			return c
	push_error("no open cell found")
	return Vector2i.ZERO


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "walkable")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	var src := TileSetAtlasSource.new()
	src.texture = _make_tiles_texture()
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in TILE_ATLAS.size():
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	for id in TILE_ATLAS:
		var td := src.get_tile_data(Vector2i(TILE_ATLAS[id], 0), 0)
		td.set_custom_data("walkable", WALKABLE.has(id))
	return ts


func _make_tiles_texture() -> ImageTexture:
	var n := TILE_ATLAS.size()
	var img := Image.create_empty(n * TILE, TILE, false, Image.FORMAT_RGB8)
	for i in n:
		for x in TILE:
			for y in TILE:
				var base := Color(0.3, 0.3, 0.34)
				match i:
					0, 5: base = Color(0.42, 0.52, 0.3) if (x + y) % 3 == 0 else Color(0.38, 0.48, 0.27)
					1: base = Color(0.18, 0.18, 0.2) if (x + y) % 2 == 0 else Color(0.15, 0.15, 0.17)
					2: base = Color(0.4, 0.28, 0.15) if x < 2 or x > TILE - 3 else Color(0.5, 0.38, 0.2)
					3: base = Color(0.25, 0.25, 0.28) if (x + y) % 2 == 0 else Color(0.22, 0.22, 0.25)
					4: base = Color(0.4, 0.4, 0.44) if (x + y) % 2 == 0 else Color(0.37, 0.37, 0.41)
					6: base = Color(0.2, 0.38, 0.2) if (x * y) % 5 != 0 else Color(0.16, 0.3, 0.16)
					7: base = Color(0.45, 0.42, 0.4) if (x + y) % 4 != 0 else Color(0.36, 0.34, 0.33)
					8: base = Color(0.2, 0.35, 0.55) if (x + y) % 2 == 0 else Color(0.18, 0.31, 0.5)
					9: base = Color(0.1, 0.1, 0.12)
					10: base = Color(0.55, 0.4, 0.35) if (x + y) % 3 != 0 else Color(0.48, 0.35, 0.3)
					11: base = Color(0.45, 0.32, 0.15) if y < 3 or y > TILE - 4 else Color(0.65, 0.5, 0.2)
					12: base = Color(0.3, 0.22, 0.1) if y < 5 else Color(0.2, 0.15, 0.08)
					13: base = Color(0.35, 0.2, 0.1) if (x + y) % 4 != 0 else Color(0.9, 0.5, 0.1)  # campfire: dark ring, flame flecks
					14: base = Color(0.25, 0.35, 0.5) if (x + y) % 2 == 0 else Color(0.22, 0.31, 0.45)  # dungeon water
					15: base = Color(0.4, 0.42, 0.45) if y % 4 != 0 else Color(0.28, 0.3, 0.33)  # etched tablet
					16: base = Color(0.2, 0.2, 0.24) if y < 3 or y > TILE - 4 else Color(0.3, 0.28, 0.3)
					17: base = Color(0.12, 0.12, 0.14) if y < 5 else Color(0.2, 0.18, 0.16)
				img.set_pixel(i * TILE + x, y, base)
	for x in range(4, 12):
		img.set_pixel(3 * TILE + x, 7, Color(0.7, 0.7, 0.75))
		img.set_pixel(4 * TILE + x, 7, Color(0.9, 0.9, 0.95))
	for x in range(3, 13):
		img.set_pixel(9 * TILE + x, 2, Color(0.85, 0.85, 0.9))
	for x in range(5, 11):
		img.set_pixel(10 * TILE + x, 4, Color(0.75, 0.3, 0.25))
	# chest gold band
	for x in range(2, 14):
		img.set_pixel(11 * TILE + x, 7, Color(0.9, 0.8, 0.3))
	# vault door keyhole
	for x in range(6, 10):
		img.set_pixel(16 * TILE + x, 7, Color(0.9, 0.8, 0.3))
	return ImageTexture.create_from_image(img)


# --- Entities -------------------------------------------------------------

func _register(e: Entity) -> void:
	entities.append(e)
	add_child(e)
	if e is Player:
		player = e


func entity_at(cell: Vector2i) -> Entity:
	for e in entities:
		if is_instance_valid(e) and e.grid_pos == cell:
			return e
	return null


# --- Items -------------------------------------------------------------

func _spawn_ground_item(item: Item, cell: Vector2i) -> void:
	var g := GroundItem.new()
	g.item = item
	g.grid_pos = cell
	ground_items[cell] = g
	add_child(g)


func _try_pickup(cell: Vector2i) -> void:
	if not ground_items.has(cell):
		return
	var g: GroundItem = ground_items[cell]
	if _gain_item(g.item):
		for i in current_map.item_spawns.size():
			var s: Dictionary = current_map.item_spawns[i]
			if s["pos"] == cell:
				current_map.item_spawns.remove_at(i)
				break
		ground_items.erase(cell)
		g.queue_free()


## Central "give the player an item" logic: stacks merge, weight/cap checks,
## hotbar auto-bind. Returns false if it couldn't fit.
func _gain_item(item: Item) -> bool:
	if item.stackable():
		for it in player.inventory:
			if it.id == item.id and it.quality == item.quality:
				it.count += item.count
				post_message("You pick up the %s. (x%d)" % [item.display_name(), it.count])
				_bind_item_hotbar(item.id)
				return true
	if player.carry_weight() + item.weight() > player.carry_capacity():
		post_message("Too heavy to carry the %s." % item.display_name())
		return false
	if player.inventory.size() >= Player.MAX_INVENTORY:
		post_message("Your pack is full.")
		return false
	player.inventory.append(item)
	_bind_item_hotbar(item.id)
	post_message("You pick up the %s." % item.display_name())
	return true


## Items auto-bind to the first empty hotbar slot.
func _bind_item_hotbar(id: String) -> void:
	for slot in player.hotbar:
		if slot["kind"] == "item" and slot["id"] == id:
			return
	for i in player.hotbar.size():
		if player.hotbar[i]["kind"] == "none":
			player.hotbar[i] = {"kind": "item", "id": id}
			return


## When the last of an item is consumed, clear its hotbar slots.
func hotbar_item_lost(id: String) -> void:
	if player.count_item(id) == 0:
		for i in player.hotbar.size():
			if player.hotbar[i]["kind"] == "item" and player.hotbar[i]["id"] == id:
				player.hotbar[i] = {"kind": "none", "id": ""}


func _finish_pickup(g: GroundItem) -> void:
	ground_items.erase(g.grid_pos)
	g.queue_free()


func cast_scroll(item: Item, user: Entity) -> void:
	match item.id:
		"scroll_flames":
			var power := int(item.def["power"] * ItemDB.QUALITY_MULT[item.quality])
			post_message("Flames burst around %s!" % user.display_name)
			for e in entities.duplicate():
				if is_instance_valid(e) and e != user and e.hostile:
					var d: Vector2i = e.grid_pos - user.grid_pos
					if absi(d.x) <= 2 and absi(d.y) <= 2:
						var dmg := randi_range(power / 2, power)
						e.take_damage(dmg)
						post_message("Flames sear the %s for %d." % [e.display_name, dmg])


# --- Turn system ----------------------------------------------------------

func _turn_cost() -> int:
	if current_depth == 0:
		var tile := tile_at(player.grid_pos)
		if SLOW_TILES.has(tile):
			return 60
		return 30
	return 0


func player_action(dir: Vector2i) -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	busy = true
	var old_map := current_map
	player.facing = dir
	if player.meditating:
		player.meditating = false
		post_message("Nyx breaks her meditation.")
	player.guarding = false
	var acted: bool = await attempt_move(player, dir)
	if acted:
		if is_instance_valid(player):
			_try_pickup(player.grid_pos)
			player.tick_resources()
			player.tick_skill_cooldowns()
			_check_special_tiles()
			var cost := _turn_cost()
			if cost > 0:
				advance_time(cost)
				_maybe_travel_encounter()
		if current_map != old_map:
			player._last_held = Vector2i.ZERO
			await get_tree().create_timer(0.15).timeout
		if is_instance_valid(player) and player.alive:
			await _resolve_enemy_turns()
			turn += 1
	busy = false


func _check_special_tiles() -> void:
	var t := tile_at(player.grid_pos)
	match t:
		"stairs_down":
			post_message("Stairs lead down into darkness. (Enter to descend)")
		"stairs_up":
			post_message("Stairs lead back up. (Enter to climb)")
		"dungeon_entrance":
			if current_map.is_threshold:
				post_message("The door hums with cold air. (Enter to descend)")
			else:
				var hint := ""
				var inst: Dictionary = dungeon_cache.get(_dungeon_id_at(player.grid_pos), {})
				if inst.is_empty():
					post_message("A dark maw opens in the hillside. What waits below is undecided. (Enter to approach)")
				elif int(inst.get("merchant_floor", -1)) != -1:
					post_message("A dark maw opens in the hillside... and something like old coin drifts up from below. (Enter to approach)")
				else:
					post_message("A dark maw opens in the hillside. The dark below smells of nothing at all. (Enter to approach)")
		"town":
			post_message("The town of Neverwinter. The gates stand open. (Enter to visit)")


func player_interact() -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	if _try_flee_ambush():
		return
	if current_map.is_threshold and tile_at(player.grid_pos) != "dungeon_entrance":
		exit_layer()
		post_message("Nyx retreats from the dungeon's mouth.")
		return
	var t := tile_at(player.grid_pos)
	match t:
		"stairs_down":
			busy = true
			layer_stack.append({"map": current_map, "depth": current_depth, "return_cell": player.grid_pos})
			var next_map: MapData
			var inst: Dictionary = dungeon_cache.get(dungeon_instance, {})
			var floors: Dictionary = inst.get("floors", {})
			if dungeon_instance != "" and floors.has(current_depth + 1):
				next_map = floors[current_depth + 1]
				post_message("The dungeon remembers this floor.")
			else:
				var mf: int = int(inst.get("merchant_floor", -1))
				var vf: int = int(inst.get("vault_floor", -1))
				next_map = DungeonGenerator.generate_floor(current_depth + 1, mf, vf)
			enter_map(next_map, current_depth + 1)
			post_message("Nyx descends to floor %d." % current_depth)
			await get_tree().create_timer(0.15).timeout
			busy = false
		"stairs_up":
			if current_depth <= 1:
				exit_layer()
				return
			busy = true
			var layer: Dictionary = layer_stack.pop_back()
			enter_map(layer["map"], layer["depth"])
			player.grid_pos = layer["return_cell"]
			player.snap()
			post_message("Nyx climbs to floor %d." % current_depth)
			await get_tree().create_timer(0.15).timeout
			busy = false
		"dungeon_entrance":
			busy = true
			var did: String = _dungeon_id_at(player.grid_pos)
			if current_map.is_threshold:
				enter_dungeon("res://maps/woods_dungeon.txt", did)
				post_message("Nyx enters the woods dungeon.")
			else:
				layer_stack.append({"map": current_map, "depth": current_depth, "return_cell": player.grid_pos})
				var threshold := AsciiMapLoader.load("res://maps/woods_threshold.txt")
				threshold.is_threshold = true
				enter_map(threshold, 0)
				post_message("Nyx stands before the dungeon's mouth. (Enter anywhere to retreat; the door leads down)")
			await get_tree().create_timer(0.15).timeout
			busy = false
		"town":
			busy = true
			layer_stack.append({"map": current_map, "depth": current_depth, "return_cell": player.grid_pos})
			enter_map(AsciiMapLoader.load("res://maps/neverwinter.txt"), 1)
			post_message("Nyx enters Neverwinter.")
			await get_tree().create_timer(0.15).timeout
			busy = false
		"lore_tablet":
			post_message(LORE_LINES.pick_random())
		"chest":
			_open_chest()
		"chest_open":
			post_message("Empty. Someone got here first — probably you.")
		"vault_door":                              # <- add from here...
			if player.count_item("vault_key") >= 1:
				player.consume_item("vault_key", 1)
				current_map.tiles[player.grid_pos] = "vault_open"
				_render_cell(player.grid_pos)
				post_message("The key turns. The vault breathes out cold, old air...")
				for i in randi_range(2, 3):
					var pool: Array[String] = ["potion_major", "sword", "armor_leather", "scroll_flames"]
					var item := ItemDB.make(pool.pick_random(), randi_range(3, 5), 1)
					if not _gain_item(item):
						_spawn_ground_item(item, player.grid_pos)
			else:
				post_message("Locked tight. Somewhere down here, something sells the key.")
		_:
			post_message("There is nothing to interact with here.")


## Containers: roll the loot pool, straight into the pack (if it fits).
func _open_chest() -> void:
	var pool: Array[String] = ["potion", "potion_major", "scroll_flames", "meat", "camp_supplies"]
	var id: String = pool.pick_random()
	var quality := 2
	var roll := randf()
	if roll < 0.05:
		quality = 4
	elif roll < 0.3:
		quality = 3
	var item := ItemDB.make(id, quality, 1)
	current_map.tiles[player.grid_pos] = "chest_open"
	_render_cell(player.grid_pos)
	post_message("The chest creaks open... %s!" % item.display_name())
	if not _gain_item(item):
		_spawn_ground_item(item, player.grid_pos)


func _render_cell(cell: Vector2i) -> void:
	map.set_cell(cell, 0, Vector2i(TILE_ATLAS[tile_at(cell)], 0))


func _maybe_travel_encounter() -> void:
	if current_depth != 0 or current_map.is_ambush or current_map.is_threshold:
		return
	if randf() > 0.12:
		return
	var roll := randi_range(0, 2)
	if roll < 2:
		_start_ambush()
	else:
		var finds: Array[String] = ["potion", "meat"]
		_spawn_ground_item(ItemDB.make(finds.pick_random(), 2, 1), player.grid_pos)
		post_message("You spot something half-buried here.")


func _start_ambush() -> void:
	layer_stack.append({"map": current_map, "depth": current_depth, "return_cell": player.grid_pos})
	var map_data := MapData.new()
	map_data.is_ambush = true
	var size := Vector2i(14, 11)
	map_data.size = size
	for x in size.x:
		for y in size.y:
			var edge := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			map_data.tiles[Vector2i(x, y)] = "wall" if edge else "floor"
	for i in 4:
		var c := random_open_cell(map_data)
		if c != Vector2i.ZERO:
			map_data.tiles[c] = "wall"
	map_data.player_spawn = Vector2i(size.x / 2, size.y / 2)
	map_data.tiles[map_data.player_spawn] = "floor"
	var ids: Array[String] = ["goblin", "goblin", "archer"]
	for i in randi_range(2, 3):
		map_data.enemy_spawns.append({"pos": _rim_cell(map_data), "id": ids.pick_random()})
	post_message("Ambush! Hostiles close in from all sides!")
	enter_map(map_data, current_depth)


func _rim_cell(map_data: MapData) -> Vector2i:
	for i in 100:
		var side := randi_range(0, 3)
		var c := Vector2i.ZERO
		match side:
			0: c = Vector2i(randi_range(1, map_data.size.x - 2), 1)
			1: c = Vector2i(randi_range(1, map_data.size.x - 2), map_data.size.y - 2)
			2: c = Vector2i(1, randi_range(1, map_data.size.y - 2))
			3: c = Vector2i(map_data.size.x - 2, randi_range(1, map_data.size.y - 2))
		if WALKABLE.has(map_data.tiles.get(c, "wall")) and entity_at(c) == null:
			return c
	return Vector2i(1, 1)


func _try_flee_ambush() -> bool:
	if layer_stack.is_empty() or not current_map.is_ambush:
		return false
	var on_edge := false
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if tile_at(player.grid_pos + d) == "wall":
			on_edge = true
			break
	if not on_edge:
		return false
	exit_layer()
	post_message("Nyx slips away from the ambush!")
	return true


# --- Rest ------------------------------------------------------------------

func player_rest() -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	if current_map.is_ambush:
		post_message("Too dangerous to rest here.")
		return
	if _enemy_near_sight():
		post_message("Enemies are too close to rest.")
		return
	if player.count_item("camp_supplies") < 1:
		post_message("You need camp supplies to rest. (Buy them in town, find them as loot.)")
		return
	busy = true
	player.consume_item("camp_supplies", 1)
	post_message("Nyx makes camp...")
	var total := 480
	var chunk := 30
	var chunks := total / chunk
	var elapsed := 0
	var interrupted := false
	while elapsed < total and not interrupted and is_instance_valid(player) and player.alive:
		advance_time(chunk)
		elapsed += chunk
		player.hp = mini(player.hp + maxi(1, player.max_hp() / chunks), player.max_hp())
		player.mana = minf(player.mana + player.max_mana() / float(chunks), player.max_mana())
		player.stamina = minf(player.stamina + 100.0 / float(chunks), 100.0)
		var interrupt_chance := 0.005 if tile_at(player.grid_pos) == "campfire" else 0.03
		if randf() < interrupt_chance:
			post_message("Nyx is roused by a sound in the night!")
			_start_ambush()
			interrupted = true
		await get_tree().create_timer(0.02).timeout
	if not interrupted and is_instance_valid(player) and player.alive:
		post_message("Nyx rests until morning, fully recovered.")
		save_game()
	elif is_instance_valid(player) and player.alive:
		post_message("The rest is broken off.")
	busy = false

func player_guard() -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	busy = true
	player.guarding = true
	post_message("Nyx takes a defensive stance.")
	player.tick_resources(1)
	advance_time(_turn_cost() if current_depth > 0 else 0)
	await _resolve_enemy_turns()
	turn += 1
	busy = false


func player_wait() -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	busy = true
	post_message("Nyx waits, catching her breath.")
	player.tick_resources(2)
	advance_time(_turn_cost() if current_depth > 0 else 0)
	await _resolve_enemy_turns()
	turn += 1
	busy = false


func player_toggle_meditation() -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	busy = true
	player.meditating = not player.meditating
	if player.meditating:
		post_message("Nyx begins meditating.")
		while player.meditating and is_instance_valid(player) and player.alive:
			player.mana = minf(player.mana + 6.0, player.max_mana())
			if _enemy_near_sight():
				player.meditating = false
				post_message("Nyx senses danger and stops meditating.")
				break
			if player.hunger < Player.STARVING_THRESHOLD:
				player.meditating = false
				post_message("Nyx is too hungry to focus on meditation.")
				break
			if Input.is_key_pressed(KEY_M):
				player.meditating = false
				post_message("Nyx stops meditating.")
				break
			player.tick_resources()
			player.tick_skill_cooldowns()
			advance_time(5)
			await get_tree().create_timer(0.15).timeout
			await _resolve_enemy_turns()
			turn += 1
	else:
		post_message("Nyx stops meditating.")
	busy = false


func _enemy_near_sight() -> bool:
	var radius: int = player.attributes["PER"] / 5 + 2
	for e in entities:
		if is_instance_valid(e) and e != player and e.hostile:
			var d: Vector2i = e.grid_pos - player.grid_pos
			if absi(d.x) <= radius and absi(d.y) <= radius:
				return true
	return false


func player_use_item(index: int) -> void:
	if busy or not is_instance_valid(player) or not player.alive:
		return
	if index >= player.inventory.size():
		return
	busy = true
	if player.meditating:
		player.meditating = false
		post_message("Nyx breaks her meditation.")
	player.guarding = false
	player.use_item(index)
	await get_tree().create_timer(0.08).timeout
	player.tick_resources()
	await _resolve_enemy_turns()
	turn += 1
	busy = false


func drop_item(index: int) -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	if index >= player.inventory.size():
		return
	var item: Item = player.inventory[index]
	if ground_items.has(player.grid_pos):
		post_message("No room to drop that here.")
		return
	var g := GroundItem.new()
	g.item = item
	g.grid_pos = player.grid_pos
	ground_items[player.grid_pos] = g
	add_child(g)
	player.inventory.remove_at(index)
	post_message("You drop the %s." % item.display_name())
func unequip_slot(slot: String) -> void:
	if not is_instance_valid(player):
		return
	var it: Item = player.equipped.get(slot)
	if it == null:
		return
	if player.inventory.size() >= Player.MAX_INVENTORY:
		post_message("Your pack is full — can't unequip.")
		return
	player.equipped.erase(slot)
	player.inventory.append(it)
	_bind_item_hotbar(it.id)
	post_message("You unequip the %s." % it.display_name())

func _talk_to(v: Villager) -> void:
	if v.def.has("root"):
		dialogue_ui.open_node(v, v.def["root"])
	elif v.def.has("stock"):
		shop_ui.open_shop(v)
	else:
		dialogue_ui.open(v.display_name, v.def["dialogue"])
func _bone_merchant_stock() -> Array:
	var stock: Array = [
		{"id": "potion_major", "quality": 3, "count": 3},
		{"id": "scroll_flames", "quality": 3, "count": 2},
		{"id": "sword", "quality": 4, "count": 1},
	]
	var inst: Dictionary = dungeon_cache.get(dungeon_instance, {})
	if int(inst.get("vault_floor", -1)) != -1:
		stock.append({"id": "vault_key", "quality": 2, "count": 1})
	return stock
func get_affinity(npc_id: String) -> int:
	return affinity.get(npc_id, 0)


func _add_affinity(npc_id: String, amount: int) -> void:
	affinity[npc_id] = clampi(get_affinity(npc_id) + amount, -100, 100)


## Dialogue option effects. Missing systems respond with flavor, not silence.
func _dialogue_effect(v: Villager, option: Dictionary) -> void:
	match String(option.get("effect", "end")):
		"end":
			dialogue_ui.close()
		"shop":
			dialogue_ui.close()
			shop_ui.open_shop(v)
		"lines":
			dialogue_ui._show_lines(option.get("lines", []), option.get("then", "root"))
		"flirt":
			_flirt(v)
		"quest":
			_quest_talk(v)
		"accept_quest":
			quests[option["quest"]] = 0
			post_message("Quest accepted: %s" % QuestDB.DEFS[option["quest"]]["title"])
			dialogue_ui.close()
		"turn_in":
			_turn_in(option["quest"])
		_:
			dialogue_ui._show_lines(["..."], "root")


func _flirt(v: Villager) -> void:
	var aff: int = get_affinity(v.npc_id)
	var chance: int = clampi(40 + player.attributes["CHA"] * 2 + aff / 4, 5, 95)
	if randi_range(0, 99) < chance:
		_add_affinity(v.npc_id, 3)
		dialogue_ui._show_lines([_flirt_success_line(aff)], "root")
	else:
		_add_affinity(v.npc_id, -2)
		dialogue_ui._show_lines([_flirt_fail_line(aff)], "root")


func _flirt_success_line(aff: int) -> String:
	if aff < 0:
		return "Mira raises an eyebrow. \"Bold. Wrong — but bold.\" ...She smiled, though."
	if aff < 20:
		return "Mira laughs despite herself. \"Careful, child. Words like that stick.\""
	return "Mira squeezes your hand. \"And if I said the feeling was mutual?\""


func _flirt_fail_line(aff: int) -> String:
	if aff < 0:
		return "Mira's eyes cool. \"Don't. Not today.\""
	return "Mira pats your arm kindly. \"Sweet, but no. Ask me when we're closer.\""
func on_enemy_killed(enemy_id: String) -> void:
	for qid in quests:
		var q: Dictionary = QuestDB.DEFS[qid]
		if q["type"] == "kill" and q["target_id"] == enemy_id:
			quests[qid] = int(quests[qid]) + 1
			post_message("Quest updated: %s (%d/%d)" % [q["title"], int(quests[qid]), int(q["amount"])])


func _quest_progress(qid: String, q: Dictionary) -> int:
	if q["type"] == "kill":
		return int(quests[qid])
	return mini(player.count_item(q["target_id"]), int(q["amount"]))


func quest_marker_for(npc_id: String) -> String:
	var def_ids: Array = NpcDB.DEFS.get(npc_id, {}).get("quests", [])
	var has_available := false
	var has_active := false
	for qid in def_ids:
		if quests_done.has(qid):
			continue
		if quests.has(qid):
			if _quest_progress(qid, QuestDB.DEFS[qid]) >= int(QuestDB.DEFS[qid]["amount"]):
				return "!"
			has_active = true
		else:
			has_available = true
	if has_available:
		return "?"
	if has_active:
		return "…"
	return ""


func _quest_talk(v: Villager) -> void:
	var def_ids: Array = NpcDB.DEFS.get(v.npc_id, {}).get("quests", [])
	for qid in def_ids:  # ready to turn in?
		if quests.has(qid) and not quests_done.has(qid):
			var q: Dictionary = QuestDB.DEFS[qid]
			if _quest_progress(qid, q) >= int(q["amount"]):
				dialogue_ui.show_node(v, {
					"text": "You actually did it. Here — as promised.",
					"options": [
						{"label": "Turn in: %s" % q["title"], "effect": "turn_in", "quest": qid},
						{"label": "Not yet", "effect": "end"}]})
				return
	for qid in def_ids:  # available to accept?
		if not quests.has(qid) and not quests_done.has(qid):
			var q: Dictionary = QuestDB.DEFS[qid]
			dialogue_ui.show_node(v, {
				"text": q["offer_text"],
				"options": [
					{"label": "Accept: %s" % q["title"], "effect": "accept_quest", "quest": qid},
					{"label": "Decline", "effect": "end"}]})
			return
	for qid in def_ids:  # in progress
		if quests.has(qid):
			var q: Dictionary = QuestDB.DEFS[qid]
			dialogue_ui.show_node(v, {
				"text": q.get("progress_text", "..."),
				"options": [{"label": "Back", "effect": "end"}]})
			return
	dialogue_ui.show_node(v, {
		"text": "No work today, child.",
		"options": [{"label": "Back", "effect": "end"}]})


func _turn_in(qid: String) -> void:
	var q: Dictionary = QuestDB.DEFS[qid]
	if q["type"] == "fetch":
		if player.count_item(q["target_id"]) < int(q["amount"]):
			post_message("Still waiting on that %s." % q["target_id"])
			return
		player.consume_item(q["target_id"], int(q["amount"]))
	quests.erase(qid)
	quests_done.append(qid)
	player.gold += int(q["reward_gold"])
	player.gain_xp(int(q["reward_xp"]))
	for r in q.get("reward_items", []):
		var item := ItemDB.make(r["id"], int(r.get("quality", 2)), int(r.get("count", 1)))
		if not _gain_item(item):
			_spawn_ground_item(item, player.grid_pos)
	post_message("Quest complete: %s! (+%d g, +%d XP)" % [q["title"], int(q["reward_gold"]), int(q["reward_xp"])])
	dialogue_ui.close()
func shop_buy(v: Villager, index: int) -> void:
	if index >= v.stock.size():
		return
	var entry: Dictionary = v.stock[index]
	if int(entry["count"]) <= 0:
		post_message("Sold out.")
		return
	var item := ItemDB.make(entry["id"], int(entry["quality"]), 1)
	var price: int = item.value()
	if player.gold < price:
		post_message("Not enough gold. (%d needed)" % price)
		return
	if player.carry_weight() + item.weight() > player.carry_capacity():
		post_message("Too heavy to carry.")
		return
	if player.inventory.size() >= Player.MAX_INVENTORY:
		post_message("Your pack is full.")
		return
	player.gold -= price
	entry["count"] = int(entry["count"]) - 1
	player.inventory.append(item)
	_bind_item_hotbar(item.id)
	post_message("You buy the %s for %d g." % [item.display_name(), price])


func shop_sell(v: Villager, index: int) -> void:
	if index >= player.inventory.size():
		return
	var item: Item = player.inventory[index]
	var price: int = item.value() / 2
	player.gold += price
	var sold := false
	for e in v.stock:
		if e["id"] == item.id and int(e["quality"]) == item.quality:
			e["count"] = int(e["count"]) + 1
			sold = true
	if not sold:
		v.stock.append({"id": item.id, "quality": item.quality, "count": 1})
	if item.stackable():
		item.count -= 1
		if item.count <= 0:
			player.inventory.remove_at(index)
	else:
		player.inventory.remove_at(index)
	post_message("You sell the %s for %d g." % [item.display_name(), price])


func _resolve_enemy_turns() -> void:
	_fast = true
	for e in entities.duplicate():
		if not is_instance_valid(e) or e == player or not e.alive:
			continue
		e.energy += e.speed()
		var actions := 0
		while is_instance_valid(e) and e.alive and e.energy >= 100.0 and actions < 8:
			var cost: int = await e.take_turn()
			e.energy -= maxf(float(cost), 0.0)
			actions += 1
		if is_instance_valid(e):
			e.tick_resources()
	_fast = false


func attempt_move(e: Entity, dir: Vector2i) -> bool:
	var target := e.grid_pos + dir
	var other := entity_at(target)
	if other != null and other != e:
		if other is Villager:
			_talk_to(other)
			return false
		if other.hostile != e.hostile:
			_attack(e, other)
			await get_tree().create_timer(0.08).timeout
			return true
		return false
	if not is_walkable(target):
		return false
	e.grid_pos = target
	e.slide()
	await get_tree().create_timer(0.012 if _fast else 0.05).timeout
	return true


func _attack(a: Entity, t: Entity) -> void:
	var chance: int = clampi(BASE_HIT + a.accuracy() - t.evasion(), 35, 95)
	if randi_range(0, 99) < chance:
		var dmg := randi_range(1, a.attack_power())
		dmg = maxi(1, dmg - t.defense())
		if randi_range(0, 99) < int(a.attributes.get("LUCK", 10)) / CRIT_DIVISOR:
			dmg *= 2
			post_message("CRITICAL! %s tears into the %s for %d!" % [a.display_name, t.display_name, dmg])
		else:
			post_message("%s hits %s for %d damage." % [a.display_name, t.display_name, dmg])
		if t.guarding:
			dmg = dmg / 2
			t.guarding = false
			post_message("%s's guard softens the blow!" % t.display_name)
		t.take_damage(dmg)
	else:
		post_message("%s swings at %s and misses." % [a.display_name, t.display_name])
		## True if a straight 8-directional line from `from` to `to` is unblocked by walls.
func has_clear_line(from: Vector2i, to: Vector2i) -> bool:
	var delta: Vector2i = to - from
	# Must be a straight line (same row, column, or perfect diagonal).
	if delta.x != 0 and delta.y != 0 and absi(delta.x) != absi(delta.y):
		return false
	var step := Vector2i(signi(delta.x), signi(delta.y))
	var cell := from + step
	while cell != to:
		if not is_walkable(cell):
			return false
		cell += step
	return true


## Ranged attack along a clear line; same math as a strike, no facing needed.
func _ranged_attack(a: Entity, t: Entity) -> void:
	post_message("The %s looses an arrow at %s!" % [a.display_name, t.display_name])
	_strike(a, t, 1.0, true)
