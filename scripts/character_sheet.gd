class_name CharacterSheet
extends CanvasLayer

var is_open := false

var panel: PanelContainer
var name_label: Label
var portrait: TextureRect
var doll: GridContainer
var attr_label: Label
var derived_label: Label


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
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)
	# Left: portrait + name
	var left := VBoxContainer.new()
	hbox.add_child(left)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 145)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(portrait)
	name_label = Label.new()
	left.add_child(name_label)
	# Middle: paper doll
	var mid := VBoxContainer.new()
	hbox.add_child(mid)
	var doll_title := Label.new()
	doll_title.text = "Equipment"
	mid.add_child(doll_title)
	doll = GridContainer.new()
	doll.columns = 3
	mid.add_child(doll)
	# Right: attributes + derived
	var right := VBoxContainer.new()
	hbox.add_child(right)
	attr_label = Label.new()
	right.add_child(attr_label)
	derived_label = Label.new()
	derived_label.custom_minimum_size = Vector2(190, 0)
	right.add_child(derived_label)
	var hint := Label.new()
	hint.text = "Click equipped gear to unequip.  C/Esc: close"
	hbox.add_child(hint)


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
		if event.keycode == KEY_C and not Game.inventory_open:
			toggle()
		elif is_open and event.keycode == KEY_ESCAPE:
			close()


func _refresh() -> void:
	var p := Game.player
	if not is_instance_valid(p):
		return
	name_label.text = "%s\nLevel %d" % [p.display_name, p.level]
	if ResourceLoader.exists("res://art/faces/nyx.png"):
		portrait.texture = load("res://art/faces/nyx.png")
	# Paper doll: weapon + armor are live; future slots are placeholders.
	for c in doll.get_children():
		c.queue_free()
	_doll_slot("weapon", p)
	_doll_slot("amulet", null, true)
	_doll_slot("ring", null, true)
	_doll_slot("armor", p)
	_doll_slot("ring2", null, true)
	_doll_slot("boots", null, true)
	# Attributes
	var lines: Array[String] = []
	for key in ATTR_ORDER:
		lines.append("%s  %d" % [ATTR_NAMES[key], p.attributes[key]])
	attr_label.text = "\n".join(lines)
	# Derived combat block
	derived_label.text = "ATK %d\nDEF %d\nACC %d\nEVA %d\nSPD %d\nCarry %d/%d\nHunger %d (%s)\nGold %d" % [
		p.attack_power(), p.defense(), p.accuracy(), p.evasion(), p.speed(),
		int(p.carry_weight()), p.carry_capacity(),
		int(p.hunger), p.hunger_stage(), p.gold]


func _doll_slot(slot: String, p: Player, future := false) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110, 44)
	if future:
		btn.text = "—"
		btn.disabled = true
		btn.tooltip_text = "Equipment slot: comes with the gear expansion."
	else:
		var it: Item = p.equipped.get(slot) as Item
		if it != null:
			var item_color: Color = it.color()
			btn.text = it.display_name()
			btn.tooltip_text = it.tooltip_text()
			var sb := StyleBoxFlat.new()
			sb.bg_color = item_color.darkened(0.3)
			sb.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", sb)
		else:
			btn.text = "(%s)" % slot
			btn.tooltip_text = "Nothing equipped."
		btn.pressed.connect(func() -> void:
			Game.unequip_slot(slot)
			_refresh())
	doll.add_child(btn)
