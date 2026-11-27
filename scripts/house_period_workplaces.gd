extends RefCounted
## Stage-specific objects are real model components and can be moved in the
## designer. Their proportions are compact enough for the existing floor plans.
const Forms=preload("res://scripts/house_period_props.gd")
const Freight=preload("res://scripts/period_freight_visuals.gd")

static func build(model: Node3D, kind: String, at: Vector3) -> bool:
	match kind:
		"claySite":
			if model.design_period==0 and model.saved_palette==0:
				return false
			clay_cut(model,at)
		"aegeanAmphoraRack":
			rack(model,at,"aegeanRed",1.55,0.96)
			for row in 2:
				for column in 3:
					var jar:=amphora(model,at+Vector3(-0.53+column*0.52,0.18+row*0.44,0),"aegeanPottery")
					jar.rotation.y=0.35*column
		"romanTaberna":
			Forms.box(model,at+Vector3.UP*0.30,Vector3(1.67,0.60,0.54),"romanBrick")
			Forms.box(model,at+Vector3.UP*0.64,Vector3(1.75,0.13,0.68),"romanTravertine")
			Forms.box(model,at+Vector3(0,0.37,0.29),Vector3(1.46,0.27,0.045),"romanRed")
			for column in 3:
				var recess:=at+Vector3(-0.51+column*0.51,0.66,0.042)
				Forms.cylinder(model,recess,0.055,0.15,0.15,"romanRed")
				Forms.cylinder(model,recess+Vector3.UP*0.055,0.035,0.105,0.105,"counterInset")
			amphora(model,at+Vector3(0.91,0,0.13),"aegeanPottery")
			amphora(model,at+Vector3(1.12,0,0.15),"romanRed")
		"norseHearth":
			Forms.box(model,at+Vector3.UP*0.035,Vector3(1.65,0.055,0.57),"sootBrick")
			for lengthwise in 7:
				for side in [-1.0,1.0]:
					var at_stone:=at+Vector3(-0.78+lengthwise*0.26,0.075,float(side)*0.335)
					var stone:=Forms.box(model,at_stone,Vector3(0.26,0.15,0.18),"medievalMasonry")
					stone.rotation.y=sin(lengthwise*7.1+side)*0.13
			for i in 4:
				var log_node:=Forms.box(model,at+Vector3(-0.52+i*0.35,0.10,0),Vector3(0.26,0.075,0.45),"norseTimber")
				log_node.rotation.y=cos(i*4.5)*0.28
				Forms.box(model,at+Vector3(-0.47+i*0.31,0.102,0.17*sin(i*0.9)),Vector3(0.14,0.045,0.12),"glowingCoal")
		"norseSleepingBench":
			for x in [-0.56,0.56]:
				for z in [-0.25,0.25]:
					Forms.box(model,at+Vector3(x,0.16,z),Vector3(0.11,0.34,0.14),"norseTimber")
			Forms.box(model,at+Vector3.UP*0.32,Vector3(1.36,0.13,0.67),"norseTimber")
			Forms.box(model,at+Vector3.UP*0.405,Vector3(1.27,0.065,0.58),"khakiCanvas")
			Forms.box(model,at+Vector3(-0.39,0.452,0.01),Vector3(0.41,0.051,0.57),"aegeanRed")
			for stripe in 3:
				Forms.box(model,at+Vector3(-0.53+stripe*0.13,0.48,0.01),Vector3(0.026,0.009,0.575),"khakiCanvas")
		"norseLoom":
			for x in [-0.49,0.49]:
				Forms.beam(model,at+Vector3(x,0,0.25),at+Vector3(x,1.49,-0.18),0.076,"norseTimber")
			Forms.beam(model,at+Vector3(-0.55,1.43,-0.15),at+Vector3(0.55,1.43,-0.15),0.088,"norseTimber")
			Forms.box(model,at+Vector3(0,1.05,-0.121),Vector3(0.80,0.57,0.035),"aegeanRed")
			for stripe in 4:
				Forms.box(model,at+Vector3(0,0.83+stripe*0.15,-0.096),Vector3(0.80,0.038,0.025),"khakiCanvas")
			for x in range(-4,5):
				var base:=at+Vector3(x*0.084,0.29,0.044)
				Forms.beam(model,base,base+Vector3(0,0.47,-0.147),0.012,"rope")
				Forms.cylinder(model,base,0.062,0.035,0.032,"medievalMasonry")
		"navalBales":
			for row in 2:
				for column in (3 if row==0 else 2):
					var p:=at+Vector3(-0.55+column*0.51+row*0.22,0.16+row*0.27,0)
					var bale:=Forms.box(model,p,Vector3(0.48,0.30,0.52),"khakiCanvas")
					bale.rotation.y=sin(row+column*1.9)*0.16
					for band in [-0.125,0.125]:
						var tie:=Forms.box(model,p+Vector3(band,0.015,0),Vector3(0.033,0.31,0.534),"rope")
						tie.rotation.y=bale.rotation.y
			Forms.cylinder(model,at+Vector3(1.04,0.24,0),0.50,0.21,0.16,"navalPlank")
		"factoryLathe":
			Forms.box(model,at+Vector3.UP*0.32,Vector3(1.62,0.62,0.53),"castIron")
			Forms.box(model,at+Vector3.UP*0.660,Vector3(1.70,0.14,0.63),"machineGreen")
			Forms.box(model,at+Vector3(-0.58,0.84,0),Vector3(0.42,0.34,0.57),"machineGreen")
			var drum:=Forms.cylinder(model,at+Vector3(-0.24,0.90,0),0.29,0.115,0.115,"metalTrim")
			drum.rotation.z=PI*0.50
			Forms.box(model,at+Vector3(0.41,0.80,0),Vector3(0.31,0.22,0.48),"castIron")
			Forms.beam(model,at+Vector3(-0.095,0.91,0),at+Vector3(0.39,0.91,0),0.074,"metalTrim")
			for side in [-1.0,1.0]:
				Forms.beam(model,at+Vector3(-0.74,0.718,side*0.24),at+Vector3(0.74,0.718,side*0.24),0.051,"metalTrim")
		"factorySwitchboard":
			Forms.box(model,at+Vector3.UP*0.62,Vector3(0.98,1.24,0.29),"machineGreen")
			Forms.box(model,at+Vector3(0,0.92,0.15),Vector3(0.76,0.43,0.044),"clockInk")
			for i in 4:
				var p:=at+Vector3(-0.28+i*0.19,0.99,0.181)
				var gauge:=Forms.cylinder(model,p,0.038,0.065,0.065,"clockFace")
				gauge.rotation.x=PI*0.50
				Forms.box(model,p+Vector3(0,-0.18,0.052),Vector3(0.042,0.091,0.047),"castIron")
		"factoryDrive":
			Forms.box(model,at+Vector3.UP*0.10,Vector3(0.74,0.20,0.62),"castIron")
			Forms.box(model,at+Vector3(-0.08,0.36,0),Vector3(0.47,0.32,0.47),"machineGreen")
			for height in [0.42,1.79]:
				var flywheel:=Forms.cylinder(model,at+Vector3(0.15,height,0),0.14,0.25,0.25,"castIron")
				flywheel.rotation.z=PI*0.5
				var collar:=Forms.cylinder(model,at+Vector3(0.235,height,0),0.10,0.11,0.11,"metalTrim")
				collar.rotation.z=PI*0.5
			for z in [-0.247,0.247]:
				Forms.box(model,at+Vector3(0.16,1.11,z),Vector3(0.10,1.37,0.041),"ironTrim")
			Forms.beam(model,at+Vector3(-0.30,1.79,0),at+Vector3(0.38,1.79,0),0.091,"metalTrim")
			Forms.beam(model,at+Vector3(-0.26,0.17,-0.15),at+Vector3(-0.26,2.17,-0.15),0.078,"castIron")
		"labStation":
			Forms.box(model,at+Vector3.UP*0.41,Vector3(1.67,0.74,0.57),"boardConcrete")
			Forms.box(model,at+Vector3.UP*0.80,Vector3(1.82,0.085,0.69),"darkCladding")
			for column in 3:
				var p:=at+Vector3(-0.55+column*0.53,0.43,0.304)
				Forms.box(model,p,Vector3(0.49,0.60,0.055),"labWhite")
				Forms.box(model,p+Vector3(0,0.20,0.045),Vector3(0.21,0.025,0.045),"metalTrim")
			Forms.box(model,at+Vector3(0.54,0.94,-0.065),Vector3(0.42,0.22,0.36),"labWhite")
			var screen:=Forms.box(model,at+Vector3(0.54,1.0,0.13),Vector3(0.29,0.11,0.043),"windowWater")
			screen.rotation.x=0.14
			for j in 3:
				Forms.cylinder(model,at+Vector3(-0.47+j*0.16,0.92,0.08),0.17+j*0.021,0.047,0.043,"windowGlass")
		"labCabinet":
			Forms.box(model,at+Vector3.UP*0.80,Vector3(1.26,1.60,0.48),"labWhite")
			Forms.box(model,at+Vector3(0,1.12,0.25),Vector3(1.13,0.77,0.06),"darkCladding")
			for column in [-1.0,1.0]:
				var p:=at+Vector3(column*0.283,1.13,0.284)
				Forms.box(model,p,Vector3(0.51,0.68,0.045),"windowGlass")
				Forms.box(model,p+Vector3(-column*0.188,-0.29,0.045),Vector3(0.043,0.11,0.035),"metalTrim")
				for tray in 2:
					Forms.box(model,p+Vector3(0,-0.61+tray*0.15,0),Vector3(0.52,0.124,0.043),"boardConcrete")
		"substation":
			substation(model,at)
		"processVessels":
			process_vessels(model,at)
		"siteShelter":
			site_shelter(model,at,model.design_period)
		"wheelLoader":
			wheel_loader(model,at)
		"loadingPallet":
			for slat in 5:
				Forms.box(model,at+Vector3(-0.39+slat*0.19,0.12,0),Vector3(0.14,0.12,0.89),"navalPlank")
			for x in [-0.36,0.0,0.36]:
				Forms.box(model,at+Vector3(x,0.048,0),Vector3(0.12,0.09,0.87),"navalPlank")
			for layer in 2:
				for index in (2 if layer==0 else 1):
					var bx: float=(-0.24+index*0.48) if layer==0 else 0.0
					Forms.box(model,at+Vector3(bx,0.36+layer*0.30,0.015),Vector3(0.43,0.31,0.52),"shippingBoard")
		"airfieldPlane":
			var root:=Node3D.new()
			model.add_child(root)
			root.position=at
			root.rotation.y=-PI*0.5
			root.scale=Vector3.ONE*2.14
			Freight.freight(root,"air",6,0)
		_:
			return false
	return true

static func clay_cut(model: Node3D,at: Vector3) -> void:
	var dry:=SurfaceTool.new()
	var wet:=SurfaceTool.new()
	for part in [dry,wet]:
		part.begin(Mesh.PRIMITIVE_TRIANGLES)
	dry.set_material(model.material_for("cutClay"))
	wet.set_material(model.material_for("dampClay"))
	for row in 12:
		for column in 22:
			var points: Array[Vector2]=[
				Vector2(column,row),Vector2(column+1,row),
				Vector2(column,row+1),Vector2(column+1,row+1),
			]
			var center:=Vector2((column+0.5)/22.0-0.5,(row+0.5)/12.0-0.5)
			var selected:=wet if center.length()<0.22 else dry
			for index in [0,1,3,0,3,2]:
				var uv:=points[index]/Vector2(22.0,12.0)
				var local:=(uv-Vector2(0.5,0.5))*Vector2(3.25,2.23)
				var radial:=Vector2(local.x/1.7,local.y/1.08).length()
				var rim:=smoothstep(0.25,0.73,radial)*(1.0-smoothstep(0.74,1.01,radial))
				var texture_jitter:=0.06*sin(local.x*12.3+local.y*3.4)*cos(local.y*9.7-local.x*4.4)
				var ridge:=rim*(0.24+0.11*cos(local.x*2.0-local.y*0.8))
				selected.set_uv(uv*2.1)
				selected.add_vertex(at+Vector3(local.x,0.035+ridge+texture_jitter*rim,local.y))
	for part in [dry,wet]:
		part.generate_normals()
		var cut:=MeshInstance3D.new()
		cut.name="ClayBank"
		cut.mesh=part.commit()
		model.add_child(cut)

static func substation(model: Node3D,at: Vector3) -> void:
	Forms.box(model,at+Vector3.UP*0.07,Vector3(2.18,0.14,1.58),"boardConcrete")
	for side in [-1.0,1.0]:
		var p:=at+Vector3(side*0.55,0.0,0)
		Forms.box(model,p+Vector3.UP*0.5,Vector3(0.72,0.82,0.93),"machineGreen")
		for blade in 5:
			Forms.box(model,p+Vector3(-0.26+blade*0.13,0.52,0.49),Vector3(0.047,0.63,0.18),"darkCladding")
		for index in 3:
			var cap:=p+Vector3(-0.22+index*0.22,0.98,-0.125)
			Forms.cylinder(model,cap,0.34,0.036,0.052,"metalTrim")
			for ring in 3:
				Forms.cylinder(model,cap+Vector3.UP*(ring*0.069-0.065),0.027,0.074,0.074,"labWhite")
		Forms.beam(model,p+Vector3(0.18,0.17,-0.60),p+Vector3(0.18,1.49,-0.60),0.072,"castIron")
	Forms.beam(model,at+Vector3(-0.55,1.42,-0.6),at+Vector3(0.84,1.42,-0.6),0.059,"metalTrim")

static func process_vessels(model: Node3D,at: Vector3) -> void:
	Forms.box(model,at+Vector3.UP*0.056,Vector3(2.01,0.112,1.52),"boardConcrete")
	for i in 2:
		var base:=at+Vector3(-0.53+i*0.82,0.11,0.14-i*0.17)
		var height:=2.20-float(i)*0.52
		Forms.cylinder(model,base+Vector3.UP*height/2.0,height,0.37,0.34,"metalTrim")
		for rung in 5:
			Forms.cylinder(model,base+Vector3.UP*(0.33+rung*height*0.14),0.075,0.393,0.393,"castIron")
		Forms.cylinder(model,base+Vector3.UP*(height+0.09),0.20,0.35,0.16,"metalTrim")
		Forms.beam(model,base+Vector3(0.37,0.30,-0.2),base+Vector3(0.37,height+0.17,-0.2),0.078,"maritimePaint")
	Forms.beam(model,at+Vector3(-0.16,0.63,-0.20),at+Vector3(0.65,0.63,-0.20),0.093,"maritimePaint")

static func site_shelter(model: Node3D,at: Vector3,age: int) -> void:
	var frame: String="metalTrim" if age>=6 else "castIron"
	for x in [-0.60,0.60]:
		for z in [-0.46,0.46]:
			var height:=1.28 if z<0.0 else 1.51
			var foot:=at+Vector3(x,0,z)
			Forms.box(model,foot+Vector3.UP*0.07,Vector3(0.18,0.14,0.18),"boardConcrete")
			Forms.beam(model,foot+Vector3.UP*0.13,foot+Vector3.UP*height,0.071,frame)
	var roof:=Forms.box(model,at+Vector3.UP*1.42,Vector3(1.54,0.087,1.16),"corrugation")
	roof.rotation.x=-0.246
	Forms.box(model,at+Vector3(0,0.69,-0.46),Vector3(1.21,1.15,0.043),"darkCladding" if age>=6 else "corrugation")

static func wheel_loader(model: Node3D,at: Vector3) -> void:
	Forms.box(model,at+Vector3(0,0.35,-0.14),Vector3(0.83,0.32,1.22),"castIron")
	Forms.box(model,at+Vector3(0,0.61,-0.51),Vector3(0.79,0.47,0.60),"machineYellow")
	Forms.box(model,at+Vector3(0,0.89,-0.12),Vector3(0.59,0.68,0.55),"metalTrim")
	Forms.box(model,at+Vector3(0,0.98,0.166),Vector3(0.46,0.46,0.02),"windowWater")
	Forms.box(model,at+Vector3(0,1.26,-0.12),Vector3(0.67,0.092,0.66),"machineYellow")
	for x in [-0.48,0.48]:
		for z in [-0.56,0.40]:
			var tire:=Forms.cylinder(model,at+Vector3(x,0.266,z),0.15,0.255,0.255,"darkRubber")
			tire.rotation.z=PI*0.5
			var axle:=Forms.cylinder(model,at+Vector3(x*1.10,0.266,z),0.13,0.12,0.12,"machineYellow")
			axle.rotation.z=PI*0.5
		var side:=signf(x)*0.36
		Forms.beam(model,at+Vector3(side,0.58,0.0),at+Vector3(side,0.33,0.79),0.082,"machineYellow")
	Forms.box(model,at+Vector3(0,0.11,0.96),Vector3(1.16,0.11,0.48),"castIron")
	Forms.box(model,at+Vector3(0,0.27,0.77),Vector3(1.16,0.34,0.11),"castIron")

static func rack(model:Node3D,at:Vector3,material: String,width:float,height:float) -> void:
	for x in [-width/2,width/2]:
		for z in [-0.19,0.19]:
			Forms.box(model,at+Vector3(x,height/2,z),Vector3(0.084,height,0.083),material)
	for row in 2:
		Forms.box(model,at+Vector3.UP*(0.15+row*0.44),Vector3(width+0.09,0.055,0.46),material)

static func amphora(model:Node3D,at:Vector3,material:String) -> Node3D:
	var base:=Forms.cylinder(model,at+Vector3.UP*0.083,0.175,0.098,0.134,material)
	var neck:=Forms.cylinder(model,at+Vector3.UP*0.213,0.14,0.078,0.075,material)
	Forms.cylinder(model,at+Vector3.UP*0.296,0.031,0.092,0.092,"paintedBronze")
	Forms.box(model,at+Vector3(0.118,0.211,0),Vector3(0.060,0.093,0.057),material)
	Forms.box(model,at+Vector3(-0.118,0.211,0),Vector3(0.060,0.093,0.057),material)
	neck.rotation.y=0.20
	return base

