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

static func create(body: String,era:=0,job:="",seed:=0,team:=-1,unit:="") -> Node3D:
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
			tint_skin(model,seed)
	if root==null:root=FALLBACK.instantiate()
	root.set_meta("human_body",body);root.set_meta("human_seed",seed)
	if team>=0:root.set_meta("human_team",team)
	if unit!="" and is_real(root):root.set_meta("human_unit",unit)
	if bool(cfg.get("child",body in ["boy","girl"])):root.set_meta("human_child",true)
	dress(root,era,job)
	return root

## Nahatooni väike erinevus inimeste vahel (heledam/tumedam, roosakam/kollakam).
const SKIN_SHADES:=[Color(1,1,1),Color(0.93,0.9,0.87),Color(1.04,1.01,0.98),Color(0.86,0.8,0.74),Color(0.98,0.95,0.96),Color(0.78,0.7,0.62)]
static func tint_skin(model: Node,seed: int) -> void:
	var shade: Color=SKIN_SHADES[stable_hash("%d:skin" % seed)%SKIN_SHADES.size()]
	if shade==Color(1,1,1):return
	for node in all_children(model):
		if not node is MeshInstance3D or node.mesh==null:continue
		var mesh: MeshInstance3D=node
		for s in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(s)
			if not material is BaseMaterial3D or not str(material.resource_name).begins_with("skin"):continue
			var key:="skin:%d:%s" % [material.get_instance_id(),shade.to_html(false)]
			if not tinted.has(key):
				var copy: BaseMaterial3D=material.duplicate();copy.albedo_color=copy.albedo_color*shade;tinted[key]=copy
			mesh.set_surface_override_material(s,tinted[key])

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

## Riidekomplekt: ese iga koha (slot) kohta. Ajastul on 5 riietust mehele ja 5 naisele,
## 5 soengut ja habemete valik; valik tehakse inimese seemne järgi püsivalt.
static func outfit_items(body: String,era: int,job:="",seed:=0) -> Array:
	var cfg:=config();var items: Dictionary=cfg.get("items",{})
	var eras: Array=cfg.get("eras",[])
	if eras.is_empty():return []
	var e: Dictionary=eras[clampi(era,0,eras.size()-1)]
	var b: Dictionary=cfg.get("bodies",{}).get(body,{})
	var adult: String=str(b.get("outfit",body))
	var own: Dictionary=e.get(body,{}) if e.get(body) is Dictionary else {}
	var slots: Dictionary={}
	var outfits: Array=e.get(adult,[]) if e.get(adult) is Array else []
	if not outfits.is_empty():
		var outfit: Dictionary=outfits[stable_hash("%d:outfit" % seed)%outfits.size()]
		for id in outfit.get("items",[]):
			if items.has(id):slots[str(items[id].slot)]=id
	var jobs: Dictionary=e.get("jobs",{})
	if jobs.has(job):
		for id in jobs[job].get("all",[])+jobs[job].get(adult,[]):
			if items.has(id):slots[str(items[id].slot)]=id
	for slot in own.get("drop",[]):slots.erase(slot)
	add_hair(slots,e,adult,body,seed)
	return slots.values()

static func add_hair(slots: Dictionary,e: Dictionary,adult: String,body: String,seed: int) -> void:
	var items: Dictionary=config().get("items",{})
	var hair: Array=e.get("hair",{}).get(adult,[])
	if not hair.is_empty():
		var id: String=str(hair[stable_hash("%d:hair" % seed)%hair.size()])
		if items.has(id):slots["hair"]=id
	if body=="man":
		var beards: Array=e.get("beards",[])
		if not beards.is_empty():
			var id: String=str(beards[stable_hash("%d:beard" % seed)%beards.size()])
			if items.has(id):slots["beard"]=id

## Väeliigi varustus (data/human_outfits.json "units") + selle ajastu soeng ja vahel habe.
static func unit_items(kind: String,seed:=0) -> Array:
	var cfg:=config();var items: Dictionary=cfg.get("items",{})
	var unit: Dictionary=cfg.get("units",{}).get(kind,{})
	var slots: Dictionary={}
	for id in unit.get("items",[]):
		if items.has(id):slots[str(items[id].slot)]=id
	var eras: Array=cfg.get("eras",[])
	if not eras.is_empty():add_hair(slots,eras[clampi(int(unit.get("era",0)),0,eras.size()-1)],"man","man",seed)
	return slots.values()

static func hair_color(seed: int) -> Color:
	var colors: Array=config().get("hair_colors",["5a4030"])
	return Color(str(colors[stable_hash("%d:haircolor" % seed)%colors.size()]))

static func team_color(team: int) -> Color:
	var colors: Array=config().get("team_colors",["276bd1","c43d43","9271ce","d2a12e"])
	return Color(str(colors[clampi(team,0,colors.size()-1)]))

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
	var ids: Array=root.get_meta("human_items") if root.has_meta("human_items") else unit_items(str(root.get_meta("human_unit")),seed) if root.has_meta("human_unit") else outfit_items(body,era,job,seed)
	var team: int=int(root.get_meta("human_team",-1))
	var hide_hair:=false
	for id in ids:
		if bool(items[id].get("hides_hair",false)):hide_hair=true
	var hidden: Dictionary={};var garments: Array=[]
	for id in ids:
		var item: Dictionary=items[id]
		if hide_hair and str(item.slot)=="hair":continue
		var meshes:=attach_garment(skeleton,str(id),body,item,seed,team)
		if meshes.is_empty():continue
		garments.append_array(meshes)
		for zone in item.get("hides",[]):hidden[zone]=true
	var zones: Dictionary=root.get_meta("human_zones",{})
	for zone in zones:
		for mesh in zones[zone]:
			if is_instance_valid(mesh):mesh.visible=not hidden.has(zone)
	root.set_meta("human_garments",garments);root.set_meta("human_outfit",ids)

static func attach_garment(skeleton: Skeleton3D,id: String,body: String,item: Dictionary,seed: int,team:=-1) -> Array:
	var scene:=packed("res://assets/people/clothes/%s/%s.glb" % [id,body])
	if scene==null or skeleton==null:return []
	var instance: Node=scene.instantiate();var meshes: Array=[]
	for node in all_children(instance):
		if node is MeshInstance3D and node.skin!=null:meshes.append(node)
	for mesh in meshes:
		mesh.get_parent().remove_child(mesh);mesh.owner=null
		skeleton.add_child(mesh);mesh.transform=Transform3D.IDENTITY;mesh.skeleton=NodePath("..")
		tint(mesh,item,seed,id,team)
	instance.free()
	if meshes.is_empty():push_warning("HumanFactory: '%s' failis pole nahastatud võrku" % id)
	return meshes

static func tint(mesh: MeshInstance3D,item: Dictionary,seed: int,id: String,team:=-1) -> void:
	if mesh.mesh==null:return
	var tints: Array=item.get("tints",[])
	var color:=Color(str(tints[stable_hash("%d:%s:tint" % [seed,id])%tints.size()])) if not tints.is_empty() else Color.WHITE
	if bool(item.get("hair_color",false)):color=hair_color(seed);tints=[color]
	elif bool(item.get("team",false)):color=team_color(team).darkened(0.18) if team>=0 else Color("8a7a62");tints=[color]   # kangas: tumedam kui UI värv
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

# ---------------------------------------------------------------- sõdurid
## Lähemal kui see kaugus näidatakse uut inimest, kaugemal sõduri vana keha (jõudlus).
const SOLDIER_DETAIL_DISTANCE:=40.0
const SOLDIER_BONES:={"hips":"body","spine":"body","chest":"chest","neck":"chest","head":"head","upperArm_L":"upperArm_L","forearm_L":"forearm_L","hand_L":"hand_L",
	"upperArm_R":"upperArm_R","forearm_R":"forearm_R","hand_R":"hand_R","thigh_L":"thigh_L","shin_L":"shin_L","foot_L":"shin_L","thigh_R":"thigh_R","shin_R":"shin_R","foot_R":"shin_R"}
const SOLDIER_STAND_HEIGHT:=0.96

## Riietab jagatud sõdurimudeli (assets/soldiers/split): lisab väeliigi riietes inimese, kes järgib
## sõduri luustikku ja animatsioone. Relvad, kilbid ja hobune jäävad sõdurimudelist.
static func dress_soldier(model: Node3D,kind: String,team: int,seed: int,model_scale:=1.0) -> bool:
	if not config().get("units",{}).has(kind):return false
	var source:=Rig.find_skeleton(model)
	if source==null:return false
	var old_bodies: Array=[]
	var old_body: Node=model.find_child("SoldierBody",true,false)
	if old_body!=null:old_bodies.append(old_body)
	elif source.find_bone("hips")>=0:
		## Vana human_far (nt maakuulaja): kogu mudel on keha, varustust pole.
		for node in all_children(source):
			if node is MeshInstance3D:old_bodies.append(node)
	if old_bodies.is_empty():return false
	var human:=create("man",0,"",seed,team,kind)
	if not is_real(human):
		human.free();return false
	human.name="SoldierHuman";human.scale=Vector3.ONE*(CALLER_SCALE/maxf(model_scale,0.001))
	model.add_child(human)
	for node in all_children(human):
		if node is GeometryInstance3D:node.visibility_range_end=SOLDIER_DETAIL_DISTANCE;node.visibility_range_end_margin=3.0
	for body in old_bodies:
		if body is GeometryInstance3D:body.visibility_range_begin=SOLDIER_DETAIL_DISTANCE;body.visibility_range_begin_margin=3.0
	var old_rig:=source.find_bone("hips")>=0
	var map: Dictionary={}
	for canon in Rig.CANONICAL:map[canon]=source.find_bone(canon if old_rig else str(SOLDIER_BONES[canon]))
	model.set_meta("soldier_human",human);model.set_meta("soldier_source",source);model.set_meta("soldier_map",map)
	model.set_meta("soldier_rig",Rig.of(Rig.find_skeleton(human)));model.set_meta("soldier_old_rig",old_rig)
	model.set_meta("soldier_hips",source.find_bone("hips" if old_rig else "body"))
	follow_soldier(model)
	return true

## Kannab sõduri luustiku hetkeasendi inimesele. Kutsu igal kaadril lähedal olevatele sõduritele.
static func follow_soldier(model: Node3D) -> void:
	var source: Skeleton3D=model.get_meta("soldier_source")
	var rig: Variant=model.get_meta("soldier_rig")
	if not is_instance_valid(source) or rig==null:return
	var map: Dictionary=model.get_meta("soldier_map")
	var delta: Dictionary={}
	for canon in map:
		var i: int=map[canon]
		delta[canon]=source.get_bone_global_pose(i).basis.get_rotation_quaternion() if i>=0 else Quaternion.IDENTITY
	var hi: int=model.get_meta("soldier_hips")
	var p:=source.get_bone_global_pose(hi).origin if hi>=0 else Vector3.ZERO
	var offset:=(p-Vector3(0,Rig.REFERENCE_HIP_HEIGHT,0)) if bool(model.get_meta("soldier_old_rig")) else (p-Vector3(0,SOLDIER_STAND_HEIGHT,0))*(Rig.REFERENCE_HIP_HEIGHT/SOLDIER_STAND_HEIGHT)
	rig.apply_global(delta,offset)

## Kindlate esemetega inimene (proovipildid, kujundaja).
static func create_with_items(body: String,ids: Array,seed:=0,team:=-1) -> Node3D:
	var root:=create(body,0,"",seed,team)
	root.set_meta("human_items",ids);dress(root,0,"")
	return root

static func is_dressed_soldier(model: Node) -> bool:
	return model!=null and model.has_meta("soldier_human")
