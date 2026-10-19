class_name Inventory
extends Node

signal changed
signal selection_changed(index: int, item: ItemInstance)

const CAPACITY := 5
var slots: Array[ItemInstance] = []
var selected_index: int = 0

func _init() -> void:
	slots.resize(CAPACITY)

func first_empty_slot() -> int:
	return slots.find(null)

func is_full() -> bool:
	return first_empty_slot() == -1

func add_item(item: ItemInstance) -> bool:
	if item == null or item in slots or is_full():
		return false
	var index := selected_index if slots[selected_index] == null else first_empty_slot()
	slots[index] = item
	changed.emit()
	select(index)
	return true

func select(index: int) -> void:
	selected_index = wrapi(index, 0, CAPACITY)
	selection_changed.emit(selected_index, current_item())

func current_item() -> ItemInstance:
	return slots[selected_index]

func remove_selected() -> ItemInstance:
	var item := current_item()
	slots[selected_index] = null
	changed.emit()
	selection_changed.emit(selected_index, null)
	return item
