extends Node2D

@onready var gold_label   = $UI/Layout/TopBar/MarginContainer/HBoxContainer/VBoxContainer/GoldLabel
@onready var total_label  = $UI/Layout/TopBar/MarginContainer/HBoxContainer/VBoxContainer/TotalLabel
@onready var grid         = $UI/Layout/Scroll/Grid
@onready var upgrade_card = $UpgradeCard

const BuildingScene = preload("res://scenes/Βuilding.tscn")

func _ready():
	GameState.gold_changed.connect(_update_gold)
	for b in GameState.buildings:
		var card = BuildingScene.instantiate()
		card.building_id = b.id
		card.open_upgrade_card.connect(func(id): upgrade_card.open_for(id))
		grid.add_child(card)
	_update_gold(GameState.gold)

func _update_gold(_v):
	gold_label.text  = "%s 💰" % _fmt(GameState.gold)
	total_label.text = "Σύνολο: %s 💰" % _fmt(GameState.total_earned)

func _fmt(n: float) -> String:
	if n >= 1_000_000: return "%.1fM" % (n / 1_000_000.0)
	if n >= 1_000:     return "%.1fK" % (n / 1_000.0)
	return str(int(n))

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
