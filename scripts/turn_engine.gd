class_name TurnEngine
## The turn loop: player actions, enemy resolution, combat math, timing.

const BASE_HIT := 75
const CRIT_DIVISOR := 3  # LUCK / this = crit chance %
const STEP_TIME := 0.05          # player step pacing
const ENEMY_STEP_TIME := 0.012   # enemy phase pacing (cascades like dominoes)


static func player_action(g: GameState, dir: Vector2i) -> void:
	if g.busy or not is_instance_valid(g.player) or not g.player.alive:
		return
	g.busy = true
	var old_map := g.current_map
	g.player.facing = dir
	if g.player.meditating:
		g.player.meditating = false
		g.post_message("Nyx breaks her meditation.")
	g.player.guarding = false
	var acted: bool = await attempt_move(g, g.player, dir)
	if acted:
		if is_instance_valid(g.player):
			g._try_pickup(g.player.grid_pos)
			g.player.tick_resources()
			g.player.tick_skill_cooldowns()
			g._check_special_tiles()
			var cost := _turn_cost(g)
			if cost > 0:
				g.advance_time(cost)
				SpawnSystem.maybe_travel_encounter(g)
		if g.current_map != old_map:
			g.player._last_held = Vector2i.ZERO
			await g.get_tree().create_timer(0.15).timeout
		if is_instance_valid(g.player) and g.player.alive:
			await resolve_enemy_turns(g)
			g.turn += 1
	g.busy = false


static func player_guard(g: GameState) -> void:
	if g.busy or not is_instance_valid(g.player) or not g.player.alive:
		return
	g.busy = true
	g.player.guarding = true
	g.post_message("Nyx takes a defensive stance.")
	g.player.tick_resources(1)
	g.advance_time(_turn_cost(g) if g.current_depth > 0 else 0)
	await resolve_enemy_turns(g)
	g.turn += 1
	g.busy = false


static func player_wait(g: GameState) -> void:
	if g.busy or not is_instance_valid(g.player) or not g.player.alive:
		return
	g.busy = true
	g.post_message("Nyx waits, catching her breath.")
	g.player.tick_resources(2)
	g.advance_time(_turn_cost(g) if g.current_depth > 0 else 0)
	await resolve_enemy_turns(g)
	g.turn += 1
	g.busy = false


static func player_toggle_meditation(g: GameState) -> void:
	if g.busy or not is_instance_valid(g.player) or not g.player.alive:
		return
	g.busy = true
	g.player.meditating = not g.player.meditating
	if g.player.meditating:
		g.post_message("Nyx begins meditating.")
		while g.player.meditating and is_instance_valid(g.player) and g.player.alive:
			g.player.mana = minf(g.player.mana + 6.0, g.player.max_mana())
			if _enemy_near_sight(g):
				g.player.meditating = false
				g.post_message("Nyx senses danger and stops meditating.")
				break
			if g.player.hunger < Player.STARVING_THRESHOLD:
				g.player.meditating = false
				g.post_message("Nyx is too hungry to focus on meditation.")
				break
			if Input.is_key_pressed(KEY_M):
				g.player.meditating = false
				g.post_message("Nyx stops meditating.")
				break
			g.player.tick_resources()
			g.player.tick_skill_cooldowns()
			g.advance_time(5)
			await g.get_tree().create_timer(0.15).timeout
			await resolve_enemy_turns(g)
			g.turn += 1
	else:
		g.post_message("Nyx stops meditating.")
	g.busy = false


static func resolve_enemy_turns(g: GameState) -> void:
	g._fast = true
	for e in g.entities.duplicate():
		if not is_instance_valid(e) or e == g.player or not e.alive:
			continue
		e.energy += e.speed()
		var actions := 0
		while is_instance_valid(e) and e.alive and e.energy >= 100.0 and actions < 8:
			var cost: int = await e.take_turn()
			e.energy -= maxf(float(cost), 0.0)
			actions += 1
		if is_instance_valid(e):
			e.tick_resources()
	g._fast = false


static func _turn_cost(g: GameState) -> int:
	if g.current_depth == 0:
		var tile := g.tile_at(g.player.grid_pos)
		if GameState.SLOW_TILES.has(tile):
			return 60
		return 30
	return 0


static func attempt_move(g: GameState, e: Entity, dir: Vector2i) -> bool:
	var target := e.grid_pos + dir
	var other := g.entity_at(target)
	if other != null and other != e:
		if other is Villager:
			g._talk_to(other)
			return false
		if other.hostile != e.hostile:
			attack(g, e, other)
			await g.get_tree().create_timer(0.08).timeout
			return true
		return false
	if not g.is_walkable(target):
		return false
	e.grid_pos = target
	e.slide()
	await g.get_tree().create_timer(ENEMY_STEP_TIME if g._fast else STEP_TIME).timeout
	return true


static func attack(g: GameState, a: Entity, t: Entity) -> void:
	var chance: int = clampi(BASE_HIT + a.accuracy() - t.evasion(), 35, 95)
	if randi_range(0, 99) < chance:
		var raw := randi_range(1, a.attack_power())
		var dmg := maxi(1, raw - t.defense())
		if randi_range(0, 99) < int(a.attributes.get("LUCK", 10)) / CRIT_DIVISOR:
			dmg *= 2
			g.post_message("CRITICAL! %s tears into the %s for %d!" % [a.display_name, t.display_name, dmg])
		else:
			g.post_message("%s hits %s for %d damage." % [a.display_name, t.display_name, dmg])
		if t.guarding:
			dmg = dmg / 2
			t.guarding = false
			g.post_message("%s's guard softens the blow!" % t.display_name)
		t.take_damage(dmg)
	else:
		g.post_message("%s swings at %s and misses." % [a.display_name, t.display_name])


static func strike(g: GameState, a: Entity, t: Entity, mult: float, is_bolt := false) -> void:
	var verb := "bolt" if is_bolt else "strike"
	var chance: int = clampi(BASE_HIT + a.accuracy() - t.evasion(), 35, 95)
	if randi_range(0, 99) >= chance:
		g.post_message("%s's %s misses the %s." % [a.display_name, verb, t.display_name])
		return
	var raw := randi_range(1, a.attack_power())
	var dmg: int = maxi(1, int(raw * mult) - t.defense())
	dmg = maxi(dmg, int(ceil(raw * 0.4)))   # mitigation floor: armor eats at most 60%
	if randi_range(0, 99) < int(a.attributes.get("LUCK", 10)) / CRIT_DIVISOR:
		dmg *= 2
		g.post_message("CRITICAL! %s's %s crushes the %s for %d!" % [a.display_name, verb, t.display_name, dmg])
	else:
		g.post_message("%s's %s hits the %s for %d." % [a.display_name, verb, t.display_name, dmg])
	t.take_damage(dmg)


static func ranged_attack(g: GameState, a: Entity, t: Entity) -> void:
	g.post_message("The %s looses an arrow at %s!" % [a.display_name, t.display_name])
	strike(g, a, t, 1.0, true)


## True if a straight 8-directional line from `from` to `to` is unblocked by walls.
static func has_clear_line(g: GameState, from: Vector2i, to: Vector2i) -> bool:
	var delta: Vector2i = to - from
	if delta.x != 0 and delta.y != 0 and absi(delta.x) != absi(delta.y):
		return false
	var step := Vector2i(signi(delta.x), signi(delta.y))
	var cell := from + step
	while cell != to:
		if not g.is_walkable(cell):
			return false
		cell += step
	return true


static func _enemy_near_sight(g: GameState) -> bool:
	var radius: int = g.player.attributes["PER"] / 5 + 2
	for e in g.entities:
		if is_instance_valid(e) and e != g.player and e.hostile:
			var d: Vector2i = e.grid_pos - g.player.grid_pos
			if absi(d.x) <= radius and absi(d.y) <= radius:
				return true
	return false
