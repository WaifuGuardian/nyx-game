class_name DialogueUi
extends CanvasLayer

var is_open := false
var speaker := ""
var villager: Villager = null
var current_node: Dictionary = {}
var lines: Array = []
var index := 0
var showing_options := false
var selected_option := 0

var panel: PanelContainer
var name_label: Label
var text_label: Label
var options_label: Label
var hint_label: Label


func _ready() -> void:
	layer = 30
	visible = false
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -190.0
	panel.offset_left = 60.0
	panel.offset_right = -60.0
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	name_label = Label.new()
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 60)
	options_label = Label.new()
	hint_label = Label.new()
	vbox.add_child(name_label)
	vbox.add_child(text_label)
	vbox.add_child(options_label)
	vbox.add_child(hint_label)


## Play a simple sequential conversation (old style).
func open(npc_name: String, dialogue_lines: Array) -> void:
	_begin(npc_name)
	lines = dialogue_lines
	current_node = {}
	showing_options = false
	_refresh()


## Open a node with choices (new style).
func open_node(v: Villager, node: Dictionary) -> void:
	show_node(v, node)


func show_node(v: Villager, node: Dictionary) -> void:
	_begin(v.display_name)
	villager = v
	_enter_node(node)

func _begin(npc_name: String) -> void:
	speaker = npc_name
	is_open = true
	Game.dialogue_open = true
	visible = true


func _enter_node(node: Dictionary) -> void:
	current_node = node
	lines = node.get("lines", [])
	index = 0
	showing_options = lines.is_empty()
	selected_option = 0
	_refresh()


func close() -> void:
	is_open = false
	Game.dialogue_open = false
	visible = false


func affinity_tag() -> String:
	if villager == null:
		return ""
	var a: int = Game.get_affinity(villager.npc_id)
	if a < -20:
		return " (hostile)"
	if a < 0:
		return " (cold)"
	if a < 20:
		return ""
	if a < 50:
		return " (warm)"
	if a < 80:
		return " (friendly)"
	return " (devoted)"


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if showing_options:
			var count: int = current_node.get("options", []).size()
			if event.keycode == KEY_UP:
				selected_option = maxi(selected_option - 1, 0)
				_refresh()
			elif event.keycode == KEY_DOWN:
				selected_option = mini(selected_option + 1, count - 1)
				_refresh()
			elif event.keycode == KEY_ENTER and count > 0:
				var chosen: Dictionary = current_node["options"][selected_option]
				Game._dialogue_effect(villager, chosen)
		else:
			if event.keycode == KEY_ENTER or event.keycode == KEY_E or event.keycode == KEY_SPACE:
				index += 1
				if index >= lines.size():
					_finish_lines()
				else:
					_refresh()
func _show_lines(new_lines: Array, then_node: String) -> void:
	current_node = {"then": then_node}
	lines = new_lines
	index = 0
	showing_options = false
	_refresh()

func _finish_lines() -> void:
	if current_node.is_empty():
		close()  # old-style sequential dialogue: done
		return
	var then: String = current_node.get("then", "root")
	if then == "close":
		close()
	else:
		var v: Villager = villager
		_enter_node(v.def["root"])  # default: back to the root node


func _refresh() -> void:
	name_label.text = speaker + affinity_tag()
	if showing_options:
		text_label.text = str(current_node.get("text", ""))
		var opts := ""
		var options: Array = current_node.get("options", [])
		for i in options.size():
			var marker := "> " if i == selected_option else "   "
			opts += "%s%d. %s\n" % [marker, i + 1, options[i]["label"]]
		options_label.text = opts
		hint_label.text = "Up/Down: choose   Enter: confirm"
	else:
		text_label.text = str(lines[index])
		options_label.text = ""
		hint_label.text = "Enter (%d/%d)" % [index + 1, lines.size()]
