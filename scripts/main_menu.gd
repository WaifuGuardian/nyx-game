
extends Control
## The front door: New Game / Load / Settings / Credits / Exit.

var confirm: ConfirmationDialog
var credits_panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# --- Backdrop: flat color, then the painted image on top of it ---
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var bg_path := "res://art/background/kanin_bg.png"
	var bg_img := TextureRect.new()
	bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(bg_path):
		bg_img.texture = load(bg_path)
	else:
		push_error("[menu] background not found: " + bg_path)
	add_child(bg_img)

	# --- Everything below draws ON TOP of the backdrop ---
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "NYX RPG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a tale of the northern woods"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_spacer(20))

	box.add_child(_menu_button("New Game", _on_new_game))
	box.add_child(_menu_button("Load Game", _on_load_game, not SaveSystem.has_save()))
	box.add_child(_menu_button("Settings", _on_settings, true))
	box.add_child(_menu_button("Credits", _on_credits))
	box.add_child(_spacer(10))
	box.add_child(_menu_button("Exit", _on_exit))

	confirm = ConfirmationDialog.new()
	confirm.dialog_text = "This will erase your current save. Begin anew?"
	confirm.ok_button_text = "Begin anew"
	confirm.cancel_button_text = "Keep my save"
	confirm.confirmed.connect(_start_new)
	add_child(confirm)

	credits_panel = _build_credits()
	add_child(credits_panel)


func _menu_button(text: String, action: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 48)
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	if disabled:
		b.tooltip_text = "Coming soon."
	b.pressed.connect(action)
	return b


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _build_credits() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	for line in [
		"NYX RPG",
		"",
		"Code — WaifuGuardian",
		"Art — her name goes here",
		"Built with Godot Engine",
		"",
		"Thanks for playing.",
	]:
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var close_btn := Button.new()
	close_btn.text = "Back"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: p.visible = false)
	v.add_child(close_btn)
	return p


func _on_new_game() -> void:
	if SaveSystem.has_save():
		confirm.popup()   # ask before erasing a life
	else:
		_start_new()


func _start_new() -> void:
	Game.boot_mode = "new"
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_load_game() -> void:
	Game.boot_mode = "load"
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_settings() -> void:
	pass  # stubbed until the settings milestone


func _on_credits() -> void:
	credits_panel.visible = not credits_panel.visible


func _on_exit() -> void:
	get_tree().quit()
