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
class HashGridItem:
	var id: int
	var position: Vector3
	var user_data: Variant # Optional
	
	func _init(in_id: int, in_position: Vector3, in_data: Variant = null) -> void:
		id = in_id
		position = in_position
		user_data = in_data


var _grid: Dictionary = {
	# cell_id <Vector3> : item <HashGridItem>
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
func add_item(position: Vector3, user_data: Variant = null) -> int:
	var cell_id: Vector3 = snapped(position, _snap)
	if not _grid.has(cell_id):
		_grid[cell_id] = []
	_last_item_id += 1
	var item: HashGridItem = HashGridItem.new(_last_item_id, position, user_data)
	_grid[cell_id].push_back(item)
	return item.id


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
## Returns an Array[Array[HashGridItems]]
func get_items_closer_than(distance: float) -> Array[Array]:
	assert(distance <= _cell_size, "Max distance can't be larger than the grid's cell_size")
	var distance_sqrd: float = pow(distance, 2.0)
	var result: Array[Array] = []
	var visited_cells: Array[Vector3] = []
	
	for cell_id: Vector3 in _grid:
		visited_cells.push_back(cell_id)
		var items: Array[HashGridItem] = []
		items.assign(_grid[cell_id])
		var neighbors: Array[HashGridItem] = []
		neighbors.append_array(items)
		
		for neighbor_cell: Vector3 in get_neighbor_cells(cell_id):
			if visited_cells.has(neighbor_cell):
				continue
			neighbors.append_array(_grid[neighbor_cell])
		
		var visited_items: Dictionary = {}
		for item: HashGridItem in items:
			if visited_items.has(item):
				continue
			visited_items[item] = true
			var group: Array[HashGridItem] = []
			for other_item: HashGridItem in neighbors:
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


## Same as get_items_closer_than, but only returns the provided user data
## instead of a list of HashGridItem.
func get_user_data_closer_than(distance: float) -> Array[Array]:
	var result: Array[Array] = []
	for group: Array[HashGridItem] in get_items_closer_than(distance):
		var data_group: Array = []
		for item in group:
			data_group.push_back(item.user_data)
		result.push_back(data_group)
	return result
