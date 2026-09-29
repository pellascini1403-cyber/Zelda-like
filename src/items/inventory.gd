class_name Inventory
extends RefCounted
## Category-bucketed inventory with per-category capacity.

signal changed

const CAPACITY := {
	&"weapon": 8, &"armor": 24, &"material": 60, &"food": 40, &"tool": 20, &"key": 99,
}

var stacks: Array[ItemStack] = []


## Adds items; returns how many were actually added (capacity may limit).
func add(item_id: StringName, count: int = 1, data: Dictionary = {}) -> int:
	var it := DB.item(item_id)
	if it == null:
		push_warning("Inventory: unknown item " + item_id)
		return 0
	if data.is_empty():
		data = ItemStack.initial_data(item_id)
	var remaining := count
	# Merge into existing stacks first
	for s in stacks:
		if remaining <= 0:
			break
		if s.can_merge(item_id, data):
			var space := it.max_stack - s.count
			var n := mini(space, remaining)
			s.count += n
			remaining -= n
	while remaining > 0:
		if category_count(it.category) >= CAPACITY.get(it.category, 60):
			break
		var n := mini(it.max_stack, remaining)
		stacks.append(ItemStack.new(item_id, n, data))
		remaining -= n
	var added := count - remaining
	if added > 0:
		changed.emit()
	return added


func can_add(item_id: StringName) -> bool:
	var it := DB.item(item_id)
	if it == null:
		return false
	for s in stacks:
		if s.can_merge(item_id, ItemStack.initial_data(item_id)):
			return true
	return category_count(it.category) < CAPACITY.get(it.category, 60)


## Removes `count` items of an id (any instance). Returns false if not enough.
func remove(item_id: StringName, count: int = 1) -> bool:
	if count_of(item_id) < count:
		return false
	var remaining := count
	for i in range(stacks.size() - 1, -1, -1):
		var s := stacks[i]
		if s.id != item_id:
			continue
		var n := mini(s.count, remaining)
		s.count -= n
		remaining -= n
		if s.count <= 0:
			stacks.remove_at(i)
		if remaining <= 0:
			break
	changed.emit()
	return true


func remove_stack(stack: ItemStack, count: int = 1) -> void:
	stack.count -= count
	if stack.count <= 0:
		stacks.erase(stack)
	changed.emit()


func count_of(item_id: StringName) -> int:
	var n := 0
	for s in stacks:
		if s.id == item_id:
			n += s.count
	return n


func has(item_id: StringName, count: int = 1) -> bool:
	return count_of(item_id) >= count


func category_count(category: StringName) -> int:
	var n := 0
	for s in stacks:
		var it := s.def()
		if it and it.category == category:
			n += 1
	return n


func in_category(category: StringName) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for s in stacks:
		var it := s.def()
		if it and it.category == category:
			out.append(s)
	return out


func find_first(item_id: StringName) -> ItemStack:
	for s in stacks:
		if s.id == item_id:
			return s
	return null


func to_array() -> Array:
	var out: Array = []
	for s in stacks:
		out.append(s.to_dict())
	return out


func from_array(arr: Array) -> void:
	stacks.clear()
	for d in arr:
		var s := ItemStack.from_dict(d)
		if DB.item(s.id) != null and s.count > 0:
			stacks.append(s)
	changed.emit()
