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
	_apply_card_style()

func _apply_card_style():
	var b = GameState.buildings[building_id]
	var base_color = Color(b.color)

	# Card background
	var style = StyleBoxFlat.new()
	style.bg_color = base_color.darkened(0.7)
	style.border_color = base_color.lightened(0.2)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", style)

	# Collect button style
	var cb_style = StyleBoxFlat.new()
	cb_style.bg_color = base_color.darkened(0.3)
	cb_style.corner_radius_top_left = 8
	cb_style.corner_radius_top_right = 8
	cb_style.corner_radius_bottom_left = 8
	cb_style.corner_radius_bottom_right = 8
	var cb_disabled = StyleBoxFlat.new()
	cb_disabled.bg_color = Color(0.2, 0.2, 0.2)
	cb_disabled.corner_radius_top_left = 8
	cb_disabled.corner_radius_top_right = 8
	cb_disabled.corner_radius_bottom_left = 8
	cb_disabled.corner_radius_bottom_right = 8
	collect_button.add_theme_stylebox_override("normal", cb_style)
	collect_button.add_theme_stylebox_override("hover", cb_style)
	collect_button.add_theme_stylebox_override("disabled", cb_disabled)
	collect_button.add_theme_color_override("font_color", Color.WHITE)
	collect_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

	# Upgrade button style
	var ub_style = StyleBoxFlat.new()
	ub_style.bg_color = Color(0.15, 0.15, 0.15)
	ub_style.border_color = base_color
	ub_style.border_width_top = 1
	ub_style.border_width_bottom = 1
	ub_style.border_width_left = 1
	ub_style.border_width_right = 1
	ub_style.corner_radius_top_left = 8
	ub_style.corner_radius_top_right = 8
	ub_style.corner_radius_bottom_left = 8
	ub_style.corner_radius_bottom_right = 8
	upgrade_button.add_theme_stylebox_override("normal", ub_style)
	upgrade_button.add_theme_stylebox_override("hover", ub_style)
	upgrade_button.add_theme_color_override("font_color", Color.WHITE)

	# Name label color
	name_label.add_theme_color_override("font_color", base_color.lightened(0.4))
	icon_label.add_theme_color_override("font_color", Color.WHITE)

func _process(delta: float):
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
	upgrade_button.text = "🔓 %s 💰" % GameState._fmt_number(float(b.unlock_cost))
	upgrade_button.modulate = Color(1, 0.9, 0.2) if can_afford else Color(0.5, 0.5, 0.5)

	# Σκοτείνιασε το card αν είναι locked
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08)
	style.border_color = Color(0.25, 0.25, 0.25)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", style)

func _update_ui():
	var b   = GameState.buildings[building_id]
	var gpc = GameState.gold_per_cycle(b)
	var uc  = GameState.upgrade_cost(b)
	var ct  = GameState.cycle_time_sec(b)
	var cap = GameState.get_max_capacity()
	var base_color = Color(b.color)

	# Restore style μόνο αν δεν έχει εφαρμοστεί ήδη
	if not has_theme_stylebox_override("panel"):
		_apply_card_style()

	icon_label.text  = b.icon_text
	name_label.text  = b.name
	level_label.text = "Lv.%d  •  +%s💰" % [b.level, GameState._fmt_number(float(gpc))]

	if b.ready >= cap:
		production_bar.value = 100
		status_label.text = "ΓΕΜΑΤΟ (%d/%d)!" % [b.ready, cap]
		status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		# Χρυσαφί progress bar
		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.9, 0.7, 0.1)
		bar_fill.corner_radius_top_left = 4
		bar_fill.corner_radius_top_right = 4
		bar_fill.corner_radius_bottom_left = 4
		bar_fill.corner_radius_bottom_right = 4
		production_bar.add_theme_stylebox_override("fill", bar_fill)
	else:
		production_bar.value = (b.progress_ms / (ct * 1000.0)) * 100.0
		var rem = ct - (b.progress_ms / 1000.0)
		if b.ready > 0:
			status_label.text = "%dx έτοιμα  •  %s" % [b.ready, GameState.fmt_time(rem)]
			status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			status_label.text = GameState.fmt_time(rem)
			status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		# Πράσινο progress bar
		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = base_color.lightened(0.1)
		bar_fill.corner_radius_top_left = 4
		bar_fill.corner_radius_top_right = 4
		bar_fill.corner_radius_bottom_left = 4
		bar_fill.corner_radius_bottom_right = 4
		production_bar.add_theme_stylebox_override("fill", bar_fill)

	collect_button.disabled = b.ready == 0
	if b.ready > 0:
		collect_button.text = "Συλλογή  +%s 💰" % GameState._fmt_number(float(b.ready * gpc))
	else:
		collect_button.text = "Παράγει..."

	var can_upgrade = GameState.gold >= uc
	upgrade_button.text = "⬆  %s 💰" % GameState._fmt_number(float(uc))
	upgrade_button.modulate = Color(1.0, 0.9, 0.2) if can_upgrade else Color(0.5, 0.5, 0.5)

func _on_collect_pressed():
	if not GameState.buildings[building_id].unlocked: return
	var earned = GameState.collect(building_id)
	if earned <= 0: return
	_spawn_float("+%s 💰" % GameState._fmt_number(float(earned)), Color(0.2, 1.0, 0.3))

func _on_upgrade_pressed():
	if not GameState.buildings[building_id].unlocked:
		var b = GameState.buildings[building_id]
		if GameState.unlock(building_id):
			_apply_card_style()
			_show_unlock_message(b.name)
		return
	open_upgrade_card.emit(building_id)

func _spawn_float(msg: String, color: Color):
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(size.x / 2.0 - 25.0, 10.0)
	lbl.z_index = 10
	add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 55.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lbl.queue_free).set_delay(0.9)

func _show_unlock_message(building_name: String):
	var lbl = Label.new()
	lbl.text = "🎉 Ξεκλείδωσες:\n%s!" % building_name
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(size.x / 2.0 - 70.0, -10.0)
	lbl.z_index = 20
	add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 90.0, 2.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 2.2)
	tw.tween_callback(lbl.queue_free).set_delay(2.2)
