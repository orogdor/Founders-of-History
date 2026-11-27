extends "res://scripts/bronze_age_map_mesh.gd"

# Compact thatched buildings for the settlement map. Dimensions are in metres.
func dwelling(kind: String, material: Material) -> Mesh:
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	if kind=="peamaja":
		var outline:=rect(Vector2.ZERO,6.4,3.9)
		prism(expand(outline,0.10),0,0.30,STONE,0)
		prism(outline,0.26,1.65,Color("997453"),0)
		for x in [-2.95,-1.50,0.0,1.50,2.95]:
			post(Vector2(x,1.98),0.25,1.51,0.15)
			post(Vector2(x,-1.98),0.25,1.51,0.15)
		for layer in 4:
			var t:=layer/4.0
			var z:=2.23*(1.0-t)
			var y:=1.58+1.69*t
			var end:=3.55-0.21*t
			var upper_z:=maxf(0.0,z-2.23/4.0)
			for side:float in [-1.0,1.0]:
				var outside:=Vector3(0,0,side)
				panel(Vector3(-end,y-0.09,side*(z+0.06)),Vector3(end,y-0.09,side*(z+0.06)),Vector3(end,y,side*(z+0.06)),Vector3(-end,y,side*(z+0.06)),outside,Color("745433"),1)
				panel(Vector3(-end,y,side*(z+0.06)),Vector3(end,y,side*(z+0.06)),Vector3(end-0.05,y+0.48,side*upper_z),Vector3(-end+0.05,y+0.48,side*upper_z),Vector3(0,1,side),Color("987447").lightened(layer*0.030),1)
		for x:float in [-3.21,3.21]:
			face(Vector3(x,1.63,-2.03),Vector3(x,1.63,2.03),Vector3(x,3.22,0),Vector3(signf(x),0,0),WOOD,2)
		rail(Vector2(-3.46,0),Vector2(3.46,0),0.21,3.22,0.13,WOOD)
		entrance(1.99)
	else:
		var radius:=1.98 if kind=="hunter" else 2.30
		var height:=2.08 if kind=="hunter" else 2.45
		round_taper(Vector2.ZERO,0,0.30,radius+0.07,radius+0.04,STONE,0)
		round_taper(Vector2.ZERO,0.28,1.05,radius,radius*0.985,Color("9c7854"),0)
		for i in 12:
			post(Vector2.from_angle(TAU*i/12.0)*radius*0.98,0.22,1.17,0.12)
		for layer in 5:
			var t:=layer/5.0
			var rim:=(1.0-t)*(radius+0.28)+0.16*sin(t*PI)
			var next:=(layer+1)/5.0
			var upper:=(1.0-next)*(radius+0.28)+0.16*sin(next*PI)
			for i in 16:
				var a:=Vector2.from_angle(TAU*i/16.0)
				var b:=Vector2.from_angle(TAU*(i+1)/16.0)
				var lo:=1.16+height*t
				var hi:=lo+height/5.0+0.04
				var shade:=Color("967447").lightened(layer*0.025).darkened(0.018*posmod(i*7+layer,5))
				var lip:=rim+0.07
				var fringe_a:=0.07+0.035*sin(i*5.2+layer)
				var fringe_b:=0.07+0.035*sin(((i+1)%16)*5.2+layer)
				panel(v(a*lip,lo-fringe_a),v(b*lip,lo-fringe_b),v(b*lip,lo),v(a*lip,lo),v(a+b,0),Color("715635"),1)
				panel(v(a*(rim+0.07),lo),v(b*(rim+0.07),lo),v(b*upper,hi),v(a*upper,hi),v(a+b,0.8),shade,1)
		entrance(radius)
		if kind=="hunter":
			var left:=Vector2(2.0,1.35);var right:=Vector2(3.35,1.35)
			post(left,0,1.10,0.13);post(right,0,1.10,0.13)
			rail(left,right,0.11,1.05,0.10,WOOD)
			prism(rect(left.lerp(right,0.50),0.71,0.095),0.40,1.08,Color("b48b64"),0)
	tool.index()
	return tool.commit()

func entrance(z: float) -> void:
	prism(rect(Vector2(0,z+0.015),0.94,0.18),0.05,1.43,Color("382b20"),2)
	for x:float in [-0.58,0.58]:
		post(Vector2(x,z+0.50),0.0,1.47,0.16)
	rail(Vector2(-0.70,z+0.51),Vector2(0.70,z+0.51),0.14,1.39,0.15,WOOD)
	panel(Vector3(-0.82,1.48,z+0.68),Vector3(0.82,1.48,z+0.68),Vector3(0.82,1.89,z-0.55),Vector3(-0.82,1.89,z-0.55),Vector3.UP,Color("a28158"),1)
