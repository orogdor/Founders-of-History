extends SceneTree
## Käivita: godot --headless --path . -s tests/human_outfits.gd
const Humans=preload("res://scripts/human_factory.gd")
const Rig=preload("res://scripts/human_rig.gd")
const Motion=preload("res://scripts/human_motion.gd")

func _initialize():
	var cfg:=Humans.config()
	var items: Dictionary=cfg.items
	var eras: Array=cfg.eras
	assert(eras.size()==7,"Igal seitsmel ajastul peab olema riidekomplekt")
	for era in eras.size():
		var man:=Humans.outfit_items("man",era,"",3)
		var woman:=Humans.outfit_items("woman",era,"",3)
		assert(not man.is_empty() and not woman.is_empty(),"Ajastu %d komplekt puudub" % era)
		assert(man!=woman,"Mehe ja naise riided peavad erinema (ajastu %d)" % era)
		for id in man+woman:assert(items.has(id),"Tundmatu ese "+str(id))
		var slots: Dictionary={}
		for id in woman:
			assert(not slots.has(items[id].slot),"Kaks eset samas kohas: "+str(id));slots[items[id].slot]=true
		for id in Humans.outfit_items("girl",era,"",3):assert(str(items[id].slot)!="jewelry","Lapsel ei ole ehteid")
	assert(Humans.outfit_items("man",1,"",5)==Humans.outfit_items("man",1,"",5),"Sama inimene peab saama samad riided")
	assert("stone_fur_hood" in Humans.outfit_items("man",0,"hunter",1),"Kütil on kiviajal kapuuts")
	# Varumudel töötab, kuni MPFB2 kehasid pole.
	var person:=Humans.create("woman",0,"lumber",1)
	assert(Rig.find_skeleton(person)!=null,"Inimesel peab olema luustik")
	Humans.equip_job(person,"lumber",0)
	assert(Humans.tool_visible(person,0) and not Humans.tool_visible(person,3),"Tööriist kuulub ajastusse")
	Humans.set_era(person,2);assert(int(person.get_meta("human_era"))==2)
	person.free()
	check_t_pose_rig()
	print("HUMAN_OUTFITS_OK")
	quit()

## MPFB2-laadne T-asendis luustik: nullpoosis peavad käed rippuma alla.
func check_t_pose_rig():
	var root:=Node3D.new();var skeleton:=Skeleton3D.new();root.add_child(skeleton)
	var spec:=[["Root","",Vector3.ZERO],["pelvis","Root",Vector3(0,0.95,0)],["spine_01","pelvis",Vector3(0,0.1,0)],["spine_03","spine_01",Vector3(0,0.3,0)],["neck_01","spine_03",Vector3(0,0.15,0)],["head","neck_01",Vector3(0,0.1,0)],
		["upperarm_l","spine_03",Vector3(0.17,0.12,0)],["lowerarm_l","upperarm_l",Vector3(0.28,0,0)],["hand_l","lowerarm_l",Vector3(0.25,0,0)],
		["upperarm_r","spine_03",Vector3(-0.17,0.12,0)],["lowerarm_r","upperarm_r",Vector3(-0.28,0,0)],["hand_r","lowerarm_r",Vector3(-0.25,0,0)],
		["thigh_l","pelvis",Vector3(0.1,-0.02,0)],["calf_l","thigh_l",Vector3(0,-0.43,0)],["foot_l","calf_l",Vector3(0,-0.42,0)],
		["thigh_r","pelvis",Vector3(-0.1,-0.02,0)],["calf_r","thigh_r",Vector3(0,-0.43,0)],["foot_r","calf_r",Vector3(0,-0.42,0)]]
	for bone in spec:
		var i:=skeleton.add_bone(bone[0])
		if bone[1]!="":skeleton.set_bone_parent(i,skeleton.find_bone(bone[1]))
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,bone[2]));skeleton.reset_bone_pose(i)
	var rig: Variant=Rig.build(skeleton,root)
	assert(rig!=null,"T-asendi luustik peab sobima")
	var motion:=Motion.new();motion.apply(root,0.0,false,"")
	var arm:=skeleton.get_bone_global_pose(skeleton.find_bone("lowerarm_l")).origin-skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_l")).origin
	assert(arm.normalized().y<-0.9,"Käsi peab rippuma alla, mitte olema T-asendis")
	root.free()
