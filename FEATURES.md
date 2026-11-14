# FEATURE CHECKLIST
*Verify these exist after every full-file replacement. Ctrl+F is your friend.*

## HUD._ready must create (as children):
- DialogueUi  -> stored in Game.dialogue_ui
- ShopUi      -> stored in Game.shop_ui
- InventoryUi (local var is fine)
- CharacterSheet (local var is fine)

## player.gd _init must have:
- display_name = "Nyx"
- token_size 1.5, show_ring false, ring gold, set_face("res://art/faces/nyx.png")
- hotbar init: power_strike, cleave, firebolt, mend (slots 1-4)

## EnemyDB.make must have:
- e.def = d.duplicate() + e.def["id"] = id
- token_size / ring_color from def
- set_face("res://art/faces/%s.png" % id)

## game.gd must contain:
- _free_adjacent_cells   (used by roll_loot)
- roll_loot              (called from Enemy.die)
- _bind_item_hotbar + hotbar_item_lost
- save_game / load_game / _map_to_dict / _dict_to_map
- advance_time (drives hunger) + clock_text

## entity.gd must have:
- token vars: face_path, face, token_size, ring_color, show_ring, _move_tween
- set_face() with get_used_rect crop + generate_mipmaps()
- snap()/slide() centered on tile (grid_pos * TILE + TILE/2), tween-kill on snap

## Maps:
- overworld.txt has @ spawn
- neverwinter.txt (town): V elder, S shopkeep, P townsperson, < south gate
- woods_dungeon.txt: < exit, B warchief, = chest

## Keys (player.gd _unhandled_input):
- Arrows move (8-dir), 1-9 hotbar, G guard, X wait, R rest, M meditate,
  Enter interact, I inventory, C character, Ctrl+S save, Ctrl+L load,
  Ctrl+N new game, F1 debug grid (debug_grid.gd on Main.tscn)
