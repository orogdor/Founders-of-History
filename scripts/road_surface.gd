extends RefCounted

enum View { DETAIL, TRAIL, WORLD }

const SHADER := preload("res://scripts/road_surface.gdshader")
const WIDTHS := [0.0, 0.78, 0.9, 1.05, 1.575]
const APPEARANCES := [[1,1,1,1],[1,2,2,2],[2,3,3,3],[2,3,4,4],[2,3,4,5],[3,6,6,5],[3,6,7,7]]
const ROAD_COLORS := ["", "716147", "7e6b50", "817767", "8b8170", "9a9182", "858682", "545a5a"]
const TRAIL_COLORS := ["", "b09a73", "bea982", "9e9585", "8f9291"]
const ROAD_KINDS := ["", "soil", "soil", "gravel", "paving", "paving", "paving", "asphalt"]
const TRAIL_KINDS := ["", "soil", "soil", "gravel", "gravel"]
const CHANNELS := ["color", "normal", "height"]
const TILE_SIZE := Vector2(225.0, 195.0)
const TRIANGLES := [0, 3, 4, 0, 4, 1, 1, 4, 5, 1, 5, 2]
static var materials: Dictionary = {}

static func appearance_for(age: int, level: int) -> int:
	return APPEARANCES[clampi(age, 0, APPEARANCES.size() - 1)][level - 1]

static func road_side(points: Array, i: int, width: float) -> Vector2:
	var point: Vector2 = points[i]
	var before := (point - Vector2(points[maxi(0,i-1)])).normalized()
	var after := (Vector2(points[mini(points.size()-1,i+1)]) - point).normalized()
	var tangent := (before + after).normalized()
	var side := Vector2(-tangent.y,tangent.x)
	return side * width / maxf(0.75,maxf(tangent.dot(before),tangent.dot(after)))

static func add_vertex(surface: SurfaceTool, p: Vector2, height: float, edge: Vector2) -> void:
	surface.set_uv(p)
	surface.set_uv2(edge)
	surface.add_vertex(Vector3(p.x, height, p.y))

static func add_strip(surface: SurfaceTool, start: Vector2, end: Vector2, start_side: Vector2,
		end_side: Vector2, height_at: Callable, lift: float, steps: int) -> void:
	var points: Array[Vector2] = []
	var heights: Array[float] = []
	for i in range(steps + 1):
		var amount := float(i) / steps
		var center := start.lerp(end, amount)
		var side := start_side.lerp(end_side, amount)
		for across in [-1, 0, 1]:
			var point: Vector2 = center + side * across
			points.append(point)
			heights.append(float(height_at.call(point.x, point.y)) + lift)
	for i in steps:
		for index in TRIANGLES:
			var row_index: int = i * 3 + index
			add_vertex(surface, points[row_index], heights[row_index], Vector2(index % 3 - 1, 0))

static func make_mesh(surface: SurfaceTool, tile: Vector2i, style: int, view := View.DETAIL) -> MeshInstance3D:
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material_for(style, view)
	instance.set_instance_shader_parameter("road_uv_offset", Vector2(tile) * TILE_SIZE)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

static func material_for(style: int, view: View) -> ShaderMaterial:
	var key := Vector2i(style, view)
	if materials.has(key):
		return materials[key]
	var is_trail := view == View.TRAIL
	var kind: String = TRAIL_KINDS[style] if is_trail else ROAD_KINDS[style]
	var tint: Color = Color(TRAIL_COLORS[style] if is_trail else ROAD_COLORS[style])
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for channel in CHANNELS:
		material.set_shader_parameter("road_" + channel, load("res://assets/ground/%s-%s.webp" % [kind, channel]))
	material.set_shader_parameter("road_tint", tint)
	material.set_shader_parameter("tiles_per_unit", 0.7 if kind == "asphalt" else 0.55)
	material.set_shader_parameter("relief_depth", 0.009 if kind == "asphalt" else 0.024)
	material.set_shader_parameter("surface_roughness", 0.84 if kind == "asphalt" else 0.96)
	material.set_shader_parameter("photo_brightness", 0.48 if kind == "asphalt" else 0.82)
	material.set_shader_parameter("shoulder_variation", 0.32 if is_trail or kind == "soil" else 0.10)
	if view == View.WORLD:
		material.set_shader_parameter("tiles_per_unit", 14.0)
		material.set_shader_parameter("texture_distance", Vector2(18.0, 60.0))
		material.set_shader_parameter("relief_distance", Vector2(6.0, 26.0))
		material.set_shader_parameter("atlas_fill", 0.18)
	materials[key] = material
	return material
