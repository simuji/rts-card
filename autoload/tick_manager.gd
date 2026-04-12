extends Node
## 全局“心跳”。非回合制下，玩家与 AI 都在同一套 tick 上推进。

signal tick(tick_index: int)

@export var interval_seconds: float = 2.0
@export var autostart: bool = true

var tick_index: int = 0
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = maxf(0.05, interval_seconds)
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	if autostart:
		_timer.start()


func set_paused(p: bool) -> void:
	_timer.paused = p


func set_interval(seconds: float) -> void:
	interval_seconds = maxf(0.05, seconds)
	_timer.wait_time = interval_seconds


func _on_timer_timeout() -> void:
	tick_index += 1
	tick.emit(tick_index)
