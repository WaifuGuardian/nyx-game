class_name InventoryUi
extends CanvasLayer

var is_open := false

var panel: PanelContainer
var title_label: Label
var grid: GridContainer


func _ready() -> void:
	layer = 20
	visible = false
	panel = PanelContainer.new()
	panel.position = Vector2(240, 100)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	title_label = Label.new()
	vbox.add_child(title_label)
	grid = GridContainer.new()
	grid.columns = 5
	vbox.add_child(grid)
	var hint := Label.new()
	hint.text = "Click: use/equip   Right-click: drop   Drag to hotbar: bind   I/Esc: close"
	vbox.add_child(hint)


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
		if event.keycode == KEY_I:
			toggle()
		elif is_open and event.keycode == KEY_ESCAPE:
			close()


func _refresh() -> void:
	var p := Game.player
	if not is_instance_valid(p):
		return
	title_label.text = "== PACK ==   %d / %d weight   Gold: %d" % [
		int(p.carry_weight()), p.carry_capacity(), p.gold]
	for c in grid.get_children():
		c.queue_free()
	for i in p.inventory.size():
		var item: Item = p.inventory[i]
		var slot := _make_slot(item)
		var idx := i
		slot.pressed.connect(func() -> void:
			Game.player_use_item(idx)
			_refresh())
		slot.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				Game.drop_item(idx)
				_refresh())
		slot.set_drag_forwarding(
			func(_pos: Vector2) -> Variant:
				var preview := ColorRect.new()
				preview.color = item.color()
				preview.custom_minimum_size = Vector2(40, 40)
				slot.set_drag_preview(preview)
				return {"from_pack": idx},
			func(_pos: Vector2, _data: Variant) -> bool:
				return true,
			func(_pos: Vector2, _data: Variant) -> void:
				pass)
		grid.add_child(slot)
	var leftover := (5 - p.inventory.size() % 5) if p.inventory.size() % 5 != 0 else 0
	for i in leftover:
		grid.add_child(_empty_slot())


func _make_slot(item: Item) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(56, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = item.tooltip_text()
	var sb := StyleBoxFlat.new()
	sb.bg_color = item.color().darkened(0.35)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.9, 0.8, 0.4).lerp(Color(0.5, 0.5, 0.55), float(6 - item.quality) / 6.0)
	sb.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	if item.stackable():
		btn.text = "x%d" % item.count
	return btn


func _empty_slot() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(56, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.14)
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("disabled", sb)
	return btn
