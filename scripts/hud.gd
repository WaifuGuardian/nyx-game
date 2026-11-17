class_name Hud
extends CanvasLayer

var stats_label: Label
var attr_label: Label
var xp_label: Label
var equip_label: Label
var hotbar_label: Label
var inv_label: Label
var log_label: Label
var quests_label: Label
var hotbar := HotbarUi.new()
	

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	stats_label = Label.new()
	attr_label = Label.new()
	xp_label = Label.new()
	equip_label = Label.new()
	hotbar_label = Label.new()
	inv_label = Label.new()
	log_label = Label.new()
	quests_label = Label.new()
	vbox.add_child(quests_label)
	vbox.add_child(stats_label)
	vbox.add_child(attr_label)
	vbox.add_child(xp_label)
	vbox.add_child(equip_label)
	vbox.add_child(hotbar_label)
	vbox.add_child(inv_label)
	vbox.add_child(log_label)
	Game.dialogue_ui = DialogueUi.new()
	add_child(Game.dialogue_ui)
	Game.shop_ui = ShopUi.new()
	add_child(Game.shop_ui)
	var inv_ui := InventoryUi.new()
	add_child(inv_ui)
	var sheet := CharacterSheet.new()
	add_child(sheet)
	add_child(hotbar)
	var pause := PauseMenu.new()
	add_child(pause)


func _process(_delta: float) -> void:
	if not is_instance_valid(Game.player):
		stats_label.text = "You died. Ctrl+L: load last rest, Ctrl+N: new game"
		for l in [attr_label, xp_label, equip_label, hotbar_label, inv_label]:
			l.text = ""
		return
	var p := Game.player
	stats_label.text = "%s   LVL %d   HP %d/%d   ST %d/100   MP %d/%d   DEF %d" % [
		Game.clock_text(), p.level, p.hp, p.max_hp(), int(p.stamina),
		int(p.mana), int(p.max_mana()), p.defense()]
	attr_label.text = "STR %d  CON %d  DEX %d  PER %d\nWIL %d  MAG %d  LUCK %d  CHA %d" % [
		p.attributes["STR"], p.attributes["CON"], p.attributes["DEX"], p.attributes["PER"],
		p.attributes["WIL"], p.attributes["MAG"], p.attributes["LUCK"], p.attributes["CHA"]]
	xp_label.text = "XP %d/%d   Gold %d   Hunger %d (%s)   Wt %d/%d%s" % [
		p.xp, p.xp_to_next(), p.gold, int(p.hunger), p.hunger_stage(),
		int(p.carry_weight()), p.carry_capacity(),
		"  ENCUMBERED!" if p.encumbered() else ""]
	var w: Item = p.equipped.get("weapon")
	var a: Item = p.equipped.get("armor")
	equip_label.text = "Wpn: %s | Arm: %s" % [
		w.display_name() if w != null else "none",
		a.display_name() if a != null else "none"]
	# --- Hotbar: 9 slots, skills with cooldowns, items with counts ---
	var hb := ""
	for i in p.hotbar.size():
		var slot: Dictionary = p.hotbar[i]
		var label := "--"
		if slot["kind"] == "skill":
			label = SkillDB.DEFS[slot["id"]]["name"]
			if p.skill_cooldowns.get(slot["id"], 0) > 0:
				label += "(%d)" % p.skill_cooldowns[slot["id"]]
		elif slot["kind"] == "item":
			for it in p.inventory:
				if it.id == slot["id"]:
					label = it.display_name() + (" x%d" % it.count if it.stackable() else "")
					break
		hb += "%d:%s  " % [i + 1, label]
	hotbar_label.text = hb
	var qtext := ""
	for qid in Game.quests:
		var q: Dictionary = QuestDB.DEFS[qid]
		qtext += "%s: %s %d/%d\n" % [q["title"], q["target_id"], Game._quest_progress(qid, q), int(q["amount"])]
	quests_label.text = qtext
	# --- Inventory list ---
	var lines := ""
	for i in p.inventory.size():
		var extra := ""
		if p.inventory[i].stackable():
			extra = " x%d" % p.inventory[i].count
		lines += "%d. %s%s\n" % [i + 1, p.inventory[i].display_name(), extra]
	inv_label.text = lines + "I: inv  C: char  G: guard  X: wait  R: rest  M: meditate  Enter: interact"
	var log_lines: Array[String] = []
	var start := maxi(0, Game.message_log.size() - 6)
	for i in range(start, Game.message_log.size()):
		log_lines.append(Game.message_log[i])
	log_label.text = "\n".join(log_lines)
