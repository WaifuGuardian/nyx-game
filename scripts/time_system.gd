class_name TimeSystem
## The world clock: time advancement, hunger decay, and the day counter.


static func advance_time(g: GameState, minutes: int) -> void:
	g.world_minutes += minutes
	while g.world_minutes >= 24 * 60:
		g.world_minutes -= 24 * 60
		g.day += 1
	if is_instance_valid(g.player) and g.player.alive:
		var was_stage: String = g.player.hunger_stage()
		g.player.hunger = maxf(0.0, g.player.hunger - minutes * Player.HUNGER_RATE)
		var now_stage: String = g.player.hunger_stage()
		if now_stage != was_stage:
			g.post_message(g.player.hunger_stage_message(now_stage))
		if g.player.hunger <= 0.0:
			g.player.starve_accumulator += minutes
			while g.player.starve_accumulator >= 60 and g.player.alive:
				g.player.starve_accumulator -= 60
				g.post_message("Starvation gnaws at Nyx. (-1 HP)")
				g.player.take_damage(1)
	g.time_passed.emit(minutes)


static func clock_text(g: GameState) -> String:
	return "Day %d  %02d:%02d" % [g.day, g.world_minutes / 60, g.world_minutes % 60]


static func abs_time(g: GameState) -> int:
	return g.day * 1440 + g.world_minutes
