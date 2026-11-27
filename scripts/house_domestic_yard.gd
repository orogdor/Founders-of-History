extends RefCounted

const Plan = preload("res://scripts/house_plan_geometry.gd")
const Fence = preload("res://scripts/house_fence.gd")
const EarthSurface = preload("res://scripts/house_domestic_soil.gdshader")
const EarthTexture = preload("res://assets/bronze_home/earth.webp")
static var soils: Dictionary = {}

static func soil_material(worn: bool) -> ShaderMaterial:
	if not soils.has(worn):
		var finish := ShaderMaterial.new()
		finish.shader = EarthSurface
		finish.set_shader_parameter("earth", EarthTexture)
		finish.set_shader_parameter("soil", Color("d1b28c" if worn else "bd9d74"))
		finish.render_priority = 1 if worn else 0
		soils[worn] = finish
	return soils[worn]

# A worn path follows the editable entrance to a gap or gate in the yard.
static func add_path(model: Node3D, design: Dictionary) -> void:
	if not design.get("yard") is Array or design.get("upperLevel", false):
		return
	var yard := PackedVector2Array()
	for vertex in design.yard:
		yard.append(Plan.point(vertex))
	if yard.size() < 3:
		return
	var geometry := Plan.plan_geometry(design)
	var edges := Plan.edges(yard)
	var fences := Fence.layout(design)
	for opening in design.get("openings", []):
		if opening.type != "door" or opening.group != "outer":
			continue
		var door := Plan.point(opening.point)
		var hit := Plan.nearest_wall(door, geometry.walls)
		if hit.is_empty() or hit.edge.group != "outer":
			continue
		var direction: Vector2 = (hit.edge.b - hit.edge.a).normalized().orthogonal()
		for floor_polygon in geometry.floors:
			if Plan.inside(door + direction * 2.0, floor_polygon):
				direction = -direction
				break
		var border := door
		var shortest := INF
		for edge in edges:
			var meet = Geometry2D.segment_intersects_segment(door, door + direction * 1400.0, edge.a, edge.b)
			if meet is Vector2 and door.distance_to(meet) < shortest:
				shortest = door.distance_to(meet)
				border = meet
		if shortest < 12.0 or not is_finite(shortest):
			continue
		var exit_point := yard_exit(door, direction, border, fences)
		if door.distance_to(exit_point) > 12.0:
			add_worn_strip(model, model.local(door), model.local(exit_point))

static func yard_exit(door: Vector2, outward: Vector2, border: Vector2, fences: Array) -> Vector2:
	# Prefer a nearby actual opening on the side the door faces. Check both
	# ends because editor-drawn walls may run in either direction.
	var best_distance := INF
	var chosen := border
	for i in fences.size():
		var first: Dictionary = fences[i]
		var a := Plan.point(first.a)
		var b := Plan.point(first.b)
		var parallel := (b - a).normalized()
		var candidates: Array[Vector2] = []
		if first.kind == "gateLine":
			candidates.append((a + b) * 0.5)
		elif absf(parallel.dot(outward)) < 0.35:
			for j in range(i + 1, fences.size()):
				var second: Dictionary = fences[j]
				var c := Plan.point(second.a)
				var d := Plan.point(second.b)
				if second.kind == "gateLine" or absf(parallel.dot((d - c).normalized())) < 0.95:
					continue
				var ends := [a, b, c, d]
				ends.sort_custom(func(left: Vector2, right: Vector2): return parallel.dot(left) < parallel.dot(right))
				var gap: Vector2 = ends[2] - ends[1]
				if gap.length() < 48.0 or gap.length() > 185.0 or absf(gap.cross(parallel)) > 8.0:
					continue
				var mid: Vector2 = (ends[1] + ends[2]) * 0.5
				if Plan.closest(mid, a, b).distance_to(mid) > 20.0 and Plan.closest(mid, c, d).distance_to(mid) > 20.0:
					candidates.append(mid)
		for target in candidates:
			if (target - door).normalized().dot(outward) < 0.48:
				continue
			var distance := target.distance_to(border)
			if distance < best_distance:
				chosen = target + outward * 7.0
				best_distance = distance
	# When a player closes the gap with a wall, wear stops at its base.
	var stop := chosen
	var nearest := door.distance_to(chosen)
	for fence in fences:
		if fence.kind == "gateLine":
			continue
		var meet = Geometry2D.segment_intersects_segment(door, chosen, Plan.point(fence.a), Plan.point(fence.b))
		if meet is Vector2 and door.distance_to(meet) < nearest:
			nearest = door.distance_to(meet)
			stop = meet
	return stop

static func add_worn_strip(model: Node3D, start: Vector3, end: Vector3) -> void:
	var delta := end - start
	var side := Vector3(-delta.z, 0, delta.x).normalized()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(5, ceili(delta.length() * 6.0))
	var lateral := [-1.0, -0.62, 0.0, 0.62, 1.0]
	for row in range(steps + 1):
		var t := float(row) / steps
		var center := start.lerp(end, t) + side * (0.10 * sin(t * PI * 1.8))
		for col in lateral.size():
			var offset: float = lateral[col]
			var jitter := sin(row * 2.9 + col * 6.57) * sin(PI * t)
			var at := center + side * offset * (0.49 + 0.09 * t + 0.055 * jitter)
			at.y = 0.012
			var color := Color("c5a47c").lerp(Color("ae8f6b"), 0.30 + jitter * 0.15)
			color.a = (1.0 - pow(absf(offset), 2.4)) * 0.85 * minf(1.0, (1.0 - t) * 9.0)
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(at.x, at.z) * 0.78)
			surface.set_color(color)
			surface.add_vertex(at)
			if row > 0 and col > 0:
				var k := row * lateral.size() + col
				for index in [k - 6, k - 5, k, k - 6, k, k - 1]:
					surface.add_index(index)
	var path := MeshInstance3D.new()
	path.name = "WornEntrancePath"
	path.mesh = surface.commit()
	path.material_override = soil_material(true)
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(path)
