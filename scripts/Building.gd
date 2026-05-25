extends PanelContainer

@export var building_id: int = 0

@onready var icon_label     = $MarginContainer/VBoxContainer/IconLabel
@onready var name_label     = $MarginContainer/VBoxContainer/NameLabel
@onready var level_label    = $MarginContainer/VBoxContainer/LevelLabel
@onready var production_bar = $MarginContainer/VBoxContainer/ProductionBar
@onready var status_label   = $MarginContainer/VBoxContainer/StatusLabel
@onready var collect_button = $MarginContainer/VBoxContainer/CollectButton
@onready var upgrade_button = $MarginContainer/VBoxContainer/UpgradeButton

var _style_applied: bool = false
var _was_unlocked: bool = false

func _ready():
	collect_button.pressed.connect(_on_collect_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	_was_unlocked = GameState.buildings[building_id].unlocked
	if _was_unlocked:
		_apply_card_style()
	else:
		_apply_locked_style()

func _process(delta: float):
	var b = GameState.buildings[building_id]

	# Μόλις ξεκλειδωθεί — εφάρμοσε χρωματιστό style μία φορά
	if b.unlocked and not _was_unlocked:
		_was_unlocked = true
		_style_applied = false
		_apply_card_style()

	if not b.unlocked:
		if Engine.get_process_frames() % 10 == 0:
			_update_locked_ui()
		return

	# Παραγωγή
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

func _apply_locked_style():
	_style_applied = false
	var s = StyleBoxFlat.new()
	s.bg_color       = Color(0.07, 0.07, 0.07)
	s.border_color   = Color(0.22, 0.22, 0.22)
	s.border_width_top = s.border_width_bottom = s.border_width_left = s.border_width_right = 1
	s.corner_radius_top_left = s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = s.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", s)

func _apply_card_style():
	if _style_applied: return
	_style_applied = true

	var b = GameState.buildings[building_id]
	var c = Color(b.color)

	# Panel
	var ps = StyleBoxFlat.new()
	ps.bg_color     = c.darkened(0.72)
	ps.border_color = c.lightened(0.2)
	ps.border_width_top = ps.border_width_bottom = ps.border_width_left = ps.border_width_right = 2
	ps.corner_radius_top_left = ps.corner_radius_top_right = 12
	ps.corner_radius_bottom_left = ps.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", ps)

	# Collect button
	for state in ["normal", "hover", "pressed"]:
		var s = StyleBoxFlat.new()
		s.bg_color = c.darkened(0.3) if state != "pressed" else c.darkened(0.5)
		s.corner_radius_top_left = s.corner_radius_top_right = 8
		s.corner_radius_bottom_left = s.corner_radius_bottom_right = 8
		collect_button.add_theme_stylebox_override(state, s)
	var ds = StyleBoxFlat.new()
	ds.bg_color = Color(0.18, 0.18, 0.18)
	ds.corner_radius_top_left = ds.corner_radius_top_right = 8
	ds.corner_radius_bottom_left = ds.corner_radius_bottom_right = 8
	collect_button.add_theme_stylebox_override("disabled", ds)
	collect_button.add_theme_color_override("font_color", Color.WHITE)
	collect_button.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))

	# Upgrade button
	var us = StyleBoxFlat.new()
	us.bg_color     = Color(0.13, 0.13, 0.13)
	us.border_color = c
	us.border_width_top = us.border_width_bottom = us.border_width_left = us.border_width_right = 1
	us.corner_radius_top_left = us.corner_radius_top_right = 8
	us.corner_radius_bottom_left = us.corner_radius_bottom_right = 8
	upgrade_button.add_theme_stylebox_override("normal", us)
	upgrade_button.add_theme_stylebox_override("hover",  us)
	upgrade_button.add_theme_color_override("font_color", Color.WHITE)

	name_label.add_theme_color_override("font_color", c.lightened(0.4))

func _update_locked_ui():
	var b = GameState.buildings[building_id]
	icon_label.text      = "🔒"
	name_label.text      = b.name
	level_label.text     = "Κλειδωμένο"
	production_bar.value = 0
	status_label.text    = ""
	collect_button.disabled = true
	collect_button.text  = "Κλειδωμένο"
	var can = GameState.gold >= b.unlock_cost
	upgrade_button.text    = "🔓 %s 💰" % GameState.fmt_number(float(b.unlock_cost))
	upgrade_button.modulate = Color(1, 0.9, 0.2) if can else Color(0.45, 0.45, 0.45)

func _update_ui():
	var b   = GameState.buildings[building_id]
	var gpc = GameState.gold_per_cycle(b)
	var uc  = GameState.upgrade_cost(b)
	var ct  = GameState.cycle_time_sec(b)
	var cap = GameState.get_max_capacity()
	var c   = Color(b.color)

	icon_label.text  = b.icon_text
	name_label.text  = b.name
	level_label.text = "Lv.%d  •  +%s 💰" % [b.level, GameState.fmt_number(float(gpc))]

	if b.ready >= cap:
		production_bar.value = 100
		status_label.text    = "ΓΕΜΑΤΟ (%d/%d)!" % [b.ready, cap]
		status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.9, 0.7, 0.1)
		fill.corner_radius_top_left = fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = fill.corner_radius_bottom_right = 4
		production_bar.add_theme_stylebox_override("fill", fill)
	else:
		var pct = 0.0
		if ct > 0:
			pct = (b.progress_ms / (ct * 1000.0)) * 100.0
		production_bar.value = pct
		var rem = ct - (b.progress_ms / 1000.0)
		if b.ready > 0:
			status_label.text = "%dx • %s" % [b.ready, GameState.fmt_time(rem)]
			status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			status_label.text = GameState.fmt_time(rem)
			status_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		var fill = StyleBoxFlat.new()
		fill.bg_color = c.lightened(0.1)
		fill.corner_radius_top_left = fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = fill.corner_radius_bottom_right = 4
		production_bar.add_theme_stylebox_override("fill", fill)

	collect_button.disabled = b.ready == 0
	collect_button.text = "Συλλογή  +%s 💰" % GameState.fmt_number(float(b.ready * gpc)) if b.ready > 0 else "Παράγει..."

	var can_up = GameState.gold >= uc
	upgrade_button.text     = "⬆  %s 💰" % GameState.fmt_number(float(uc))
	upgrade_button.modulate = Color(1.0, 0.9, 0.2) if can_up else Color(0.5, 0.5, 0.5)

func _on_collect_pressed():
	if not GameState.buildings[building_id].unlocked: return
	var earned = GameState.collect(building_id)
	if earned <= 0: return
	_spawn_float("+%s 💰" % GameState.fmt_number(float(earned)), Color(0.2, 1.0, 0.3))

func _on_upgrade_pressed():
	var b = GameState.buildings[building_id]
	if not b.unlocked:
		if GameState.unlock(building_id):
			_show_unlock_message(b.name)
		return
	var card = get_tree().current_scene.get_node_or_null("UpgradeCard")
	if card:
		card.open_for(building_id)

func _spawn_float(msg: String, color: Color):
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(size.x / 2.0 - 25.0, 8.0)
	lbl.z_index = 10
	add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 55.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lbl.queue_free).set_delay(0.9)

func _show_unlock_message(bname: String):
	var lbl = Label.new()
	lbl.text = "🎉 Ξεκλείδωσες:\n%s!" % bname
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(size.x / 2.0 - 70.0, -8.0)
	lbl.z_index = 20
	add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 90.0, 2.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 2.2)
	tw.tween_callback(lbl.queue_free).set_delay(2.2)