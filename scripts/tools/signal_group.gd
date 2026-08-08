class_name SignalGroup extends RefCounted

signal _all_complete
signal _any_complete

var _remaining_count: int = 0
var _is_waiting: bool = false
var _connections: Array[Dictionary] = []


func all(signals: Array) -> void:
	disconnect_pending()
	_remaining_count = signals.size()
	_is_waiting = _remaining_count > 0

	if not _is_waiting:
		return

	for signal_to_wait: Signal in signals:
		var callback := Callable(self, "_on_all_signal_complete")
		signal_to_wait.connect(callback, CONNECT_ONE_SHOT as Object.ConnectFlags)
		_connections.append({
			"signal": signal_to_wait,
			"callback": callback
		})

	await _all_complete


func any(signals: Array) -> void:
	disconnect_pending()
	_is_waiting = not signals.is_empty()

	if not _is_waiting:
		return

	for signal_to_wait: Signal in signals:
		var callback := Callable(self, "_on_any_signal_complete")
		signal_to_wait.connect(callback, CONNECT_ONE_SHOT as Object.ConnectFlags)
		_connections.append({
			"signal": signal_to_wait,
			"callback": callback
		})

	await _any_complete


func cancel() -> void:
	disconnect_pending()
	_remaining_count = 0
	_is_waiting = false


func disconnect_pending() -> void:
	for connection in _connections:
		var signal_to_wait: Signal = connection["signal"]
		var callback: Callable = connection["callback"]
		if signal_to_wait.is_connected(callback):
			signal_to_wait.disconnect(callback)

	_connections.clear()


func _on_all_signal_complete() -> void:
	if not _is_waiting:
		return

	_remaining_count -= 1
	if _remaining_count <= 0:
		_is_waiting = false
		_connections.clear()
		_all_complete.emit()


func _on_any_signal_complete() -> void:
	if not _is_waiting:
		return

	_is_waiting = false
	disconnect_pending()
	_any_complete.emit()
