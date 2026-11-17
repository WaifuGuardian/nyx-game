class_name CharacterSheet
extends CanvasLayer

var is_open := false

var panel: PanelContainer
var name_label: Label
var doll_body: TextureRect
var doll_legs: TextureRect
var doll_chest: TextureRect
var doll: Control
var doll_legs_slot: Button
var doll_chest_slot: Button
var attr_box: VBoxContainer
var derived_label: Label
const ATTR_HELP := {
	"STR": "Strength — melee damage and carry capacity. Every 4 points: +1 attack power.",
	"CON": "Constitution — health, stamina, and toughness. Every point: +2 max HP. Every 5: +1 defense.",
	"DEX": "Dexterity — accuracy, evasion, and turn speed. Faster hands, harder to hit.",
	"PER": "Perception — sight radius, spotting, and ranged aim (when ranged arrives).",
	"WIL": "Will — mana pool and resistance to mental effects. Every point: +2 max mana.",
	"MAG": "Magic — spell power and what spells you can cast. (Spells coming soon.)",
	"LUCK": "Luck — critical hit chance and loot fortune. Every 3 points: +1% crit.",
	"CHA": "Charisma — flirting, bartering, recruitment, and first impressions.",
}
const ATTR_ORDER: Array[String] = ["STR", "CON", "DEX", "PER", "WIL", "MAG", "LUCK", "CHA"]
const ATTR_NAMES := {"STR": "Strength", "CON": "Constitution", "DEX": "Dexterity",
	"PER": "Perception", "WIL": "Will", "MAG": "Magic", "LUCK": "Luck", "CHA": "Charisma"}


func _ready() -> void:
	layer = 20
	visible = false
	panel = PanelContainer.new()
	panel.position = Vector2(180, 70)
	add_child(panel)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)
	

	# --- Left: the layered paper doll ---
	var left := VBoxContainer.new()
	hbox.add_child(left)
	doll = Control.new()
	doll.custom_minimum_size = Vector2(190, 404)   # 760x1616 at 0.25 scale
	doll.clip_contents = true
	left.add_child(doll)
	doll_body = _doll_layer_rect("res://art/doll/nyx_doll.png")
	doll_legs = _doll_layer_rect(null)
	doll_chest = _doll_layer_rect(null)
	# name + level under the doll
	name_label = Label.new()
	left.add_child(name_label)

	# --- Middle: paper doll slots (click to unequip) ---
	var mid := VBoxContainer.new()
	hbox.add_child(mid)
	var doll_title := Label.new()
	doll_title.text = "Equipment"
	mid.add_child(doll_title)
	doll_chest_slot = _slot_button()
	doll_legs_slot = _slot_button()
	var slot_hint := Label.new()
	mid.add_child(doll_chest_slot)
	var spacer := Label.new()
	spacer.text = "  "
	mid.add_child(spacer)
	mid.add_child(doll_legs_slot)
	var amulet_btn := _future_slot("Amulet")
	mid.add_child(amulet_btn)
	var boots_btn := _future_slot("Boots")
	mid.add_child(boots_btn)
	slot_hint.text = "Click equipped gear to unequip."
	mid.add_child(slot_hint)

	# --- Right: attributes + derived ---
	var right := VBoxContainer.new()
	hbox.add_child(right)
	attr_box = VBoxContainer.new()
	right.add_child(attr_box)
	derived_label = Label.new()
	derived_label.custom_minimum_size = Vector2(190, 0)
	right.add_child(derived_label)

	var hint := Label.new()
	hint.text = "C/Esc: close"
	hbox.add_child(hint)


func _doll_layer_rect(path) -> TextureRect:
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if path is String and path != "":
		tr.texture = load(path)
	doll.add_child(tr)
	return tr


func _slot_button() -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(110, 40)
	return btn


func _future_slot(slot_name: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "—"
	btn.disabled = true
	btn.tooltip_text = "%s slot: comes with the gear expansion." % slot_name
	return btn


func toggle() -> void:
	is_open = not is_open
	Game.inventory_open = is_open
	visible = is_open
	if is_open:
		_refresh()


func close() -> void:
	is_open = false
	Game.inventory_open = false
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Game.dialogue_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			if is_open:
				close()
			elif not Game.inventory_open:
				toggle()
		elif is_open and event.keycode == KEY_ESCAPE:
			close()
		elif is_open and event.keycode == KEY_ESCAPE:
			close()


func _refresh() -> void:
	var p := Game.player
	if not is_instance_valid(p):
		return
	name_label.text = "%s\nLevel %d" % [p.display_name, p.level]
	# --- Doll layers: base body -> legs -> chest ---
	_set_layer(doll_body, "res://art/doll/nyx_doll.png")
	_set_layer(doll_legs, _layer_of(p.equipped.get("legs")))
	_set_layer(doll_chest, _layer_of(p.equipped.get("chest")))
	# --- Slot buttons mirror the doll ---
	_fill_slot(doll_chest_slot, p.equipped.get("chest"), "chest")
	_fill_slot(doll_legs_slot, p.equipped.get("legs"), "legs")
	# --- Attributes ---
	for c in attr_box.get_children():
		c.queue_free()
	for key in ATTR_ORDER:
		var row := Label.new()
		row.text = "%s  %d" % [ATTR_NAMES[key], p.attributes[key]]
		row.tooltip_text = ATTR_HELP[key]
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		attr_box.add_child(row)
	# --- Derived combat block ---
	derived_label.text = "ATK %d\nDEF %d\nACC %d\nEVA %d\nSPD %d\nCarry %d/%d\nHunger %d (%s)\nGold %d" % [
		p.attack_power(), p.defense(), p.accuracy(), p.evasion(), p.speed(),
		int(p.carry_weight()), p.carry_capacity(),
		int(p.hunger), p.hunger_stage(), p.gold]


func _layer_of(it) -> String:
	if it is Item and it.def.get("doll_layer", "") != "":
		return it.def["doll_layer"]
	return ""


func _set_layer(tr: TextureRect, path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		tr.texture = load(path)
	else:
		tr.texture = null


func _fill_slot(btn: Button, it, slot: String) -> void:
	if it is Item:
		btn.text = it.display_name()
		btn.tooltip_text = it.tooltip_text()
		btn.disabled = false
		btn.pressed.connect(func() -> void:
			Game.unequip_slot(slot)
			_refresh())
	else:
		btn.text = "(%s)" % slot
		btn.tooltip_text = "Nothing equipped."
		btn.disabled = true
