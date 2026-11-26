extends RefCounted

const Eras=preload("res://scripts/house_eras.gd")
const HouseModel=preload("res://scripts/house_plan_model.gd")
const Placement=preload("res://scripts/building_placement.gd")
const Fits=preload("res://data/building_fits.json")
const Rules=preload("res://data/build_rules.json")
const TownShader=preload("res://scripts/town_material.gdshader")
const SurfaceDetail=preload("res://scripts/surface_detail.gd")
const Mobile=preload("res://scripts/mobile_profile.gd")
const PlainFallbacks=["nitrate","oilwell","refinery","powerplant","autofactory","airfield","master_workshop","infirmary","keep"]
const LOW_CACHE_SIZE=128

static var low_meshes:Dictionary={}
static var low_order:Array[String]=[]
static var vertex_materials:Dictionary={}
static var has_vertex_colors:Dictionary={}
static var town_material:ShaderMaterial
static var settlement_town_material:ShaderMaterial
static var low_material:StandardMaterial3D

static func specification(type: String,age: int,design: Dictionary,tier: int,simplified:=false) -> Dictionary:
	var building_age:=maxi(int(Rules.data.age.get(type,0)),age)
	var fit_id:=Eras.fit_id(type,building_age)
	if type=="palisade" and tier==2 and fit_id=="palisade" and design.is_empty():
		fit_id="palisade-tier2"
	# At distance the matching plan provides a much lighter mesh than the GLB.
	var plan:=Eras.live_plan(type,building_age,design,not simplified and building_age in [0,2])
	var id:=str(plan.get("id",fit_id))
	if plan.is_empty():
		var procedural:="procedural_"+type+"@"+str(clampi(building_age,0,6))
		if (building_age>=3 or id.is_empty()) and ResourceLoader.exists("res://assets/buildings/"+procedural+".glb"):
			id=procedural
	var fit:Dictionary={} if id.begins_with("procedural_") else Fits.data.get(fit_id,{})
	return {"id":id,"plan":plan,"fit":fit,"town_shader":id.begins_with("procedural_") and type not in PlainFallbacks}

static func create(type: String,age: int,design: Dictionary={},tier:=1) -> Node3D:
	var spec:=specification(type,age,design,tier)
	var raw:=source(spec,false)
	if raw==null:return null
	var wrapper:=Node3D.new()
	wrapper.set_meta("designer_id",spec.id)
	wrapper.add_child(raw)
	return wrapper

static func source(spec: Dictionary,simplified: bool,settlement_detail:=false) -> Node3D:
	var raw:Node3D
	if not spec.plan.is_empty():
		if simplified:
			raw=HouseModel.new()
			raw.simplified=true
			raw.settlement_detail=settlement_detail
			raw.rebuild(spec.plan)
		else:
			raw=HouseModel.from_design(spec.plan)
	else:
		var path:="res://assets/buildings/"+str(spec.id)+".glb"
		if spec.id.is_empty() or not ResourceLoader.exists(path):return null
		raw=load(path).instantiate()
		if not simplified:apply_imported_materials(raw,spec.town_shader)
	if not spec.fit.is_empty():
		var scale: Array=spec.fit.scale
		var offset: Array=spec.fit.offset
		raw.scale=Vector3(scale[0],scale[1],scale[2])
		raw.position=Vector3(offset[0],offset[1],offset[2])
	return raw

static func apply_imported_materials(node: Node,town: bool) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		for surface in node.mesh.get_surface_count():
			var surface_key:="%d:%d" % [node.mesh.get_rid().get_id(),surface]
			if not has_vertex_colors.has(surface_key):
				var colors:Variant=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				has_vertex_colors[surface_key]=colors!=null and not colors.is_empty()
			var painted: bool=has_vertex_colors[surface_key]
			if town and painted:
				if town_material==null:
					town_material=ShaderMaterial.new()
					town_material.shader=TownShader
					town_material.set_shader_parameter("close_detail",not Mobile.active)
				node.set_surface_override_material(surface,town_material)
			else:
				var original:Material=node.get_active_material(surface)
				if not original is StandardMaterial3D or (not painted and original.albedo_texture==null):continue
				var key:=[original.get_instance_id(),painted]
				if not vertex_materials.has(key):
					var corrected:StandardMaterial3D=original.duplicate()
					if painted:corrected.vertex_color_use_as_albedo=true
					SurfaceDetail.refine_architecture(corrected,"",not Mobile.active)
					vertex_materials[key]=corrected
				node.set_surface_override_material(surface,vertex_materials[key])
	for child in node.get_children():apply_imported_materials(child,town)

static func bounds(node: Node,transform:=Transform3D.IDENTITY) -> AABB:
	var pose:Transform3D=transform*node.transform if node is Node3D else transform
	var result:AABB=pose*node.get_aabb() if node is MeshInstance3D and node.mesh!=null else AABB()
	for child in node.get_children():
		var child_bounds:=bounds(child,pose)
		if not child_bounds.has_surface():continue
		result=child_bounds if not result.has_surface() else result.merge(child_bounds)
	return result

static func simplified_mesh(type: String,age: int,design: Dictionary={},tier:=1) -> ArrayMesh:
	var spec:=specification(type,age,design,tier,true)
	var key:=mesh_key(spec)
	if low_meshes.has(key):
		low_order.erase(key)
		low_order.append(key)
		return low_meshes[key]
	var raw:=source(spec,true)
	if raw==null:return null
	var arrays:=geometry_arrays()
	if type in Placement.Walls and spec.plan.is_empty():
		append_wall_shell(type,tier,bounds(raw),arrays)
	else:
		append_meshes(raw,Transform3D.IDENTITY,arrays,0.34 if type=="woodgate" else 0.0)
	raw.free()
	if arrays[Mesh.ARRAY_INDEX].is_empty():return null
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,flat_material())
	return cache_mesh(key,mesh)

static func mesh_key(spec: Dictionary) -> String:
	var key: String=spec.id
	if not spec.plan.is_empty() and not is_same(spec.plan,Eras.default_plan(spec.id)):
		key+=":"+str(hash(spec.plan))
	return key

static func cache_mesh(key: String,mesh: ArrayMesh) -> ArrayMesh:
	low_meshes[key]=mesh
	low_order.append(key)
	if low_order.size()>LOW_CACHE_SIZE:low_meshes.erase(low_order.pop_front())
	return mesh

static func geometry_arrays(with_uv:=false) -> Array:
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array()
	arrays[Mesh.ARRAY_COLOR]=PackedColorArray()
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array()
	if with_uv:arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array()
	return arrays

static func flat_material() -> StandardMaterial3D:
	if low_material==null:
		low_material=StandardMaterial3D.new()
		low_material.vertex_color_use_as_albedo=true
		low_material.cull_mode=BaseMaterial3D.CULL_DISABLED
		low_material.roughness=0.92
	return low_material

static func settlement_mesh(type: String,age: int,design: Dictionary={},tier:=1) -> ArrayMesh:
	var spec:=specification(type,age,design,tier,true)
	var key:="settlement:"+mesh_key(spec)
	if low_meshes.has(key):
		low_order.erase(key)
		low_order.append(key)
		return low_meshes[key]
	var raw:=source(spec,true,true)
	if raw==null:return null
	var groups: Dictionary={}
	append_settlement(raw,Transform3D.IDENTITY,groups,{},spec.town_shader)
	raw.free()
	var mesh:=ArrayMesh.new()
	for material in groups:
		if groups[material][Mesh.ARRAY_INDEX].is_empty():continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,groups[material])
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
	return cache_mesh(key,mesh) if mesh.get_surface_count()>0 else null

static func append_settlement(node: Node,transform: Transform3D,groups: Dictionary,materials: Dictionary,town: bool) -> void:
	var pose:Transform3D=transform*node.transform if node is Node3D else transform
	if node is MeshInstance3D and node.mesh!=null:
		for surface in node.mesh.get_surface_count():
			var original: Material=node.get_active_material(surface)
			if not materials.has(original):materials[original]=settlement_material(original,town)
			var material: Material=materials[original]
			if not groups.has(material):groups[material]=geometry_arrays(true)
			append_surface(node.mesh,surface,original,pose,groups[material],0.0,material!=flat_material())
	for child in node.get_children():append_settlement(child,pose,groups,materials,town)

static func settlement_material(original: Material,town: bool) -> Material:
	if town:
		if settlement_town_material==null:
			settlement_town_material=ShaderMaterial.new()
			settlement_town_material.shader=TownShader
			settlement_town_material.set_shader_parameter("close_detail",false)
		return settlement_town_material
	if original is ShaderMaterial:return original
	if not original is StandardMaterial3D:return flat_material()
	if original.albedo_texture==null and original.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:return flat_material()
	var material: StandardMaterial3D=original.duplicate()
	material.normal_enabled=false
	material.heightmap_enabled=false
	material.ao_enabled=false
	material.vertex_color_use_as_albedo=true
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func append_wall_shell(type: String,tier: int,extents: AABB,output: Array) -> void:
	# These long silhouettes must retain both ends, even at the lowest detail level.
	var wood:=type=="palisade"
	var shade:=Color("715239") if wood else Color("8e8472")
	var material:=StandardMaterial3D.new()
	material.albedo_color=shade
	var center:=extents.get_center()
	var body:=BoxMesh.new()
	var body_height:=0.61 if type=="reinforced_wall" else 0.72 if wood else 0.79
	body.size=Vector3(extents.size.x,extents.size.y*body_height,extents.size.z)
	var at:=Vector3(center.x,extents.position.y+body.size.y*0.5,center.z)
	append_surface(body,0,material,Transform3D(Basis.IDENTITY,at),output)
	if not wood:
		var crown:=StandardMaterial3D.new()
		crown.albedo_color=shade.lightened(0.10)
		var ledge:=BoxMesh.new()
		ledge.size=Vector3(extents.size.x,extents.size.y*(1.0-body_height if type=="stonewall" else 0.14),extents.size.z*0.96)
		var y:=extents.position.y+body.size.y+ledge.size.y*0.5
		append_surface(ledge,0,crown,Transform3D(Basis.IDENTITY,Vector3(center.x,y,center.z)),output)
		if type=="reinforced_wall":
			var count:=maxi(2,roundi(extents.size.x/1.2))
			var merlon:=BoxMesh.new()
			merlon.size=Vector3(extents.size.x/count*0.57,extents.size.y*0.25,extents.size.z*0.18)
			for side in [-1,1]:
				var z:=center.z+float(side)*extents.size.z*0.39
				for i in count:
					var x:=lerpf(extents.position.x,extents.end.x,(float(i)+0.5)/count)
					append_surface(merlon,0,crown,Transform3D(Basis.IDENTITY,Vector3(x,extents.end.y-merlon.size.y*0.5,z)),output)
		return
	var post_count:=mini(18,maxi(4,roundi(extents.size.x/0.55)))
	var post:=CylinderMesh.new()
	post.top_radius=0.015
	post.bottom_radius=maxf(0.055,minf(0.20,extents.size.z*0.43))
	post.height=extents.size.y*0.32
	post.radial_segments=4
	post.rings=0
	for i in post_count:
		var x:=lerpf(extents.position.x+post.bottom_radius,extents.end.x-post.bottom_radius,(float(i)+0.5)/post_count)
		var y:=extents.end.y-post.height*0.5
		append_surface(post,0,material,Transform3D(Basis.IDENTITY,Vector3(x,y,center.z)),output)
	if tier==2:
		var walk:=BoxMesh.new()
		walk.size=Vector3(extents.size.x,0.12,extents.size.z)
		append_surface(walk,0,material,Transform3D(Basis.IDENTITY,Vector3(center.x,extents.end.y*0.65,center.z)),output)

static func append_meshes(node: Node,transform: Transform3D,output: Array,minimum_ratio: float) -> void:
	var pose:Transform3D=transform*node.transform if node is Node3D else transform
	if node is MeshInstance3D and node.mesh!=null:
		for surface in node.mesh.get_surface_count():
			append_surface(node.mesh,surface,node.get_active_material(surface),pose,output,minimum_ratio)
	for child in node.get_children():
		append_meshes(child,pose,output,minimum_ratio)

static func append_surface(mesh: Mesh,surface: int,material: Material,pose: Transform3D,output: Array,minimum_ratio:=0.0,keep_material:=false) -> void:
	if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return
	var arrays:=mesh.surface_get_arrays(surface)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:Variant=arrays[Mesh.ARRAY_NORMAL]
	var colors:Variant=arrays[Mesh.ARRAY_COLOR]
	var uv:Variant=arrays[Mesh.ARRAY_TEX_UV]
	var indices:Variant=arrays[Mesh.ARRAY_INDEX]
	# Use the GLB importer's own simplification to keep the original silhouette.
	if mesh is ArrayMesh and indices!=null and indices.size()>=72:
		var surface_data:=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
		var stride:=maxi(2,RenderingServer.mesh_surface_get_format_index_stride(mesh.surface_get_format(surface),vertices.size()))
		var minimum_count:=maxi(12,ceili(indices.size()*minimum_ratio))
		for lod in surface_data.get("lods",[]):
			var bytes:PackedByteArray=lod.index_data
			var count:=int(bytes.size()/stride)
			if count<minimum_count or count>=indices.size():continue
			var selected:=PackedInt32Array()
			selected.resize(count)
			for i in count:
				selected[i]=bytes.decode_u16(i*stride) if stride==2 else bytes.decode_u32(i*stride)
			indices=selected
	var tint:Color=material.albedo_color if not keep_material and material is BaseMaterial3D else Color.WHITE
	var normal_basis:=pose.basis.inverse().transposed() if absf(pose.basis.determinant())>0.000001 else Basis.IDENTITY
	var count:int=indices.size() if indices!=null and not indices.is_empty() else vertices.size()
	var mapped:Dictionary={}
	for i in count:
		var vertex:int=indices[i] if indices!=null and not indices.is_empty() else i
		if not mapped.has(vertex):
			mapped[vertex]=output[Mesh.ARRAY_VERTEX].size()
			output[Mesh.ARRAY_VERTEX].append(pose*vertices[vertex])
			output[Mesh.ARRAY_NORMAL].append((normal_basis*normals[vertex]).normalized() if normals!=null and not normals.is_empty() else Vector3.UP)
			var color:Color=tint*colors[vertex] if colors!=null and not colors.is_empty() else tint
			color.a=1.0
			output[Mesh.ARRAY_COLOR].append(color)
			if output[Mesh.ARRAY_TEX_UV]!=null:
				output[Mesh.ARRAY_TEX_UV].append(uv[vertex] if uv!=null and not uv.is_empty() else Vector2.ZERO)
		output[Mesh.ARRAY_INDEX].append(mapped[vertex])


static func add_instance(groups: Dictionary,mesh: Mesh,pose: Transform3D) -> void:
	if not groups.has(mesh):groups[mesh]=[]
	groups[mesh].append(pose)

static func add_batches(parent: Node3D,groups: Dictionary,shadows: bool) -> void:
	for mesh in groups:
		var batch:=MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=mesh
		batch.instance_count=groups[mesh].size()
		for i in batch.instance_count:batch.set_instance_transform(i,groups[mesh][i])
		var visual:=MultiMeshInstance3D.new()
		visual.multimesh=batch
		if not shadows:visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(visual)
