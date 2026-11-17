# FEATURE CHECKLIST
*Verify these exist after every full-file replacement. Ctrl+F is your friend.*

## Autoload: game.gd (class_name GameState) — the state owner:
- state: player, entities, current_map/depth, layer_stack, ground_items,
  quests/quests_done, affinity, dungeon_cache/instance, world_minutes/day,
  dialogue_ui, shop_ui, busy/inventory_open/dialogue_open, _fast
- delegates: TimeSystem (advance_time/clock_text/abs_time),
  SaveSystem (save/load/has_save/delete_save),
  TurnEngine (player_action/guard/wait/meditation, _resolve_enemy_turns,
  _turn_cost, attempt_move, _attack, _strike, _ranged_attack, has_clear_line,
  _enemy_near_sight), SpawnSystem (encounters, ambush, flee, roll_loot,
  _free_adjacent_cells, random_open_cell)
- still local: post_message, new_game, use_hotbar, _cast_skill, map handling
  (enter_overworld/dungeon, exit_layer, enter_map, _render_map, tileset),
  items (_try_pickup/_gain_item/_bind_item_hotbar/hotbar_item_lost,
  cast_scroll, _open_chest), interact (player_interact, dungeon/threshold
  dispatch, vault_door), rest, drop/unequip, _talk_to/_dialogue_effect/
  _flirt, quests (_quest_talk/_turn_in/quest_marker_for/on_enemy_killed),
  _bone_merchant_stock, LORE_LINES, _dungeon_id_at

## Registries (static classes):
- ItemDB (QUALITY_NAMES/MULT, DEFS with id/kind/slot/doll_layer, make())
- EnemyDB (roles, morale, drops, boss warchief, make() with token wiring)
- NpcDB (elder/ Bram/ townsperson/ bone_merchant; root dialogue nodes, stock)
- QuestDB (hungry_souls fetch, goblin_cull kill; rewards as data)
- SkillDB (power_strike/cleave/firebolt/mend; costs, cooldowns, kinds)
- DungeonGenerator (shape rooms: rect/ellipse/L; corridors; room features;
  merchant/vault placement; fallback blob)

## Subsystems:
- save_system.gd: SAVE_PATH, save/load, _*_to_dict/_dict_to_map, cache dicts
- time_system.gd: advance_time (hunger decay), clock_text, abs_time
- turn_engine.gd: BASE_HIT, CRIT_DIVISOR, STEP_TIME/ENEMY_STEP_TIME,
  player actions, resolve_enemy_turns, attempt_move, attack/strike/ranged,
  has_clear_line, _enemy_near_sight
- spawn_system.gd: AMBUSH_CHANCE, encounters/ambush maps/flee/loot rolls

## entity.gd must have:
- token vars (face_path, face, token_size, ring_color, show_ring, _move_tween)
- set_face(): get_used_rect crop + generate_mipmaps()
- snap()/slide(): tile-center anchor (grid_pos*TILE + TILE/2), tween-kill
- _draw(): shadow, face/ring or color fallback, meditate dot, hp bar

## player.gd _init must have:
- display_name "Nyx", token_size 1.5, show_ring false, set_face(nyx.png)
- equipped = {chest: cloth_top, legs: cloth_legs}
- hotbar: power_strike/cleave/firebolt/mend in slots 1-4
- hunger/starve fields, gold, facing

## HUD._ready must create:
- DialogueUi -> Game.dialogue_ui, ShopUi -> Game.shop_ui,
  InventoryUi, CharacterSheet (local ok)

## Maps:
- overworld.txt: @ spawn, D entrance (DUNGEON_CHARS -> woods_dungeon), T town
- woods_threshold.txt: threshold (is_threshold set in code), D door, @ spawn
- neverwinter.txt: V elder, S shopkeep, P townsperson, < south gate
- woods_dungeon.txt: < exit, B warchief, = chest

## Loader (map_loader_ascii.gd):
- TILE_CHARS (NO "D" — it lives in DUNGEON_CHARS, elif order matters!)
- ENEMY/NPC/ITEM/DUNGEON_CHARS tables; ragged-line wall padding
## Draw order (2D/UI):
- Children draw in tree order; LATER children draw ON TOP
- Background images: add_child BEFORE the UI elements that sit on them
- Veils/overlays: between the image and the UI
## Keys (player.gd):
- Arrows 8-dir, 1-9 hotbar, G guard, X wait, R rest, M meditate,
  Enter interact, I pack, C character, Ctrl+S save, Ctrl+L load,
  Ctrl+N new game, F1 grid (debug_grid.gd on Main.tscn)

## UI guard order (LOCKED RULE):
- In _unhandled_input: the OPEN/TOGGLE key is checked BEFORE any
  "if not is_open: return" guard — the open-key must never be
  eaten by the closed-state guard. Esc/close only works when open.
