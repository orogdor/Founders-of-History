extends RefCounted
## The span uses the same bank anchors as the navigable river crossing.
const Finishes = preload("res://scripts/bronze_home_materials.gd")

static func create_span(length_m: float, width_m: float, rise_m: float, variation := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "BronzeTimberBridge"
	var timber := SurfaceTool.new()
	var masonry := SurfaceTool.new()
	var bindings := SurfaceTool.new()
	for surface in [timber, masonry, bindings]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blank := BoxMesh.new()
	var roundwood := CylinderMesh.new()
	roundwood.radial_segments = 8
	roundwood.rings = 0
	roundwood.height = 1.0
	roundwood.top_radius = 0.5
	roundwood.bottom_radius = 0.5
	var half := length_m * 0.5
	var scale_ref := clampf(width_m / 4.3, 0.25, 1.5)
	var deck_depth := 0.18 * scale_ref
	var rail_height := 0.82 * scale_ref
	var bow := func(x: float) -> float:
		return 0.07 * scale_ref + rise_m * (1.0 - pow(x / half, 2.0))
	var boards := clampi(ceili(length_m / (0.33 * scale_ref)), 10, 200)
	var step := length_m / boards
	for i in boards:
		var x := -half + (i + 0.5) * step
		var width_variation := 0.07 * sin(i * 1.76 + variation)
		var tilt := atan(-2.0 * rise_m * x / (half * half))
		var size := Vector3(step * 0.977, deck_depth, width_m + width_variation * scale_ref)
		block(timber, blank, Vector3(x, bow.call(x), 0), size, tilt)
	var bays := maxi(3, roundi(length_m / (2.3 * scale_ref)))
	for side in [-1.0, 1.0]:
		var z: float = side * (width_m * 0.5 - 0.12 * scale_ref)
		for i in range(bays + 1):
			var x := lerpf(-half, half, float(i) / bays)
			var foot := Vector3(x, bow.call(x), z)
			var top := foot + Vector3.UP * rail_height
			pole(timber, roundwood, foot - Vector3.UP * deck_depth, top + Vector3.UP * (0.09 * scale_ref), 0.15 * scale_ref)
			for offset: float in [-0.04, 0.015]:
				pole(bindings, roundwood, top + Vector3.UP * ((offset - 0.08) * scale_ref), top + Vector3.UP * ((offset - 0.045) * scale_ref), 0.18 * scale_ref)
			if i < bays:
				var next_x := lerpf(-half, half, float(i + 1) / bays)
				var next := Vector3(next_x, bow.call(next_x), z)
				pole(timber, roundwood, top - Vector3.UP * (0.10 * scale_ref), next + Vector3.UP * (rail_height - 0.10 * scale_ref), 0.10 * scale_ref)
				pole(timber, roundwood, foot - Vector3.UP * deck_depth, next - Vector3.UP * deck_depth, 0.26 * scale_ref)
			if i > 0 and i < bays and i % 3 == 0:
				pole(timber, roundwood, foot - Vector3.UP * (rise_m + 1.7 * scale_ref), foot, 0.31 * scale_ref)
	for side: float in [-1.0, 1.0]:
		var cells := maxi(2, ceili(width_m / (0.69 * scale_ref)))
		var row_width := width_m / cells
		for row in 2:
			for j in cells:
				var z := (j + 0.5) * row_width - width_m * 0.5
				var thickness := (0.32 + 0.07 * sin(j * 1.87 + side)) * scale_ref
				block(masonry, blank, Vector3(side * (half - row * 0.15 * scale_ref), -0.10 * scale_ref - row * thickness, z), Vector3((0.94+row*0.24)*scale_ref, thickness, row_width*0.99))
	for entry: Array in [[timber,"wood"],[masonry,"rubble"],[bindings,"matting"]]:
		var surface: SurfaceTool = entry[0]
		surface.set_material(Finishes.get_finish(entry[1], variation))
		var part := MeshInstance3D.new()
		part.name = entry[1]
		part.mesh = surface.commit()
		root.add_child(part)
	return root

static func block(surface: SurfaceTool, blank: BoxMesh, at: Vector3, size: Vector3, tilt := 0.0) -> void:
	var pose := Transform3D(Basis(Vector3.BACK, tilt) * Basis.from_scale(size), at)
	surface.append_from(blank, 0, pose)

static func pole(surface: SurfaceTool, blank: CylinderMesh, a: Vector3, b: Vector3, diameter: float) -> void:
	var axis := b - a
	var rotation := Basis(Quaternion(Vector3.UP, axis.normalized()))
	surface.append_from(blank, 0, Transform3D(rotation * Basis.from_scale(Vector3(diameter, axis.length(), diameter)), (a + b) * 0.5))

static func set_period(crossing: Node3D, bronze: bool) -> void:
	load("res://scripts/period_river_crossing.gd").set_period(crossing,1 if bronze else 0)
