extends RefCounted

const SHADER=preload("res://scripts/ground_blend.gdshader")
const MOBILE_SHADER=preload("res://scripts/mobile_ground.gdshader")
const Mobile=preload("res://scripts/mobile_profile.gd")
const CLIFF_TEXTURE=preload("res://assets/house_designer/mine-rock.webp")
const KINDS:=["grass","soil","forest"]
const CHANNELS:=["color","normal","rough"]
const CLIMATE_BLEND:={
	"desert":Vector3i(255,0,8),
	"mesa":Vector3i(247,0,224),
	"steppe":Vector3i(119,0,8),
	"tundra":Vector3i(0,97,0),
	"taiga":Vector3i(0,33,0),
	"snow":Vector3i(0,255,0),
	"snow_mountain":Vector3i(0,219,0),
}
static var world_requested:=false
static var detail_requested:=false
static var requests: Dictionary={}
static var textures: Dictionary={}
static var waiting: Array=[]
static var waiting_world: Array[WeakRef]=[]
static var waiting_detail: Array[WeakRef]=[]
static var detail_maps_queued:=false
static var poll_frame: int=-1
static var materials: Dictionary={}
static var climate_map: ImageTexture

static func set_climate(data: PackedByteArray,columns: int,rows: int) -> void:
	climate_map=null
	if columns>0 and rows>0 and data.size()==columns*rows*3:
		var image:=Image.create_from_data(columns,rows,false,Image.FORMAT_RGB8,data)
		climate_map=ImageTexture.create_from_image(image)
	for material in materials.values():apply_climate(material)

static func apply_climate(material: ShaderMaterial) -> void:
	material.set_shader_parameter("climate_map",climate_map)
	material.set_shader_parameter("climate_ready",climate_map!=null)

static func request_world_assets() -> void:
	if world_requested:return
	world_requested=true
	request_texture("ground_height_maps","res://assets/ground/ground-height.webp")
	for kind in KINDS:request_texture(kind+"_color","res://assets/ground/"+kind+"-color.webp")

static func request_assets() -> void:
	request_world_assets()
	if detail_requested:return
	detail_requested=true
	for kind in KINDS:
		for channel in channels():
			if channel!="color":request_texture(kind+"_"+channel,"res://assets/ground/"+kind+"-"+channel+".webp")

static func request_texture(key: String,path: String) -> void:
	if ResourceLoader.exists(path):
		requests[key]={"path":path,"error":ResourceLoader.load_threaded_request(path,"Texture2D",false)}

static func channels() -> Array:
	return ["color"] if Mobile.active else CHANNELS

static func world_assets_ready() -> bool:
	if not textures.has("ground_height_maps"):return false
	for kind in KINDS:
		if not textures.has(kind+"_color"):return false
	return true

static func assets_ready() -> bool:
	return textures.size()==KINDS.size()*channels().size()+1

static func poll() -> void:
	if not world_requested:return
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
	if world_assets_ready():
		for pending in waiting_world:
			var world_material: ShaderMaterial=pending.get_ref()
			if world_material!=null:apply_world_textures(world_material)
		waiting_world.clear()
	if assets_ready() and not Mobile.active and not detail_maps_queued:
		detail_maps_queued=true
		for material in materials.values():
			if material.shader==SHADER:waiting_detail.append(weakref(material))
	for i in mini(4,waiting_detail.size()):
		var material: ShaderMaterial=waiting_detail.pop_front().get_ref()
		if material!=null:apply_detail_textures(material)
	if not world_assets_ready():return
	var applied:=0
	while not waiting.is_empty() and applied<4:
		var entry: Dictionary=waiting.pop_front();var instance: Variant=entry.node.get_ref()
		if instance==null:continue
		instance.material_override=make_material(entry.color,float(entry.forest));applied+=1

static func make_material(color: Color,forest: float) -> ShaderMaterial:
	var key:=color.to_html()+":"+str(forest)+":"+str(Mobile.active)
	if materials.has(key):return materials[key]
	var material:=ShaderMaterial.new();material.shader=MOBILE_SHADER if Mobile.active else SHADER
	apply_climate(material)
	for kind in KINDS:material.set_shader_parameter(kind+"_color",textures[kind+"_color"])
	if Mobile.active:material.set_shader_parameter("surface_textures_ready",true)
	elif assets_ready():apply_detail_textures(material)
	material.set_shader_parameter("ground_height_maps",textures["ground_height_maps"])
	material.set_shader_parameter("forest_factor",forest);material.set_shader_parameter("base_color",color)
	materials[key]=material
	if materials.size()>128:materials.erase(materials.keys()[0])
	return material

static func attach(instance: MeshInstance3D,color: Color,forest: float,tile: Vector2i) -> void:
	instance.set_instance_shader_parameter("detail_uv_offset",Vector2(tile)*Vector2(225.0,195.0))
	request_world_assets()
	if world_assets_ready():
		instance.material_override=make_material(color,forest);return
	var fallback:=StandardMaterial3D.new();fallback.albedo_color=color;fallback.roughness=1.0;fallback.cull_mode=BaseMaterial3D.CULL_DISABLED
	instance.material_override=fallback
	waiting.append({"node":weakref(instance),"color":color,"forest":forest})

static func attach_world(material: ShaderMaterial) -> void:
	request_world_assets()
	apply_climate(material)
	if world_assets_ready():
		apply_world_textures(material)
	else:
		waiting_world.append(weakref(material))

static func apply_world_textures(material: ShaderMaterial) -> void:
	for kind in KINDS:
		material.set_shader_parameter(kind+"_color",textures[kind+"_color"])
	material.set_shader_parameter("ground_height_maps",textures["ground_height_maps"])
	material.set_shader_parameter("surface_textures_ready",true)

static func apply_detail_textures(material: ShaderMaterial) -> void:
	for kind in KINDS:
		material.set_shader_parameter(kind+"_normal",textures[kind+"_normal"])
		material.set_shader_parameter(kind+"_rough",textures[kind+"_rough"])
	material.set_shader_parameter("cliff_color",CLIFF_TEXTURE)
	material.set_shader_parameter("detail_maps_ready",true)

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
	waiting_detail.clear()
	detail_maps_queued=false
