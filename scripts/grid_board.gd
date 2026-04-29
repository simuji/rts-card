extends Node2D

const PREVIEW_OK_ALPHA := 0.45
const PREVIEW_BLOCKED_ALPHA := 0.35
const EMPTY_CARD_TEXT := "空"
const HAND_CARD_SIZE := Vector2(128, 128)
const CARD_GAP := 12.0
const HAND_CARD_SCENES := {
	"木材": preload("res://scenes/card/ItemCard/wood_card.tscn"),
	"石头": preload("res://scenes/card/ItemCard/stone_card.tscn"),
	"士兵": preload("res://scenes/card/UnitCard/soldier_card.tscn"),
	"弓箭手": preload("res://scenes/card/UnitCard/archer_card.tscn"),
	"矿工": preload("res://scenes/card/UnitCard/miner_card.tscn"),
	"伐木工": preload("res://scenes/card/UnitCard/lumberjack_card.tscn")
}
const SLOT_SIZE := Vector2(128, 128)
const BUILDING_CARD_PREVIEW_SIZE := 128.0
const BUILDING_PREVIEW_HOUSE := preload("res://scenes/card/BuildingCard/house_card.tscn")
const BUILDING_PREVIEW_CAMP := preload("res://scenes/card/BuildingCard/camp_card.tscn")
const BUILDING_PREVIEW_FOREST := preload("res://scenes/card/BuildingCard/forest_card.tscn")
const BUILDING_PREVIEW_MINE := preload("res://scenes/card/BuildingCard/mine_card.tscn")

@export var grid_cols: int = 16
@export var grid_rows: int = 10
@export var cell_size: int = 48
@export var board_origin: Vector2 = Vector2(0, -20)
@export var initial_forest_count: int = 6
@export var initial_mine_count: int = 5

var building_defs: Array[Dictionary] = [
	{
		"id": "hut",
		"display_name": "小屋",
		"description": "基础建筑，当前未配置生产配方。",
		"size": Vector2i(1, 1),
		"color": Color(0.35, 0.85, 0.45),
		"preview_scene": BUILDING_PREVIEW_HOUSE,
		"recipes": []
	},
	{
		"id": "farm",
		"display_name": "麦田",
		"description": "农业建筑，配方可在后续版本配置。",
		"size": Vector2i(2, 1),
		"color": Color(0.30, 0.70, 0.95),
		"preview_scene": BUILDING_PREVIEW_CAMP,
		"recipes": []
	},
	{
		"id": "tower",
		"display_name": "塔楼",
		"description": "防御建筑，当前未配置生产配方。",
		"size": Vector2i(2, 2),
		"color": Color(0.85, 0.55, 0.25),
		"preview_scene": BUILDING_PREVIEW_CAMP,
		"recipes": []
	},
	{
		"id": "hall",
		"display_name": "大厅",
		"description": "中心建筑，当前未配置生产配方。",
		"size": Vector2i(3, 2),
		"color": Color(0.70, 0.35, 0.90),
		"preview_scene": BUILDING_PREVIEW_HOUSE,
		"recipes": []
	}
]

var selected_building_idx: int = 0
var selected_size: Vector2i = Vector2i.ONE
var hovered_cell: Vector2i = Vector2i(-1, -1)

var occupied_cells: Dictionary = {}
var placed_buildings: Array[Dictionary] = []
var active_building_index: int = -1

var hand_cards: Array[Dictionary] = [
	{"type": "item", "name": "士兵", "count": 3},
	{"type": "item", "name": "弓箭手", "count": 2},
	{"type": "item", "name": "矿工", "count": 3},
	{"type": "item", "name": "伐木工", "count": 3},
	{"type": "event", "name": "行军"}
]
var dragging_card: Dictionary = {}
var dragging_card_index: int = -1
var dragging_mouse_pos: Vector2 = Vector2.ZERO
## 从手牌放入卡槽时扣除的数量；事件卡为 0（手牌不减少）。
var dragging_hand_take_count: int = 0
var building_placed_layer: Control
var building_preview_host: Control
var building_preview_card: Control
var hand_visual_layer: Control
var hand_drag_ghost: Control

@onready var building_panel: PanelContainer = $CanvasLayer/BuildingPanel
@onready var title_label: Label = $CanvasLayer/BuildingPanel/Margin/VBox/Title
@onready var desc_label: Label = $CanvasLayer/BuildingPanel/Margin/VBox/Description
@onready var event_slot_label: Label = $CanvasLayer/BuildingPanel/Margin/VBox/EventSlotLabel
@onready var resource_slot_label: Label = $CanvasLayer/BuildingPanel/Margin/VBox/ResourceSlotLabel
@onready var event_slot_area: PanelContainer = $CanvasLayer/BuildingPanel/Margin/VBox/SlotRow/EventSlotArea
@onready var resource_slot_area: PanelContainer = $CanvasLayer/BuildingPanel/Margin/VBox/SlotRow/ResourceSlotArea
@onready var produce_btn: Button = $CanvasLayer/BuildingPanel/Margin/VBox/ProduceButton
@onready var add_cards_btn: Button = $CanvasLayer/BuildingPanel/Margin/VBox/AddCardsButton
@onready var result_label: Label = $CanvasLayer/BuildingPanel/Margin/VBox/Result
@onready var tip_label: Label = $CanvasLayer/BuildingPanel/Margin/VBox/DragTip


## 与 GUI 一致：用 Viewport 当前鼠标（避免 event.position 与系统光标在 stretch 下不同步）
func _viewport_mouse() -> Vector2:
	return get_viewport().get_mouse_position()


## 视口坐标 → 本节点局部（viewport = get_global_transform_with_canvas() * local）
func _board_pointer_from_viewport(vp_mouse: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * vp_mouse


## 视口坐标 → 画布坐标，与 Control.get_global_rect 同一空间
func _ui_contains_pointer(c: Control, vp_mouse: Vector2) -> bool:
	var canvas_pt := get_viewport().get_canvas_transform().affine_inverse() * vp_mouse
	return c.get_global_rect().has_point(canvas_pt)


func _ready() -> void:
	selected_size = building_defs[selected_building_idx]["size"]
	building_panel.visible = false
	event_slot_area.custom_minimum_size = SLOT_SIZE
	resource_slot_area.custom_minimum_size = SLOT_SIZE
	event_slot_area.size = SLOT_SIZE
	resource_slot_area.size = SLOT_SIZE
	produce_btn.pressed.connect(_on_produce_pressed)
	add_cards_btn.pressed.connect(_on_add_cards_pressed)
	_setup_building_world_ui()
	_spawn_random_forests_and_mines()
	_setup_hand_visual_layer()
	_sync_hand_card_visuals()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var vp_mouse := _viewport_mouse()
		var board_mouse := _board_pointer_from_viewport(vp_mouse)
		hovered_cell = _world_to_cell(board_mouse)
		dragging_mouse_pos = board_mouse
		if not dragging_card.is_empty():
			_position_hand_drag_ghost(board_mouse)
		_update_building_placement_preview()
		queue_redraw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var vp_b := _viewport_mouse()
		var board_mouse_b := _board_pointer_from_viewport(vp_b)
		if _start_drag_from_slot(vp_b):
			return
		if _start_drag_from_hand(board_mouse_b):
			return
		if _is_mouse_over_building_panel(vp_b):
			# Let UI controls (e.g. produce button) handle the click.
			return
		var click_cell := _world_to_cell(board_mouse_b)
		_on_left_click(click_cell)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var vp_u := _viewport_mouse()
		if dragging_card_index >= 0:
			_try_drop_card_to_slot(vp_u)
			queue_redraw()
			return

	# Fallback: if dragging from slot (index = -1) and mouse is released, ensure drag exits.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var vp_u2 := _viewport_mouse()
		if not dragging_card.is_empty():
			_try_drop_card_to_slot(vp_u2)
			queue_redraw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var vp_r := _viewport_mouse()
		var board_mouse_r := _board_pointer_from_viewport(vp_r)
		if _is_mouse_over_building_panel(vp_r) or _hand_card_index_at(board_mouse_r) >= 0:
			return
		var click_cell := _world_to_cell(board_mouse_r)
		_remove_at(click_cell)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_select_building(0)
			KEY_2, KEY_KP_2:
				_select_building(1)
			KEY_3, KEY_KP_3:
				_select_building(2)
			KEY_4, KEY_KP_4:
				_select_building(3)
			KEY_R:
				selected_size = Vector2i(selected_size.y, selected_size.x)
				_update_building_placement_preview()
				queue_redraw()


func _draw() -> void:
	_draw_grid()
	_draw_placed_buildings()
	_draw_preview()
	_draw_legend()
	_draw_hand_title()


func _draw_grid() -> void:
	var board_size := Vector2(grid_cols * cell_size, grid_rows * cell_size)
	draw_rect(Rect2(board_origin, board_size), Color(0.13, 0.15, 0.18), true)
	for x in range(grid_cols + 1):
		var from := board_origin + Vector2(x * cell_size, 0)
		var to := from + Vector2(0, grid_rows * cell_size)
		draw_line(from, to, Color(0.35, 0.38, 0.42), 1.0)
	for y in range(grid_rows + 1):
		var from := board_origin + Vector2(0, y * cell_size)
		var to := from + Vector2(grid_cols * cell_size, 0)
		draw_line(from, to, Color(0.35, 0.38, 0.42), 1.0)


func _draw_placed_buildings() -> void:
	for i in range(placed_buildings.size()):
		var building := placed_buildings[i]
		var top_left: Vector2i = building["cell"]
		var size: Vector2i = building["size"]
		var rect := Rect2(board_origin + Vector2(top_left.x * cell_size, top_left.y * cell_size), Vector2(size.x * cell_size, size.y * cell_size))
		if building.get("visual_host") == null:
			var color: Color = building["color"]
			draw_rect(rect, color, true)
			draw_rect(rect, Color(0, 0, 0, 0.5), false, 2.0)
		if i == active_building_index:
			draw_rect(rect.grow(2), Color(1, 1, 0.25, 0.9), false, 3.0)


func _draw_preview() -> void:
	if not _is_cell_inside_board(hovered_cell):
		return
	var selected_def := building_defs[selected_building_idx]
	var preview_rect := Rect2(board_origin + Vector2(hovered_cell.x * cell_size, hovered_cell.y * cell_size), Vector2(selected_size.x * cell_size, selected_size.y * cell_size))
	var can_place := _can_place(hovered_cell, selected_size)
	if selected_def.get("preview_scene") != null and building_preview_card != null and building_preview_host.visible:
		var border_col := Color(0.35, 0.95, 0.55, 0.95) if can_place else Color(0.95, 0.25, 0.22, 0.95)
		draw_rect(preview_rect, border_col, false, 3.0)
		return
	var preview_color: Color = selected_def["color"]
	preview_color.a = PREVIEW_OK_ALPHA if can_place else PREVIEW_BLOCKED_ALPHA
	if not can_place:
		preview_color = Color(0.95, 0.2, 0.2, PREVIEW_BLOCKED_ALPHA)
	draw_rect(preview_rect, preview_color, true)
	draw_rect(preview_rect, Color(1, 1, 1, 0.8), false, 2.0)


func _draw_legend() -> void:
	var selected_def := building_defs[selected_building_idx]
	var hint := "1-4 选建筑 | R 旋转尺寸 | 左键放置/选中 | 右键移除"
	var info := "当前: %s  大小: %dx%d | 从下方手牌拖入右侧卡槽" % [selected_def["display_name"], selected_size.x, selected_size.y]
	draw_string(ThemeDB.fallback_font, Vector2(board_origin.x, board_origin.y - 24), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.93, 0.93, 0.93))
	draw_string(ThemeDB.fallback_font, Vector2(board_origin.x, board_origin.y - 6), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.85, 0.45))


func _draw_hand_title() -> void:
	var origin := _hand_origin()
	draw_string(ThemeDB.fallback_font, origin + Vector2(0, -10), "卡牌栏（按住左键拖拽）", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 0.95))


func _on_left_click(cell: Vector2i) -> void:
	if not _is_cell_inside_board(cell):
		_close_building_panel()
		return
	if occupied_cells.has(cell):
		_open_building_panel(occupied_cells[cell])
		return
	_try_place_at(cell)
	_close_building_panel()


func _select_building(idx: int) -> void:
	if idx < 0 or idx >= building_defs.size():
		return
	selected_building_idx = idx
	selected_size = building_defs[selected_building_idx]["size"]
	_rebuild_building_preview_card()
	_update_building_placement_preview()
	queue_redraw()


func _setup_building_world_ui() -> void:
	building_placed_layer = Control.new()
	building_placed_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(building_placed_layer)

	building_preview_host = Control.new()
	building_preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(building_preview_host)

	_rebuild_building_preview_card()
	_update_building_placement_preview()


func _rebuild_building_preview_card() -> void:
	if building_preview_card != null:
		building_preview_card.queue_free()
		building_preview_card = null
	if building_preview_host == null:
		return
	var def: Dictionary = building_defs[selected_building_idx]
	var ps: Variant = def.get("preview_scene", null)
	if ps == null or not (ps is PackedScene):
		if building_preview_host != null:
			building_preview_host.visible = false
		return
	var inst := (ps as PackedScene).instantiate()
	if not (inst is Control):
		if inst is Node:
			(inst as Node).queue_free()
		return
	building_preview_card = inst as Control
	building_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_control_mouse_ignore_recursive(building_preview_card)
	building_preview_host.add_child(building_preview_card)


func _set_control_mouse_ignore_recursive(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_set_control_mouse_ignore_recursive(c)


func _setup_hand_visual_layer() -> void:
	hand_visual_layer = Control.new()
	hand_visual_layer.name = "HandVisualLayer"
	hand_visual_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_visual_layer)


func _sync_hand_card_visuals() -> void:
	if hand_visual_layer == null:
		return
	while hand_visual_layer.get_child_count() > 0:
		var c: Node = hand_visual_layer.get_child(0)
		hand_visual_layer.remove_child(c)
		c.free()
	hand_visual_layer.position = _hand_origin()
	for i in range(hand_cards.size()):
		if i == dragging_card_index:
			continue
		var v := _instantiate_hand_card_visual(hand_cards[i])
		hand_visual_layer.add_child(v)
		v.position = Vector2((HAND_CARD_SIZE.x + CARD_GAP) * i, 0)


func _instantiate_hand_card_visual(card: Dictionary) -> Control:
	var cn := str(card.get("name", ""))
	var scene: Variant = HAND_CARD_SCENES.get(cn, null)
	if scene != null and scene is PackedScene:
		var inst := (scene as PackedScene).instantiate()
		if not (inst is Control):
			if inst is Node:
				(inst as Node).queue_free()
			return _make_fallback_hand_panel(card)
		var ctl := inst as Control
		if "input_disabled_for_hand_preview" in ctl:
			ctl.set("input_disabled_for_hand_preview", true)
		ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_control_mouse_ignore_recursive(ctl)
		_apply_hand_card_name_label(ctl, card)
		ctl.custom_minimum_size = HAND_CARD_SIZE
		ctl.size = HAND_CARD_SIZE
		return ctl
	return _make_fallback_hand_panel(card)


func _make_fallback_hand_panel(card: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = HAND_CARD_SIZE
	p.size = HAND_CARD_SIZE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := Label.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.set_anchors_preset(Control.PRESET_FULL_RECT)
	lb.offset_left = 6.0
	lb.offset_top = 6.0
	lb.offset_right = -6.0
	lb.offset_bottom = -6.0
	lb.add_theme_color_override("font_color", Color(1, 1, 1))
	lb.text = _format_card_name(card)
	p.add_child(lb)
	return p


func _apply_hand_card_name_label(root: Control, card: Dictionary) -> void:
	var nl: Node = root.get_node_or_null("NameLabel")
	if nl is Label:
		var typ := str(card.get("type", ""))
		if typ == "event":
			(nl as Label).text = "%s\nx1" % str(card.get("name", ""))
		else:
			(nl as Label).text = "%s\nx%d" % [str(card.get("name", "")), int(card.get("count", 1))]


func _create_hand_drag_ghost() -> void:
	_destroy_hand_drag_ghost()
	if dragging_card.is_empty():
		return
	hand_drag_ghost = _instantiate_hand_card_visual(dragging_card)
	if hand_drag_ghost == null:
		return
	add_child(hand_drag_ghost)
	hand_drag_ghost.z_index = 200
	hand_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_position_hand_drag_ghost(dragging_mouse_pos)


func _destroy_hand_drag_ghost() -> void:
	if hand_drag_ghost != null and is_instance_valid(hand_drag_ghost):
		hand_drag_ghost.queue_free()
	hand_drag_ghost = null


func _position_hand_drag_ghost(mouse_pos: Vector2) -> void:
	if hand_drag_ghost == null or not is_instance_valid(hand_drag_ghost):
		return
	hand_drag_ghost.position = mouse_pos - HAND_CARD_SIZE * 0.5


func _layout_building_card_in_host(host: Control, card: Control, top_left_cell: Vector2i, footprint: Vector2i, modulate_color: Color) -> void:
	var fp := Vector2(footprint.x * cell_size, footprint.y * cell_size)
	host.position = board_origin + Vector2(top_left_cell.x * cell_size, top_left_cell.y * cell_size)
	host.size = fp
	var s: float = minf(fp.x / BUILDING_CARD_PREVIEW_SIZE, fp.y / BUILDING_CARD_PREVIEW_SIZE)
	card.scale = Vector2(s, s)
	var drawn := Vector2(BUILDING_CARD_PREVIEW_SIZE * s, BUILDING_CARD_PREVIEW_SIZE * s)
	card.position = (fp - drawn) * 0.5
	card.modulate = modulate_color


func _update_building_placement_preview() -> void:
	if building_preview_host == null:
		return
	if building_preview_card == null:
		building_preview_host.visible = false
		return
	if not _is_cell_inside_board(hovered_cell):
		building_preview_host.visible = false
		return
	var can_place := _can_place(hovered_cell, selected_size)
	building_preview_host.visible = true
	var tint := Color(1, 1, 1, 0.88) if can_place else Color(1, 0.72, 0.72, 0.78)
	_layout_building_card_in_host(building_preview_host, building_preview_card, hovered_cell, selected_size, tint)


func _mount_placed_building_visual(building: Dictionary) -> void:
	if building_placed_layer == null:
		return
	var ps: Variant = building.get("preview_scene", null)
	if ps == null or not (ps is PackedScene):
		return
	var inst := (ps as PackedScene).instantiate()
	if not (inst is Control):
		if inst is Node:
			(inst as Node).queue_free()
		return
	var card := inst as Control
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_control_mouse_ignore_recursive(card)
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_placed_layer.add_child(host)
	host.add_child(card)
	building["visual_host"] = host
	building["visual_card"] = card
	var cell: Vector2i = building["cell"]
	var footprint: Vector2i = building["size"]
	_layout_building_card_in_host(host, card, cell, footprint, Color(1, 1, 1, 1))


func _free_placed_building_visual(building: Dictionary) -> void:
	var host: Variant = building.get("visual_host")
	if host is Control:
		(host as Control).queue_free()
	building.erase("visual_host")
	building.erase("visual_card")


func _make_building_dict(def: Dictionary, cell: Vector2i, footprint: Vector2i) -> Dictionary:
	return {
		"id": def["id"],
		"display_name": def["display_name"],
		"description": def["description"],
		"recipes": def["recipes"],
		"cell": cell,
		"size": footprint,
		"color": def["color"],
		"preview_scene": def.get("preview_scene"),
		"event_card": "",
		"resource_cards": {},
		"items": {}
	}


func _commit_building_to_grid(building: Dictionary) -> void:
	var cell: Vector2i = building["cell"]
	var footprint: Vector2i = building["size"]
	var building_index := placed_buildings.size()
	placed_buildings.append(building)
	_mount_placed_building_visual(building)
	for tile in _cells_for_footprint(cell, footprint):
		occupied_cells[tile] = building_index


func _forest_building_def() -> Dictionary:
	return {
		"id": "forest",
		"display_name": "森林",
		"description": "在资源卡槽放入伐木工并执行生产，可获得木材（无需事件卡）。",
		"size": Vector2i(1, 1),
		"color": Color(0.18, 0.48, 0.26),
		"preview_scene": BUILDING_PREVIEW_FOREST,
		"recipes": [
			{
				"event": "",
				"resources": {"伐木工": 1},
				"outputs": {"木材": 3}
			}
		]
	}


func _mine_building_def() -> Dictionary:
	return {
		"id": "mine",
		"display_name": "矿洞",
		"description": "在资源卡槽放入矿工并执行生产，可获得石头（无需事件卡）。",
		"size": Vector2i(1, 1),
		"color": Color(0.35, 0.32, 0.38),
		"preview_scene": BUILDING_PREVIEW_MINE,
		"recipes": [
			{
				"event": "",
				"resources": {"矿工": 1},
				"outputs": {"石头": 3}
			}
		]
	}


func _spawn_random_forests_and_mines() -> void:
	var cells: Array[Vector2i] = []
	for y in range(grid_rows):
		for x in range(grid_cols):
			cells.append(Vector2i(x, y))
	cells.shuffle()
	var idx := 0
	var forest_def := _forest_building_def()
	var forest_left := mini(maxi(initial_forest_count, 0), cells.size())
	while forest_left > 0 and idx < cells.size():
		var cell := cells[idx]
		idx += 1
		if _can_place(cell, forest_def["size"]):
			_commit_building_to_grid(_make_building_dict(forest_def, cell, forest_def["size"]))
			forest_left -= 1
	var mine_def := _mine_building_def()
	var mine_left := mini(maxi(initial_mine_count, 0), cells.size())
	while mine_left > 0 and idx < cells.size():
		var cell := cells[idx]
		idx += 1
		if _can_place(cell, mine_def["size"]):
			_commit_building_to_grid(_make_building_dict(mine_def, cell, mine_def["size"]))
			mine_left -= 1


func _try_place_at(cell: Vector2i) -> void:
	if not _can_place(cell, selected_size):
		return
	var selected_def := building_defs[selected_building_idx]
	_commit_building_to_grid(_make_building_dict(selected_def, cell, selected_size))
	queue_redraw()


func _remove_at(cell: Vector2i) -> void:
	if not occupied_cells.has(cell):
		return
	var remove_index: int = occupied_cells[cell]
	if active_building_index == remove_index:
		_close_building_panel()
	var removed: Dictionary = placed_buildings[remove_index]
	_free_placed_building_visual(removed)
	placed_buildings.remove_at(remove_index)
	if active_building_index > remove_index:
		active_building_index -= 1
	occupied_cells.clear()
	for i in range(placed_buildings.size()):
		var building := placed_buildings[i]
		for tile in _cells_for_footprint(building["cell"], building["size"]):
			occupied_cells[tile] = i
	queue_redraw()


func _can_place(cell: Vector2i, size: Vector2i) -> bool:
	if not _is_cell_inside_board(cell):
		return false
	if not _is_cell_inside_board(cell + size - Vector2i.ONE):
		return false
	for tile in _cells_for_footprint(cell, size):
		if occupied_cells.has(tile):
			return false
	return true


func _cells_for_footprint(top_left: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			cells.append(top_left + Vector2i(x, y))
	return cells


## 参数为本 Node2D 局部坐标（与 _draw 一致），不是视口/屏幕坐标
func _world_to_cell(board_local_pos: Vector2) -> Vector2i:
	var local := board_local_pos - board_origin
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	return Vector2i(int(floor(local.x / cell_size)), int(floor(local.y / cell_size)))


func _is_cell_inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_cols and cell.y < grid_rows


func _open_building_panel(building_index: int) -> void:
	if building_index < 0 or building_index >= placed_buildings.size():
		return
	active_building_index = building_index
	var building := placed_buildings[building_index]
	building_panel.visible = true
	title_label.text = "建筑: %s" % building["display_name"]
	desc_label.text = "说明: %s" % building["description"]
	tip_label.text = "从下方手牌拖入卡槽：物品与单位可堆叠；事件卡显示为 x1，放入卡槽或生产均不消耗手牌中的该卡。"
	_refresh_slot_texts()
	_refresh_result_text()
	queue_redraw()


func _close_building_panel() -> void:
	active_building_index = -1
	building_panel.visible = false
	queue_redraw()


func _refresh_slot_texts() -> void:
	if active_building_index < 0 or active_building_index >= placed_buildings.size():
		return
	var building := placed_buildings[active_building_index]
	var event_text: String = EMPTY_CARD_TEXT
	if str(building.get("event_card", "")) != "":
		event_text = "%s x1" % str(building["event_card"])
	var resource_text := _format_resource_dict(building["resource_cards"])
	event_slot_label.text = "事件卡槽: %s" % event_text
	resource_slot_label.text = "资源卡槽: %s" % resource_text


func _refresh_result_text() -> void:
	if active_building_index < 0 or active_building_index >= placed_buildings.size():
		return
	var building := placed_buildings[active_building_index]
	var items: Dictionary = building["items"]
	if items.is_empty():
		result_label.text = "产出: 无"
		return
	var output_parts: Array[String] = []
	for item_name in items.keys():
		output_parts.append("%s x%d" % [item_name, items[item_name]])
	result_label.text = "产出: %s" % ", ".join(output_parts)


func _on_produce_pressed() -> void:
	if active_building_index < 0 or active_building_index >= placed_buildings.size():
		return
	var building := placed_buildings[active_building_index]
	var recipe := _find_matching_recipe(building)
	var output_items: Dictionary = {}
	if recipe.is_empty():
		tip_label.text = "条件不足：卡槽未满足任何配方。"
	else:
		output_items = recipe["outputs"].duplicate()
		_add_output_cards_to_hand(output_items)
		var res: Dictionary = placed_buildings[active_building_index]["resource_cards"]
		var need: Dictionary = recipe.get("resources", {})
		for key in need.keys():
			var have_amt: int = int(res.get(key, 0))
			var need_amt: int = int(need[key])
			var left: int = have_amt - need_amt
			if left <= 0:
				res.erase(key)
			else:
				res[key] = left
		placed_buildings[active_building_index]["resource_cards"] = res
		tip_label.text = "生产成功：已生成 %s 到下方手牌（事件卡未消耗；卡槽内单位/物品已按配方扣除）" % _format_resource_dict(output_items)
	placed_buildings[active_building_index]["items"] = output_items
	_refresh_slot_texts()
	_refresh_result_text()


func _on_add_cards_pressed() -> void:
	_add_card_to_hand({"type": "item", "name": "士兵", "count": 2})
	_add_card_to_hand({"type": "item", "name": "弓箭手", "count": 2})
	_add_card_to_hand({"type": "item", "name": "矿工", "count": 2})
	_add_card_to_hand({"type": "item", "name": "伐木工", "count": 2})
	_add_card_to_hand({"type": "item", "name": "木材", "count": 2})
	_add_card_to_hand({"type": "item", "name": "石头", "count": 2})
	_add_card_to_hand({"type": "event", "name": "行军"})
	tip_label.text = "已补充测试手牌。"
	queue_redraw()


func _hand_origin() -> Vector2:
	return Vector2(board_origin.x, board_origin.y + grid_rows * cell_size + 50)


func _hand_card_rect(index: int) -> Rect2:
	var origin := _hand_origin()
	return Rect2(origin + Vector2((HAND_CARD_SIZE.x + CARD_GAP) * index, 0), HAND_CARD_SIZE)


func _hand_card_index_at(mouse_pos: Vector2) -> int:
	for i in range(hand_cards.size()):
		if i == dragging_card_index:
			continue
		if _hand_card_rect(i).has_point(mouse_pos):
			return i
	return -1


func _start_drag_from_hand(mouse_pos: Vector2) -> bool:
	for i in range(hand_cards.size()):
		if _hand_card_rect(i).has_point(mouse_pos):
			dragging_card_index = i
			dragging_card = hand_cards[i].duplicate(true)
			dragging_card["source"] = "hand"
			dragging_mouse_pos = mouse_pos
			var htype := str(dragging_card.get("type", ""))
			if htype == "event":
				dragging_hand_take_count = 0
			elif htype == "item":
				dragging_hand_take_count = mini(1, int(dragging_card.get("count", 1)))
				dragging_card["count"] = dragging_hand_take_count
			else:
				dragging_hand_take_count = 0
			_sync_hand_card_visuals()
			_create_hand_drag_ghost()
			queue_redraw()
			return true
	return false


func _start_drag_from_slot(vp_mouse: Vector2) -> bool:
	if active_building_index < 0 or active_building_index >= placed_buildings.size():
		return false
	var building := placed_buildings[active_building_index]
	var board_pt := _board_pointer_from_viewport(vp_mouse)

	if _ui_contains_pointer(event_slot_area, vp_mouse) and building["event_card"] != "":
		dragging_card_index = -1
		dragging_card = {"type": "event", "name": building["event_card"], "source": "event_slot"}
		dragging_mouse_pos = board_pt
		placed_buildings[active_building_index]["event_card"] = ""
		_refresh_slot_texts()
		_sync_hand_card_visuals()
		_create_hand_drag_ghost()
		queue_redraw()
		return true

	if _ui_contains_pointer(resource_slot_area, vp_mouse):
		var resources: Dictionary = building["resource_cards"]
		if resources.is_empty():
			return false
		var key_name: String = resources.keys()[0]
		var current_count: int = int(resources[key_name])
		dragging_card_index = -1
		dragging_card = {"type": "item", "name": key_name, "count": 1, "source": "resource_slot"}
		dragging_mouse_pos = board_pt
		if current_count <= 1:
			resources.erase(key_name)
		else:
			resources[key_name] = current_count - 1
		placed_buildings[active_building_index]["resource_cards"] = resources
		_refresh_slot_texts()
		_sync_hand_card_visuals()
		_create_hand_drag_ghost()
		queue_redraw()
		return true

	return false


func _try_drop_card_to_slot(vp_mouse: Vector2) -> void:
	if active_building_index < 0 or active_building_index >= placed_buildings.size():
		_return_drag_card_to_hand()
		_cancel_drag()
		return

	var dropped := false

	if _ui_contains_pointer(event_slot_area, vp_mouse) and dragging_card["type"] == "event":
		placed_buildings[active_building_index]["event_card"] = str(dragging_card.get("name", ""))
		dropped = true
	elif _ui_contains_pointer(resource_slot_area, vp_mouse) and dragging_card["type"] == "item":
		var resources: Dictionary = placed_buildings[active_building_index]["resource_cards"]
		var current_count: int = int(resources.get(dragging_card["name"], 0))
		resources[dragging_card["name"]] = current_count + int(dragging_card.get("count", 1))
		placed_buildings[active_building_index]["resource_cards"] = resources
		dropped = true

	if dropped:
		if dragging_card.get("source", "hand") == "hand" and dragging_card_index >= 0 and dragging_hand_take_count > 0:
			var idx := dragging_card_index
			var take := dragging_hand_take_count
			var hc: Dictionary = hand_cards[idx]
			var newc: int = int(hc.get("count", 1)) - take
			if newc <= 0:
				hand_cards.remove_at(idx)
			else:
				hand_cards[idx]["count"] = newc
		tip_label.text = "已放入卡槽：%s" % _format_card_name(dragging_card)
		_refresh_slot_texts()
	else:
		_return_drag_card_to_hand()
		tip_label.text = "拖拽失败：请把卡放到匹配卡槽。"

	_cancel_drag()


func _cancel_drag() -> void:
	_destroy_hand_drag_ghost()
	dragging_card_index = -1
	dragging_card = {}
	dragging_hand_take_count = 0
	_sync_hand_card_visuals()
	queue_redraw()


func _is_mouse_over_building_panel(vp_mouse: Vector2) -> bool:
	if not building_panel.visible:
		return false
	return _ui_contains_pointer(building_panel, vp_mouse)


func _return_drag_card_to_hand() -> void:
	if dragging_card.is_empty():
		return
	var src := str(dragging_card.get("source", "hand"))
	if src == "event_slot" and active_building_index >= 0 and active_building_index < placed_buildings.size():
		placed_buildings[active_building_index]["event_card"] = str(dragging_card.get("name", ""))
		queue_redraw()
		return
	if src != "hand":
		_add_card_to_hand(_make_hand_card(dragging_card))
	queue_redraw()


func _make_hand_card(card: Dictionary) -> Dictionary:
	if card["type"] == "item":
		return {"type": "item", "name": card["name"], "count": int(card.get("count", 1))}
	return {"type": "event", "name": card["name"]}


func _format_card_name(card: Dictionary) -> String:
	var card_type := str(card.get("type", ""))
	if card_type == "event":
		return "[事件] %s x1" % card["name"]
	if card_type == "item":
		return "[物品] %s x%d" % [card["name"], int(card.get("count", 1))]
	return str(card.get("name", ""))


func _format_resource_dict(resource_dict: Dictionary) -> String:
	if resource_dict.is_empty():
		return EMPTY_CARD_TEXT
	var parts: Array[String] = []
	for key in resource_dict.keys():
		parts.append("%s x%d" % [key, resource_dict[key]])
	return ", ".join(parts)


func _find_matching_recipe(building: Dictionary) -> Dictionary:
	var recipes: Array = building.get("recipes", [])
	for recipe in recipes:
		if not _recipe_event_match(building, recipe):
			continue
		if not _recipe_resource_match(building, recipe):
			continue
		return recipe
	return {}


func _recipe_event_match(building: Dictionary, recipe: Dictionary) -> bool:
	return building.get("event_card", "") == recipe.get("event", "")


func _recipe_resource_match(building: Dictionary, recipe: Dictionary) -> bool:
	var have: Dictionary = building.get("resource_cards", {})
	var need: Dictionary = recipe.get("resources", {})
	for key in need.keys():
		if int(have.get(key, 0)) < int(need[key]):
			return false
	return true


func _add_output_cards_to_hand(items: Dictionary) -> void:
	for item_name in items.keys():
		_add_card_to_hand({"type": "item", "name": str(item_name), "count": int(items[item_name])})


func _add_card_to_hand(card: Dictionary) -> void:
	var ctype := str(card.get("type", ""))
	if ctype == "item":
		for i in range(hand_cards.size()):
			var hand_card: Dictionary = hand_cards[i]
			if str(hand_card.get("type", "")) == "item" and hand_card.get("name", "") == card.get("name", ""):
				hand_cards[i]["count"] = int(hand_card.get("count", 1)) + int(card.get("count", 1))
				_sync_hand_card_visuals()
				queue_redraw()
				return
		hand_cards.append(card)
		_sync_hand_card_visuals()
		queue_redraw()
		return
	if ctype == "event":
		hand_cards.append({"type": "event", "name": str(card.get("name", ""))})
		_sync_hand_card_visuals()
		queue_redraw()
		return
	hand_cards.append(card)
	_sync_hand_card_visuals()
	queue_redraw()
