extends Control
## Demo：建筑/事件/物品/士兵皆为卡牌。物品(金币)→兵营建筑；士兵→前哨建筑；事件→议政厅。

const CARD_SCENE := preload("res://scenes/card/card.tscn")

@onready var _tick_label: Label = %TickLabel
@onready var _stats: Label = %StatsLabel
@onready var _log: RichTextLabel = %LogLabel
@onready var _board: HBoxContainer = %BoardRow
@onready var _hand: HBoxContainer = %HandRow
@onready var _overlay: ColorRect = %GameOverOverlay
@onready var _overlay_label: Label = %GameOverLabel
@onready var _enemy_ai: SimpleEnemyAI = %SimpleEnemyAI

var _ended: bool = false


func _ready() -> void:
	_overlay.visible = false
	%PauseBtn.toggled.connect(_on_pause_toggled)
	%RestartBtn.pressed.connect(_on_restart_pressed)
	%OverlayRestart.pressed.connect(_on_restart_pressed)
	TickManager.tick.connect(_on_global_tick)
	GameState.stats_changed.connect(_refresh_stats)
	GameState.game_over.connect(_on_game_over)
	_spawn_board()
	_spawn_hand()
	_refresh_stats()
	_append_log(
		"桌面：兵营(建筑)收金币(物品)；前哨(建筑)收士兵；议政厅(建筑)收事件牌。每 Tick 发 1 张金币。"
	)


func _spawn_board() -> void:
	_add_building_card(_make_building_def("barracks", "兵营"))
	_add_building_card(_make_building_def("outpost", "前哨"))
	_add_building_card(_make_building_def("council", "议政厅"))


func _make_building_def(bid: String, title: String) -> CardDefinition:
	var d := CardDefinition.new()
	d.id = bid
	d.display_name = title
	d.category = CardDefinition.Category.BUILDING
	d.draggable = false
	return d


func _add_building_card(def: CardDefinition) -> void:
	var c: TableCard = CARD_SCENE.instantiate()
	c.set_definition(def)
	c.custom_minimum_size = Vector2(128, 76)
	c.received_drop.connect(func(src: Control, ddef: CardDefinition): _on_building_drop(c, src, ddef))
	_board.add_child(c)


func _make_gold_def() -> CardDefinition:
	var d := CardDefinition.new()
	d.id = "gold"
	d.display_name = "金币"
	d.category = CardDefinition.Category.ITEM
	return d


func _make_soldier_def() -> CardDefinition:
	var d := CardDefinition.new()
	d.id = "soldier"
	d.display_name = "士兵"
	d.category = CardDefinition.Category.SOLDIER
	return d


func _make_caravan_event_def() -> CardDefinition:
	var d := CardDefinition.new()
	d.id = "caravan"
	d.display_name = "商队补给"
	d.category = CardDefinition.Category.EVENT
	return d


func _spawn_hand() -> void:
	for i in 4:
		_add_card(_make_gold_def())
	_add_card(_make_caravan_event_def())


func _add_card(def: CardDefinition) -> void:
	var c: TableCard = CARD_SCENE.instantiate()
	c.set_definition(def)
	_hand.add_child(c)


func _count_hand_category(cat: CardDefinition.Category) -> int:
	var n := 0
	for c in _hand.get_children():
		if c is TableCard:
			var def: CardDefinition = c.definition
			if def and def.category == cat:
				n += 1
	return n


func _clear_hand() -> void:
	for c in _hand.get_children():
		c.queue_free()


func _clear_board() -> void:
	for c in _board.get_children():
		c.queue_free()


func _on_global_tick(idx: int) -> void:
	if _ended:
		return
	_tick_label.text = "Tick #%d（间隔 %.1fs）" % [idx, TickManager.interval_seconds]
	GameState.tick_income()
	_add_card(_make_gold_def())
	_enemy_ai.react_to_tick()
	_append_log("Tick %d：电脑 +1 金；你获得 1 张金币(物品)。" % idx)


func _refresh_stats() -> void:
	var gs := GameState
	_stats.text = "手牌 物%d 兵%d 事件%d  兵营进度 %d/%d  基地 %d\n电脑 金%d 兵%d 基地%d" % [
		_count_hand_category(CardDefinition.Category.ITEM),
		_count_hand_category(CardDefinition.Category.SOLDIER),
		_count_hand_category(CardDefinition.Category.EVENT),
		gs.player_barracks_gold,
		gs.BARRACKS_COST,
		gs.player_base_hp,
		gs.enemy_gold,
		gs.enemy_army,
		gs.enemy_base_hp,
	]


func _on_building_drop(building: TableCard, dropped: Control, def: CardDefinition) -> void:
	match building.definition.id:
		"barracks":
			_resolve_barracks(dropped, def)
		"outpost":
			_resolve_outpost(dropped, def)
		"council":
			_resolve_council(dropped, def)
		_:
			pass


func _resolve_barracks(card: Control, def: CardDefinition) -> void:
	if def.category != CardDefinition.Category.ITEM or def.id != "gold":
		_append_log("兵营只收纳金币(物品)。")
		return
	if not card.get_parent():
		return
	card.queue_free()
	var produced := GameState.feed_player_barracks_one_gold()
	for i in produced:
		_add_card(_make_soldier_def())
	if produced > 0:
		_append_log("产出了 %d 张士兵牌。" % produced)
	else:
		_append_log("兵营收纳 1 枚金币（进度 %d/%d）。" % [
			GameState.player_barracks_gold,
			GameState.BARRACKS_COST,
		])


func _resolve_outpost(card: Control, def: CardDefinition) -> void:
	if def.category != CardDefinition.Category.SOLDIER:
		_append_log("前哨只接受士兵牌出击。")
		return
	if not card.get_parent():
		return
	card.queue_free()
	GameState.player_raid_enemy_base()
	_append_log("士兵突袭：对敌方基地 %d 伤害。" % GameState.ATTACK_BASE_DAMAGE)


func _resolve_council(card: Control, def: CardDefinition) -> void:
	if def.category != CardDefinition.Category.EVENT:
		_append_log("议政厅只结算事件牌。")
		return
	if not card.get_parent():
		return
	card.queue_free()
	match def.id:
		"caravan":
			for i in 2:
				_add_card(_make_gold_def())
			_append_log("事件「商队补给」：获得 2 张金币(物品)。")
		_:
			_append_log("未实现的事件：%s。" % def.id)


func _on_game_over(player_won: bool) -> void:
	_ended = true
	TickManager.set_paused(true)
	_overlay.visible = true
	_overlay_label.text = "你赢了！" if player_won else "你输了…"
	_append_log("游戏结束。")


func _append_log(line: String) -> void:
	_log.append_text(line + "\n")


func _on_restart_pressed() -> void:
	_ended = false
	TickManager.set_paused(false)
	_clear_hand()
	_clear_board()
	GameState.reset_demo()
	_spawn_board()
	_spawn_hand()
	_overlay.visible = false
	_log.clear()
	_refresh_stats()
	_append_log("已重置：四类卡牌已就位。")


func _on_pause_toggled(pressed: bool) -> void:
	TickManager.set_paused(pressed)
