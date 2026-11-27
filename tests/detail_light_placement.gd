extends SceneTree

const Lights=preload("res://scripts/detail_lights.gd")

func _initialize() -> void:
	var house:={"type":"house","hp":60,"x":13.0,"z":-4.0,"ready":true,"buildingRotationV228":0.0}
	var hunter:={"type":"hunter","hp":45,"x":-9.0,"z":8.0,"ready":true}
	var latest:=house.duplicate()
	latest.buildingRotationV228=0.83
	var original:=Lights.locations([house],true,0)
	var turned:=Lights.locations([latest],true,0)
	assert(original.size()==1 and turned.size()==1)
	var center:=Vector2(house.x,house.z)
	var first:=Vector2(original[0].x,original[0].z)-center
	var rotated:=Vector2(turned[0].x,turned[0].z)-center
	assert(rotated.is_equal_approx(first.rotated(-0.83)),"Torch must follow the doorway when a hut rotates")
	var unfinished:=hunter.duplicate()
	unfinished.ready=false
	unfinished.x-=18.0
	var destroyed:=hunter.duplicate()
	destroyed.hp=0
	destroyed.x-=31.0
	var local:=Lights.locations([house,hunter,house.duplicate(),unfinished,destroyed],true,0)
	assert(local.size()==2,"Each eligible entrance should receive one torch")
	assert(local[0].kind=="house" and local[1].kind=="hunter")
	print("DETAIL_LIGHT_PLACEMENT_OK")
	quit()
