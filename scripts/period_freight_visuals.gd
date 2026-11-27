extends RefCounted
const Vapor=preload("res://scripts/period_vapor.gd")
const Forms=preload("res://scripts/period_ship_visuals.gd")

static func cylinder(parent: Node3D,at: Vector3,radius: float,height: float,lengthwise: bool,tint: Material) -> void:
	var pipe:=CylinderMesh.new()
	pipe.top_radius=radius
	pipe.bottom_radius=radius
	pipe.height=height
	pipe.radial_segments=12
	var piece:=Forms.part(parent,pipe,tint,at)
	if lengthwise:piece.rotation.x=PI/2

static func road_vehicle(parent: Node3D,age: int,team: int,scale_factor: float,variant: int) -> bool:
	if age<1:
		return false
	var vehicle:=Node3D.new()
	vehicle.name="PeriodRoadVehicle"
	vehicle.scale=Vector3.ONE*scale_factor
	parent.add_child(vehicle)
	if age>=5:
		motor_lorry(vehicle,age,team,variant)
	else:
		wooden_wagon(vehicle,age,variant)
	return true

static func motor_lorry(body: Node3D,age: int,team: int,variant: int) -> void:
	var iron:=Forms.material(Color("414a49"),"period_castIron",variant)
	var rubber:=Forms.material(Color("25272a"))
	var pale:=Forms.material(Color("bec9c0"))
	var glass:=Forms.material(Color("668491"))
	var red:=Forms.material(Color("a54436"))
	var lamps:=Forms.material(Color("eee1b2"))
	var truck_colors: Array[Color]=[Color("d5ddd5"),Color("ab5d52"),Color("8492b5"),Color("c79c4f")]
	var paint:=Forms.material(Color("737660") if age==5 else truck_colors[posmod(team,truck_colors.size())])
	Forms.block(body,Vector3(0,0.44,-0.15),Vector3(1.46,0.18,3.55),iron)
	if age==5:
		Forms.block(body,Vector3(0,0.81,1.04),Vector3(0.87,0.51,0.86),paint)
		Forms.block(body,Vector3(0,0.95,0.34),Vector3(1.19,0.84,0.57),paint)
		Forms.block(body,Vector3(0,1.31,0.68),Vector3(1.10,0.37,0.06),glass)
		Forms.block(body,Vector3(0,1.53,0.31),Vector3(1.31,0.13,0.67),paint)
		Forms.block(body,Vector3(0,0.78,1.49),Vector3(0.65,0.44,0.055),iron)
		Forms.block(body,Vector3(0,1.03,-0.91),Vector3(1.38,0.96,1.82),Forms.material(Color("aea179"),"period_khakiCanvas",variant))
	else:
		Forms.block(body,Vector3(0,0.94,0.99),Vector3(1.43,0.93,1.09),paint)
		var windshield:=Forms.block(body,Vector3(0,1.12,1.550),Vector3(1.30,0.36,0.048),glass)
		windshield.rotation.x=-0.09
		Forms.block(body,Vector3(0,0.66,1.55),Vector3(1.31,0.22,0.078),iron)
		Forms.block(body,Vector3(0,1.08,-0.59),Vector3(1.50,1.31,2.06),Forms.material(Color("aeb7ac"),"period_darkCladding",variant))
		Forms.block(body,Vector3(0,1.04,-1.63),Vector3(0.025,1.22,0.036),iron)
		for side in [-1.0,1.0]:
			Forms.block(body,Vector3(side*0.728,1.11,1.04),Vector3(0.02,0.33,0.63),glass)
			Forms.block(body,Vector3(side*0.83,1.07,1.42),Vector3(0.18,0.13,0.13),iron)
	for side in [-1.0,1.0]:
		for z in [-1.22,1.11]:
			wheel(body,Vector3(side*0.72,0.34,z),0.34,0.16,rubber,pale,0)
		Forms.block(body,Vector3(side*0.61,0.76,1.61 if age>=6 else 1.51),Vector3(0.20,0.13,0.09),lamps)
		Forms.block(body,Vector3(side*0.59,0.52,-1.66 if age>=6 else -1.84),Vector3(0.13,0.12,0.05),red)

static func wooden_wagon(body: Node3D,age: int,variant: int) -> void:
	var finishes: Array[String]=["","period_aegeanRed","period_navalPlank","period_norseTimber","period_maritimePaint"]
	var wood:=Forms.BronzeFinishes.get_finish("wood",variant) if age in [1,2] else Forms.material(Color("b59b7f"),finishes[age],variant)
	var trim:=Forms.material(Color("985342") if age==2 else Color("8b7262"))
	var iron:=Forms.material(Color("484741"),"period_castIron",variant)
	var cargo:=Forms.material(Color("b5a284"),"period_khakiCanvas",variant)
	var high:=age==4
	var ground_clearance:=0.53 if high else 0.43
	Forms.block(body,Vector3(0,ground_clearance,-0.22),Vector3(1.16,0.12,1.67),wood)
	for side in [-1.0,1.0]:
		Forms.block(body,Vector3(side*0.54,ground_clearance+0.21,-0.22),Vector3(0.11,0.39,1.60),wood)
		Forms.block(body,Vector3(side*0.54,ground_clearance+0.42,-0.22),Vector3(0.13,0.055,1.63),trim)
		Forms.spar(body,Vector3(side*0.49,ground_clearance,0.36),Vector3(side*0.35,ground_clearance-0.03,1.88),0.04,"755943")
		for z in ([-0.84,0.30] if high or age==2 else [-0.33]):
			wheel(body,Vector3(side*0.64,ground_clearance-0.05,z),ground_clearance-0.06,0.064,wood if age==1 else iron,wood if age==2 else trim,8 if high or age==2 else 6)
	Forms.block(body,Vector3(0,ground_clearance+0.24,-1.08),Vector3(1.08,0.40,0.1),wood)
	if high:
		var cover:=CapsuleMesh.new()
		cover.height=1.67
		cover.radius=0.53
		cover.radial_segments=12
		cover.rings=4
		var canvas:=Forms.part(body,cover,cargo,Vector3(0,1.02,-0.23))
		canvas.rotation.x=PI/2.0
	elif age==1:
		var wares:=Node3D.new()
		wares.scale=Vector3.ONE*0.67
		wares.position.y=ground_clearance+0.06
		body.add_child(wares)
		for at: Vector3 in [Vector3(-0.25,0,-0.02),Vector3(0.23,0,-0.75)]:
			Forms.BronzePots.place(wares,"householdJar",at)
	elif age==2:
		var pot_scale:=.93
		for z:float in [-.68,-.15,.35]:
			for x:float in [-.25,.25]:
				Forms.RomanCargo.place(body,Vector3(x,ground_clearance+.07,z),pot_scale)
		for z:float in [-.65,.17]:
			Forms.spar(body,Vector3(-.54,ground_clearance+.43,z),Vector3(.53,ground_clearance+.43,z),.023,"a98d60")
	else:
		Forms.block(body,Vector3(0.24,ground_clearance+0.27,-0.23),Vector3(0.43,0.34,0.68),cargo)
		cylinder(body,Vector3(-0.27,ground_clearance+0.29,-0.28),0.18,0.36,false,trim)

static func wheel(parent: Node3D, at: Vector3,radius: float,width: float,outer: Material,inner: Material,spokes: int) -> void:
	if spokes==0:
		var tire:=CylinderMesh.new()
		tire.height=width
		tire.top_radius=radius
		tire.bottom_radius=radius
		tire.radial_segments=12
		Forms.part(parent,tire,outer,at).rotation.z=PI/2.0
	else:
		var rim:=TorusMesh.new()
		rim.inner_radius=radius-0.043
		rim.outer_radius=radius
		rim.rings=16
		rim.ring_segments=6
		Forms.part(parent,rim,outer,at).rotation.z=PI/2.0
		for i in spokes:
			var angle:=float(i)*TAU/float(spokes)
			var spoke:=Forms.block(parent,at+Vector3(0,cos(angle),sin(angle))*radius*0.48,Vector3(width*0.7,radius*0.86,0.041),inner)
			spoke.rotation.x=angle
	var hub:=CylinderMesh.new()
	hub.height=width*1.14
	hub.top_radius=radius*0.34
	hub.bottom_radius=radius*0.34
	hub.radial_segments=10
	Forms.part(parent,hub,inner,at).rotation.z=PI/2.0

static func freight(parent: Node3D,kind: String,age: int,team: int) -> bool:
	if age<5 or kind not in ["rail","air"]:
		return false
	var shell:=Node3D.new()
	shell.name="PeriodFreight"
	shell.scale=Vector3.ONE*0.48
	parent.add_child(shell)
	var trim:=Forms.material(Color(["476273","8e6252","726783","937b49"][clampi(team,0,3)]))
	var iron:=Forms.material(Color("484c47"),"period_castIron",team)
	var glass:=Forms.material(Color("688898"))
	var pale:=Forms.material(Color("b6bdba"))
	var brass:=Forms.material(Color("997c56"))
	var buffer:=Forms.material(Color("865646"))
	if kind=="rail":
		var chassis:=Forms.material(Color("806654"),"period_navalPlank",team)
		Forms.block(shell,Vector3(0,0.38,-0.17),Vector3(1.22,0.21,3.34),chassis)
		if age==5:
			cylinder(shell,Vector3(0,0.93,0.42),0.37,1.58,true,iron)
			Forms.block(shell,Vector3(0,1.01,-0.69),Vector3(0.97,0.95,0.78),trim)
			Forms.block(shell,Vector3(0,1.47,-0.70),Vector3(1.13,0.13,0.94),iron)
			cylinder(shell,Vector3(0,1.43,0.94),0.135,0.44,false,iron)
			cylinder(shell,Vector3(0,1.67,0.94),0.19,0.10,false,brass)
			cylinder(shell,Vector3(0,1.34,0.39),0.225,0.29,false,iron)
			cylinder(shell,Vector3(0,0.93,1.20),0.39,0.075,true,brass)
			cylinder(shell,Vector3(0,0.93,1.247),0.31,0.055,true,iron)
			Forms.block(shell,Vector3(0,0.41,1.43),Vector3(1.15,0.19,0.16),buffer)
			Forms.block(shell,Vector3(0,1.31,1.212),Vector3(0.19,0.17,0.126),brass)
			for side in [-1.0,1.0]:
				Forms.block(shell,Vector3(0.497*float(side),1.12,-0.69),Vector3(0.037,0.31,0.48),glass)
				Forms.block(shell,Vector3(0.56*float(side),0.26,0.27),Vector3(0.075,0.073,1.37),brass)
			Vapor.add(shell,Vector3(0,1.73,0.94),Vector2(0.79,1.37),"steam",team)
			Forms.block(shell,Vector3(0,0.85,-1.59),Vector3(1.0,0.76,1.04),chassis)
		else:
			Forms.block(shell,Vector3(0,0.91,0.52),Vector3(1.11,0.89,1.65),trim)
			Forms.block(shell,Vector3(0,0.98,1.36),Vector3(1.0,0.27,0.055),glass)
			Forms.block(shell,Vector3(0,1.35,0.51),Vector3(1.18,0.13,1.65),pale)
			Forms.block(shell,Vector3(0,0.89,-1.07),Vector3(1.09,0.98,1.42),Forms.material(Color("9b6950"),"period_corrugation",team))
		for sign_ in [-1.0,1.0]:
			for z in [-1.57,-0.72,0.18,0.91]:
				var wheel:=CylinderMesh.new()
				wheel.height=0.12
				wheel.top_radius=0.28
				wheel.bottom_radius=0.28
				wheel.radial_segments=12
				var tire:=Forms.part(shell,wheel,iron,Vector3(float(sign_)*0.52,0.29,z))
				tire.rotation.z=PI/2.0
				var hub:=CylinderMesh.new()
				hub.height=0.16
				hub.top_radius=0.082
				hub.bottom_radius=0.082
				hub.radial_segments=8
				var pin:=Forms.part(shell,hub,brass,Vector3(float(sign_)*0.54,0.29,z))
				pin.rotation.z=PI/2.0
	elif age==5:
		biplane(shell,trim,iron,team)
	else:
		var hull:=CapsuleMesh.new()
		hull.radius=0.31
		hull.height=3.16
		hull.radial_segments=10
		hull.rings=7
		var bird:=Forms.part(shell,hull,pale,Vector3(0,0.85,0))
		bird.rotation.x=PI/2.0
		for sign_ in [-1.0,1.0]:
			var wing:=Forms.block(shell,Vector3(0.86*float(sign_),0.83,-0.2),Vector3(1.78,0.095,0.49),pale)
			wing.rotation.y=0.25*float(sign_)
			cylinder(shell,Vector3(0.89*float(sign_),0.77,0.04),0.14,0.68,true,trim)
		Forms.block(shell,Vector3(0,0.90,-1.23),Vector3(1.06,0.08,0.48),trim)
		Forms.block(shell,Vector3(0,1.22,-1.28),Vector3(0.09,0.66,0.42),trim)
		Forms.block(shell,Vector3(0,1.03,0.92),Vector3(0.44,0.17,0.23),glass)
	return true

static func biplane(shell: Node3D,trim: Material,iron: Material,variant: int) -> void:
	var linen:=Forms.material(Color("cabd96"),"period_khakiCanvas",variant)
	var hull:=CapsuleMesh.new()
	hull.radius=0.23
	hull.height=2.52
	hull.radial_segments=10
	hull.rings=7
	Forms.part(shell,hull,linen,Vector3(0,0.63,0)).rotation.x=PI*0.5
	Forms.block(shell,Vector3(0,0.67,0.19),Vector3(0.27,0.16,0.33),iron)
	for height in [0.54,1.25]:
		Forms.block(shell,Vector3(0,height,0.12),Vector3(2.60,0.084,0.50),linen)
		for side in [-1.0,1.0]:
			Forms.block(shell,Vector3(side*0.98,height+0.048,0.10),Vector3(0.27,0.018,0.37),trim)
	for x in [-1.0,-0.43,0.43,1.0]:
		for z in [-0.047,0.306]:
			Forms.spar(shell,Vector3(x,0.58,z),Vector3(x,1.21,z+0.06),0.018,"726653")
	Forms.block(shell,Vector3(0,0.65,-1.01),Vector3(0.83,0.054,0.26),linen)
	Forms.block(shell,Vector3(0,0.83,-1.03),Vector3(0.07,0.36,0.30),linen)
	cylinder(shell,Vector3(0,0.64,1.10),0.18,0.27,true,iron)
	var blade:=Forms.block(shell,Vector3(0,0.64,1.27),Vector3(0.057,0.82,0.035),trim)
	blade.rotation.z=-0.46
	for x in [-0.295,0.295]:
		Forms.spar(shell,Vector3(x,0.23,0.43),Vector3(x*0.53,0.52,0.30),0.024,"51483e")
		wheel(shell,Vector3(x,0.21,0.43),0.17,0.064,iron,trim,0)

