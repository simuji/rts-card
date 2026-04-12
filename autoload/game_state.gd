extends Node
## Demo 用共享状态：玩家兵力为手牌（不由此处计数）；敌方仍为数值金/兵/基地。

signal stats_changed
signal game_over(player_won: bool)

## 玩家经济以「金币牌」表现；此处只记录已喂进兵营、尚未凑满产兵的部分（0..BARRACKS_COST-1）。
var player_barracks_gold: int = 0
var enemy_gold: int = 5
var enemy_army: int = 2

var player_base_hp: int = 20
var enemy_base_hp: int = 20

const BARRACKS_COST: int = 3
const ATTACK_SELF_ARMY_COST: int = 1
const ATTACK_BASE_DAMAGE: int = 3


func reset_demo() -> void:
	player_barracks_gold = 0
	enemy_gold = 5
	enemy_army = 2
	player_base_hp = 20
	enemy_base_hp = 20
	stats_changed.emit()


## 向兵营放入 1 张金币牌；每凑满 BARRACKS_COST 枚产 1 兵。返回本次产兵数量。
func feed_player_barracks_one_gold() -> int:
	player_barracks_gold += 1
	var produced := 0
	while player_barracks_gold >= BARRACKS_COST:
		player_barracks_gold -= BARRACKS_COST
		produced += 1
	stats_changed.emit()
	return produced


## 玩家已牺牲一名士兵（由界面扣牌），对敌方基地造成伤害。
func player_raid_enemy_base() -> void:
	enemy_base_hp -= ATTACK_BASE_DAMAGE
	stats_changed.emit()
	_check_end()


func enemy_try_train() -> bool:
	if enemy_gold < BARRACKS_COST:
		return false
	enemy_gold -= BARRACKS_COST
	enemy_army += 1
	stats_changed.emit()
	return true


func enemy_try_attack_player_base() -> bool:
	if enemy_army < ATTACK_SELF_ARMY_COST:
		return false
	enemy_army -= ATTACK_SELF_ARMY_COST
	player_base_hp -= ATTACK_BASE_DAMAGE
	stats_changed.emit()
	_check_end()
	return true


func tick_income() -> void:
	enemy_gold += 1
	stats_changed.emit()


func _check_end() -> void:
	if enemy_base_hp <= 0:
		game_over.emit(true)
	elif player_base_hp <= 0:
		game_over.emit(false)
