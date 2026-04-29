extends Panel

const FRAME_NORMAL: Texture2D = preload("res://pictures/ui/ItemBackgroud.png")
const FRAME_PRESSED: Texture2D = preload("res://pictures/ui/ItemBackgroudPressed.png")

signal drag_started(card: Panel, mouse_pos: Vector2)
signal drag_moved(card: Panel, mouse_pos: Vector2)
signal drag_ended(card: Panel, mouse_pos: Vector2)

@onready var frame_texture_rect: TextureRect = $Frame
var is_dragging := false
## 为 true 时仅展示，由 GridBoard 负责拖拽命中（手牌/幽灵预览）。
@export var input_disabled_for_hand_preview: bool = false


func _ready() -> void:
	if input_disabled_for_hand_preview:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process_input(false)
		_set_frame_pressed(false)
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(false)
	_set_frame_pressed(false)
	# Let the root Panel receive clicks; otherwise TextureRect/Label may eat input.
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if input_disabled_for_hand_preview:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_set_frame_pressed(true)
			is_dragging = true
			set_process_input(true)
			drag_started.emit(self, get_global_mouse_position())
		else:
			_set_frame_pressed(false)
			_finish_drag_if_needed()


func _input(event: InputEvent) -> void:
	if input_disabled_for_hand_preview or not is_dragging:
		return
	if event is InputEventMouseMotion:
		drag_moved.emit(self, get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_set_frame_pressed(false)
		_finish_drag_if_needed()


func _finish_drag_if_needed() -> void:
	if not is_dragging:
		return
	is_dragging = false
	set_process_input(false)
	drag_ended.emit(self, get_global_mouse_position())


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if not is_dragging:
			_set_frame_pressed(false)


func _set_frame_pressed(is_pressed: bool) -> void:
	if frame_texture_rect == null:
		return
	frame_texture_rect.texture = FRAME_PRESSED if is_pressed else FRAME_NORMAL
