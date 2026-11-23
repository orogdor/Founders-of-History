extends RefCounted
## Inimeste loomine: keha (mees, naine, poiss, tüdruk), ajastu riided ja tööriist.
##
## Andmed: data/human_outfits.json.
## Keha:   res://assets/people/bodies/<keha>.glb (MPFB2 eksport, meetrites).
## Riie:   res://assets/people/clothes/<ese>/<keha>.glb (sama luustikuga nahastatud võrk).
## Kui keha faili veel pole, tagastatakse senine human_far.glb, et mäng töötaks edasi.
##
## Keha võrgud nimega body_<tsoon> (nt body_torso, body_thighs) peidetakse,
## kui mõni selga pandud riie katab seda tsooni.

const Rig=preload("res://scripts/human_rig.gd")
const Equipment=preload("res://scripts/human_equipment.gd")
const FALLBACK=preload("res://assets/people/human_far.glb")
const DATA_PATH:="res://data/human_outfits.json"
## Mängu kutsujad skaleerivad inimese 1,66-ga (vana mudel on umbes 1 ühik pikk).
const CALLER_SCALE:=1.66
const CHILD_FALLBACK_SCALE:=0.69

static var data: Dictionary={}
static var scenes: Dictionary={}
static var tinted: Dictionary={}

static func config() -> Dictionary:
	if data.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		data=parsed if parsed is Dictionary else {"bodies":{},"items":{},"eras":[]}
	return data

static func packed(path: String) -> PackedScene:
	if path.is_empty():return null
	if not scenes.has(path):scenes[path]=load(path) if ResourceLoader.exists(path) else null
	return scenes[path]

static func stable_hash(text: String) -> int:
	return absi(hash(text))

## Valib keha töötaja võtme järgi püsivalt (sama töötaja on alati sama inimene).
static func pick_body(key: String,kind:="",child:=false) -> String:
	var female:=stable_hash(key)%2==1
	if kind in ["market_woman"]:female=true
	if child:return "girl" if female else "boy"
	return "woman" if female else "man"

## Kas mudel on uus riietatav inimene (mitte vana varumudel).
static func is_real(model: Node) -> bool:
	return model!=null and model.has_meta("human_real")

## Kutsuja skaala kordaja: vanal mudelil tehakse laps väiksemaks, päris lapse kehal mitte.
static func size_factor(model: Node) -> float:
	if model!=null and not is_real(model) and model.has_meta("human_child"):return CHILD_FALLBACK_SCALE
	return 1.0

static func create(body: String,era:=0,job:="",seed:=0) -> Node3D:
	var cfg: Dictionary=config().get("bodies",{}).get(body,{})
	var scene:=packed(str(cfg.get("scene","")))
	var root: Node3D=null
	if scene!=null:
		root=Node3D.new();root.name="Human"
		var model: Node3D=scene.instantiate();model.name="Body"
		model.scale=Vector3.ONE*(float(cfg.get("scale",1.0))/CALLER_SCALE);root.add_child(model)
		var rig: Variant=Rig.build(Rig.find_skeleton(model),root,cfg.get("bones",{}))
		if rig==null:
			push_warning("HumanFactory: keha '%s' luustik ei sobi, kasutan vana mudelit" % body)
			root.free();root=null
		else:
			root.set_meta("human_real",true)
			root.set_meta("human_zones",collect_zones(model))
	if root==null:root=FALLBACK.instantiate()
	root.set_meta("human_body",body);root.set_meta("human_seed",seed)
	if bool(cfg.get("child",body in ["boy","girl"])):root.set_meta("human_child",true)
	dress(root,era,job)
	return root

static func collect_zones(model: Node) -> Dictionary:
	var zones: Dictionary={}
	for node in all_children(model):
		if node is MeshInstance3D and str(node.name).begins_with("body_"):
			var zone:=str(node.name).substr(5).to_lower()
			var parts:=zone.split("_")
			if parts.size()>1 and parts[-1].is_valid_int():zone="_".join(parts.slice(0,-1))
			if not zones.has(zone):zones[zone]=[]
			zones[zone].append(node)
	return zones

static func all_children(node: Node) -> Array:
	var out: Array=[]
	for child in node.get_children():
		out.append(child);out.append_array(all_children(child))
	return out

## Riidekomplekt: ese iga koha (slot) kohta.
static func outfit_items(body: String,era: int,job:="",seed:=0) -> Array:
	var cfg:=config();var items: Dictionary=cfg.get("items",{})
	var eras: Array=cfg.get("eras",[])
	if eras.is_empty():return []
	var e: Dictionary=eras[clampi(era,0,eras.size()-1)]
	var b: Dictionary=cfg.get("bodies",{}).get(body,{})
	var adult: String=str(b.get("outfit",body))
	var own: Dictionary=e.get(body,{})
	var plan: Dictionary=e.get(str(own.get("from",adult)),{}) if own.has("from") or own.is_empty() else own
	var slots: Dictionary={}
	for id in plan.get("base",[]):
		if items.has(id):slots[str(items[id].slot)]=id
	var options: Dictionary=plan.get("options",{})
	var keys: Array=options.keys();keys.sort()
	for k in keys.size():
		var choices: Array=options[keys[k]]
		if choices.is_empty():continue
		slots.erase(keys[k])
		for id in choices[stable_hash("%d:%s" % [seed,keys[k]])%choices.size()]:
			if items.has(id):slots[str(items[id].slot)]=id
	var jobs: Dictionary=e.get("jobs",{})
	if jobs.has(job):
		for id in jobs[job].get("all",[])+jobs[job].get(adult,[]):
			if items.has(id):slots[str(items[id].slot)]=id
	for slot in own.get("drop",[]):slots.erase(slot)
	for key in ["hair","beard"]:
		var list: Array=b.get(key,[])
		if not list.is_empty() and not slots.has(key):
			var id: String=str(list[stable_hash("%d:%s" % [seed,key])%list.size()])
			if items.has(id):slots[key]=id
	return slots.values()

## Paneb riided selga. Kutsu uuesti ajastu või ameti vahetudes.
static func dress(root: Node3D,era: int,job:="") -> void:
	root.set_meta("human_era",era);root.set_meta("human_job",job)
	if not is_real(root):return
	var skeleton:=Rig.find_skeleton(root)
	for node in root.get_meta("human_garments",[]):
		if is_instance_valid(node):
			if node.get_parent()!=null:node.get_parent().remove_child(node)
			node.queue_free()
	var body: String=str(root.get_meta("human_body"));var seed: int=int(root.get_meta("human_seed",0))
	var items: Dictionary=config().get("items",{})
	var ids:=outfit_items(body,era,job,seed)
	var hide_hair:=false
	for id in ids:
		if bool(items[id].get("hides_hair",false)):hide_hair=true
	var hidden: Dictionary={};var garments: Array=[]
	for id in ids:
		var item: Dictionary=items[id]
		if hide_hair and str(item.slot)=="hair":continue
		var meshes:=attach_garment(skeleton,str(id),body,item,seed)
		if meshes.is_empty():continue
		garments.append_array(meshes)
		for zone in item.get("hides",[]):hidden[zone]=true
	var zones: Dictionary=root.get_meta("human_zones",{})
	for zone in zones:
		for mesh in zones[zone]:
			if is_instance_valid(mesh):mesh.visible=not hidden.has(zone)
	root.set_meta("human_garments",garments);root.set_meta("human_outfit",ids)

static func attach_garment(skeleton: Skeleton3D,id: String,body: String,item: Dictionary,seed: int) -> Array:
	var scene:=packed("res://assets/people/clothes/%s/%s.glb" % [id,body])
	if scene==null or skeleton==null:return []
	var instance: Node=scene.instantiate();var meshes: Array=[]
	for node in all_children(instance):
		if node is MeshInstance3D and node.skin!=null:meshes.append(node)
	for mesh in meshes:
		mesh.get_parent().remove_child(mesh);mesh.owner=null
		skeleton.add_child(mesh);mesh.transform=Transform3D.IDENTITY;mesh.skeleton=NodePath("..")
		tint(mesh,item,seed,id)
	instance.free()
	if meshes.is_empty():push_warning("HumanFactory: '%s' failis pole nahastatud võrku" % id)
	return meshes

static func tint(mesh: MeshInstance3D,item: Dictionary,seed: int,id: String) -> void:
	if mesh.mesh==null:return
	var tints: Array=item.get("tints",[])
	var color:=Color(str(tints[stable_hash("%d:%s:tint" % [seed,id])%tints.size()])) if not tints.is_empty() else Color.WHITE
	for s in mesh.mesh.get_surface_count():
		var material:=mesh.get_active_material(s)
		if not material is BaseMaterial3D:continue
		# Riiete tipuvärvides on varjud (voldid, kaenlaalused, äärte mustus).
		var shaded: bool=(mesh.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR)!=0
		if tints.is_empty() and not shaded:continue
		var key:="%d:%s:%s" % [material.get_instance_id(),color.to_html(false),shaded]
		if not tinted.has(key):
			var copy: BaseMaterial3D=material.duplicate();copy.albedo_color=copy.albedo_color*color
			copy.vertex_color_use_as_albedo=shaded;tinted[key]=copy
		mesh.set_surface_override_material(s,tinted[key])

## Ajastu tööriista nimi ametile (kiviajal senised tööriistad).
static func tool_name(kind: String,era: int) -> String:
	if era<=0:return ""
	var eras: Array=config().get("eras",[])
	if eras.is_empty():return ""
	var tools: Dictionary=eras[clampi(era,0,eras.size()-1)].get("tools",{})
	return str(tools.get(kind,""))

## Paneb ametile ja ajastule vastava tööriista kätte ning jätab selle meeles (meta "job_tool").
static func equip_job(model: Node3D,kind: String,era: int) -> Node3D:
	if model.has_meta("job_tool"):
		detach(model.get_meta("job_tool"));model.remove_meta("job_tool")
	var tool: Node3D=Equipment.job(model,kind) if era<=0 else null
	if era>0:
		var name:=tool_name(kind,era)
		if not name.is_empty():tool=Equipment.attach(model,"hand_R",name)
	if tool!=null:model.set_meta("job_tool",tool)
	model.set_meta("job_kind",kind);model.set_meta("job_tool_era",era)
	return tool

static func detach(prop: Variant) -> void:
	if not is_instance_valid(prop):return
	var node: Node=prop
	while node.get_parent()!=null and not node is BoneAttachment3D:node=node.get_parent()
	if node is BoneAttachment3D:
		node.get_parent().remove_child(node);node.queue_free()
	else:prop.queue_free()

## Kas tööriist sobib praegusesse ajastusse (vana loogika: ainult kiviajal).
static func tool_visible(model: Node,era: int) -> bool:
	if not model.has_meta("job_tool_era"):return era==0
	return int(model.get_meta("job_tool_era"))==era

## Kutsu igal kaadril: vahetab riided ja tööriista ainult siis, kui ajastu muutus.
static func set_era(model: Node3D,era: int) -> void:
	if int(model.get_meta("human_era",-1))==era:return
	dress(model,era,str(model.get_meta("human_job","")))
	if model.has_meta("job_kind"):equip_job(model,str(model.get_meta("job_kind")),era)
