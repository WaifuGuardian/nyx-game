class_name QuestDB

## type: "fetch" (deliver `amount` of `target_id`) | "kill" (kill `amount` of `target_id`)
const DEFS: Dictionary = {
	"hungry_souls": {
		"title": "Hungry Souls", "giver": "elder", "type": "fetch",
		"target_id": "meat", "amount": 3,
		"offer_text": "Winter's coming and the granary runs thin. Bring me 3 cuts of meat and I'll make it worth your while.",
		"progress_text": "Any luck with that meat, child?",
		"reward_gold": 30, "reward_xp": 15,
		"reward_items": [{"id": "potion", "quality": 2, "count": 1}],
	},
	"goblin_cull": {
		"title": "Goblin Cull", "giver": "elder", "type": "kill",
		"target_id": "goblin", "amount": 2,
		"offer_text": "Goblins raid our edges from the hills. Cull 2 of them, and Neverwinter sleeps easier.",
		"progress_text": "The hills are still loud. Two goblins, Nyx.",
		"reward_gold": 40, "reward_xp": 25,
		"reward_items": [],
	},
}
