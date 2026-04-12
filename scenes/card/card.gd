class_name TableCard
extends PanelContainer
## 桌面卡牌：可拖动；建筑类卡牌可接收符合规则的拖放。

signal drag_ended
signal received_drop(dropped_source: Control, dropped_definition: CardDefinition)

@export var definition: CardDefinition

@onready var _label: Label = %NameLabel


func _ready() -> void:
	_apply_visuals()
	if definition and not definition.changed.is_connected(_apply_visuals):
		definition.changed.connect(_apply_visuals)


func set_definition(def: CardDefinition) -> void:
	definition = def
	_apply_visuals()


func _apply_visuals() -> void:
	if _label == null:
		return
	if definition:
		_label.text = definition.display_name
	else:
		_label.text = "?"


func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null or not definition.draggable:
		return null
	var preview := duplicate() as PanelContainer
	preview.custom_minimum_size = custom_minimum_size
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"type": "card", "source": self, "definition": definition}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if definition == null or definition.category != CardDefinition.Category.BUILDING:
		return false
	if not data is Dictionary or data.get("type", "") != "card":
		return false
	var ddef: CardDefinition = data.get("definition")
	if ddef == null:
		return false
	match definition.id:
		"barracks":
			return ddef.category == CardDefinition.Category.ITEM and ddef.id == "gold"
		"outpost":
			return ddef.category == CardDefinition.Category.SOLDIER
		"council":
			return ddef.category == CardDefinition.Category.EVENT
		_:
			return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var src: Control = data.get("source")
	var ddef: CardDefinition = data.get("definition")
	if src == null or ddef == null:
		return
	received_drop.emit(src, ddef)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_ended.emit()
