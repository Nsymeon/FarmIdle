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
	upgrade_btn.pressed.connect(_on_upgrade)
	close_btn.pressed.connect(_on_close)
	overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed: _on_close())
	hide()

func open_for(building_id: int):
	_id = building_id
	_refresh()
	show()

func _refresh():
	if _id < 0: return
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
	upgrade_btn.text = ("⬆ Αναβάθμιση — %d💰" % cost) if can \
		else ("Χρειάζεσαι %d💰 ακόμα" % (cost - int(GameState.gold)))

func _fill_grid(grid: GridContainer, b: Dictionary, prev):
	for c in grid.get_children(): c.queue_free()
	var rows = [
		["Χρυσός/cycle:", "%d💰%s" % [
			GameState.gold_per_cycle(b),
			("  (+%d)" % (GameState.gold_per_cycle(b) - GameState.gold_per_cycle(prev))) if prev else ""]],
		["Χρόνος cycle:", GameState.fmt_time(GameState.cycle_time_sec(b))],
	]
	var col = Color(0.1, 0.5, 0.1) if prev else Color(0.2, 0.2, 0.2)
	for row in rows:
		var k = Label.new()
		k.text = row[0]
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		var v = Label.new()
		v.text = row[1]
		v.add_theme_font_size_override("font_size", 12)
		v.add_theme_color_override("font_color", col)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		grid.add_child(v)

func _on_upgrade():
	if GameState.upgrade(_id): _refresh()

func _on_close():
	hide()
	card_closed.emit()

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
