extends Node

signal gold_changed(new_gold: float)
signal building_updated(id: int)

var gold: float = 50.0
var total_earned: float = 0.0
var last_save_time: int = 0

const MAX_READY = 5
const SAVE_PATH = "user://savegame.json"

var buildings: Array = [
	{
		"id": 0, "name": "Κοτέτσι", "icon_text": "🐔",
		"level": 1, "base_gold": 2, "cycle_ms": 5000.0,
		"base_cost": 40, "ready": 0, "progress_ms": 0.0,
		"unlocked": true, "unlock_cost": 0
	},
	{
		"id": 1, "name": "Στάβλος Αγελάδας", "icon_text": "🐄",
		"level": 1, "base_gold": 5, "cycle_ms": 10000.0,
		"base_cost": 100, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 1000
	},
	{
		"id": 2, "name": "Χωράφι Σίτου", "icon_text": "🌾",
		"level": 1, "base_gold": 3, "cycle_ms": 7000.0,
		"base_cost": 70, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 2000
	},
	{
		"id": 3, "name": "Μελισσοκομείο", "icon_text": "🍯",
		"level": 1, "base_gold": 8, "cycle_ms": 15000.0,
		"base_cost": 150, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 5000
	},
	{
		"id": 4, "name": "Μποστάνι", "icon_text": "🫐",
		"level": 1, "base_gold": 1, "cycle_ms": 3000.0,
		"base_cost": 25, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 10000
	},
	{
		"id": 5, "name": "Αγορά", "icon_text": "🏪",
		"level": 1, "base_gold": 15, "cycle_ms": 20000.0,
		"base_cost": 200, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 20000
	},
]

func _ready():
	load_game()
	_process_offline_earnings()

func gold_per_cycle(b: Dictionary) -> int:
	return b.base_gold * b.level

func upgrade_cost(b: Dictionary) -> int:
	return int(b.base_cost * pow(1.5, b.level - 1))

func cycle_time_sec(b: Dictionary) -> float:
	return max(1.5, (b.cycle_ms / 1000.0) * pow(0.92, b.level - 1))

func fmt_time(sec: float) -> String:
	if sec >= 60.0:
		return "%.1fm" % (sec / 60.0)
	return "%.1fs" % sec

func collect(building_id: int) -> int:
	var b = buildings[building_id]
	if b.ready == 0:
		return 0
	var earned = b.ready * gold_per_cycle(b)
	gold += earned
	total_earned += earned
	b.ready = 0
	gold_changed.emit(gold)
	save_game()
	return earned

func upgrade(building_id: int) -> bool:
	var b = buildings[building_id]
	var cost = upgrade_cost(b)
	if gold < cost:
		return false
	gold -= cost
	b.level += 1
	b.progress_ms = 0.0
	b.ready = 0
	gold_changed.emit(gold)
	building_updated.emit(building_id)
	save_game()
	return true

func unlock(building_id: int) -> bool:
	var b = buildings[building_id]
	if b.unlocked:
		return false
	if gold < b.unlock_cost:
		return false
	gold -= b.unlock_cost
	b.unlocked = true
	gold_changed.emit(gold)
	building_updated.emit(building_id)
	save_game()
	return true

func _process_offline_earnings():
	var current_time = int(Time.get_unix_time_from_system())
	if last_save_time == 0:
		last_save_time = current_time
		return
	var offline_sec = clamp(float(current_time - last_save_time), 0.0, 4.0 * 3600.0)
	for b in buildings:
		var cycle_ms = cycle_time_sec(b) * 1000.0
		var total_ms = b.progress_ms + (offline_sec * 1000.0)
		var cycles_done = min(int(total_ms / cycle_ms), MAX_READY - b.ready)
		b.ready += cycles_done
		b.progress_ms = 0.0 if b.ready >= MAX_READY else fmod(total_ms, cycle_ms)
	last_save_time = current_time

func save_game():
	last_save_time = int(Time.get_unix_time_from_system())
	var data = {
		"gold": gold, "total_earned": total_earned,
		"last_save_time": last_save_time,
		"buildings": buildings.duplicate(true)
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return
	gold = float(data.get("gold", 50.0))
	total_earned = float(data.get("total_earned", 0.0))
	last_save_time = int(data.get("last_save_time", 0))
	var saved = data.get("buildings", [])
	for i in range(min(saved.size(), buildings.size())):
		buildings[i].level       = int(saved[i].get("level", 1))
		buildings[i].ready       = int(saved[i].get("ready", 0))
		buildings[i].progress_ms = float(saved[i].get("progress_ms", 0.0))
	buildings[i].unlocked = bool(saved[i].get("unlocked", i == 0))
	buildings[i].unlock_cost = int(saved[i].get("unlock_cost", buildings[i].unlock_cost))

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()