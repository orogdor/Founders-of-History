extends RefCounted
## Multi-arch masonry crossing. The editor model and river crossing share the deck.
const MeshParts = preload("res://scripts/bronze_home_structure.gd")
const Finishes = preload("res://scripts/iron_age_materials.gd")

static func create_span(length_m: float, width_m: float, rise_m: float, variation := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "IronArchBridge"
	var stone := MeshParts.surface(Finishes.get_finish("stone",variation))
	var bricks := MeshParts.surface(Finishes.get_finish("brick",variation))
	var caps := MeshParts.surface(Finishes.get_finish("lime",variation))
	var unit := clampf(width_m / 4.8,0.22,1.25)
	var bays := maxi(1,roundi(length_m / (9.4 * unit)))
	var bay := length_m / bays
	var half_w := width_m * 0.5
	var radius := bay * 0.425
	var crown := clampf(bay * 0.24, 1.1 * unit, 2.55 * unit)
	var depth := 0.24 * unit
	var road := func(x: float) -> float:
		return 0.20 * unit + rise_m * (1.0 - pow(clampf(x/(length_m*0.5),-1,1),2.0))
	for n in bays:
		var mid := (n + 0.5) * bay - length_m * 0.5
		var spring := float(road.call(mid)) - crown - 0.44 * unit
		var segments := 13
		for i in segments:
			var p := PI * float(i) / segments
			var q := PI * float(i+1) / segments
			var a := Vector2(mid-radius*cos(p),spring+crown*sin(p))
			var b := Vector2(mid-radius*cos(q),spring+crown*sin(q))
			var a_top := Vector2(a.x,road.call(a.x))
			var b_top := Vector2(b.x,road.call(b.x))
			MeshParts.quad(stone,Vector3(a.x,a.y,-half_w),Vector3(b.x,b.y,-half_w),Vector3(b.x,b.y,half_w),Vector3(a.x,a.y,half_w),Vector3(b.y-a.y,a.x-b.x,0).normalized())
			MeshParts.quad(stone,Vector3(a.x,a_top.y,-half_w),Vector3(b.x,b_top.y,-half_w),Vector3(b.x,b_top.y,half_w),Vector3(a.x,a_top.y,half_w),Vector3.UP)
			for side: float in [-1.0,1.0]:
				var z := side * half_w
				MeshParts.quad(stone, Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(b.x,b_top.y,z),Vector3(a.x,a_top.y,z),Vector3.BACK*side)
				# Slight clearance between voussoirs exposes the mortar line.
				var t := p+0.006
				var u := q-0.006
				var vz := z + side * unit * 0.065
				var key := 0.29 * unit if i == segments/2 else 0.22 * unit
				var face := caps if i == segments/2 else bricks
				MeshParts.quad(face, arch_point(mid,spring,radius,crown,t,vz),arch_point(mid,spring,radius,crown,u,vz),
					arch_point(mid,spring,radius+key,crown+key,u,vz),arch_point(mid,spring,radius+key,crown+key,t,vz),Vector3.BACK*side)
	# Piers close the intervals between arches; cutwaters split the flow at each footing.
	for n in range(bays+1):
		var x := -length_m*0.5 + n * bay
		var pier_width := bay - radius * 2.0
		var deck_y := float(road.call(x))
		var base_y := deck_y - crown - unit*2.5
		var w := pier_width if n>0 and n<bays else pier_width*0.5
		var cx := x + (w*0.5 if n==0 else -w*0.5 if n==bays else 0.0)
		MeshParts.bar(stone,Vector3(cx,(deck_y+base_y)*0.5,0),Vector3.RIGHT,Vector3.BACK,w+0.012*unit,deck_y-base_y,width_m)
		if n>0 and n<bays:
			for side: float in [-1.0,1.0]:
				var crest := deck_y - 0.74 * unit
				var a := Vector3(x-w*0.5,crest,side*half_w)
				var b := Vector3(x+w*0.5,crest,side*half_w)
				var c := Vector3(x,crest-0.45*unit,side*(half_w+0.57*w))
				var low := Vector3.UP*(base_y-crest)
				MeshParts.triangle(caps,a,b,c,Vector3.UP)
				MeshParts.quad(stone,a,c,c+low,a+low,Vector3(-1,0,side))
				MeshParts.quad(stone,b,c,c+low,b+low,Vector3(1,0,side))
	var sections := maxi(8,ceili(length_m / (0.95 * unit)))
	for i in sections:
		var step := length_m / sections
		var x := (i+0.5) * step-length_m*0.5
		var top := float(road.call(x))
		var angle := atan((float(road.call(x+step*0.5))-float(road.call(x-step*0.5)))/step)
		for side: float in [-1.0,1.0]:
			var z := side*(half_w-depth*0.5)
			MeshParts.bar(stone,Vector3(x,top+unit*0.33,z),Vector3(cos(angle),sin(angle),0),Vector3.BACK,step*1.002,unit*0.66,depth)
			MeshParts.bar(caps,Vector3(x,top+unit*0.715,z),Vector3(cos(angle),sin(angle),0),Vector3.BACK,step*0.984,unit*0.11,depth+unit*0.10)
	MeshParts.finish(root,stone,"AshlarPiersAndVaults")
	MeshParts.finish(root,bricks,"BrickArchRings")
	MeshParts.finish(root,caps,"CopingAndKeystones")
	return root

static func arch_point(mid: float, spring: float, rx: float, ry: float, angle: float, z: float) -> Vector3:
	return Vector3(mid - rx*cos(angle),spring+ry*sin(angle),z)

