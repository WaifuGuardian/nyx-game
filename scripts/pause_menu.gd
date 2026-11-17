class_name PauseMenu
extends CanvasLayer

var is_open := false

var panel: PanelContainer
var resume_btn: Button


func _ready() -> void:
	layer = 40
	visible = false
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(260, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_btn("Resume", toggle))
	v.add_child(_btn("Load Game", func() -> void:
		Game.boot_mode = "load"
		get_tree().change_scene_to_file("res://Main.tscn")))
	v.add_child(_btn("Main Menu", func() -> void:
		get_tree().change_scene_to_file("res://MainMenu.tscn")))
	v.add_child(_btn("Exit Game", func() -> void: get_tree().quit()))


func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func toggle() -> void:
	is_open = not is_open
	visible = is_open
	Game.inventory_open = is_open   # reuse the modal flag: input freezes while paused


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if Game.dialogue_open:
				return
			toggle()
