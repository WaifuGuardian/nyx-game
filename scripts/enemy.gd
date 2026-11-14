class_name Enemy
extends Entity

var def: Dictionary = {}
var fleeing := false


func _init() -> void:
	hostile = true


func take_turn() -> int:
	if not is_instance_valid(Game.player):
		return 100
	if fleeing:
		await _flee()
		return 100
	var to_player: Vector2i = Game.player.grid_pos - grid_pos
	var dist := absi(to_player.x) + absi(to_player.y)
	var role: String = def.get("role", "melee")
	if role == "ranged" and dist == 2:
		var away := Vector2i(-signi(to_player.x), -signi(to_player.y))
		await Game.attempt_move(self, away)
		return 100
	if dist <= 8:
		var dir := Vector2i(signi(to_player.x), signi(to_player.y))
		if not await Game.attempt_move(self, dir):
			var alt := Vector2i(signi(to_player.y), signi(to_player.x))
			await Game.attempt_move(self, alt)
		return 100
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	await Game.attempt_move(self, dirs.pick_random())
	return 100


func _flee() -> void:
	var to_player: Vector2i = Game.player.grid_pos - grid_pos
	if absi(to_player.x) + absi(to_player.y) >= 10:
		Game.post_message("The %s escapes!" % display_name)
		_escape()
		return
	var dir := Vector2i(-signi(to_player.x), -signi(to_player.y))
	if not await Game.attempt_move(self, dir):
		var alt := Vector2i(-signi(to_player.y), -signi(to_player.x))
		await Game.attempt_move(self, alt)


func _escape() -> void:
	alive = false
	Game.entities.erase(self)
	queue_free()


func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if not alive or fleeing:
		return
	var morale: int = def.get("morale", 50)
	if hp > 0 and hp < max_hp() * 3 / 10 and randi_range(0, 99) < 100 - morale:
		fleeing = true
		Game.post_message("The %s turns to flee!" % display_name)


func die() -> void:
	Game.post_message("The %s dies." % display_name)
	if is_instance_valid(Game.player):
		Game.player.gain_xp(def.get("xp", 5))
	Game.on_enemy_killed(def["id"])
	Game.roll_loot(self)
	super.die()
