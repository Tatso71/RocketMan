extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const KINDS := ["water", "gas", "energy"]
const NAMES := {"water": "Tubo acqua", "gas": "Tubo gas", "energy": "Cavo energia"}
const COLORS := {"water": Color("72ccea"), "gas": Color("dcda77"), "energy": Color("ef9d70")}
const OFFSETS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var cells := {"water": {}, "gas": {}, "energy": {}}
var dirty := true
var memberships: Dictionary = {}
var components: Dictionary = {}

func add(kind: String, cell: Vector2i) -> bool:
	if kind not in KINDS or cells[kind].has(cell):
		return false
	cells[kind][cell] = true
	dirty = true
	return true

func remove(kind: String, cell: Vector2i) -> bool:
	if kind not in KINDS or not cells[kind].erase(cell):
		return false
	dirty = true
	return true

func _rebuild() -> void:
	if not dirty:
		return
	memberships.clear()
	components.clear()
	for kind: String in KINDS:
		var membership := {}
		var groups: Array = []
		for cell: Vector2i in cells[kind]:
			if membership.has(cell):
				continue
			var group: Array[Vector2i] = [cell]
			membership[cell] = groups.size()
			var head := 0
			while head < group.size():
				var current := group[head]
				head += 1
				for offset: Vector2i in OFFSETS:
					var next := current + offset
					if cells[kind].has(next) and not membership.has(next):
						membership[next] = groups.size()
						group.append(next)
			groups.append(group)
		memberships[kind] = membership
		components[kind] = groups
	dirty = false

func component(kind: String, cell: Vector2i) -> Array:
	_rebuild()
	var index: int = memberships.get(kind, {}).get(cell, -1)
	return [] if index < 0 else components[kind][index]

func connected(kind: String, first: Vector2i, second: Vector2i) -> bool:
	_rebuild()
	var membership: Dictionary = memberships.get(kind, {})
	return membership.has(first) and membership.has(second) and membership[first] == membership[second]

static func port(building: Dictionary, kind: String) -> Vector2i:
	var size: Vector2i = preload("res://scripts/systems/outpost_buildings.gd").SIZES.get(building.id, Vector2i.ONE)
	var offset := Vector2i(0, size.y - 1)
	if (building.id == "gas_converter" and kind == "energy") or (building.id == "pump" and kind == "water"):
		offset.x = size.x - 1
	return Vector2i(building.origin) + offset

func snapshot() -> Dictionary:
	var entries: Array = []
	for kind: String in KINDS:
		for cell: Vector2i in cells[kind]:
			entries.append([kind, cell.x, cell.y])
	return {"version": 1, "cells": entries}

func restore(data: Variant, site: RefCounted) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		cells = {"water": {}, "gas": {}, "energy": {}}
		dirty = true
		return true
	if data.get("version") != 1 or not data.get("cells") is Array or data.cells.size() > (site.RIGHT - site.LEFT) * site.DEPTH * KINDS.size():
		return false
	var next := {"water": {}, "gas": {}, "energy": {}}
	for entry in data.cells:
		if not entry is Array or entry.size() != 3 or entry[0] not in KINDS:
			return false
		var cell = Grid.decode_cell(entry.slice(1))
		if not cell is Vector2i or not site.contains(cell) or not site.material(cell).is_empty() or next[entry[0]].has(cell):
			return false
		next[entry[0]][cell] = true
	cells = next
	dirty = true
	return true
