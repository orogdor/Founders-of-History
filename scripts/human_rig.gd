extends RefCounted
## Sobitab mängu senise 17 luuga inimese liigutused ja varustuse suvalisele
## inimluustikule (MPFB2/MakeHuman, Godoti humanoidprofiil, Mixamo jne).
##
## Vana luustik (human_far.glb) on mudeli ruumis ilma pöördeta puhkeasendis,
## käed rippu. HumanMotion annab iga luu kohaliku pöörde selle luustiku jaoks.
## Siin arvutatakse nendest iga luu soovitud maailmasuund ja kantakse see uue
## luustiku puhkeasendile, sh A- või T-asendis käte pööramine alla.

const CANONICAL:=["hips","spine","chest","neck","head","upperArm_L","forearm_L","hand_L","upperArm_R","forearm_R","hand_R","thigh_L","shin_L","foot_L","thigh_R","shin_R","foot_R"]
const PARENT:={"spine":"hips","chest":"spine","neck":"chest","head":"neck","upperArm_L":"chest","forearm_L":"upperArm_L","hand_L":"forearm_L","upperArm_R":"chest","forearm_R":"upperArm_R","hand_R":"forearm_R","thigh_L":"hips","shin_L":"thigh_L","foot_L":"shin_L","thigh_R":"hips","shin_R":"thigh_R","foot_R":"shin_R"}
## Luu suund vanas mudelis (lapse asukoht vanema suhtes, human_far.glb).
const CHILD:={"hips":"spine","spine":"chest","chest":"neck","neck":"head","upperArm_L":"forearm_L","forearm_L":"hand_L","upperArm_R":"forearm_R","forearm_R":"hand_R","thigh_L":"shin_L","shin_L":"foot_L","thigh_R":"shin_R","shin_R":"foot_R"}
const REFERENCE_DIR:={"hips":Vector3(0,1,0),"spine":Vector3(0,1,0),"chest":Vector3(0,1,0),"neck":Vector3(0,0.05,0.01),"upperArm_L":Vector3(0.04,-0.18,0),"forearm_L":Vector3(0.023,-0.15,0),"upperArm_R":Vector3(-0.04,-0.18,0),"forearm_R":Vector3(-0.023,-0.15,0),"thigh_L":Vector3(0.01,-0.2,0),"shin_L":Vector3(0.005,-0.215,0),"thigh_R":Vector3(-0.01,-0.2,0),"shin_R":Vector3(-0.005,-0.215,0)}
const REFERENCE_HIP_HEIGHT:=0.5
## Tuntud luunimed eri tööriistadest. Võrdlus on tõstutundetu.
const ALIASES:={
	"hips":["hips","pelvis","mixamorig:hips","root_hips","spine05"],
	"spine":["spine","spine_01","spine01","spine04","mixamorig:spine","lowerback"],
	"chest":["chest","upperchest","spine_03","spine_02","spine02","spine03","mixamorig:spine2","mixamorig:spine1"],
	"neck":["neck","neck_01","neck01","mixamorig:neck"],
	"head":["head","mixamorig:head"],
	"upperArm_L":["upperarm_l","leftupperarm","upperarm01.l","upperarm01_l","upper_arm.l","upper_arm_l","mixamorig:leftarm","l_upperarm"],
	"forearm_L":["forearm_l","lowerarm_l","leftlowerarm","lowerarm01.l","lowerarm01_l","forearm.l","mixamorig:leftforearm","l_forearm"],
	"hand_L":["hand_l","lefthand","wrist.l","wrist_l","hand.l","mixamorig:lefthand","l_hand"],
	"upperArm_R":["upperarm_r","rightupperarm","upperarm01.r","upperarm01_r","upper_arm.r","upper_arm_r","mixamorig:rightarm","r_upperarm"],
	"forearm_R":["forearm_r","lowerarm_r","rightlowerarm","lowerarm01.r","lowerarm01_r","forearm.r","mixamorig:rightforearm","r_forearm"],
	"hand_R":["hand_r","righthand","wrist.r","wrist_r","hand.r","mixamorig:righthand","r_hand"],
	"thigh_L":["thigh_l","leftupperleg","upperleg01.l","upperleg01_l","thigh.l","mixamorig:leftupleg","l_thigh"],
	"shin_L":["shin_l","calf_l","leftlowerleg","lowerleg01.l","lowerleg01_l","shin.l","mixamorig:leftleg","l_calf"],
	"foot_L":["foot_l","leftfoot","foot.l","mixamorig:leftfoot","l_foot"],
	"thigh_R":["thigh_r","rightupperleg","upperleg01.r","upperleg01_r","thigh.r","mixamorig:rightupleg","r_thigh"],
	"shin_R":["shin_r","calf_r","rightlowerleg","lowerleg01.r","lowerleg01_r","shin.r","mixamorig:rightleg","r_calf"],
	"foot_R":["foot_r","rightfoot","foot.r","mixamorig:rightfoot","r_foot"],
}

var skeleton: Skeleton3D
var index: Dictionary={}        # kanooniline nimi -> luu indeks
var rest_global: Dictionary={}  # indeks -> Quaternion (luustiku ruumis)
var calibration: Dictionary={}  # kanooniline -> Quaternion (luustiku ruumis)
var between: Dictionary={}      # kanooniline -> Quaternion: vahepealsete luude puhkepööre
var anchor: Dictionary={}       # kanooniline -> lähim kaardistatud eellane või ""
var top_parent: Dictionary={}   # kanooniline -> eellaste puhkepööre, kui kaardistatud eellast pole
var space: Quaternion=Quaternion.IDENTITY   # mudeli ruum -> luustiku ruum
var unit_scale:=1.0             # luustiku ühik mudeli ühikutes
var hip_ratio:=1.0
var hip_parent_rest:=Quaternion.IDENTITY

static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:return node
	for child in node.get_children():
		var result:=find_skeleton(child)
		if result!=null:return result
	return null

## Tagastab luustiku sobituse või null, kui luustik on vana mängumudel või ei sobi.
static func build(target: Skeleton3D,model_root: Node,overrides: Dictionary={}) -> Variant:
	if target==null:return null
	var rig=load("res://scripts/human_rig.gd").new()
	if not rig._map(target,overrides):return null
	rig._measure(model_root)
	target.set_meta("human_rig",rig)
	return rig

static func of(target: Skeleton3D) -> Variant:
	return target.get_meta("human_rig") if target!=null and target.has_meta("human_rig") else null

func _map(target: Skeleton3D,overrides: Dictionary) -> bool:
	skeleton=target
	var lower: Dictionary={}
	for i in skeleton.get_bone_count():lower[skeleton.get_bone_name(i).to_lower()]=i
	for name in CANONICAL:
		var found:=-1
		if overrides.has(name):found=skeleton.find_bone(str(overrides[name]))
		if found<0:
			for alias in ALIASES[name]:
				if lower.has(alias):found=int(lower[alias]);break
		if found>=0:index[name]=found
	for required in ["hips","chest","head","upperArm_L","forearm_L","hand_L","upperArm_R","forearm_R","hand_R","thigh_L","shin_L","thigh_R","shin_R"]:
		if not index.has(required):
			push_warning("HumanRig: luustikus puudub luu '%s'" % required);return false
	return true

func _global_rest(bone: int) -> Transform3D:
	var t:=Transform3D.IDENTITY
	while bone>=0:
		t=skeleton.get_bone_rest(bone)*t;bone=skeleton.get_bone_parent(bone)
	return t

func _measure(model_root: Node) -> void:
	# Luustiku sõlme asend mudeli juure suhtes (sõlmed ei pruugi veel puus olla).
	var t:=Transform3D.IDENTITY;var node: Node=skeleton
	while node!=null and node!=model_root:
		if node is Node3D:t=(node as Node3D).transform*t
		node=node.get_parent()
	space=t.basis.get_rotation_quaternion().inverse()
	unit_scale=maxf(0.0001,t.basis.get_scale().y)
	var mapped_by_index: Dictionary={}
	for name in index:mapped_by_index[int(index[name])]=name
	for name in index:
		var bone: int=index[name]
		rest_global[bone]=_global_rest(bone).basis.get_rotation_quaternion()
		# Lähim kaardistatud eellane ja vahepealsete luude pööre.
		var q:=Quaternion.IDENTITY;var p:=skeleton.get_bone_parent(bone)
		while p>=0 and not mapped_by_index.has(p):
			q=skeleton.get_bone_rest(p).basis.get_rotation_quaternion()*q;p=skeleton.get_bone_parent(p)
		anchor[name]=mapped_by_index.get(p,"")
		if p>=0:between[name]=q
		else:top_parent[name]=q
	for name in CANONICAL:
		if not index.has(name):continue
		var child: String=CHILD.get(name,"")
		if child!="" and index.has(child):
			var rest_dir:Vector3=_global_rest(index[child]).origin-_global_rest(index[name]).origin
			var wanted_dir:Vector3=space*Vector3(REFERENCE_DIR[name]).normalized()
			calibration[name]=_arc(rest_dir.normalized(),wanted_dir) if rest_dir.length()>0.00001 else Quaternion.IDENTITY
		else:
			calibration[name]=calibration.get(PARENT.get(name,""),Quaternion.IDENTITY)
	var hips: int=index["hips"]
	var hip_height:=(space.inverse()*_global_rest(hips).origin).y*unit_scale
	hip_ratio=hip_height/REFERENCE_HIP_HEIGHT if hip_height>0.01 else 1.0
	var hp:=skeleton.get_bone_parent(hips)
	hip_parent_rest=_global_rest(hp).basis.get_rotation_quaternion() if hp>=0 else Quaternion.IDENTITY

static func _arc(a: Vector3,b: Vector3) -> Quaternion:
	var d:=clampf(a.dot(b),-1,1)
	if d>0.99999:return Quaternion.IDENTITY
	if d<-0.99999:
		var axis:=a.cross(Vector3.RIGHT)
		if axis.length()<0.001:axis=a.cross(Vector3.UP)
		return Quaternion(axis.normalized(),PI)
	return Quaternion(a.cross(b).normalized(),acos(d))

## Rakendab HumanMotion.calculate() tulemuse.
func apply_pose(result: Dictionary) -> void:
	var poses: Dictionary=result.poses
	var delta: Dictionary={}   # vana mudeli ruumis maailmapööre
	for name in CANONICAL:
		var local: Quaternion=Basis.from_euler(poses.get(name,Vector3.ZERO),EULER_ORDER_XYZ).get_rotation_quaternion()
		var parent: String=PARENT.get(name,"")
		delta[name]=(delta[parent]*local) if parent!="" else local
	var target: Dictionary={}
	var inv_space:=space.inverse()
	for name in CANONICAL:
		if not index.has(name):continue
		var bone: int=index[name]
		# Puuduva luu korral (nt kael) kasuta lähima vanema liigutust.
		var d: Quaternion=delta[name]
		target[name]=(space*d*inv_space)*Quaternion(calibration[name])*Quaternion(rest_global[bone])
		var parent_global: Quaternion
		var a: String=anchor[name]
		parent_global=(Quaternion(target[a])*Quaternion(between[name])) if a!="" else Quaternion(top_parent[name])
		skeleton.set_bone_pose_rotation(bone,(parent_global.inverse()*Quaternion(target[name])).normalized())
	var hips: int=index["hips"]
	var offset:=(float(result.get("hip_y",REFERENCE_HIP_HEIGHT))-REFERENCE_HIP_HEIGHT)*hip_ratio/unit_scale
	var local_offset:=hip_parent_rest.inverse()*(space*Vector3(0,offset,0))
	skeleton.set_bone_pose_position(hips,skeleton.get_bone_rest(hips).origin+local_offset)

## Tegelik luunimi vana nime järgi (nt "hand_R" -> "hand_r").
func bone_name(canonical: String) -> String:
	return skeleton.get_bone_name(index[canonical]) if index.has(canonical) else canonical

## Sõlm luu kinnituse alla, mille sees vanale mudelile tehtud ese istub õigesti.
func prop_frame(canonical: String) -> Node3D:
	var frame:=Node3D.new();frame.name="PropFrame"
	if index.has(canonical):
		var q:=(Quaternion(calibration[canonical])*Quaternion(rest_global[index[canonical]])).inverse()*space
		frame.basis=Basis(q).scaled(Vector3.ONE/unit_scale)
	return frame
