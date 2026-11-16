class_name Player
extends Entity

const MAX_INVENTORY := 10
const XP_PER_LEVEL := 40
const HUNGER_RATE := 100.0 / 2880.0
const STARVING_THRESHOLD := 15.0

var inventory: Array[Item] = []
var equipped: Dictionary = {}  # "weapon": Item, "armor": Item
var xp := 0
var level := 1
var hunger := 100.0
var starve_accumulator := 0
var gold := 300
var facing := Vector2i(1, 0)
var hotbar: Array = []  # 9 slots: {"kind": "skill"/"item"/"none", "id": String}
var skill_cooldowns: Dictionary = {}  # skill id -> turns remaining
var _last_held := Vector2i.ZERO


func _init() -> void:
	display_name = "Nyx"
	attributes["STR"] = 40
	attributes["CON"] = 40
	attributes["DEX"] = 40
	attributes["WIL"] = 40
	attributes["PER"] = 40
	attributes["LUCK"] = 40
	token_size = 1.5
	show_ring = false
	ring_color = Color(0.85, 0.7, 0.3)
	set_face("res://art/faces/nyx.png")
	hp = max_hp()
	mana = max_mana()
	equipped = {
		"chest": ItemDB.make("cloth_top"),
		"legs": ItemDB.make("cloth_legs"),
	}
	for id in ["power_strike", "cleave", "firebolt", "mend"]:
		hotbar.append({"kind": "skill", "id": id})
	while hotbar.size() < 10:
		hotbar.append({"kind": "none", "id": ""})


func _process(_delta: float) -> void:
	if Game.inventory_open or Game.dialogue_open:
		return
	var held := Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		held.y -= 1
	if Input.is_action_pressed("ui_down"):
		held.y += 1
	if Input.is_action_pressed("ui_left"):
		held.x -= 1
	if Input.is_action_pressed("ui_right"):
		held.x += 1
	held = Vector2i(clampi(held.x, -1, 1), clampi(held.y, -1, 1))
	if held != Vector2i.ZERO and held != _last_held:
		Game.player_action(held)
	_last_held = held


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if Game.inventory_open or Game.dialogue_open:
			return
		if event.keycode == KEY_G:
			Game.player_guard()
		elif event.keycode == KEY_ENTER:
			Game.player_interact()
		elif event.keycode == KEY_X:
			Game.player_wait()
		elif event.keycode == KEY_R:
			Game.player_rest()
		elif event.keycode == KEY_M:
			Game.player_toggle_meditation()
		elif event.keycode == KEY_S and event.ctrl_pressed:
			Game.save_game()
		elif event.keycode == KEY_L and event.ctrl_pressed:
			Game.load_game()
		elif event.keycode == KEY_N and event.ctrl_pressed:
			Game.start_new_game()
		else:
			var idx: int = event.keycode - KEY_1
			if idx >= 0 and idx < 9:
				Game.use_hotbar(idx)
			elif event.keycode == KEY_0:
				Game.use_hotbar(9)


# --- Hunger ---------------------------------------------------------------

func hunger_stage() -> String:
	if hunger >= 80.0:
		return "full"
	if hunger >= 40.0:
		return "normal"
	if hunger >= STARVING_THRESHOLD:
		return "hungry"
	if hunger > 0.0:
		return "starving"
	return "famished"


func hunger_stage_message(stage: String) -> String:
	match stage:
		"full":
			return "Nyx is full."
		"normal":
			return "Nyx's appetite settles into routine."
		"hungry":
			return "Nyx is getting hungry. Food would help."
		"starving":
			return "Nyx is STARVING. Eat, or she will waste away."
		_:
			return "Nyx is famished. Starvation gnaws at her."


func eat(nutrition: int) -> void:
	hunger = minf(hunger + float(nutrition), 100.0)


func count_item(id: String) -> int:
	var total := 0
	for it in inventory:
		if it.id == id:
			total += it.count
	return total


func consume_item(id: String, amount: int) -> void:
	var left := amount
	for it in inventory.duplicate():
		if left <= 0:
			return
		if it.id == id:
			var take := mini(left, it.count)
			it.count -= take
			left -= take
			if it.count <= 0:
				inventory.erase(it)
	Game.hotbar_item_lost(id)


# --- Derived stats ----------------------------------------------------------

func attack_power() -> int:
	var atk := 0
	var w: Item = equipped.get("weapon")
	if w != null:
		atk = int(w.def.get("atk", 0) * ItemDB.QUALITY_MULT[w.quality])
	return 1 + int(attributes["STR"] / 4.0) + atk


func defense() -> int:
	var d: int = super.defense()
	for slot in ["chest", "legs"]:
		var a: Item = equipped.get(slot) as Item
		if a != null and a.def.get("kind", "") == "armor":
			d += int(a.def.get("def", 0) * ItemDB.QUALITY_MULT[a.quality])
	return d


func carry_capacity() -> int:
	return 20 + attributes["STR"] * 3


func carry_weight() -> float:
	var w := 0.0
	for it in inventory:
		w += it.weight()
	for k in equipped:
		w += equipped[k].weight()
	return w


func encumbered() -> bool:
	return carry_weight() > carry_capacity()


func accuracy() -> int:
	var a: int = super.accuracy()
	if encumbered():
		a = int(a * 0.8)
	if hunger < STARVING_THRESHOLD:
		a = int(a * 0.8)
	return a


func evasion() -> int:
	var e: int = super.evasion()
	if encumbered():
		e = int(e * 0.8)
	if hunger < STARVING_THRESHOLD:
		e = int(e * 0.8)
	return e


# --- Progression ------------------------------------------------------------

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		_level_up()


func xp_to_next() -> int:
	return level * XP_PER_LEVEL


func _level_up() -> void:
	attributes["CON"] += 1
	if level % 2 == 0:
		attributes["STR"] += 1
	hp = mini(hp + 5, max_hp())
	Game.post_message("Nyx reaches level %d! (+1 CON)" % level)


func tick_skill_cooldowns() -> void:
	for k in skill_cooldowns:
		if skill_cooldowns[k] > 0:
			skill_cooldowns[k] -= 1


# --- Items ------------------------------------------------------------

func use_item(index: int) -> void:
	var item: Item = inventory[index]
	match String(item.def["kind"]):
		"potion":
			hp = mini(hp + int(item.def["heal"]), max_hp())
			_consume(item)
			Game.post_message("You drink the %s. (+%d HP)" % [item.display_name(), int(item.def["heal"])])
		"food":
			eat(int(item.def["nutrition"]))
			_consume(item)
			Game.post_message("You eat the %s. (+%d food)" % [item.display_name(), int(item.def["nutrition"])])
		"scroll":
			Game.cast_scroll(item, self)
			_consume(item)
		"weapon", "armor":
			var slot: String = item.def.get("slot", "chest")
			var old: Item = equipped.get(slot)
			equipped[slot] = item
			if old != null:
				inventory[index] = old
			else:
				inventory.erase(item)
			Game.post_message("You equip the %s." % item.display_name())
		"supply":
			Game.post_message("Camp supplies are used automatically when resting. (R)")
		"material":
			Game.post_message("Raw material. For crafting and selling, later.")


func _consume(item: Item) -> void:
	if item.stackable():
		item.count -= 1
		if item.count <= 0:
			inventory.erase(item)
			Game.hotbar_item_lost(item.id)
	else:
		inventory.erase(item)
		Game.hotbar_item_lost(item.id)


func die() -> void:
	Game.post_message("Nyx has fallen on turn %d. (Ctrl+L: load last rest, Ctrl+N: new game)" % Game.turn)
	print("You died on turn %d." % Game.turn)
	super.die()
