extends SceneTree

const Models=preload("res://scripts/building_models.gd")
const Placement=preload("res://scripts/building_placement.gd")
const WorldTown=preload("res://scripts/world_city_layout.gd")
const Detail=preload("res://scripts/detail_view.gd")
const Eras=preload("res://scripts/house_eras.gd")
const HouseModel=preload("res://scripts/house_plan_model.gd")
const Lights=preload("res://scripts/detail_lights.gd")
const NatureProps=preload("res://scripts/detail_nature_props.gd")
const StoneSurface=preload("res://scripts/stone_surface.gd")

func _initialize() -> void:
	call_deferred("run")

func wall(x: float,z: float,turn:=0.0) -> Dictionary:
	return {"type":"stonewall","x":x,"z":z,"hp":100,"ready":true,"wallAngleV175":turn,"palisadeSpanV167":7.0}

func triangle_count(model: Node) -> int:
	var count:=0
	if model is MeshInstance3D and model.mesh!=null:
		for i in model.mesh.get_surface_count():
			var arrays:Array=model.mesh.surface_get_arrays(i)
			var indices:Variant=arrays[Mesh.ARRAY_INDEX]
			count+=int((indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3.0)
	for child in model.get_children():count+=triangle_count(child)
	return count

func has_exterior_material(mesh: ArrayMesh) -> bool:
	for i in mesh.get_surface_count():
		var paint:=mesh.surface_get_material(i)
		if paint is ShaderMaterial or (paint is BaseMaterial3D and paint.albedo_texture!=null):
			return true
	return false

func run() -> void:
	root.size=Vector2i(1280,720)
	for age in Eras.NAMES.size():
		var high:=Models.create("house",age)
		var low:=Models.simplified_mesh("house",age)
		assert(high!=null and low!=null)
		assert(high.get_meta("designer_id")==Eras.project_id("house",age))
		if age<=2:
			var id:=Eras.fit_id("house",age)
			assert(low==Models.simplified_mesh("house",age,Eras.default_plan(id)))
		if age==2:
			var original_path:="res://assets/buildings/%s.glb" % Eras.fit_id("house",age)
			assert(high.get_child(0).scene_file_path==original_path,"Expected the original Iron Age house mesh")
		if age==0:
			assert(high.get_child(0).get_script()==HouseModel,"The close Stone Age house uses the lower thatched roof")
		assert(low.surface_get_array_index_len(0)/3 < triangle_count(high)*0.25)
		assert(Models.simplified_mesh("house",age)==low)
		var middle:=Models.settlement_mesh("house",age)
		assert(middle!=null and middle!=low and has_exterior_material(middle),"The settlement house must retain authored materials")
		assert(Models.settlement_mesh("house",age)==middle,"Repeated houses should share a mesh")
		high.free()
		var gate_mesh:=Models.simplified_mesh("woodgate",age)
		assert(gate_mesh!=null and gate_mesh.get_aabb().size.x>=6.4)
	var fieldstone:=StoneSurface.material("stone",true,true)
	assert(fieldstone.get_shader_parameter("stone_texture")==StoneSurface.FIELDSTONE)
	assert(fieldstone.get_shader_parameter("mesh_uv") and float(fieldstone.get_shader_parameter("relief_amount"))<0.015)
	var wall_model:=Models.create("stonewall",2)
	var found_stone:=false
	for part in wall_model.find_children("*","MeshInstance3D",true,false):
		for i in part.mesh.get_surface_count():
			var finish: Material=part.get_active_material(i)
			found_stone=found_stone or (finish is ShaderMaterial and finish.shader==StoneSurface.STONE)
	assert(found_stone,"The imported fortification should share the new masonry")
	wall_model.free()
	var hunter:=Models.create("hunter",0)
	assert(hunter.get_child(0).get_script()==HouseModel)
	assert(Models.bounds(hunter).size.y<4.6,"A hunting hut should stay close to human scale")
	hunter.free()
	var stump:=NatureProps.stump()
	assert(stump.get_surface_count()==2 and stump.get_aabb().size.y<0.6)
	for kind in NatureProps.PALETTES:
		var deposit:=NatureProps.deposit(kind)
		assert(deposit.get_aabb().has_volume() and deposit.get_aabb().size.y<2.0)
		assert(NatureProps.deposit(kind)==deposit,"Resource meshes should be reused")
	var parent:={"id":8,"team":0,"c":12,"r":15,"economy":{"buildings":[{"type":"hall","x":0,"z":0,"hp":200}]}}
	var district:={"id":8,"team":0,"c":13,"r":15,"districtOf":8,"economy":{"buildings":[{"type":"hall","x":0,"z":0,"virtual":true,"hp":200}]}}
	parent.districts={"13:15":district}
	assert(is_same(Lights.local_context([parent],8,Vector2i(12,15)),parent))
	assert(Lights.locations(Lights.local_context([parent],8,Vector2i(12,15)).economy.buildings).size()==2)
	assert(is_same(Lights.local_context([parent],8,Vector2i(13,15)),district))
	assert(Lights.locations(Lights.local_context([parent],8,Vector2i(13,15)).economy.buildings).is_empty())
	assert(Lights.local_context([parent],8,Vector2i(14,15)).is_empty())

	var first:=wall(-3.5,0)
	var corner:=wall(0,3.5,-PI/2)
	var gate:={"type":"woodgate","x":7.0,"z":0.0,"hp":100,"ready":true}
	var approach:=wall(0,0)
	var neighbor:=wall(-109.0,12.0)
	var adjacent:Dictionary=neighbor.duplicate()
	adjacent.x+=225.0
	var border:=wall(109.0,12.0)
	var a:=Placement.joined_endpoints(first,[first,corner])
	var b:=Placement.joined_endpoints(corner,[first,corner])
	assert(a[1].distance_to(b[0])<Placement.cap_mesh(first).top_radius*2)
	var arrival:=Placement.joined_endpoints(approach,[approach,gate])
	assert(arrival[1].x>3.5 and arrival[1].x<4.0)
	assert(arrival[1].distance_to(Vector2(gate.x,gate.z))>2.5)
	var crossing:=Placement.joined_endpoints(border,[border,adjacent])
	var mirror:Dictionary=border.duplicate()
	mirror.x-=225.0
	var other:=Placement.joined_endpoints(neighbor,[neighbor,mirror])
	assert(crossing[1].distance_to(other[0]+Vector2(225,0))<0.3)
	var bounds:=Models.simplified_mesh("stonewall",2).get_aabb()
	var ground:=func(x: float,z: float)->float:return 0.3*x-0.1*z
	var pose:=Placement.wall_transform(first,a,bounds,Vector3.ONE,ground)
	var start:Vector3=pose*Vector3(bounds.position.x,0.0,bounds.get_center().z)
	var end:Vector3=pose*Vector3(bounds.end.x,0.0,bounds.get_center().z)
	assert(is_equal_approx(start.y,ground.call(start.x,start.z)))
	assert(is_equal_approx(end.y,ground.call(end.x,end.z)))
	var world:=WorldTown.build([first,corner,gate],2,Vector3.ZERO,func(at: Vector3)->float:return at.x*0.2)
	var instances:=0
	for node in world.get_children():instances+=node.multimesh.instance_count
	assert(instances==7)
	world.free()

	var detail:=Detail.new()
	root.add_child(detail)
	var camera:=Camera3D.new()
	root.add_child(camera)
	var home:={"type":"house","ready":true,"hp":100,"x":0.0,"z":0.0}
	var model:=Models.create("house",3)
	detail.add_child(model)
	detail.remember_building_lod(model,home,3)
	camera.position=Vector3(0,145,0)
	detail.update_building_lods(camera)
	assert(model.get_node("BuildingLow").mesh==Models.settlement_mesh("house",3))
	assert(not model.get_child(0).visible)
	camera.position=Vector3(0,700,0)
	detail.update_building_lods(camera)
	assert(model.get_node("BuildingLow").mesh==Models.simplified_mesh("house",3))
	camera.position=Vector3(0,3,7)
	detail.update_building_lods(camera)
	assert(model.get_child(0).visible and not model.get_node("BuildingLow").visible)
	detail.free()
	camera.free()
	HouseModel.clear_cache()
	print("MAP_BUILDING_MODELS_OK")
	quit()
