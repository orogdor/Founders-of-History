extends SceneTree

const City = preload("res://scripts/world_city_layout.gd")
const LOD = preload("res://scripts/house_period_city_lod.gd")
const Styles = preload("res://scripts/house_period_styles.gd")

var problems: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		problems.append(message)
		push_error(message)

func building(kind: String) -> Dictionary:
	return {"type":kind, "x":0.0, "z":0.0, "hp":100, "ready":true}

func _initialize() -> void:
	var covered := 0
	for id: String in Styles.Catalogue.data.catalog:
		if Styles.age_of(id) != 2:
			continue
		var kind := id.get_slice("@", 0)
		var role := LOD.category(kind, 2)
		check(role == "iron_" + kind, id + " lost its individual map silhouette")
		var mesh := LOD.mesh(2, role)
		check(mesh != null and mesh.get_surface_count() == 1 and mesh.get_aabb().size.length() > 1.8, id + " map mesh is incomplete")
		covered += 1
	check(covered == 53, "Iron catalogue coverage changed")

	var hall := building("hall")
	var edited := hall.duplicate(true)
	edited.houseDesignV354 = Styles.get_plan("hall@2").duplicate(true)
	edited.houseDesignV354.wallScale = 250
	var map := City.build([hall, hall, edited], Vector3.ZERO, func(_p): return 0.0, Vector2i.ZERO, 2)
	check(map.get_child_count() == 2, "Identical default halls must share a batch and the custom hall must retain its own mesh")
	if map.get_child_count() == 2:
		var ordinary: MultiMesh = map.get_child(0).multimesh
		var custom: MultiMesh = map.get_child(1).multimesh
		check(ordinary.instance_count == 2 and custom.instance_count == 1, "Incorrect number of map instances")
		check(ordinary.mesh.get_aabb().size.y < custom.mesh.get_aabb().size.y, "Edited wall height disappeared on the map")
	check(City.stamp([hall], 2) != City.stamp([edited], 2), "A house edit should refresh its city marker")
	map.free()

	var harbour := building("harbor")
	harbour.shoreAngle = 0.67
	map = City.build([harbour], Vector3.ZERO, func(_p): return 0.0, Vector2i.ZERO, 2)
	var coast_plan := Styles.get_plan(Styles.designer_id("harbor",2))
	var expected: float = harbour.shoreAngle + Styles.coast_yaw(coast_plan)
	check(is_equal_approx(City.map_rotation(harbour,2,{},false), expected), "Map pier no longer follows the coast")
	# The headless dummy renderer discards MultiMesh instance transforms.
	if DisplayServer.get_name() != "headless":
		var batch: MultiMesh = map.get_child(0).multimesh
		check(batch.get_instance_transform(0).basis.orthonormalized().is_equal_approx(Basis(Vector3.UP,expected)), "Visible harbour rotation differs from its plan")
	map.free()
	check(City.clearances([building("field")], Vector2.ZERO, 2).size() == 1, "Wilderness trees can grow inside a Iron field")
	check(City.clearances([building("field")], Vector2.ZERO, 0).is_empty(), "The Stone Age field layout changed")
	var short_field := building("field")
	var broad_field := short_field.duplicate()
	broad_field.width = 28
	check(City.stamp([short_field],2) != City.stamp([broad_field],2), "Resizing a field did not update the map")
	if problems.is_empty():
		print("IRON_WORLD_MAP_OK ", covered, " site meshes, edited city, harbour and field")
	quit(0 if problems.is_empty() else 1)
