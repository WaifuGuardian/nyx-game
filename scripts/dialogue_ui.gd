class_name DialogueUi
extends CanvasLayer

var is_open := false
var speaker := ""
var lines: Array = []
var index := 0

var panel: PanelContainer
var name_label: Label
var text_label: Label
var hint_label: Label


func _ready() -> void:
	layer = 30
	visible = false
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -170.0
	panel.offset_left = 60.0
	panel.offset_right = -60.0
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	name_label = Label.new()
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 70)
	hint_label = Label.new()
	vbox.add_child(name_label)
	vbox.add_child(text_label)
	vbox.add_child(hint_label)


func open(npc_name: String, dialogue_lines: Array) -> void:
	speaker = npc_name
	lines = dialogue_lines
	index = 0
	is_open = true
	Game.dialogue_open = true
	visible = true
	_refresh()


func close() -> void:
	is_open = false
	Game.dialogue_open = false
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_E or event.keycode == KEY_SPACE:
			index += 1
			if index >= lines.size():
				close()
			else:
				_refresh()


func _refresh() -> void:
	name_label.text = speaker
	text_label.text = str(lines[index])
	hint_label.text = "Enter (%d/%d)" % [index + 1, lines.size()]
