extends CanvasLayer

@onready var overlay     = $Overlay
@onready var b_icon      = $Overlay/Card/MarginContainer/VBoxContainer/Header/BIcon
@onready var b_name      = $Overlay/Card/MarginContainer/VBoxContainer/Header/VBoxContainer/BName
@onready var b_level     = $Overlay/Card/MarginContainer/VBoxContainer/Header/VBoxContainer/BLevel
@onready var grid_now    = $Overlay/Card/MarginContainer/VBoxContainer/GridNow
@onready var grid_next   = $Overlay/Card/MarginContainer/VBoxContainer/GridNext
@onready var upgrade_btn = $Overlay/Card/MarginContainer/VBoxContainer/UpgradeBtn
@onready var close_btn   = $Overlay/Card/MarginContainer/VBoxContainer/CloseBtn

signal card_closed
var _id: int = -1

func _ready():
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	overlay.gui_input.connect(_on_overlay_input)
	hide()

func open_for(building_id: int):
	_id = building_id
	_refresh()
	show()

func open_demo_complete():
	_id = -1
	b_icon.text  = "🏆"
	b_name.text  = "Συγχαρητήρια!"
	b_level.text = "Έφτασες στο τέλος του demo!"
	for c in grid_now.get_children(): c.queue_free()
	for c in grid_next.get_children(): c.queue_free()
	var lbl = Label.new()
	lbl.text = "Ευχαριστούμε που παίξατε!\nΕλπίζουμε να σας άρεσε!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	grid_now.add_child(lbl)
	upgrade_btn.text     = "Κλείσιμο"
	upgrade_btn.disabled = false
	upgrade_btn.modulate = Color(1, 1, 1)
	show()

func _refresh():
	if _id < 0:
		return
	var b     = GameState.buildings[_id]
	var bn    = b.duplicate(true)
	bn.level += 1
	var cost  = GameState.upgrade_cost(b)

	b_icon.text  = b.icon_text
	b_name.text  = b.name
	b_level.text = "Επίπεδο %d" % b.level

	_fill_grid(grid_now, b, null)
	_fill_grid(grid_next, bn, b)

	var can = GameState.gold >= cost
	upgrade_btn.disabled = not can
	upgrade_btn.text = "⬆ Αναβάθμιση — %s💰" % GameState.fmt_number(float(cost)) if can \
		else "Χρειάζεσαι %s💰 ακόμα" % GameState.fmt_number(float(cost - int(GameState.gold)))

func _fill_grid(grid: GridContainer, b: Dictionary, prev):
	for c in grid.get_children():
		c.queue_free()
	var rows = [
		["Χρυσός/cycle:", "%s💰%s" % [
			GameState.fmt_number(float(GameState.gold_per_cycle(b))),
			("  (+%d)" % (GameState.gold_per_cycle(b) - GameState.gold_per_cycle(prev))) if prev else ""]],
		["Χρόνος cycle:", GameState.fmt_time(GameState.cycle_time_sec(b))],
	]
	var val_color = Color(0.1, 0.5, 0.1) if prev else Color(0.2, 0.2, 0.2)
	for row in rows:
		var k = Label.new()
		k.text = row[0]
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		var v = Label.new()
		v.text = row[1]
		v.add_theme_font_size_override("font_size", 12)
		v.add_theme_color_override("font_color", val_color)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		grid.add_child(v)

func _on_upgrade_pressed():
	if _id < 0:
		_on_close_pressed()
		return
	if GameState.upgrade(_id):
		_refresh()

func _on_close_pressed():
	hide()
	card_closed.emit()

func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_close_pressed()

func _input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
