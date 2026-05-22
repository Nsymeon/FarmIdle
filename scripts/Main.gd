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

func _ready():
	# Βεβαιώσου ότι το Scroll παίρνει όλο τον διαθέσιμο χώρο
	$UI/Layout/Scroll.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	GameState.gold_changed.connect(_update_gold)
	GameState.special_upgraded.connect(_update_special_buttons)
	tap_button.pressed.connect(_on_tap_pressed)
	auto_collect_btn.pressed.connect(_on_auto_collect_upgrade)
	max_cap_btn.pressed.connect(_on_max_cap_upgrade)
	auto_tap_btn.pressed.connect(_on_auto_tap_upgrade)

	# Κυκλικό tap button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#4a8c2a")
	style_normal.corner_radius_top_left    = 45
	style_normal.corner_radius_top_right   = 45
	style_normal.corner_radius_bottom_left = 45
	style_normal.corner_radius_bottom_right = 45
	style_normal.border_width_top    = 3
	style_normal.border_width_bottom = 3
	style_normal.border_width_left   = 3
	style_normal.border_width_right  = 3
	style_normal.border_color = Color("#88cc44")
	style_normal.content_margin_left   = 0
	style_normal.content_margin_right  = 0
	style_normal.content_margin_top    = 0
	style_normal.content_margin_bottom = 0
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color("#5da334")
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color("#3a7020")
	tap_button.add_theme_stylebox_override("normal",  style_normal)
	tap_button.add_theme_stylebox_override("hover",   style_hover)
	tap_button.add_theme_stylebox_override("pressed", style_pressed)
	tap_button.custom_minimum_size = Vector2(90, 90)

	for b in GameState.buildings:
		var card = BuildingScene.instantiate()
		card.building_id = b.id
		card.open_upgrade_card.connect(func(id): upgrade_card.open_for(id))
		grid.add_child(card)

	_update_gold(GameState.gold)
	_update_special_buttons()

# ─────────────────────────────────────────────────────────────
# GAME LOOP
# ─────────────────────────────────────────────────────────────
func _process(delta: float):
	# Auto collect
	if GameState.auto_collect_level > 0:
		auto_collect_timer += delta
		if auto_collect_timer >= GameState.auto_collect_interval():
			auto_collect_timer = 0.0
			var earned = GameState.collect_all()
			if earned > 0:
				_show_float("+%s AUTO" % GameState._fmt_number(float(earned)), Color(0.3, 0.9, 1.0))

	# Auto tap
	if GameState.auto_tap_level > 0:
		auto_tap_timer += delta
		if auto_tap_timer >= GameState.auto_tap_interval():
			auto_tap_timer = 0.0
			var earned = GameState.tap_gold()
			_show_float("+%d TAP" % earned, Color(1.0, 0.85, 0.1))

# ─────────────────────────────────────────────────────────────
# TAP BUTTON
# ─────────────────────────────────────────────────────────────
func _on_tap_pressed():
	var earned = GameState.tap_gold()
	_show_float("+%d" % earned, Color(0.3, 0.7, 1.0))

# Tap gold = 1 base
#          + sum of building levels
#          + 2 × auto_collect_level
#          + 3 × max_capacity_level
#          + 2 × auto_tap_level
# (GameState.tap_gold() υπολογίζει αυτόματα τα building levels,
#  τα special bonuses τα προσθέτουμε εδώ ως display hint)
func _tap_power() -> int:
	var total = 1
	for b in GameState.buildings:
		if b.unlocked:
			total += b.level
	total += GameState.auto_collect_level * 2
	total += GameState.max_capacity_level * 3
	total += GameState.auto_tap_level * 2
	return total

# ─────────────────────────────────────────────────────────────
# SPECIAL BUTTONS
# ─────────────────────────────────────────────────────────────
func _on_auto_collect_upgrade():
	var was_zero = GameState.auto_collect_level == 0
	var success  = GameState.upgrade_auto_collect()
	if success:
		if was_zero:
			_show_float("Μπράβο!\nΞεκλείδωσες\nΑυτο-Συλλογή!", Color(0.3, 0.9, 1.0))
		_check_game_complete()
	else:
		var cost = GameState.auto_collect_upgrade_cost()
		_show_float("Χρειάζεσαι\n%s💰" % GameState._fmt_number(float(cost)), Color(1.0, 0.3, 0.3))

func _on_max_cap_upgrade():
	var success = GameState.upgrade_max_capacity()
	if success:
		_check_game_complete()
	else:
		var cost = GameState.max_capacity_upgrade_cost()
		_show_float("Χρειάζεσαι\n%s💰" % GameState._fmt_number(float(cost)), Color(1.0, 0.3, 0.3))

func _on_auto_tap_upgrade():
	var was_zero = GameState.auto_tap_level == 0
	var success  = GameState.upgrade_auto_tap()
	if success:
		if was_zero:
			_show_float("Μπράβο!\nΞεκλείδωσες\nΑυτο-Πάτημα!", Color(0.7, 0.3, 1.0))
		_check_game_complete()
	else:
		var cost = GameState.auto_tap_upgrade_cost()
		_show_float("Χρειάζεσαι\n%s💰" % GameState._fmt_number(float(cost)), Color(1.0, 0.3, 0.3))

func _update_special_buttons():
	# ── Auto Collect ──────────────────────────────────────────
	var ac_lvl  = GameState.auto_collect_level
	var ac_cost = GameState.auto_collect_upgrade_cost()
	var ac_can  = GameState.gold >= ac_cost
	if ac_lvl == 0:
		auto_collect_btn.text = "Αυτο-\nΣυλλογη\nΞεκλ. %s" % GameState._fmt_number(float(ac_cost))
	else:
		auto_collect_btn.text = "Αυτο-\nΣυλλογη\nLv%d|%ss\n+%s💰" % [
			ac_lvl,
			GameState._fmt_number(GameState.auto_collect_interval()),
			GameState._fmt_number(float(ac_cost))
		]
	auto_collect_btn.modulate = Color(1,1,1) if ac_can else Color(0.6,0.6,0.6)

	# ── Max Capacity ──────────────────────────────────────────
	var mc_lvl  = GameState.max_capacity_level
	var mc_cost = GameState.max_capacity_upgrade_cost()
	var mc_can  = GameState.gold >= mc_cost
	max_cap_btn.text = "Χωρητ.\nLv%d|x%d\n+%s💰" % [
		mc_lvl,
		GameState.get_max_capacity(),
		GameState._fmt_number(float(mc_cost))
	]
	max_cap_btn.modulate = Color(1,1,1) if mc_can else Color(0.6,0.6,0.6)

	# ── Auto Tap ──────────────────────────────────────────────
	var at_lvl  = GameState.auto_tap_level
	var at_cost = GameState.auto_tap_upgrade_cost()
	var at_can  = GameState.gold >= at_cost
	if at_lvl == 0:
		auto_tap_btn.text = "Αυτο-\nΠατημα\nΞεκλ. %s" % GameState._fmt_number(float(at_cost))
	else:
		auto_tap_btn.text = "Αυτο-\nΠατημα\nLv%d|%ss\n+%s💰" % [
			at_lvl,
			GameState._fmt_number(GameState.auto_tap_interval()),
			GameState._fmt_number(float(at_cost))
		]
	auto_tap_btn.modulate = Color(1,1,1) if at_can else Color(0.6,0.6,0.6)

	# Ενημέρωσε tap button tooltip με νέο power
	tap_button.tooltip_text = "+%d💰 ανά πάτημα" % _tap_power()

# ─────────────────────────────────────────────────────────────
# ΤΕΛΟΣ DEMO
# ─────────────────────────────────────────────────────────────
func _check_game_complete():
	for b in GameState.buildings:
		if not b.unlocked:
			return
	if GameState.auto_collect_level == 0:
		return
	if GameState.auto_tap_level == 0:
		return
	_show_demo_complete()

func _show_demo_complete():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.anchor_right  = 1.0
	overlay.anchor_bottom = 1.0
	overlay.z_index = 100
	get_tree().current_scene.add_child(overlay)

	var lbl = Label.new()
	lbl.text = "Συγχαρητήρια!\n\nΈχεις φτάσει\nστο τέλος\nαυτού του demo!\n\nΕυχαριστούμε\nπου παίξατε!"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.anchor_right  = 1.0
	lbl.anchor_bottom = 1.0
	lbl.z_index = 101
	get_tree().current_scene.add_child(lbl)

# ─────────────────────────────────────────────────────────────
# UI HELPERS
# ─────────────────────────────────────────────────────────────
func _show_float(msg: String, color: Color):
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(
		get_viewport().get_visible_rect().size.x / 2.0 - 60.0,
		get_viewport().get_visible_rect().size.y - 220.0
	)
	lbl.z_index = 20
	get_tree().current_scene.add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 80.0, 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free).set_delay(1.2)

func _update_gold(_v):
	gold_label.text  = "%s" % _fmt(GameState.gold)
	total_label.text = "Σύνολο: %s" % _fmt(GameState.total_earned)
	_update_special_buttons()
	_check_game_complete()

func _fmt(n: float) -> String:
	if n >= 1_000_000: return "%.1fM" % (n / 1_000_000.0)
	if n >= 1_000:     return "%.1fK" % (n / 1_000.0)
	return str(int(n))

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
