extends SceneTree

const Models=preload("res://scripts/building_models.gd")
const Placement=preload("res://scripts/building_placement.gd")
const WorldTown=preload("res://scripts/world_city_layout.gd")
const Detail=preload("res://scripts/detail_view.gd")
const Eras=preload("res://scripts/house_eras.gd")
const HouseModel=preload("res://scripts/house_plan_model.gd")

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

func run() -> void:
	for age in Eras.NAMES.size():
		var high:=Models.create("house",age)
		var low:=Models.simplified_mesh("house",age)
		assert(high!=null and low!=null)
		assert(high.get_meta("designer_id")==Eras.project_id("house",age))
		assert(low.surface_get_array_index_len(0)/3 < triangle_count(high)*0.25)
		assert(Models.simplified_mesh("house",age)==low)
		high.free()
		var gate_mesh:=Models.simplified_mesh("woodgate",age)
		assert(gate_mesh!=null and gate_mesh.get_aabb().size.x>=6.4)
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
	camera.position=Vector3(0,180,0)
	detail.update_building_lods(camera)
	assert(model.get_node("BuildingLow").mesh==Models.simplified_mesh("house",3))
	assert(not model.get_child(0).visible)
	camera.position=Vector3(0,3,7)
	detail.update_building_lods(camera)
	assert(model.get_child(0).visible and not model.get_node("BuildingLow").visible)
	detail.free()
	camera.free()
	HouseModel.clear_cache()
	print("MAP_BUILDING_MODELS_OK")
	quit()
