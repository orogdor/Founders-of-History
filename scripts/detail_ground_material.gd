extends RefCounted

const SHADER=preload("res://scripts/ground_blend.gdshader")
const PaintedMaterials=preload("res://scripts/painted_building_materials.gd")
const FAMILIES=[PaintedMaterials.MEADOW,PaintedMaterials.FOREST,PaintedMaterials.SOIL,PaintedMaterials.STONE]
static var requested:=false
static var requests: Dictionary={}
static var textures: Dictionary={}
static var waiting: Array=[]
static var poll_frame: int=-1
static var materials: Dictionary={}

static func request_assets() -> void:
	if requested:return
	requested=true
	for family in FAMILIES:
		var path: String=PaintedMaterials.ROOT+family+"_atlas.png"
		requests[family]={"path":path,"error":ResourceLoader.load_threaded_request(path,"Texture2D",false)}

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
	if not requests.is_empty() or not textures.has(PaintedMaterials.MEADOW):return
	var applied:=0
	while not waiting.is_empty() and applied<4:
		var entry: Dictionary=waiting.pop_front();var instance: Variant=entry.node.get_ref()
		if instance==null:continue
		instance.material_override=make_material(entry.color,float(entry.forest));applied+=1

static func make_material(color: Color,forest: float) -> ShaderMaterial:
	var key:=color.to_html()+":"+str(forest)
	if materials.has(key):return materials[key]
	var material:=ShaderMaterial.new();material.shader=SHADER
	for family in FAMILIES:
		var atlas: Texture2D=textures.get(family)
		if atlas==null:atlas=PaintedMaterials.atlas(family)
		material.set_shader_parameter("painted_"+family,atlas)
	material.set_shader_parameter("forest_factor",forest);material.set_shader_parameter("base_color",color)
	materials[key]=material;return material

static func attach(instance: MeshInstance3D,color: Color,forest: float,tile:=Vector2i.ZERO) -> void:
	request_assets()
	instance.set_instance_shader_parameter("painted_world_origin",Vector2(tile)*Vector2(225,195))
	if requests.is_empty() and textures.has(PaintedMaterials.MEADOW):
		instance.material_override=make_material(color,forest);return
	var fallback:=StandardMaterial3D.new();fallback.albedo_color=color;fallback.roughness=1.0;fallback.cull_mode=BaseMaterial3D.CULL_DISABLED
	instance.material_override=fallback
	waiting.append({"node":weakref(instance),"color":color,"forest":forest})

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
