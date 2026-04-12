class_name CardDefinition
extends Resource

enum Category { BUILDING, EVENT, ITEM, SOLDIER }

@export var id: String = ""
@export var display_name: String = "Card"
@export var category: Category = Category.ITEM
## 建筑等固定在桌面上的牌设为 false，不可拖入手牌区外操作。
@export var draggable: bool = true
