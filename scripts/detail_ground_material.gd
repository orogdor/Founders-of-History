extends RefCounted

const SHADER=preload("res://scripts/ground_blend.gdshader")
const MOBILE_SHADER=preload("res://scripts/mobile_ground.gdshader")
const Mobile=preload("res://scripts/mobile_profile.gd")
const KINDS:=["grass","soil","forest"]
const CHANNELS:=["color","normal","rough"]
static var requested:=false
static var requests: Dictionary={}
static var textures: Dictionary={}
static var waiting: Array=[]
static var waiting_world: Array[WeakRef]=[]
static var poll_frame: int=-1
static var materials: Dictionary={}

static func request_assets() -> void:
	if requested:return
	requested=true
	var paths := {"ground_height_maps":"res://assets/ground/ground-height.webp"}
	for kind in KINDS:
		for channel in channels():
			paths[kind+"_"+channel]="res://assets/ground/"+kind+"-"+channel+".webp"
	for key in paths:
		var path: String=paths[key]
		requests[key]={"path":path,"error":ResourceLoader.load_threaded_request(path,"Texture2D",false)}

static func channels() -> Array:
	return ["color"] if Mobile.active else CHANNELS

static func assets_ready() -> bool:
	return requests.is_empty() and textures.size()==KINDS.size()*channels().size()+1

static func poll() -> void:
	request_assets()
	var frame:=Engine.get_process_frames()
	if poll_frame==frame:return
	poll_frame=frame
	for key in requests.keys():
		var request: Dictionary=requests[key];var path: String=request.path
		if int(request.error)!=OK:
			var fallback: Texture2D=load(path)
			if fallback!=null:textures[key]=fallback
			requests.erase(key);continue
		var status:=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var texture: Texture2D=ResourceLoader.load_threaded_get(path)
			if texture!=null:textures[key]=texture
			requests.erase(key)
		elif status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var fallback: Texture2D=load(path)
			if fallback!=null:textures[key]=fallback
			requests.erase(key)
	if not assets_ready():return
	for pending in waiting_world:
		var world_material: ShaderMaterial=pending.get_ref()
		if world_material!=null:apply_world_textures(world_material)
	waiting_world.clear()
	var applied:=0
	while not waiting.is_empty() and applied<4:
		var entry: Dictionary=waiting.pop_front();var instance: Variant=entry.node.get_ref()
		if instance==null:continue
		instance.material_override=make_material(entry.color,float(entry.forest));applied+=1

static func make_material(color: Color,forest: float) -> ShaderMaterial:
	var key:=color.to_html()+":"+str(forest)
	if materials.has(key):return materials[key]
	var material:=ShaderMaterial.new();material.shader=MOBILE_SHADER if Mobile.active else SHADER
	for kind in KINDS:
		for channel in channels():material.set_shader_parameter(kind+"_"+channel,textures[kind+"_"+channel])
	if Mobile.active:material.set_shader_parameter("surface_textures_ready",true)
	material.set_shader_parameter("ground_height_maps",textures["ground_height_maps"])
	material.set_shader_parameter("forest_factor",forest);material.set_shader_parameter("base_color",color)
	materials[key]=material
	if materials.size()>128:materials.erase(materials.keys()[0])
	return material

static func attach(instance: MeshInstance3D,color: Color,forest: float,tile: Vector2i) -> void:
	instance.set_instance_shader_parameter("detail_uv_offset",Vector2(tile)*Vector2(225.0,195.0))
	request_assets()
	if assets_ready():
		instance.material_override=make_material(color,forest);return
	var fallback:=StandardMaterial3D.new();fallback.albedo_color=color;fallback.roughness=1.0;fallback.cull_mode=BaseMaterial3D.CULL_DISABLED
	instance.material_override=fallback
	waiting.append({"node":weakref(instance),"color":color,"forest":forest})

static func attach_world(material: ShaderMaterial) -> void:
	request_assets()
	if assets_ready():
		apply_world_textures(material)
	else:
		waiting_world.append(weakref(material))

static func apply_world_textures(material: ShaderMaterial) -> void:
	for kind in KINDS:
		material.set_shader_parameter(kind+"_color",textures[kind+"_color"])
	material.set_shader_parameter("ground_height_maps",textures["ground_height_maps"])
	material.set_shader_parameter("surface_textures_ready",true)

static func finish_requests() -> void:
	for key in requests.keys():
		var request: Dictionary=requests[key]
		if int(request.error)==OK:
			var path: String=request.path;var status:=ResourceLoader.load_threaded_get_status(path)
			if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:
				var texture: Texture2D=ResourceLoader.load_threaded_get(path)
				if texture!=null:textures[key]=texture
		requests.erase(key)
	waiting.clear()
	waiting_world.clear()
