class_name ShopUi
extends CanvasLayer

var open := false
var villager: Villager = null
var sell_mode := false
var selected := 0

var panel: PanelContainer
var title_label: Label
var list_label: Label
var detail_label: Label


func _ready() -> void:
	layer = 30
	visible = false
	panel = PanelContainer.new()
	panel.position = Vector2(260, 80)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	title_label = Label.new()
	list_label = Label.new()
	list_label.custom_minimum_size = Vector2(320, 0)
	detail_label = Label.new()
	detail_label.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(title_label)
	vbox.add_child(list_label)
	vbox.add_child(detail_label)


func open_shop(v: Villager) -> void:
	villager = v
	open = true
	sell_mode = false
	selected = 0
	Game.dialogue_open = true
	visible = true
	_refresh()


func close() -> void:
	open = false
	Game.dialogue_open = false
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
		elif event.keycode == KEY_TAB:
			sell_mode = not sell_mode
			selected = 0
		elif event.keycode == KEY_UP:
			selected = maxi(selected - 1, 0)
		elif event.keycode == KEY_DOWN:
			selected = mini(selected + 1, _list_size() - 1)
		elif event.keycode == KEY_ENTER:
			if sell_mode:
				Game.shop_sell(villager, selected)
			else:
				Game.shop_buy(villager, selected)
		selected = clampi(selected, 0, maxi(0, _list_size() - 1))
		_refresh()


func _list_size() -> int:
	if villager == null:
		return 0
	if sell_mode:
		return Game.player.inventory.size()
	return villager.stock.size()


func _refresh() -> void:
	if villager == null:
		return
	title_label.text = "%s   |   Your gold: %d   |   %s (Tab to switch)" % [
		villager.display_name, Game.player.gold, "SELLING" if sell_mode else "BUYING"]
	var lines := ""
	if sell_mode:
		var inv: Array[Item] = Game.player.inventory
		for i in inv.size():
			var marker := "> " if i == selected else "   "
			lines += "%s%d. %s   sells for %d\n" % [
				marker, i + 1, inv[i].display_name(), inv[i].value() / 2]
		list_label.text = lines
		if selected < inv.size():
			detail_label.text = "%s\nWeight: %.1f" % [inv[selected].display_name(), inv[selected].weight()]
	else:
		for i in villager.stock.size():
			var e: Dictionary = villager.stock[i]
			var marker := "> " if i == selected else "   "
			var item := ItemDB.make(e["id"], e["quality"])
			var tag := "SOLD OUT" if int(e["count"]) <= 0 else "x%d" % int(e["count"])
			lines += "%s%s   %s   %d g\n" % [marker, item.display_name(), tag, item.value()]
		list_label.text = lines
		if selected < villager.stock.size():
			var e: Dictionary = villager.stock[selected]
			var item := ItemDB.make(e["id"], e["quality"])
			detail_label.text = "%s\nCosts %d g. You have %d g." % [
				item.display_name(), item.value(), Game.player.gold]
