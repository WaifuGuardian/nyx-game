class_name HotbarUi
extends CanvasLayer

var slots: Array = []   # of Button


func _ready() -> void:
	layer = 15
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -76.0
	bar.offset_left = 8.0
	bar.offset_right = -8.0
	bar.offset_bottom = -8.0
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	for i in 10:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.focus_mode = Control.FOCUS_NONE
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed \
					and ev.button_index == MOUSE_BUTTON_LEFT \
					and ev.shift_pressed:
				Game.hotbar_clear_slot(i))
		btn.set_drag_forwarding(
			func(_pos: Vector2) -> Variant:
				var slot: Dictionary = Game.player.hotbar[i]
				if slot["kind"] == "none":
					return null
				var preview := Label.new()
				preview.text = "%d" % (i + 1) if i < 9 else "0"
				btn.set_drag_preview(preview)     # <- on the button, not self
				return {"from_hotbar": i},
			func(_pos: Vector2, data: Variant) -> bool:
				return _can_drop(data),
			func(_pos: Vector2, data: Variant) -> void:
				_drop(i, data))
		btn.pressed.connect(func() -> void: Game.use_hotbar(i))
		bar.add_child(btn)
		slots.append(btn)


func _drag_data(i: int) -> Variant:
	var slot: Dictionary = Game.player.hotbar[i]
	if slot["kind"] == "none":
		return null
	var preview := Label.new()
	preview.text = "%d" % (i + 1) if i < 9 else "0"
	slots[i].set_drag_preview(preview)
	return {"from_hotbar": i}


func _can_drop(data: Variant) -> bool:
	return data is Dictionary and (data.has("from_pack") or data.has("from_hotbar"))


func _drop(i: int, data: Variant) -> void:
	if data.has("from_pack"):
		Game.hotbar_bind_item(data["from_pack"], i)
	elif data.has("from_hotbar"):
		Game.hotbar_move(data["from_hotbar"], i)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(Game.player):
		return
	var p := Game.player
	for i in slots.size():
		var slot: Dictionary = p.hotbar[i]
		var btn: Button = slots[i]
		var key_label := "%d" % (i + 1) if i < 9 else "0"
		match slot["kind"]:
			"skill":
				var def: Dictionary = SkillDB.DEFS[slot["id"]]
				var label: String = def["name"]
				var cd: int = p.skill_cooldowns.get(slot["id"], 0)
				if cd > 0:
					label += " (%d)" % cd
				btn.text = "%s\n%s" % [key_label, label]
				btn.tooltip_text = "%s\nCosts %d %s, %d turn cooldown." % [
					def["name"], int(def["cost"]), def["cost_type"], int(def["cooldown"])]
			"item":
				var shown := ""
				for it in p.inventory:
					if it.id == slot["id"]:
						shown = it.display_name() + (" x%d" % it.count if it.stackable() else "")
						btn.tooltip_text = it.tooltip_text()
						break
				btn.text = "%s\n%s" % [key_label, shown if shown != "" else "(none)"]
			_:
				btn.text = "%s\n--" % key_label
				btn.tooltip_text = "Empty slot. Drag an item here from the pack."
