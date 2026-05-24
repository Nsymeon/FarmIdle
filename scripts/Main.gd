extends Node2D

@onready var gold_label       = $UI/Layout/TopBar/MarginContainer/HBoxContainer/VBoxContainer/GoldLabel
@onready var total_label      = $UI/Layout/TopBar/MarginContainer/HBoxContainer/VBoxContainer/TotalLabel
@onready var grid             = $UI/Layout/Scroll/Grid
@onready var upgrade_card     = $UpgradeCard
@onready var tap_button       = $UI/Layout/BottomBar/TapButton
@onready var auto_collect_btn = $UI/Layout/SpecialBar/SpecialButtons/AutoCollectBtn
@onready var max_cap_btn      = $UI/Layout/SpecialBar/SpecialButtons/MaxCapBtn
@onready var auto_tap_btn     = $UI/Layout/SpecialBar/SpecialButtons/AutoTapBtn

const BuildingScene = preload("res://scenes/Building.tscn")

var auto_collect_timer: float = 0.0
var auto_tap_timer: float = 0.0
var tap_rotation_deg: float = 0.0

func _ready():
	GameState.gold_changed.connect(_update_gold)
	GameState.special_upgraded.connect(_update_special_buttons)

	tap_button.pressed.connect(_on_tap_pressed)
	auto_collect_btn.pressed.connect(_on_auto_collect_upgrade)
	max_cap_btn.pressed.connect(_on_max_cap_upgrade)
	auto_tap_btn.pressed.connect(_on_auto_tap_upgrade)

	_style_top_bar()
	_style_tap_button()
	_style_special_buttons()

	for b in GameState.buildings:
		upgrade_card.hide()
		var card = BuildingScene.instantiate()
		card.building_id = b.id
		card.open_upgrade_card.connect(func(id): upgrade_card.open_for(id))
		grid.add_child(card)

	_update_gold(GameState.gold)
	_update_special_buttons()

# ─── Styling ─────────────────────────────────────────────────

func _style_top_bar():
	# TopBar background
	var top_bar = $UI/Layout/TopBar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.08)
	style.border_color = Color(0.2, 0.5, 0.15)
	style.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", style)

	# Gold label styling
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	gold_label.add_theme_font_size_override("font_size", 26)
	total_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	total_label.add_theme_font_size_override("font_size", 11)

	# Title styling
	var title = $UI/Layout/TopBar/MarginContainer/HBoxContainer/TitleLabel
	title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.5))
	title.add_theme_font_size_override("font_size", 20)

func _style_tap_button():
	tap_button.text = "💧"
	tap_button.add_theme_font_size_override("font_size", 30)
	tap_button.focus_mode = Control.FOCUS_NONE
	tap_button.custom_minimum_size = Vector2(90, 90)

	var mk_style = func(color: Color) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color = color
		s.corner_radius_top_left = 45
		s.corner_radius_top_right = 45
		s.corner_radius_bottom_left = 45
		s.corner_radius_bottom_right = 45
		s.border_color = color.lightened(0.3)
		s.border_width_top = 3
		s.border_width_bottom = 3
		s.border_width_left = 3
		s.border_width_right = 3
		s.shadow_color = Color(0, 0, 0, 0.4)
		s.shadow_size = 6
		return s

	tap_button.add_theme_stylebox_override("normal",  mk_style.call(Color("#1a6b8a")))
	tap_button.add_theme_stylebox_override("hover",   mk_style.call(Color("#2080aa")))
	tap_button.add_theme_stylebox_override("pressed", mk_style.call(Color("#0e4d66")))
	tap_button.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

func _style_special_buttons():
	var colors = [Color("#1a6b8a"), Color("#7a3b0e"), Color("#4a1a8a")]
	var buttons = [auto_collect_btn, max_cap_btn, auto_tap_btn]
	for i in range(3):
		var btn = buttons[i]
		var c = colors[i]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(105, 85)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color.WHITE)

		var mk = func(col: Color) -> StyleBoxFlat:
			var s = StyleBoxFlat.new()
			s.bg_color = col
			s.corner_radius_top_left = 10
			s.corner_radius_top_right = 10
			s.corner_radius_bottom_left = 10
			s.corner_radius_bottom_right = 10
			s.border_color = col.lightened(0.3)
			s.border_width_top = 1
			s.border_width_bottom = 1
			s.border_width_left = 1
			s.border_width_right = 1
			return s

		btn.add_theme_stylebox_override("normal",  mk.call(c))
		btn.add_theme_stylebox_override("hover",   mk.call(c.lightened(0.15)))
		btn.add_theme_stylebox_override("pressed", mk.call(c.darkened(0.2)))
		btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

# ─── Process ─────────────────────────────────────────────────

func _process(delta: float):
	if GameState.auto_collect_level > 0:
		auto_collect_timer += delta
		if auto_collect_timer >= GameState.auto_collect_interval():
			auto_collect_timer = 0.0
			var earned = GameState.collect_all()
			if earned > 0:
				_show_float("🌾 +%s" % GameState._fmt_number(float(earned)), Color(0.3, 1.0, 0.5))

	if GameState.auto_tap_level > 0:
		auto_tap_timer += delta
		if auto_tap_timer >= GameState.auto_tap_interval():
			auto_tap_timer = 0.0
			var earned = GameState.tap_gold()
			_show_float("💧 +%d" % earned, Color(0.3, 0.7, 1.0))

# ─── Tap Button ──────────────────────────────────────────────

func _on_tap_pressed():
	var earned = GameState.tap_gold()
	tap_rotation_deg += 1.0
	tap_button.pivot_offset = tap_button.size / 2.0
	tap_button.rotation_degrees = tap_rotation_deg
	_show_float("💧 +%d" % earned, Color(0.4, 0.8, 1.0))

# ─── Special Buttons ─────────────────────────────────────────

func _on_auto_collect_upgrade():
	var was_zero = GameState.auto_collect_level == 0
	if GameState.upgrade_auto_collect():
		if was_zero:
			_show_float("🎉 Αυτο-Συλλογή ξεκλειδώθηκε!", Color(0.3, 1.0, 0.8))
		_check_game_complete()
	else:
		_show_float("Χρειάζεσαι %s 💰" % GameState._fmt_number(float(GameState.auto_collect_upgrade_cost())), Color(1.0, 0.3, 0.3))

func _on_max_cap_upgrade():
	if GameState.upgrade_max_capacity():
		_show_float("📦 Χωρητικότητα x%d!" % GameState.get_max_capacity(), Color(1.0, 0.7, 0.2))
	else:
		_show_float("Χρειάζεσαι %s 💰" % GameState._fmt_number(float(GameState.max_capacity_upgrade_cost())), Color(1.0, 0.3, 0.3))

func _on_auto_tap_upgrade():
	var was_zero = GameState.auto_tap_level == 0
	if GameState.upgrade_auto_tap():
		if was_zero:
			_show_float("🎉 Αυτο-Πάτημα ξεκλειδώθηκε!", Color(0.8, 0.3, 1.0))
		_check_game_complete()
	else:
		_show_float("Χρειάζεσαι %s 💰" % GameState._fmt_number(float(GameState.auto_tap_upgrade_cost())), Color(1.0, 0.3, 0.3))

# ─── Special Buttons UI ──────────────────────────────────────

func _update_special_buttons():
	var ac_lv   = GameState.auto_collect_level
	var ac_cost = GameState.auto_collect_upgrade_cost()
	var ac_can  = GameState.gold >= ac_cost
	if ac_lv == 0:
		auto_collect_btn.text = "🌾 Αυτο-\nΣυλλογή\n🔓 %s💰" % GameState._fmt_number(float(ac_cost))
	else:
		auto_collect_btn.text = "🌾 Αυτο-\nΣυλλογή\nLv%d | %s\n+Lv %s💰" % [ac_lv, GameState.fmt_time(GameState.auto_collect_interval()), GameState._fmt_number(float(ac_cost))]
	auto_collect_btn.modulate = Color(1,1,1) if ac_can else Color(0.55,0.55,0.55)

	var mc_lv   = GameState.max_capacity_level
	var mc_cost = GameState.max_capacity_upgrade_cost()
	var mc_can  = GameState.gold >= mc_cost
	max_cap_btn.text = "📦 Χωρητ.\nLv%d | x%d\n+Lv %s💰" % [mc_lv, GameState.get_max_capacity(), GameState._fmt_number(float(mc_cost))]
	max_cap_btn.modulate = Color(1,1,1) if mc_can else Color(0.55,0.55,0.55)

	var at_lv   = GameState.auto_tap_level
	var at_cost = GameState.auto_tap_upgrade_cost()
	var at_can  = GameState.gold >= at_cost
	if at_lv == 0:
		auto_tap_btn.text = "💧 Αυτο-\nΠάτημα\n🔓 %s💰" % GameState._fmt_number(float(at_cost))
	else:
		auto_tap_btn.text = "💧 Αυτο-\nΠάτημα\nLv%d | %s\n+Lv %s💰" % [at_lv, GameState.fmt_time(GameState.auto_tap_interval()), GameState._fmt_number(float(at_cost))]
	auto_tap_btn.modulate = Color(1,1,1) if at_can else Color(0.55,0.55,0.55)

# ─── Gold Display ─────────────────────────────────────────────

func _update_gold(_v):
	gold_label.text  = "%s 💰" % GameState._fmt_number(GameState.gold)
	total_label.text = "Σύνολο: %s 💰" % GameState._fmt_number(GameState.total_earned)
	_update_special_buttons()

# ─── Float Text ───────────────────────────────────────────────

func _show_float(msg: String, color: Color):
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(
		get_viewport().get_visible_rect().size.x / 2.0 - 60.0,
		get_viewport().get_visible_rect().size.y - 220.0
	)
	lbl.z_index = 20
	get_tree().current_scene.add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 90.0, 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free).set_delay(1.2)

# ─── Game Complete ────────────────────────────────────────────

func _check_game_complete():
	for b in GameState.buildings:
		if not b.unlocked: return
	if GameState.auto_collect_level == 0: return
	if GameState.auto_tap_level == 0: return
	upgrade_card.open_demo_complete()

# ─── Notifications ────────────────────────────────────────────

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
