# NYX RPG — ROADMAP

## DONE
- M1 RPG spine: attributes, energy scheduler, accuracy/evasion, XP/levels,
  data-driven enemies (roles + morale), message log
- M2 Items 2.0: ItemDB registry, quality ladder, weight/encumbrance,
  equipment slots, stacking, armor mitigation, scrolls, materials
- M3 UI v1: modal inventory, character sheet, HUD, debug grid (F1)
- M4 World: MapData + ASCII loader, woods dungeon (handcrafted), procedural
  floors, stairs, overworld with biomes + travel time, ambush maps
  (fight or flee), layer stack
- M5 Survival: hunger stages + starvation, eating, rest (supplies, 8h,
  interrupt events), save-on-rest, full save/load (Ctrl+S/L/N)
- M6.1 Town: neverwinter (enterable), NPC dialogue (VN box), shop with
  buy/sell, gold economy, loot drops, boss (Warchief) with special drops,
  chests, skills + hotbar, crits (LUCK)
- Dialogue choices + affinity: Flirt/Gift/Quest/Trade menu (spec'd,
  sees NpcDB "topics" field; quest option stubs until quests exist)
- Dungeon generator v2: room types (fight/loot/trap/rest), boss placement
- Quest system: fetch/kill/explore/craft types, timers as fail condition,
  markers (?, grey, green !), rewards as data
## IN PROGRESS
- (nothing — milestone boundary)

## NEXT (pick in any order)
- Art pass 1: Mira/Bram/townsperson faces, Y-sort, tile size decision
  (16 vs 32 — waiting on artist's native grain), real icons
- Proper Main Menu, with a "start new game", "load game" and "exit" buttons, as well as settings later on
- An ui improvement. A proper backpack one can drag things around in and click on items to "equip/use", "Inspect", "drop" etc
- Another UI improvement. Make a menu for the game. One where you can see your skills, journal, quests, status, as well as a load game button.
- Make proper hotkeys. You have button 1-10 that you can use at the bottom of your screen, and you can drag food, items and spells/skills to 
quick use them from the hotkey.
-Make it so you can attack with clicking, rather than walking into enemies. Ranged attacks can be shot within a certain range of you at an enemy
of your choosing rather than require a straight line.

## LATER (specced in design doc)
- NPC schedules, karma/crime/fame, dialogue topic trees, cooking with
  ingredient inheritance, spellcrafting, recruitment/companions, romance,
  outfits, faith, identification, weather/seasons, fast travel, noise,
  home plots, save slot screen with thumbnails, tutorial (diegetic),
  status effects, targeting UI, drowsiness/sanity, death screen polish

## CONVENTIONS
- Never paste a full file without Ctrl+A first
- Verify FEATURES.md after every full-file replacement
- One change -> run -> next change
- New class_name? Save, then Project -> Reload Current Project if anything
  says "not declared"
- Balance knobs live in: SkillDB (costs/cooldowns/mults), game.gd top
  (BASE_HIT, CRIT_DIVISOR), EnemyDB (attributes/morale/drops)
