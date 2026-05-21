extends Node

signal gold_changed(new_gold: float)
signal building_updated(id: int)
signal special_upgraded

var gold: float = 0.0
var total_earned: float = 0.0
var last_save_time: int = 0

const SAVE_PATH = "user://savegame.json"

# ─── Special Systems ─────────────────────────────────────────
var max_capacity_level: int = 1       # capacity = level + 1 (lv1=2, lv2=3...)
var auto_collect_level: int = 0       # 0 = κλειδωμένο
var auto_tap_level: int = 0           # 0 = κλειδωμένο

const AUTO_COLLECT_UNLOCK = 5000
const AUTO_TAP_UNLOCK     = 3000

func get_max_capacity() -> int:
	match max_capacity_level:
		1: return 2
		2: return 3
		3: return 4
		4: return 5
		5: return 7
		6: return 10
		_: return min(2 + max_capacity_level, 20)

func max_capacity_upgrade_cost() -> int:
	return int(8000 * pow(5.0, max_capacity_level - 1))

func auto_collect_interval() -> float:
	if auto_collect_level <= 0: return 9999.0
	return max(5.0, 60.0 / float(auto_collect_level))

func auto_collect_upgrade_cost() -> int:
	if auto_collect_level == 0: return AUTO_COLLECT_UNLOCK
	return int(2000 * pow(3.0, auto_collect_level - 1))

func auto_tap_interval() -> float:
	if auto_tap_level <= 0: return 9999.0
	return max(2.0, 15.0 - float(auto_tap_level - 1) * 2.0)

func auto_tap_upgrade_cost() -> int:
	if auto_tap_level == 0: return AUTO_TAP_UNLOCK
	return int(1500 * pow(2.5, auto_tap_level - 1))

# ─── Buildings ───────────────────────────────────────────────
var buildings: Array = [
	{
		"id": 0, "name": "Κοτέτσι", "icon_text": "KOTA",
		"level": 1, "base_gold": 2, "cycle_ms": 4000.0,
		"base_cost": 30, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 100
	},
	{
		"id": 1, "name": "Στάβλος Αγελάδας", "icon_text": "AGEL",
		"level": 1, "base_gold": 8, "cycle_ms": 10000.0,
		"base_cost": 80, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 500
	},
	{
		"id": 2, "name": "Χωράφι Σιταριού", "icon_text": "SITO",
		"level": 1, "base_gold": 20, "cycle_ms": 18000.0,
		"base_cost": 200, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 3000
	},
	{
		"id": 3, "name": "Μελισσοκομείο", "icon_text": "MELI",
		"level": 1, "base_gold": 50, "cycle_ms": 30000.0,
		"base_cost": 500, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 15000
	},
	{
		"id": 4, "name": "Μποστάνι", "icon_text": "MPOS",
		"level": 1, "base_gold": 120, "cycle_ms": 50000.0,
		"base_cost": 1200, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 60000
	},
	{
		"id": 5, "name": "Αγορά", "icon_text": "AGORA",
		"level": 1, "base_gold": 300, "cycle_ms": 80000.0,
		"base_cost": 3000, "ready": 0, "progress_ms": 0.0,
		"unlocked": false, "unlock_cost": 200000
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
	if sec >= 60.0: return "%.1fm" % (sec / 60.0)
	return "%.1fs" % sec

func _fmt_number(n: float) -> String:
	if n >= 1_000_000: return "%.1fM" % (n / 1_000_000.0)
	if n >= 1_000:     return "%.1fK" % (n / 1_000.0)
	return str(int(n))

func collect(building_id: int) -> int:
	var b = buildings[building_id]
	if b.ready == 0: return 0
	var earned = b.ready * gold_per_cycle(b)
	gold += earned
	total_earned += earned
	b.ready = 0
	gold_changed.emit(gold)
	save_game()
	return earned

func collect_all() -> int:
	var total = 0
	for b in buildings:
		if b.unlocked and b.ready > 0:
			total += b.ready * gold_per_cycle(b)
			b.ready = 0
	if total > 0:
		gold += total
		total_earned += total
		gold_changed.emit(gold)
		save_game()
	return total

func upgrade(building_id: int) -> bool:
	var b = buildings[building_id]
	var cost = upgrade_cost(b)
	if gold < cost: return false
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
	if b.unlocked: return false
	if gold < b.unlock_cost: return false
	gold -= b.unlock_cost
	b.unlocked = true
	gold_changed.emit(gold)
	building_updated.emit(building_id)
	save_game()
	return true

func tap_gold() -> int:
	var total = 1
	for b in buildings:
		if b.unlocked: total += b.level
	gold += total
	total_earned += total
	gold_changed.emit(gold)
	return total

func upgrade_max_capacity() -> bool:
	var cost = max_capacity_upgrade_cost()
	if gold < cost: return false
	gold -= cost
	max_capacity_level += 1
	gold_changed.emit(gold)
	special_upgraded.emit()
	save_game()
	return true

func upgrade_auto_collect() -> bool:
	var cost = auto_collect_upgrade_cost()
	if gold < cost: return false
	gold -= cost
	auto_collect_level += 1
	gold_changed.emit(gold)
	special_upgraded.emit()
	save_game()
	return true

func upgrade_auto_tap() -> bool:
	var cost = auto_tap_upgrade_cost()
	if gold < cost: return false
	gold -= cost
	auto_tap_level += 1
	gold_changed.emit(gold)
	special_upgraded.emit()
	save_game()
	return true

func _process_offline_earnings():
	var current_time = int(Time.get_unix_time_from_system())
	if last_save_time == 0:
		last_save_time = current_time
		return
	var offline_sec = clamp(float(current_time - last_save_time), 0.0, 4.0 * 3600.0)
	var cap = get_max_capacity()
	for b in buildings:
		if not b.unlocked: continue
		var cycle_ms = cycle_time_sec(b) * 1000.0
		var total_ms = b.progress_ms + (offline_sec * 1000.0)
		var cycles_done = min(int(total_ms / cycle_ms), cap - b.ready)
		b.ready += cycles_done
		b.progress_ms = 0.0 if b.ready >= cap else fmod(total_ms, cycle_ms)
	last_save_time = current_time

func save_game():
	last_save_time = int(Time.get_unix_time_from_system())
	var data = {
		"gold": gold, "total_earned": total_earned,
		"last_save_time": last_save_time,
		"max_capacity_level": max_capacity_level,
		"auto_collect_level": auto_collect_level,
		"auto_tap_level": auto_tap_level,
		"buildings": buildings.duplicate(true)
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH): return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary: return
	gold = float(data.get("gold", 50.0))
	total_earned = float(data.get("total_earned", 0.0))
	last_save_time = int(data.get("last_save_time", 0))
	max_capacity_level = int(data.get("max_capacity_level", 1))
	auto_collect_level = int(data.get("auto_collect_level", 0))
	auto_tap_level = int(data.get("auto_tap_level", 0))
	var saved = data.get("buildings", [])
	for i in range(min(saved.size(), buildings.size())):
		buildings[i].level       = int(saved[i].get("level", 1))
		buildings[i].ready       = int(saved[i].get("ready", 0))
		buildings[i].progress_ms = float(saved[i].get("progress_ms", 0.0))
		buildings[i].unlocked    = bool(saved[i].get("unlocked", i == 0))

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
