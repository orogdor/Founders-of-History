extends RefCounted
## Liigutusteek uutele inimestele: Quaternius Universal Animation Library 1 ja 2 (CC0),
## üle kantud iga keha (mees, naine, poiss, tüdruk) luustikule skriptiga tools/retarget_ual.py.
## Fail: res://assets/people/animations/<keha>.glb. HumanMotion.apply valib siit mängu tegevusele klipi.

static var libraries: Dictionary={}
## Klipid, mis mängivad ühe korra (ülejäänud korduvad).
const ONCE:=["death","sit_down","sit_up","get_up","hit","hit_back"]
## Mängu tegevus -> klipp (seistes). Mitu valikut: inimene saab oma seemne järgi ühe.
const WORK:={
	"chop":["chop"],"forge":["chop"],"saw":["chop"],"mill":["chop"],"mine":["chop"],
	"build":["fix_kneel","interact"],"work":["interact"],
	"gather":["harvest"],"plant":["plant"],"farm":["plant","harvest"],"water":["water"],
	"fishing":["hold_up"],"hunt":["throw"],"study":["talk"],"herd":["hold_up"],
	"sit":["crouch"],"eat":["eat"],"play":["dance"],"guard":["idle_arms"],"talk":["talk"],"dig":["harvest"],
	"train":["sword_a","sword_b","sword_c","sword_attack"],"carry":["idle"],"stalk":["crouch"],
}
const IDLE:=["idle","idle","idle","idle_arms","idle","idle_arms","idle_no"]
const BLEND:=0.3

static func library(body: String,prepared: PackedScene=null) -> AnimationLibrary:
	if libraries.has(body):return libraries[body]
	var lib: AnimationLibrary=null
	var path:="res://assets/people/animations/%s.glb" % body
	var source:=prepared
	if source==null and ResourceLoader.exists(path):source=load(path) as PackedScene
	if source!=null:
		var scene:=source.instantiate()
		var player: AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
		if player!=null and player.has_animation_library(""):
			lib=player.get_animation_library("")
			for name in lib.get_animation_list():
				lib.get_animation(name).loop_mode=Animation.LOOP_NONE if name in ONCE else Animation.LOOP_LINEAR
		scene.free()
	libraries[body]=lib
	return lib

## Lisab kehale AnimationPlayeri (aega juhib HumanMotion mänguaja järgi). Tagastab null, kui teeki pole.
static func attach(model: Node3D,body: String) -> AnimationPlayer:
	var lib:=library(body)
	if lib==null:return null
	var player:=AnimationPlayer.new();player.name="Clips"
	model.add_child(player)
	player.add_animation_library("",lib)
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return player

static func pick(list: Array,seed: int) -> String:
	return str(list[absi(seed)%list.size()])

## Klipp tegevuse järgi.
static func clip_for(moving: bool,action: String,seed: int,child: bool) -> String:
	if moving:
		if action=="carry":return "walk_carry"
		if action=="stalk":return "sneak"
		if action=="play" or (child and seed%3==0):return "jog"
		return "walk"
	if action.is_empty():return pick(IDLE,seed)
	return pick(WORK.get(action,["interact"]),seed)
