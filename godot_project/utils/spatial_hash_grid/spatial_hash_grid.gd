class_name SpatialHashGrid
extends RefCounted


## The spatial hash grid is used to partition 3D items in a 3D grid and speed
## up the overlap calculations.
##
## When adding an atom, the atom position is snapped to the nearest _cell_size
## to get its parent cell id before adding the atom to the _grid.
## When querying for nearby atoms, we check all 8 surrounding cells (if they exists)
## and only calculate the distance to the atoms within these cells, instead of
## using the entire set.


## The element stored in the hash grid
class Item:
	var id: int
	var position: Vector3
	var user_data: Variant # Optional
	
	func _init(in_id: int, in_position: Vector3, in_data: Variant = null) -> void:
		id = in_id
		position = in_position
		user_data = in_data


var _grid: Dictionary = {
	# cell_id <Vector3> : items <Array<Item>>
}
var _cell_size: float
var _snap: Vector3 
var _last_item_id: int


func _init(in_cell_size: float) -> void:
	_cell_size = in_cell_size
	_snap = Vector3(_cell_size, _cell_size, _cell_size)
	_last_item_id = -1


## Adds a point to the grid.
## Optionally, user data can be attached and retrieved later with `get_data_closer_than()`
func add_item(position: Vector3, user_data: Variant = null) -> Item:
	var cell_id: Vector3 = snapped(position, _snap)
	if not _grid.has(cell_id):
		_grid[cell_id] = []
	_last_item_id += 1
	var item: Item = Item.new(_last_item_id, position, user_data)
	_grid[cell_id].push_back(item)
	return item


## Removes a point from the grid
## If multiple points share the same position, use user_data to precise which
## one should be removed. If no user_data is provided, every points at this
## position will be removed.
func remove_item_by_position(position: Vector3, user_data: Variant = null) -> void:
	var cell_id: Vector3 = snapped(position, _snap)
	if not _grid.has(cell_id):
		return
	for i: int in range(_grid[cell_id].size() - 1, 0, -1):
		var item: Item = _grid[cell_id][i]
		if not item.position.is_equal_approx(position):
			continue
		# Positions match. Delete if no user data or if the user data match.
		if not user_data or (user_data == item.user_data):
			_grid[cell_id].remove_at(i)


## Take an existing item and move it to a new position.
## This method updates its location withing the spatial grid.
func move_item(item: Item, new_position: Vector3) -> void:
	var old_cell_id: Vector3 = snapped(item.position, _snap)
	var old_cell: Array = _grid.get(old_cell_id, [])
	assert(not old_cell.is_empty(), "Item does not belong to this SpatialHashGrid")
	
	var new_cell_id: Vector3 = snapped(new_position, _snap)
	item.position = new_position
	if old_cell_id.is_equal_approx(new_cell_id):
		# Item did not move far enough to change cell. Nothing to do.
		return
	
	# Move the item to its new cell
	old_cell.erase(item)
	if not _grid.has(new_cell_id):
		_grid[new_cell_id] = []
	_grid[new_cell_id].push_back(item)


## Returns a flat list of all items in the grid
func get_all_items() -> Array[Item]:
	var result: Array[Item] = []
	for list: Array in _grid.values():
		result.append_array(list)
	return result


## Returns all cells directly touching the cell (diagonals included)
## Resulting array size can vary from 0 to 8.
## The main (center) cell is not included in the results.
func get_neighbor_cells(cell_id: Vector3) -> Array[Vector3]:
	var neighbor_cells: Array[Vector3] = []
	for x: int in [-1, 0, 1]:
		for y: int in [-1, 0, 1]:
			for z: int in [-1, 0, 1]:
				var offset: Vector3 = Vector3(x, y, z) * _cell_size
				if offset.is_zero_approx():
					continue # Don't include the center cell in the neighbors
				var neighbor_id: Vector3 = offset + cell_id
				if _grid.has(neighbor_id):
					neighbor_cells.push_back(neighbor_id)
	return neighbor_cells


## Go through every point (added with add_item) and pack together all the items
## closer than `distance`.
## Returns an Array[Array[Item]]
func get_items_closer_than(distance: float) -> Array[Array]:
	assert(distance <= _cell_size, "Max distance can't be larger than the grid's cell_size")
	var distance_sqrd: float = pow(distance, 2.0)
	var result: Array[Array] = []
	var visited_cells: Array[Vector3] = []
	
	for cell_id: Vector3 in _grid:
		visited_cells.push_back(cell_id)
		var items: Array[Item] = []
		items.assign(_grid[cell_id])
		var neighbors: Array[Item] = []
		neighbors.append_array(items)
		
		for neighbor_cell: Vector3 in get_neighbor_cells(cell_id):
			if visited_cells.has(neighbor_cell):
				continue
			neighbors.append_array(_grid[neighbor_cell])
		
		var visited_items: Dictionary = {}
		for item: Item in items:
			if visited_items.has(item):
				continue
			visited_items[item] = true
			var group: Array[Item] = []
			for other_item: Item in neighbors:
				if visited_items.has(other_item):
					continue
				visited_items[other_item] = true
				if item.position.distance_squared_to(other_item.position) < distance_sqrd:
					if not group.has(item):
						group.push_back(item)
					if not group.has(other_item):
						group.push_back(other_item)
			if not group.is_empty():
				result.push_back(group)
	
	return result


func get_items_around(position: Vector3, distance: float = -1.0) -> Array[Item]:
	assert(distance <= _cell_size, "Max distance can't be larger than the grid's cell_size")
	if distance <= 0.0:
		distance = _cell_size
	var result: Array[Item] = []
	var distance_sqrd: float = pow(distance, 2.0)
	var center_cell_id: Vector3 = snapped(position, _snap)
	var cells_to_scan: Array[Vector3] = get_neighbor_cells(center_cell_id)
	cells_to_scan.push_back(center_cell_id)
	for cell_id: Vector3 in cells_to_scan:
		for item: Item in _grid.get(cell_id, []):
			if item.position.distance_squared_to(position) <= distance_sqrd:
				result.push_back(item)
	return result


## Same as get_items_closer_than, but only returns the provided user data
## instead of a list of Item.
func get_user_data_closer_than(distance: float) -> Array[Array]:
	var result: Array[Array] = []
	for group: Array[Item] in get_items_closer_than(distance):
		var data_group: Array = []
		for item in group:
			data_group.push_back(item.user_data)
		result.push_back(data_group)
	return result


func has_any_closer_than(point: Vector3, distance: float, in_exceptions: Array[Item] = []) -> bool:
	var distance_squared: float = pow(distance, 2.0)
	var center_cell: Vector3 = snapped(point, _snap)
	var neighbor_cells := get_neighbor_cells(center_cell)
	neighbor_cells.push_front(center_cell)
	for cell: Vector3 in neighbor_cells:
		for item: Item in _grid.get(cell, []):
			if item in in_exceptions:
				continue
			if item.position.distance_squared_to(point) < distance_squared:
				return true
	return false
