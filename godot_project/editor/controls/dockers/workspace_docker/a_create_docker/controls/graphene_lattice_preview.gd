@tool
class_name GrapheneLatticePreview
extends Control

@export_range(2, 10, 1, "or_greater") var n: int = 2:
	set(v): n = v; queue_redraw()
@export_range(0, 10, 1, "or_greater") var m: int = 0:
	set(v): m = v; queue_redraw()

@export var lattice_color := Color.GRAY:
	get():  return lattice_color


@onready var _polygon_2d: Polygon2D = $Polygon2D


func _ready() -> void:
	resized.connect(_on_resized)
	clip_contents = true
	_polygon_2d.material.set_shader_parameter(&"color_src", lattice_color)


func _validate_property(property: Dictionary) -> void:
	if property.name == "custom_minimum_size":
		# dont save in tscn file
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _draw() -> void:
	var bg: StyleBox = get_theme_stylebox("bg", "GrapheneLatticePreview")
	draw_style_box(bg, Rect2(Vector2(), size))
	
	var root_three: float = sqrt(3.0)
	var rel_a1 := Vector2(1.5, root_three / 2.0)
	var rel_a2 := Vector2(1.5, -root_three / 2.0)
	var rel_c  := n * rel_a1 + m * rel_a2

	var bond_length: float = (size.x * 0.8) / rel_c.x
	var right := Vector2.RIGHT * bond_length
	var diag := right.rotated(deg_to_rad(60))
	var diag2 := Vector2(diag.x, -diag.y)
	var pattern_size := Vector2(abs(right.x) * 2 + abs(diag.x) * 2, abs(diag.y) * 2.0)
	for x: float in range(0, size.x, pattern_size.x):
		for y: float in range(0, size.y, pattern_size.y):
			var pos := Vector2(x, y)
			pos += Vector2(0, diag.y)
			draw_line(pos, pos + diag, lattice_color)
			draw_line(pos, pos + diag2, lattice_color)
			pos += diag2
			draw_line(pos, pos + right, lattice_color)
			pos += right
			draw_line(pos, pos + diag, lattice_color)
			pos += diag
			draw_line(pos, pos - diag2, lattice_color)
			draw_line(pos, pos + right, lattice_color)
	
	var a1: Vector2 = right + diag2
	var a2: Vector2 = right + diag
	var c: Vector2 = n * a1 + m * a2
	
	var c_draw_from := diag + Vector2(0, diag.y)
	if (m - n) < -2:
		# add offset in Y to fit in the preview
		c_draw_from.y += pattern_size.y * floor(abs(m - n) / 2.0)
	var t_dir := Vector2(-c.y, c.x).normalized()
	var t_to: Vector2 = c_draw_from + t_dir * size.length()
	
	_polygon_2d.polygon = [
		c_draw_from,
		c_draw_from + c,
		t_to + c,
		t_to
	]
	draw_line(c_draw_from, c_draw_from + c, Color.GREEN, 2)
	draw_dashed_line(c_draw_from, t_to, Color.GREEN, 2, 8)
	draw_dashed_line(c_draw_from + c, t_to + c, Color.GREEN, 2, 8)


func get_estimated_circumference() -> float:
	# formula extracted from https://en.wikipedia.org/wiki/Carbon_nanotube#Circumference_and_diameter
	const CARBON_BOND_LENGTH_NM = 0.148
	var root_three: float = sqrt(3.0)
	var rel_a1 := Vector2(1.5, root_three / 2.0).normalized()
	var rel_a2 := Vector2(1.5, -root_three / 2.0).normalized()
	var u: Vector2 = (rel_a1 + rel_a2) * CARBON_BOND_LENGTH_NM
	var circumference: float = u.length() * sqrt(n ** 2 + n * m + m ** 2)
	return circumference


func get_estimated_diameter() -> float:
	return get_estimated_circumference() / PI


func _on_resized() -> void:
	custom_minimum_size.y = size.x
