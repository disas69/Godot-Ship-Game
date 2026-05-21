class_name ObjectPool extends RefCounted

var max_size: int = 0

var _available: Array = []
var _create_item: Callable
var _reset_item: Callable
var _discard_item: Callable
var _is_valid_item: Callable


func _init(
	create_item: Callable = Callable(),
	reset_item: Callable = Callable(),
	discard_item: Callable = Callable(),
	max_pool_size: int = 0,
	is_valid_item: Callable = Callable()
) -> void:
	_create_item = create_item
	_reset_item = reset_item
	_discard_item = discard_item
	_is_valid_item = is_valid_item
	max_size = max_pool_size


func size() -> int:
	return _available.size()


func is_empty() -> bool:
	return _available.is_empty()


func prewarm(count: int) -> void:
	while _available.size() < count:
		var item = _create_new_item()
		if item == null:
			return
		if not release(item):
			return


func acquire() -> Variant:
	while not _available.is_empty():
		var item = _available.pop_back()
		if _is_item_valid(item):
			return item

	return _create_new_item()


func release(item: Variant) -> bool:
	if not _is_item_valid(item):
		return false

	if max_size > 0 and _available.size() >= max_size:
		_discard(item)
		return false

	if _reset_item.is_valid():
		_reset_item.call(item)

	_available.append(item)
	return true


func clear() -> void:
	for item in _available:
		if _is_item_valid(item):
			_discard(item)
	_available.clear()


func _create_new_item() -> Variant:
	if not _create_item.is_valid():
		push_warning("ObjectPool has no valid create callback.")
		return null
	return _create_item.call()


func _is_item_valid(item: Variant) -> bool:
	if _is_valid_item.is_valid():
		return bool(_is_valid_item.call(item))
	if item is Object:
		return is_instance_valid(item)
	return item != null


func _discard(item: Variant) -> void:
	if _discard_item.is_valid():
		_discard_item.call(item)
