class_name SimpleEnemyAI
extends Node
## 每个全局 tick 做一次决策：优先征兵，否则在有余力时进攻玩家基地。

func react_to_tick() -> void:
	if not is_instance_valid(GameState):
		return
	# 简单优先级：先攒钱征兵；兵够就换家
	if GameState.enemy_gold >= GameState.BARRACKS_COST:
		GameState.enemy_try_train()
	elif GameState.enemy_army >= GameState.ATTACK_SELF_ARMY_COST:
		GameState.enemy_try_attack_player_base()
