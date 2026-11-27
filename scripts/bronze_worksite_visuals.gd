extends RefCounted
## Bronze Age furnishings are anchored to their editable plan items.
const Masonry = preload("res://scripts/bronze_home_structure.gd")
const Finishes = preload("res://scripts/bronze_home_materials.gd")
const Plan = preload("res://scripts/house_plan_geometry.gd")
const Facade = preload("res://scripts/house_facade_details.gd")
const Bridge = preload("res://scripts/bronze_river_bridge.gd")
const Ships = preload("res://scripts/period_ship_visuals.gd")
const Fence = preload("res://scripts/house_fence.gd")

const TYPES := ["kiln","oven","bronzeHearth","stall","shaft","wellRoof","bronzeCrane","loom","target","banner","sawBench","millstone","canopy","stockShelter","clothRack","ore","tower","vegBed","flaxRow","bronzeOutcrop","quarrySite","claySite","bronzeBlocks","roadStones","bronzeSledge"]
static var assets: Dictionary = {}
static var surfaces: Dictionary = {}
var pieces: Array[Dictionary] = [{},{}]
var cover := false
var variation := 0

func builder(finish: String) -> SurfaceTool:
	var group: Dictionary = pieces[int(cover)]
	if not group.has(finish):
		var key := finish + str(variation)
		if not surfaces.has(key):
			var name_ := finish
			var tint := Color.WHITE
			match finish:
				"shadow":
					name_="earth"
					tint=Color("33261f")
				"charcoal":
					name_="rubble"
					tint=Color("594942")
				"malachite":
					name_="bronze"
					tint=Color("689480")
				"tin":
					name_="rubble"
					tint=Color("8c9493")
				"soil":
					name_="earth"
					tint=Color("796246")
				"bedrock","sandstone":
					name_="rubble"
					tint=Color("8f9181") if finish=="bedrock" else Color("b1a68b")
				"sage","leaves","stems","petals":
					name_="plaster"
					tint=Color({"sage":"7f9a57","leaves":"457742","stems":"78964f","petals":"698cc7"}[finish])
				"blue":
					name_="linen"
					tint=Color("56888e")
				"madder":
					name_="linen"
					tint=Color("ac5d48")
				"rope":
					name_="matting"
					tint=Color("a68760")
				"ember":
					name_="kiln"
			var mat := Finishes.get_finish(name_,variation).duplicate() as StandardMaterial3D
			mat.albedo_color=tint
			if finish=="rubble":
				mat.vertex_color_use_as_albedo=true
				mat.vertex_color_is_srgb=true
			if finish=="ember":
				mat.emission_enabled=true
				mat.emission=Color("e45926")
				mat.emission_energy_multiplier=0.38
			surfaces[key]=mat
		group[finish]=Masonry.surface(surfaces[key])
		group[finish].set_color(Color.WHITE)
	return group[finish]

func meshes() -> Array:
	var result: Array = []
	for group in pieces:
		var mesh := ArrayMesh.new()
		for part: SurfaceTool in group.values():
			part.index()
			part.commit(mesh)
		result.append(mesh if mesh.get_surface_count()>0 else null)
	return result

static func install(model:Node3D, parts:Array, at:Vector3, label:String, angle:=0.0) -> void:
	for n in parts.size():
		if parts[n]==null:continue
		var node:=MeshInstance3D.new()
		node.mesh=parts[n]
		node.name=label+("Cover" if n==1 else "")
		node.position=at
		node.rotation.y=angle
		if n==1:node.set_meta("house_roof",true)
		model.add_child(node,true)

static func place(model:Node3D, kind:String, at:Vector3, family:String, design:Dictionary) -> bool:
	if kind=="bronzeBoat":
		var ship:=Ships.visual("transport",1,1,0.13,model.texture_variant)
		ship.name="BronzeHarborBoat"
		ship.position=at+Vector3.DOWN*0.18
		ship.rotation.y=1.32
		model.add_child(ship)
		return true
	if kind=="bridgeSpan":
		var span:=Bridge.create_span(3.90,1.43,0.20,model.texture_variant)
		span.position=at
		model.add_child(span)
		return true
	if not kind in TYPES:return false
	# Vary the cloth across a row of traders; all alike meshes are shared.
	var v:int=posmod(model.texture_variant+roundi(at.x*4.0+at.z),3) if kind in ["stall","vegBed","flaxRow"] else 0
	var copper:bool=kind=="ore" and str(design.id).get_slice("@",0)=="coppermine"
	var key:=kind+str(v)+str(copper)
	if not assets.has(key):
		var kit=load("res://scripts/bronze_worksite_visuals.gd").new()
		kit.variation=v
		match kind:
			"kiln","oven","bronzeHearth":kit.firing_chamber(kind)
			"wellRoof","shaft":kit.hoist(kind=="wellRoof")
			"stall":kit.merchant_stall()
			"loom":kit.weaving_frame()
			"bronzeCrane":kit.quarry_shear()
			"target":kit.woven_target()
			"banner":kit.standard()
			"sawBench":kit.trestle()
			"millstone":kit.mill()
			"ore":kit.ore_pile(copper)
			"stockShelter","canopy":kit.shade(kind=="stockShelter")
			"tower":kit.lookout()
			"clothRack":kit.drying_cloth()
			"vegBed","flaxRow":kit.planted_bed(kind=="flaxRow")
			"bronzeOutcrop","quarrySite","claySite":kit.exposed_ledge(kind)
			"bronzeBlocks","roadStones","bronzeSledge":kit.dressed_stone(kind)
		assets[key]=kit.meshes()
	var rotation_angle := 0.0
	if kind=="banner" and family=="guard":rotation_angle=-0.18
	if kind=="tower":
		for mount in Fence.tower_positions(design):
			if mount.attached and model.local(mount.point).distance_squared_to(at)<0.001:
				rotation_angle=-float(mount.angle)
				break
	install(model,assets[key],at,"Bronze_"+kind,rotation_angle)
	return true

func beam(a:Vector3,b:Vector3,radius:float,finish: String="wood",r2:float=-1.0,steps:=8) -> void:
	var axis:=(b-a).normalized()
	if axis.length_squared()<0.99:return
	var u:=axis.cross(Vector3.UP if absf(axis.y)<0.9 else Vector3.RIGHT).normalized()
	var v:=axis.cross(u).normalized()
	var surface:=builder(finish)
	var end_r:=radius if r2<0.0 else r2
	for i in steps:
		var t:=TAU*i/steps
		var s:=TAU*(i+1)/steps
		var d:=u*cos(t)+v*sin(t)
		var e:=u*cos(s)+v*sin(s)
		Masonry.quad(surface,a+d*radius,a+e*radius,b+e*end_r,b+d*end_r,d+e)
		Masonry.triangle(surface,a,a+e*radius,a+d*radius,-axis)
		Masonry.triangle(surface,b,b+d*end_r,b+e*end_r,axis)

func block(at:Vector3,size:Vector3,finish:String,angle:=0.0) -> void:
	var axis:=Vector3.RIGHT.rotated(Vector3.UP,angle)
	Masonry.bar(builder(finish),at,axis,axis.cross(Vector3.UP),size.x,size.y,size.z)

# A ring profile can leave a genuine stoking arch open on its front face.
func vessel(at:Vector3, profile:Array, finish:String, opening_height:=0.0, steps:=20) -> void:
	var surface:=builder(finish)
	for row in range(profile.size()-1):
		var lo:Vector2=profile[row]
		var hi:Vector2=profile[row+1]
		for i in steps:
			var t:=TAU*i/steps
			var s:=TAU*(i+1)/steps
			var a:=Vector3(sin(t),0,cos(t))
			var b:=Vector3(sin(s),0,cos(s))
			if opening_height>0.0 and hi.y<=opening_height and cos((t+s)*0.5)>0.86:continue
			var normal:Vector3=(a+b).normalized()*(hi.y-lo.y)+Vector3.UP*(lo.x-hi.x)
			Masonry.quad(surface,at+a*lo.x+Vector3.UP*lo.y,at+b*lo.x+Vector3.UP*lo.y,at+b*hi.x+Vector3.UP*hi.y,at+a*hi.x+Vector3.UP*hi.y,normal)

func firing_chamber(kind:String) -> void:
	var smelter:=kind=="bronzeHearth"
	var baker:=kind=="oven"
	var origin:=Vector3.ZERO
	var size_factor:=0.82 if baker else 1.0
	var height:=1.43 if smelter else 0.91 if baker else 1.22
	var profile:Array=[Vector2(.76*size_factor,.02),Vector2(.82*size_factor,.19),Vector2(.78*size_factor,.42),Vector2(.69*size_factor,.58),Vector2(.52*size_factor,height*.76),Vector2(.23*size_factor,height),Vector2(.245*size_factor,height+.085),Vector2(.17*size_factor,height+.10),Vector2(.16*size_factor,height-.10)]
	vessel(origin,profile,"kiln",.58)
	vessel(Vector3(0,.002,.32),[Vector2(.48,.016),Vector2(.44,.056),Vector2(.02,.065)],"shadow")
	for i in 9:
		var angle:=PI*i/8.0
		var center:=Vector3(cos(angle)*.385,.18+sin(angle)*.31,.69*size_factor)
		var voussoir:=Vector3(cos(angle)*.09,sin(angle)*.09,.0)
		beam(center-voussoir,center+voussoir,.113,"kiln",.128,6)
	for i in 4:
		var coal:=Vector3(-.21+.14*i,.068,.52+sin(i*2.8)*.09)
		beam(coal,coal+Vector3(.06,.045,.03),.068,"ember",.042,6)
	if smelter:
		for x in [-.40,-.17]:
			beam(Vector3(x,.24,.80),Vector3(x-.18,.31,1.04),.063,"kiln")
	else:
		for i in 3:
			beam(Vector3(.65+.11*i,.075,.21),Vector3(.76+.11*i,.11,.87),.064,"wood",.052)

func sheet(at:Vector3, width:float, depth:float, height:float, base:String, stripe:String) -> void:
	var columns:=9
	var rows:=4
	var point:=func(i:int,j:int)->Vector3:
		var u:=float(i)/columns
		var v:=float(j)/rows
		return at+Vector3((u-.5)*width,height+(1.0-v)*.16-.13*sin(PI*u)-.085*sin(PI*v),(v-.5)*depth)
	for i in columns:
		var fabric:=builder(stripe if i in [1,7] else base)
		for j in rows:
			Masonry.quad(fabric,point.call(i,j),point.call(i+1,j),point.call(i+1,j+1),point.call(i,j+1),Vector3.UP)
		var a:Vector3=point.call(i,rows)
		var b:Vector3=point.call(i+1,rows)
		Masonry.quad(fabric,a,b,b+Vector3.DOWN*.14,(a+b)*.5+Vector3.DOWN*.19,Vector3.BACK)
		Masonry.triangle(fabric,a,(a+b)*.5+Vector3.DOWN*.19,a+Vector3.DOWN*.13,Vector3.BACK)

func merchant_stall() -> void:
	for x in [-.78,.78]:
		for z in [-.49,.49]:
			beam(Vector3(x,0,z),Vector3(x,1.85 if z<0 else 1.7,z),.049)
		beam(Vector3(x,.12,.44),Vector3(x,.76,-.43),.035)
	beam(Vector3(-.86,1.69,.49),Vector3(.85,1.69,.49),.055)
	beam(Vector3(-.86,1.85,-.49),Vector3(.85,1.85,-.49),.055)
	block(Vector3(0,.57,.20),Vector3(1.49,.095,.51),"wood")
	for x in [-.62,.58]:
		beam(Vector3(x,0,.20),Vector3(x,.54,.2),.06)
	for i in 4:
		var p:=Vector3(-.53+i*.33,.62,.22)
		vessel(p,[Vector2(.073,0),Vector2(.13,.026),Vector2(.14,.093),Vector2(.11,.127),Vector2(.1,.114),Vector2(.024,.055)],"kiln",0.0,12)
	cover=true
	sheet(Vector3.ZERO,1.93,1.27,1.69,"linen",["madder","blue","matting"][variation])
	cover=false

func hoist(well:bool) -> void:
	if well:
		vessel(Vector3.ZERO,[Vector2(.73,.01),Vector2(.73,.45),Vector2(.76,.52),Vector2(.74,.61),Vector2(.53,.62),Vector2(.50,.47),Vector2(.50,.06)],"rubble")
		vessel(Vector3.ZERO,[Vector2(.49,.026),Vector2(.008,.028)],"shadow")
	else:
		block(Vector3(0,.019,0),Vector3(1.22,.045,1.06),"shadow")
		for sign_:float in [-1.0,1.0]:
			block(Vector3(sign_*.68,.13,0),Vector3(.18,.25,1.4),"rubble")
			block(Vector3(0,.13,sign_*.6),Vector3(1.45,.25,.17),"rubble")
	for sign_:float in [-1.0,1.0]:
		beam(Vector3(.80*sign_,0,-.22),Vector3(.71*sign_,1.68,0),.085,"wood",.072)
		if not well:beam(Vector3(.86*sign_,.02,.59),Vector3(.72*sign_,1.49,0),.067)
	beam(Vector3(-.91,1.45,0),Vector3(.90,1.45,0),.09)
	for i in 7:
		var x:float=-.15+i*.044
		beam(Vector3(x,1.45,0),Vector3(x+.023,1.45,0),.112,"rope")
	beam(Vector3(.14,1.43,.09),Vector3(.14,.53,.09),.017,"rope")
	vessel(Vector3(.14,.38,.09),[Vector2(.105,0),Vector2(.16,.18),Vector2(.16,.23),Vector2(.12,.23),Vector2(.09,.06)],"wood",0,10)
	beam(Vector3(.92,1.45,0),Vector3(.92,1.62,.22),.04)
	beam(Vector3(.91,1.62,.22),Vector3(1.13,1.62,.22),.03)
	if well:
		cover=true
		sheet(Vector3.ZERO,1.95,1.43,1.73,"matting","matting")
		cover=false

func quarry_shear() -> void:
	var apex:=Vector3(0,2.19,.18)
	for side in [-1.0,1.0]:
		beam(Vector3(.80*side,.02,-.45),apex,.088,"wood",.061)
	beam(Vector3(.18,.03,1.22),apex,.081,"wood",.058)
	beam(apex,Vector3(-.08,.61,.13),.026,"rope")
	block(Vector3(-.08,.44,.13),Vector3(.72,.36,.46),"rubble",.11)
	for x in [-.26,.11]:
		beam(Vector3(x,.30,.37),Vector3(-.08,.63,.13),.018,"rope")

func weaving_frame() -> void:
	for x in [-.53,.53]:
		beam(Vector3(x,.0,.28),Vector3(x,1.57,-.18),.065)
	beam(Vector3(-.63,1.52,-.18),Vector3(.64,1.52,-.18),.065)
	for i in 13:
		var x:float=-.46+i*.075
		beam(Vector3(x,1.43,-.15),Vector3(x,.26,.17),.008,"linen",.007,5)
		if i%2==0:beam(Vector3(x,.25,.17),Vector3(x,.35,.14),.04,"kiln",.034,6)
	for i in 6:
		var y:float=.73+i*.114
		block(Vector3(0,y,.068-(y-.73)*.267),Vector3(.88,.118,.032),"blue" if i in [1,4] else "linen")

func woven_target() -> void:
	for x in [-.27,.27]:
		beam(Vector3(x,.02,.23),Vector3(x*.7,1.28,0),.05)
	beam(Vector3(0,.03,-.57),Vector3(0,1.17,0),.06)
	var center:=Vector3(0,1.04,.04)
	beam(center,center+Vector3.BACK*.10,.431,"matting",.415,18)
	beam(center+Vector3.BACK*.101,center+Vector3.BACK*.108,.25,"madder",.25,18)
	beam(center+Vector3.BACK*.11,center+Vector3.BACK*.116,.16,"matting",.16,16)
	beam(center+Vector3.BACK*.12,center+Vector3.BACK*.126,.065,"madder",.065,12)

func standard() -> void:
	beam(Vector3.ZERO,Vector3.UP*2.24,.049,"wood",.032)
	beam(Vector3(-.36,2.07,0),Vector3(.36,2.07,0),.028)
	var cloth:=builder("madder")
	Masonry.quad(cloth,Vector3(-.32,2.06,0),Vector3(.32,2.06,0),Vector3(.28,1.46,.065),Vector3(-.32,1.42,.065),Vector3.BACK)
	Masonry.triangle(cloth,Vector3(-.32,1.42,.065),Vector3(.28,1.46,.065),Vector3(0,1.27,.10),Vector3.BACK)
	Masonry.quad(builder("linen"),Vector3(-.31,1.64,.053),Vector3(.295,1.67,.047),Vector3(.293,1.61,.057),Vector3(-.31,1.58,.06),Vector3.BACK)

func trestle() -> void:
	for x in [-.66,.66]:
		for sign_:float in [-1.0,1.0]:
			beam(Vector3(x,.0,sign_*.4),Vector3(x,.75,-sign_*.23),.059)
		beam(Vector3(x,.63,-.40),Vector3(x,.63,.4),.068)
	beam(Vector3(-1.05,.76,0),Vector3(1.13,.74,.03),.14,"wood",.105,10)
	block(Vector3(0,.87,.045),Vector3(.63,.028,.13),"bronze",.36)

func mill() -> void:
	vessel(Vector3.ZERO,[Vector2(.42,.0),Vector2(.53,.10),Vector2(.51,.42),Vector2(.43,.46),Vector2(.08,.46)],"rubble")
	vessel(Vector3.ZERO,[Vector2(.47,.47),Vector2(.49,.52),Vector2(.43,.64),Vector2(.17,.70),Vector2(.094,.69),Vector2(.09,.57)],"rubble")
	beam(Vector3(.30,.60,.06),Vector3(.32,.89,.08),.048)


# The principal portico follows the first exterior door in the editor's opening order.
static func entrance(model:Node3D, design:Dictionary, geometry:Dictionary, height:float) -> void:
	if design.get("upperLevel",false) or design.get("porch","none")=="none" or design.get("roofForm","")!="earthenShed":
		return
	for door in design.get("openings",[]):
		if door.get("type","")!="door" or door.get("group","outer")!="outer":
			continue
		for edge in geometry.walls:
			if edge.group!="outer":continue
			var p:=Plan.point(door.point)
			if p.distance_to(Plan.closest(p,edge.a,edge.b))>0.7:continue
			var out:=Facade.exterior(edge,geometry.floors)
			var top:=minf(2.40,Masonry.wall_height(edge,design.rooms,height)-0.10)
			var wide:=minf(3.30,model.local(edge.a).distance_to(model.local(edge.b))-0.28)
			if wide<1.15 or top<1.28:continue
			var kit=load("res://scripts/bronze_worksite_visuals.gd").new()
			kit.variation=model.texture_variant
			var reach:=1.40 if design.bronzeFamily=="civic" else 1.09
			kit.portico(wide,reach,top,design.bronzeFamily=="civic")
			install(model,kit.meshes(),model.local(p),"BronzePorch",atan2(out.x,out.y))
			return

func portico(width:float, depth:float, height:float, civic:bool) -> void:
	var half:=width*.5-.13
	for x in [-half,half]:
		var foot:=Vector3(x,0,depth-.10)
		block(foot+Vector3.UP*.07,Vector3(.35,.14,.36),"rubble")
		beam(foot+Vector3.UP*.14,foot+Vector3.UP*(height-.08),.099,"wood",.13,10)
		beam(foot+Vector3.UP*(height-.21),foot+Vector3.UP*(height-.08),.16,"kiln",.18,10)
		block(foot+Vector3.UP*(height-.066),Vector3(.39,.115,.35),"wood")
		beam(Vector3(x,height,.01),Vector3(x,height,depth+.10),.085,"wood")
	beam(Vector3(-half-.19,height,depth-.10),Vector3(half+.19,height,depth-.10),.105,"wood")
	cover=true
	sheet(Vector3(0,0,depth*.53),width+.18,depth+.19,height+.09,"matting" if civic else "linen","madder" if civic else "blue")

static func tower_deck(model:Node3D,room:Dictionary,design:Dictionary,height:float) -> void:
	var perimeter:=Plan.room_polygon(room)
	var indices:=Geometry2D.triangulate_polygon(perimeter)
	if indices.is_empty():return
	var kit=load("res://scripts/bronze_worksite_visuals.gd").new()
	kit.variation=model.texture_variant
	var deck:=Masonry.surface(model.material_for(str(design.get("roofMat","earth"))))
	var base:=Masonry.room_height(room,height)
	for i in range(0,indices.size(),3):
		Masonry.triangle(deck,model.local(perimeter[indices[i]],base+.03),model.local(perimeter[indices[i+1]],base+.03),model.local(perimeter[indices[i+2]],base+.03),Vector3.UP)
	Masonry.finish(model,deck,"BronzeTowerDeck")
	var stone:SurfaceTool=kit.builder("rubble")
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(perimeter)
	for edge in Plan.edges(perimeter):
		var a:Vector3=model.local(edge.a,base)
		var b:Vector3=model.local(edge.b,base)
		var length:=a.distance_to(b)
		if length<.01:continue
		var axis:=(b-a)/length
		var forward:=axis.cross(Vector3.UP)
		Masonry.bar(stone,(a+b)*.5+Vector3.UP*.17,axis,forward,length+.06,.34,.30)
		var count:=maxi(1,roundi(length/.93))
		for n in count:
			var p:=a.lerp(b,(float(n)+.5)/count)
			Masonry.stone(stone,p+Vector3.UP*.47,axis,forward,minf(.57,length/count*.64),.43,.34,rng)
	install(model,kit.meshes(),Vector3.ZERO,"BronzeTowerParapet")


func ore_pile(copper:bool) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=417 if copper else 319
	var finish:="malachite" if copper else "tin"
	var rock:=builder("rubble")
	var ore:=builder(finish)
	ore.set_color(Color.WHITE)
	for i in 13:
		var ring:=TAU*float(i)/7.
		var radius:=.36 if i<7 else .184 if i<12 else .02
		var p:=Vector3(cos(ring)*radius,.10 if i<7 else .26 if i<12 else .39,sin(ring)*radius)
		var size:=rng.randf_range(.29,.45)
		var axis:=Vector3.RIGHT.rotated(Vector3.UP,ring+.21)
		Masonry.stone(ore if i%3==1 or i==12 else rock,p,axis,axis.cross(Vector3.UP),size,size*.73,size*.84,rng)

func shade(backed:bool) -> void:
	var width:=2.29 if backed else 2.14
	var depth:=1.65 if backed else 1.46
	for x in [-width*.44,width*.44]:
		for z in [-depth*.4,depth*.4]:
			var top:=1.66 if z<0.0 else 1.47
			beam(Vector3(x,0,z),Vector3(x,top,z),.057,"wood",.064)
		beam(Vector3(x,1.65,-depth*.5),Vector3(x,1.47,depth*.5),.055)
	beam(Vector3(-width*.49,1.48,depth*.4),Vector3(width*.49,1.48,depth*.4),.068)
	beam(Vector3(-width*.49,1.66,-depth*.4),Vector3(width*.49,1.66,-depth*.4),.068)
	if backed:
		for i in 11:
			var x:float=-width*.43+i*width*.086
			beam(Vector3(x,.12,-depth*.4),Vector3(x,1.51,-depth*.4),.042,"wood",.038,6)
	cover=true
	sheet(Vector3.ZERO,width,depth,1.52,"matting","matting")

func drying_cloth() -> void:
	for x in [-.80,.80]:
		beam(Vector3(x-.13,0,.18),Vector3(x,1.38,0),.054)
		beam(Vector3(x+.11,0,-.18),Vector3(x,1.38,0),.045)
	beam(Vector3(-.91,1.34,0),Vector3(.92,1.34,0),.044)
	for i in 3:
		var x:float=-.71+i*.49
		var finish:String=["linen","madder","blue"][i]
		for j in 4:
			var u:=float(j)*.11
			var a:=Vector3(x+u,1.335,.064)
			var b:=Vector3(x+u+.11,1.334,.064)
			var c:=Vector3(x+u+.11,.60+.05*sin(i+u*7),.11+.035*cos((u+.11)*19.))
			var d:=Vector3(x+u,.60+.05*sin(i+u*7),.11+.035*cos(u*19.))
			Masonry.quad(builder(finish),a,b,c,d,Vector3.BACK)

func lookout() -> void:
	for x in [-.57,.57]:
		for z in [-.52,.52]:
			var p:=Vector3(x,0,z)
			beam(p*1.19,Vector3(x,3.94,z),.104,"wood",.075,10)
			beam(Vector3(x,2.04,z),Vector3(x,2.19,z),.128,"rope")
		beam(Vector3(x,.40,-.52),Vector3(x,2.04,.52),.056)
		beam(Vector3(x,2.19,-.61),Vector3(x,2.19,.61),.091)
		beam(Vector3(x,2.95,-.55),Vector3(x,2.95,.55),.051)
	for z in [-.52,.52]:
		beam(Vector3(-.57,2.98,z),Vector3(.57,2.98,z),.058)
		beam(Vector3(-.57,.36,z),Vector3(.57,2.04,z),.064)
	for i in 8:
		block(Vector3(0,2.30,-.57+i*.161),Vector3(1.47,.102,.15),"wood")
	for x in [-.28,.12]:
		beam(Vector3(x,0,.99),Vector3(x,2.42,.55),.044)
	for i in 8:
		var fraction:=float(i+1)/9
		var p:=Vector3(-.28,2.42*fraction,.99-.44*fraction)
		beam(p,p+Vector3.RIGHT*.40,.031)
	cover=true
	sheet(Vector3.ZERO,1.81,1.64,3.80,"matting","matting")

func masonry_skin(a:Vector3,b:Vector3,depth:float,height:float,rng:RandomNumberGenerator) -> void:
	var span:=a.distance_to(b)
	if span<.02:return
	var axis:=(b-a)/span
	var forward:=axis.cross(Vector3.UP)
	var rock:=builder("rubble")
	var rows:=maxi(1,roundi(height/.46))
	var row_height:=height/rows
	for row in rows:
		var x:=0.
		while x<span-.002:
			var w:=rng.randf_range(.57,1.07)
			if row%2==1 and x<.001:w*=.58
			if span-x-w<.28:w=span-x
			var p:=a+axis*(x+.5*w)+Vector3.UP*((row+.5)*row_height)
			Masonry.stone(rock,p,axis,forward,w*1.035,row_height*rng.randf_range(1.00,1.10),depth*rng.randf_range(.98,1.07),rng)
			x+=w

func parapet(a:Vector3,b:Vector3,rng:RandomNumberGenerator) -> void:
	var length:=a.distance_to(b)
	if length<.035:return
	var axis:=(b-a)/length
	var forward:=axis.cross(Vector3.UP)
	var rock:=builder("rubble")
	Masonry.bar(rock,(a+b)*.5+Vector3.UP*.245,axis,forward,length,.49,.19)
	var count:=maxi(1,roundi(length/1.09))
	for i in count:
		var part:=length/count
		var center:=a.lerp(b,(float(i)+.5)/count)
		Masonry.stone(rock,center+Vector3.UP*.74,axis,forward,part*.61,.56,.27,rng)

static func fort_wall(model:Node3D,a:Vector3,b:Vector3,fence:Dictionary,stair:Dictionary) -> void:
	var kit=load("res://scripts/bronze_worksite_visuals.gd").new()
	kit.variation=model.texture_variant
	var length:=a.distance_to(b)
	var axis:=(b-a)/length
	var side:=Vector3(-axis.z,0,axis.x)
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(fence.a)
	var stone:SurfaceTool=kit.builder("rubble")
	Masonry.bar(stone,(a+b)*.5+Vector3.UP*1.10,axis,side,length,2.23,1.34)
	kit.masonry_skin(a,b,1.44,2.21,rng)
	Masonry.bar(stone,(a+b)*.5+Vector3.UP*2.20,axis,side,length,.12,1.48)
	for sign_:float in [-1.0,1.0]:
		var offset:=side*sign_*.706+Vector3.UP*2.23
		if not stair.is_empty() and stair.wall==fence and int(stair.side)==int(sign_):
			var center:float=a.distance_to(model.local(stair.opening))/length
			var radius:float=float(stair.landingWidth)/Plan.PX_PER_M*.49/length
			kit.parapet(a+offset,a.lerp(b,clampf(center-radius,0.,1.))+offset,rng)
			kit.parapet(a.lerp(b,clampf(center+radius,0.,1.))+offset,b+offset,rng)
		else:
			kit.parapet(a+offset,b+offset,rng)
	install(model,kit.meshes(),Vector3.ZERO,"BronzeRampart")


func planted_bed(flax:bool) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=1871+variation*19
	var soil:=builder("soil")
	var slices:Array[PackedVector3Array]=[]
	var columns:=14
	for col in columns+1:
		var x:float=(float(col)/columns-.5)*2.51
		var half_width:=.39 if flax else .43
		var end:=.74 if col==0 or col==columns else 1.
		var z:=rng.randf_range(-.04,.04)
		var height:=rng.randf_range(.053,.087)
		slices.append(PackedVector3Array([Vector3(x,.012,z-half_width*end),Vector3(x,height,z-half_width*.71*end),Vector3(x,height+.03,z),Vector3(x,height,z+half_width*.71*end),Vector3(x,.012,z+half_width*end)]))
		if col>0:
			for j in 4:
				Masonry.quad(soil,slices[col-1][j],slices[col][j],slices[col][j+1],slices[col-1][j+1],Vector3.UP)
	for lane in 3 if flax else 2:
		var n:=17 if flax else 7
		for i in n:
			var x:=lerpf(-1.15,1.15,(i+rng.randf_range(-.16,.16))/maxf(1.,n-1.))
			var z:float=lane*(.19 if flax else .32)-(.19 if flax else .16)+rng.randf_range(-.037,.037)
			var foot:=Vector3(x,.082,z)
			if flax:
				flax_plant(foot,rng)
			else:
				for j in 7:
					var turn:=j*TAU/7.0+rng.randf()*.39
					var dir:=Vector3(cos(turn),0,sin(turn))
					var vigor:=rng.randf_range(.70,1.16)
					var tip:=foot+dir*vigor*(.10 if j%3==0 else .20)+Vector3.UP*vigor*(.21 if j%3==0 else .14)
					var mid:=foot.lerp(tip,.56)+Vector3.UP*.045
					blade(foot,mid,tip,.061*vigor,"sage" if (i+j+lane)%3==0 else "leaves")

func blade(foot:Vector3,mid:Vector3,tip:Vector3,width:float,finish:String) -> void:
	var axis:=(tip-foot).cross(Vector3.UP).normalized()
	if axis.is_zero_approx():axis=Vector3.RIGHT
	var surface:=builder(finish)
	var spine:=mid+Vector3.UP*width*.48
	Masonry.triangle(surface,foot,mid-axis*width,spine,Vector3.UP)
	Masonry.triangle(surface,foot,spine,mid+axis*width,Vector3.UP)
	Masonry.triangle(surface,tip,spine,mid-axis*width,Vector3.UP)
	Masonry.triangle(surface,tip,mid+axis*width,spine,Vector3.UP)

func flax_plant(foot:Vector3,rng:RandomNumberGenerator) -> void:
	var tip:=foot+Vector3(rng.randf_range(-.069,.069),rng.randf_range(.30,.49),rng.randf_range(-.065,.065))
	beam(foot,tip,.011,"stems",.007,4)
	for j in 3:
		var angle:=rng.randf()*TAU
		var twig:=Vector3(cos(angle),0,sin(angle))*.084
		var base:=foot.lerp(tip,rng.randf_range(.20,.73))
		var end:=base+twig+Vector3.UP*.066
		blade(base,base.lerp(end,.5),end,.024,"leaves" if j%2 else "stems")
	var petals:=builder("petals")
	var phase:=rng.randf()*TAU
	for j in 5:
		var a:=phase+j*TAU/5.
		var along:=Vector3(cos(a),0,sin(a))
		var outer:=tip+along*.044+Vector3.UP*.022
		var side:=along.cross(Vector3.UP)*.019
		Masonry.quad(petals,tip,outer-side,outer+along*.006,outer+side,Vector3.UP)


# Each terrace has a rough back and a short dressed working face toward the yard.
func exposed_ledge(kind:String) -> void:
	var size:=1.0 if kind=="quarrySite" else .73 if kind=="bronzeOutcrop" else .86
	var clay:=kind=="claySite"
	var rng:=RandomNumberGenerator.new()
	rng.seed=59483 if clay else 4125
	var levels:=2 if clay else 3
	for level in levels:
		var h:=.21 if clay else .39
		var half_x:=(1.98-level*.33)*size
		var half_z:=(1.22-level*.24)*size
		var y:=h*size*level
		var z:=level*-.18*size
		var base:=PackedVector3Array()
		var top:=PackedVector3Array()
		for outline:Vector2 in [Vector2(-.97,.42),Vector2(-.79,.89),Vector2(-.32,1.),Vector2(.24,.96),Vector2(.73,.80),Vector2(1.,.37),Vector2(.93,-.57),Vector2(.57,-1.),Vector2(-.19,-.96),Vector2(-.82,-.87),Vector2(-1.,-.31)]:
			var p:=Vector3(outline.x*half_x,y,z+outline.y*half_z)
			base.append(p)
			top.append(p+Vector3(rng.randf_range(-.09,.05),h*size+rng.randf_range(-.065,.046),rng.randf_range(-.09,.045)))
		var center:=Vector3(-half_x*.11,y+h*size+.016,z-half_z*.08)
		for j in base.size():
			var k:=(j+1)%base.size()
			var material:=builder("kiln" if clay else "sandstone" if (j+level*3)%4==1 else "bedrock")
			Masonry.triangle(material,center,top[j],top[k],Vector3.UP)
			Masonry.quad(material,base[j],base[k],top[k],top[j],(base[j]+base[k])*.5-Vector3(0,y,z))
	for i in 11:
		var x:=rng.randf_range(-1.80,1.65)*size
		var z:=rng.randf_range(.77,1.49)*size
		var width:=rng.randf_range(.17,.42)*size
		var axis:=Vector3.RIGHT.rotated(Vector3.UP,rng.randf()*TAU)
		var loose:=builder("kiln" if clay else "rubble")
		loose.set_color(Color.WHITE)
		Masonry.stone(loose,Vector3(x,width*.20,z),axis,axis.cross(Vector3.UP),width,width*.52,width*.79,rng)
	if not clay:
		# The cut blocks still in the bed follow a wedge line.
		for i in 5:
			var p:=Vector3((i-2)*.212*size,.39*size,.91*size)
			block(p+Vector3.UP*.043,Vector3(.036,.11,.067),"wood",.10)

func dressed_stone(kind:String) -> void:
	var sledge:=kind=="bronzeSledge"
	var road:=kind=="roadStones"
	var rng:=RandomNumberGenerator.new()
	rng.seed=831
	if sledge:
		for z in [-.37,.37]:
			beam(Vector3(-.91,.089,z),Vector3(.77,.089,z),.071,"wood",.083)
			beam(Vector3(.77,.089,z),Vector3(.99,.22,z),.083,"wood",.047)
		for x in [-.57,-.28,.03,.36,.62]:
			beam(Vector3(x,.156,-.41),Vector3(x,.156,.41),.069,"wood")
	var rock:=builder("rubble")
	for i in 2 if sledge else 7 if road else 5:
		var pos:Vector3
		var size:Vector3
		if sledge:
			pos=Vector3(-.36+i*.55,.395,0)
			size=Vector3(.55,.38,.68)
		elif road:
			pos=Vector3(-.47+(i%3)*.45,.075+floori(i/6.)*.105,-.24+floori((i%6)/3.)*.40)
			size=Vector3(.43,.16,.36)
		else:
			pos=Vector3((i%2-.50)*.54,.14+floori(i/4.)*.27,(floori((i%4)/2.)-.5)*.44)
			size=Vector3(.58,.30,.50)
		var axis:=Vector3.RIGHT.rotated(Vector3.UP,rng.randf_range(-.11,.09))
		Masonry.stone(rock,pos,axis,axis.cross(Vector3.UP),size.x,size.y,size.z,rng)
	if sledge:
		for x in [-.37,.23]:
			beam(Vector3(x,.19,-.42),Vector3(x,.59,-.27),.021,"rope")
			beam(Vector3(x,.59,-.27),Vector3(x,.59,.27),.021,"rope")
			beam(Vector3(x,.59,.27),Vector3(x,.19,.42),.021,"rope")

