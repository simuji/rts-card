class_name DropSlot
extends PanelContainer
## 投放区：收到卡牌后把语义交给 handler（由 demo 绑定）。

signal accepted_card(card: Control, definition: CardDefinition)

@export var slot_id: String = ""

@onready var _title: Label = %TitleLabel


func _ready() -> void:
	if slot_id.is_empty():
		slot_id = name
	if _title:
		_title.text = slot_id


func set_slot_title(t: String) -> void:
	slot_id = t
	if _title:
		_title.text = t


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "card"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var src: Control = data.get("source")
	var def: CardDefinition = data.get("definition")
	if src == null or def == null:
		return
	accepted_card.emit(src, def)
