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
var _demo_shown: bool = false

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
	_style_background()

	for b in GameState.buildings:
		var card = BuildingScene.instantiate()
		card.building_id = b.id
		grid.add_child(card)

	upgrade_card.hide()
	_update_gold(GameState.gold)
	_update_special_buttons()

	# Αν το demo ήταν ήδη complete από προηγούμενο save
	if GameState.demo_complete:
		_demo_shown = true

# ─── Background ──────────────────────────────────────────────

func _style_background():
	var bg = $UI
	# Σκοτεινό πράσινο-γκρι background
	var canvas_bg = ColorRect.new()
	canvas_bg.color = Color(0.06, 0.09, 0.06)
	canvas_bg.anchor_right = 1.0
	canvas_bg.anchor_bottom = 1.0
	canvas_bg.z_index = -1
	add_child(canvas_bg)

# ─── Top Bar ─────────────────────────────────────────────────

func _style_top_bar():
	var top_bar = $UI/Layout/TopBar
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.11, 0.07)
	s.border_color = Color(0.18, 0.45, 0.12)
	s.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", s)

	gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	gold_label.add_theme_font_size_override("font_size", 26)
	total_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.45))
	total_label.add_theme_font_size_override("font_size", 11)

	var title = $UI/Layout/TopBar/MarginContainer/HBoxContainer/TitleLabel
	if title:
		title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.4))
		title.add_theme_font_size_override("font_size", 20)

# ─── Tap Button ──────────────────────────────────────────────

func _style_tap_button():
	tap_button.focus_mode = Control.FOCUS_NONE
	tap_button.custom_minimum_size = Vector2(100, 100)
	tap_button.text = ""
	var tex = load("res://assets/spuros.png")
	if tex:
		tap_button.icon = tex
		tap_button.expand_icon = true

	var mk = func(col: Color) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color = col
		s.corner_radius_top_left = s.corner_radius_top_right = 50
		s.corner_radius_bottom_left = s.corner_radius_bottom_right = 50
		s.border_color = col.lightened(0.35)
		s.border_width_top = s.border_width_bottom = s.border_width_left = s.border_width_right = 3
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 8
		return s

	tap_button.add_theme_stylebox_override("normal",  mk.call(Color("#1a6b8a")))
	tap_button.add_theme_stylebox_override("hover",   mk.call(Color("#2285aa")))
	tap_button.add_theme_stylebox_override("pressed", mk.call(Color("#0d4d66")))
	tap_button.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

# ─── Special Buttons ─────────────────────────────────────────

func _style_special_buttons():
	var colors = [Color("#155a75"), Color("#6a3208"), Color("#3d1575")]
	var btns   = [auto_collect_btn, max_cap_btn, auto_tap_btn]
	for i in range(3):
		var btn = btns[i]
		var c   = colors[i]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(108, 88)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color.WHITE)

		var mk = func(col: Color) -> StyleBoxFlat:
			var s = StyleBoxFlat.new()
			s.bg_color = col
			s.corner_radius_top_left = s.corner_radius_top_right = 10
			s.corner_radius_bottom_left = s.corner_radius_bottom_right = 10
			s.border_color = col.lightened(0.3)
			s.border_width_top = s.border_width_bottom = s.border_width_left = s.border_width_right = 1
			return s

		btn.add_theme_stylebox_override("normal",  mk.call(c))
		btn.add_theme_stylebox_override("hover",   mk.call(c.lightened(0.12)))
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
				_show_float("🌾 +%s" % GameState.fmt_number(float(earned)), Color(0.3, 1.0, 0.5))

	if GameState.auto_tap_level > 0:
		auto_tap_timer += delta
		if auto_tap_timer >= GameState.auto_tap_interval():
			auto_tap_timer = 0.0
			var earned = GameState.tap_gold()
			_show_float("💧 +%d" % earned, Color(0.3, 0.7, 1.0))

# ─── Tap ─────────────────────────────────────────────────────

func _on_tap_pressed():
	var earned = GameState.tap_gold()
	tap_rotation_deg += 1.0
	tap_button.pivot_offset = tap_button.size / 2.0
	tap_button.rotation_degrees = tap_rotation_deg
	_show_float("💧 +%d" % earned, Color(0.4, 0.85, 1.0))

# ─── Special Button Actions ───────────────────────────────────

func _on_auto_collect_upgrade():
	var was_zero = GameState.auto_collect_level == 0
	if GameState.upgrade_auto_collect():
		if was_zero:
			_show_float("🎉 Αυτο-Συλλογή ξεκλειδώθηκε!", Color(0.3, 1.0, 0.8))
		_check_game_complete()
	else:
		_show_float("Χρειάζεσαι %s 💰" % GameState.fmt_number(float(GameState.auto_collect_upgrade_cost())), Color(1.0, 0.3, 0.3))

func _on_max_cap_upgrade():
	if GameState.upgrade_max_capacity():
		_show_float("📦 Χωρητικότητα x%d!" % GameState.get_max_capacity(), Color(1.0, 0.7, 0.2))
		_check_game_complete()
	else:
		_show_float("Χρειάζεσαι %s 💰" % GameState.fmt_number(float(GameState.max_capacity_upgrade_cost())), Color(1.0, 0.3, 0.3))

func _on_auto_tap_upgrade():
	var was_zero = GameState.auto_tap_level == 0
	if GameState.upgrade_auto_tap():
		if was_zero:
			_show_float("🎉 Αυτο-Πάτημα ξεκλειδώθηκε!", Color(0.8, 0.3, 1.0))
		_check_game_complete()
	else:
		_show_float("Χρειάζεσαι %s 💰" % GameState.fmt_number(float(GameState.auto_tap_upgrade_cost())), Color(1.0, 0.3, 0.3))

# ─── Special Buttons UI ───────────────────────────────────────

func _update_special_buttons():
	# Auto Collect
	var ac = GameState.auto_collect_level
	var ac_c = GameState.auto_collect_upgrade_cost()
	auto_collect_btn.text = (
		"🌾 Αυτο-\nΣυλλογή\n🔓 %s💰" % GameState.fmt_number(float(ac_c))
		if ac == 0 else
		"🌾 Αυτο-\nΣυλλογή\nLv%d | %s\n+%s💰" % [ac, GameState.fmt_time(GameState.auto_collect_interval()), GameState.fmt_number(float(ac_c))]
	)
	auto_collect_btn.modulate = Color(1,1,1) if GameState.gold >= ac_c else Color(0.5,0.5,0.5)

	# Max Capacity
	var mc_c = GameState.max_capacity_upgrade_cost()
	max_cap_btn.text = "📦 Χωρητ.\nLv%d | x%d\n+%s💰" % [
		GameState.max_capacity_level,
		GameState.get_max_capacity(),
		GameState.fmt_number(float(mc_c))
	]
	max_cap_btn.modulate = Color(1,1,1) if GameState.gold >= mc_c else Color(0.5,0.5,0.5)

	# Auto Tap
	var at = GameState.auto_tap_level
	var at_c = GameState.auto_tap_upgrade_cost()
	auto_tap_btn.text = (
		"💧 Αυτο-\nΠάτημα\n🔓 %s💰" % GameState.fmt_number(float(at_c))
		if at == 0 else
		"💧 Αυτο-\nΠάτημα\nLv%d | %s\n+%s💰" % [at, GameState.fmt_time(GameState.auto_tap_interval()), GameState.fmt_number(float(at_c))]
	)
	auto_tap_btn.modulate = Color(1,1,1) if GameState.gold >= at_c else Color(0.5,0.5,0.5)

# ─── Gold Display ─────────────────────────────────────────────

func _update_gold(_v):
	gold_label.text  = "%s 💰" % GameState.fmt_number(GameState.gold)
	total_label.text = "Σύνολο: %s 💰" % GameState.fmt_number(GameState.total_earned)
	_update_special_buttons()

# ─── Float Text ───────────────────────────────────────────────

func _show_float(msg: String, color: Color):
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", color)
	var vp = get_viewport().get_visible_rect().size
	lbl.position = Vector2(vp.x / 2.0 - 60.0, vp.y - 230.0)
	lbl.z_index = 20
	get_tree().current_scene.add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 90.0, 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free).set_delay(1.2)

# ─── Game Complete ────────────────────────────────────────────

func _check_game_complete():
	if _demo_shown: return
	if not GameState.check_all_unlocked(): return
	_demo_shown = true
	upgrade_card.open_demo_complete()

# ─── Notifications ────────────────────────────────────────────

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
