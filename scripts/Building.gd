extends PanelContainer

@export var building_id: int = 0

@onready var icon_label     = $MarginContainer/VBoxContainer/IconLabel
@onready var name_label     = $MarginContainer/VBoxContainer/NameLabel
@onready var level_label    = $MarginContainer/VBoxContainer/LevelLabel
@onready var production_bar = $MarginContainer/VBoxContainer/ProductionBar
@onready var status_label   = $MarginContainer/VBoxContainer/StatusLabel
@onready var collect_button = $MarginContainer/VBoxContainer/CollectButton
@onready var upgrade_button = $MarginContainer/VBoxContainer/UpgradeButton

signal open_upgrade_card(id: int)

func _ready():
	collect_button.pressed.connect(_on_collect_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)

func _process(delta: float):
	# Πάρε πάντα reference από το array — ποτέ var b = ...
	if not GameState.buildings[building_id].unlocked:
		_update_locked_ui()
		return

	var b = GameState.buildings[building_id]
	var cap = GameState.get_max_capacity()

	if b.ready < cap:
		b.progress_ms += delta * 1000.0
		var cycle_ms = GameState.cycle_time_sec(b) * 1000.0
		while b.progress_ms >= cycle_ms and b.ready < cap:
			b.progress_ms -= cycle_ms
			b.ready += 1
		if b.ready >= cap:
			b.progress_ms = 0.0

	if Engine.get_process_frames() % 5 == 0:
		_update_ui()

func _update_locked_ui():
	var b = GameState.buildings[building_id]
	icon_label.text  = "🔒"
	name_label.text  = b.name
	level_label.text = "Κλειδωμένο"
	production_bar.value = 0
	status_label.text = ""
	collect_button.disabled = true
	collect_button.text = "Κλειδωμένο"
	var can_afford = GameState.gold >= b.unlock_cost
	var cost_str = GameState._fmt_number(float(b.unlock_cost))
	upgrade_button.text = "Ξεκλείδωμα: %s💰" % cost_str
	upgrade_button.modulate = Color(1, 0.85, 0.1) if can_afford else Color(0.5, 0.5, 0.5)

func _update_ui():
	var b   = GameState.buildings[building_id]
	var gpc = GameState.gold_per_cycle(b)
	var uc  = GameState.upgrade_cost(b)
	var ct  = GameState.cycle_time_sec(b)
	var cap = GameState.get_max_capacity()

	icon_label.text  = b.icon_text
	name_label.text  = b.name
	level_label.text = "Lv.%d  +%d💰" % [b.level, gpc]

	if b.ready >= cap:
		production_bar.value = 100
		status_label.text    = "ΓΕΜΑΤΟ (%d)!" % b.ready
	else:
		production_bar.value = (b.progress_ms / (ct * 1000.0)) * 100.0
		var rem = ct - (b.progress_ms / 1000.0)
		status_label.text = ("%dx • " % b.ready if b.ready > 0 else "") + GameState.fmt_time(rem)

	collect_button.disabled = b.ready == 0
	collect_button.text = "Συλλογή +%d💰" % (b.ready * gpc) if b.ready > 0 else "Παράγει..."
	upgrade_button.text = "⬆ %s💰" % GameState._fmt_number(float(uc))
	upgrade_button.modulate = Color(1,1,1) if GameState.gold >= uc else Color(.6,.6,.6)

func _on_collect_pressed():
	if not GameState.buildings[building_id].unlocked:
		return
	var earned = GameState.collect(building_id)
	if earned <= 0:
		return
	var lbl = Label.new()
	lbl.text = "+%d💰" % earned
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.8, 0.1))
	lbl.position = Vector2(size.x / 2.0 - 20.0, 15.0)
	lbl.z_index = 10
	add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 50.0, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free).set_delay(0.8)

func _on_upgrade_pressed():
	if not GameState.buildings[building_id].unlocked:
		var b = GameState.buildings[building_id]
		if GameState.unlock(building_id):
			_show_unlock_message(b.name)
		return
	open_upgrade_card.emit(building_id)

func _show_unlock_message(building_name: String):
	var lbl = Label.new()
	lbl.text = "Μπράβο!\nΞεκλείδωσες το:\n%s!" % building_name
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(size.x / 2.0 - 80.0, -20.0)
	lbl.z_index = 20
	add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 100.0, 2.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tw.tween_callback(lbl.queue_free).set_delay(2.0)
