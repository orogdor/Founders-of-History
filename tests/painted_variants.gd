extends SceneTree

const Painted = preload("res://scripts/painted_building_materials.gd")
const Detail = preload("res://scripts/detail_view.gd")
const FloorPlan = preload("res://scripts/house_plan_model.gd")
const Designs = preload("res://data/house_default_designs.json")
const WorldModels = preload("res://scripts/world_city_layout.gd")
const FAMILIES := ["meadow", "reed", "wood", "stone", "plaster", "tile", "forest", "soil"]


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for material: String in FAMILIES:
		var paths: Dictionary = {}
		for index in Painted.VARIANTS:
			var color := Painted.texture(material, index)
			var height := Painted.texture(material, index, true)
			assert(color != null and height != null)
			assert(color.get_size() == height.get_size() and color.get_width() == 384)
			paths[color.resource_path] = true
			paths[height.resource_path] = true
		assert(paths.size() == 16)
	assert(Painted.atlas(Painted.MEADOW).get_size() == Vector2(1664,832))
	assert(Painted.atlas(Painted.REED).get_size() == Vector2(1664,832))
	for family in [Painted.FOREST, Painted.SOIL, Painted.STONE]:
		assert(Painted.atlas(family).get_size() == Vector2(1664,832))

	var designer := FloorPlan.new()
	designer.texture_variant = 6
	var brick := designer.material_for("brick")
	assert(brick.albedo_texture == Painted.texture("designer_proc-brick",6))
	assert(brick.heightmap_enabled and brick.heightmap_texture == Painted.texture("designer_proc-brick",6,true))
	assert(brick.normal_enabled and brick.normal_texture != null)
	assert(designer.material_for("floor").albedo_texture.get_image().detect_alpha() == Image.ALPHA_NONE)
	designer.free()

	var stock_mesh := MeshInstance3D.new()
	stock_mesh.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	var source: String = Painted.STOCK_SOURCES.data["257ea35e"]
	original.albedo_texture = load("res://assets/buildings/" + source)
	stock_mesh.set_surface_override_material(0,original)
	Painted.apply_stock(stock_mesh,4)
	var varied := stock_mesh.get_active_material(0) as BaseMaterial3D
	assert(varied.albedo_texture == Painted.texture("stock_257ea35e",4))
	assert(varied.heightmap_texture == Painted.texture("stock_257ea35e",4,true))
	stock_mesh.free()

	var tile := Vector2i(82,109)
	var variants: Dictionary = {}
	for x in range(-30,31,2):
		var place := Vector2(x,7)
		variants[Painted.variant_at(tile,place,"hunter")] = true
	assert(variants.size() == Painted.VARIANTS)
	var edge := Painted.variant_at(tile,Vector2(112.5,3),"hunter")
	assert(edge == Painted.variant_at(tile+Vector2i(1,0),Vector2(-112.5,3),"hunter"))

	var detail := Detail.new()
	root.add_child(detail)
	var hunter := detail.create_designed_building("hunter",0,{},1,3)
	var roof := hunter.find_child("part_14",true,false) as MeshInstance3D
	var material := roof.get_active_material(0) as BaseMaterial3D
	assert(material.albedo_texture == Painted.texture(Painted.REED,3))
	assert(material.heightmap_enabled and material.heightmap_texture == Painted.texture(Painted.REED,3,true))
	assert(material.normal_enabled and material.normal_texture != null)
	hunter.free()

	var custom := FloorPlan.from_design(Designs.data.hunter,5)
	var custom_roof := custom.find_child("RoofDeck",true,false) as MeshInstance3D
	assert(custom_roof.get_active_material(0).get_shader_parameter("painted_reed") == Painted.texture(Painted.REED,5))
	custom.free()
	FloorPlan.clear_cache()

	var buildings := [{"type":"house","x":3.0,"z":4.0,"hp":100,"ready":true}]
	var town := WorldModels.build(buildings,Vector3.ZERO,func(_point):return 0.0,tile)
	var batch := town.get_child(0).multimesh as MultiMesh
	assert(batch.use_custom_data)
	if DisplayServer.get_name() != "headless":
		assert(roundi(batch.get_instance_custom_data(0).r*7.0) == Painted.variant_at(tile,Vector2(3,4),"house"))
	town.free()
	detail.queue_free()
	print("PAINTED_VARIANTS_OK ",FAMILIES.size()*Painted.VARIANTS)
	quit()
