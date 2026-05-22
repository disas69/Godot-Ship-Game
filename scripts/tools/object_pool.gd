class_name ObjectPool extends RefCounted

var max_size: int = 0

var available: Array = []
var create_item_callback: Callable
var reset_item_callback: Callable
var discard_item_callback: Callable
var is_valid_item_callback: Callable


func _init(
	create_item: Callable = Callable(),
	reset_item: Callable = Callable(),
	discard_item: Callable = Callable(),
	max_pool_size: int = 0,
	is_valid_item: Callable = Callable()
) -> void:
	create_item_callback = create_item
	reset_item_callback = reset_item
	discard_item_callback = discard_item
	is_valid_item_callback = is_valid_item
	max_size = max_pool_size


func size() -> int:
	return available.size()


func is_empty() -> bool:
	return available.is_empty()


func prewarm(count: int) -> void:
	while available.size() < count:
		var item = create_new_item()
		if item == null:
			return
		if not release(item):
			return


func acquire() -> Variant:
	while not available.is_empty():
		var item = available.pop_back()
		if is_item_valid(item):
			return item

	return create_new_item()


func release(item: Variant) -> bool:
	if not is_item_valid(item):
		return false

	if max_size > 0 and available.size() >= max_size:
		discard(item)
		return false

	if reset_item_callback.is_valid():
		reset_item_callback.call(item)

	available.append(item)
	return true


func clear() -> void:
	for item in available:
		if is_item_valid(item):
			discard(item)
	available.clear()


func create_new_item() -> Variant:
	if not create_item_callback.is_valid():
		push_warning("ObjectPool has no valid create callback.")
		return null
	return create_item_callback.call()


func is_item_valid(item: Variant) -> bool:
	if is_valid_item_callback.is_valid():
		return bool(is_valid_item_callback.call(item))
	if item is Object:
		return is_instance_valid(item)
	return item != null


func discard(item: Variant) -> void:
	if discard_item_callback.is_valid():
		discard_item_callback.call(item)
