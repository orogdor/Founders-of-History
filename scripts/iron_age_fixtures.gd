extends RefCounted
const Kit=preload("res://scripts/iron_age_mesh.gd")
const Mason=preload("res://scripts/bronze_home_structure.gd")
const Fence=preload("res://scripts/house_fence.gd")
const Boats=preload("res://scripts/period_ship_visuals.gd")
const Bridge=preload("res://scripts/iron_river_bridge.gd")
const TYPES:=["archGate","romanTaberna","stall","waterwheel","forge","furnace","bronzeHearth","kiln","oven","wellRoof","well","fruitTree","romanColumn","romanBasin","millstone","clothRack","loom","anvil","jewelBench","shaft","ore","coalPile","vegBed","flaxRow","quarrySite","claySite","bronzeOutcrop","bronzeBlocks","bronzeSledge","roadStones","bronzeCrane","sawBench","stockShelter","canopy","tower","target","banner","bridgeSpan","bronzeBoat","boat"]
static var assets:Dictionary={}

static func place(model:Node3D,kind:String,at:Vector3,design:Dictionary) -> bool:
	if kind not in TYPES:return false
	if kind=="bridgeSpan":
		var bridge:=Bridge.create_span(4.55,1.45,.42,model.texture_variant)
		bridge.position=at
		model.add_child(bridge)
		return true
	if kind in ["bronzeBoat","boat"]:
		var ship:=Boats.visual("transport",1,2,.15 if kind=="bronzeBoat" else .10,model.texture_variant)
		ship.name="RomanHarbourBoat"
		ship.rotation.y=1.43
		ship.position=at+Vector3.DOWN*.17
		model.add_child(ship)
		return true
	var v:=posmod(model.texture_variant+roundi(at.x*4+at.z),3) if kind in ["fruitTree","stall","romanTaberna","vegBed","flaxRow"] else 0
	var ore_type:String=str(design.get("id","")).get_slice("@",0) if kind=="ore" else ""
	var gate_width:=3.6
	if kind=="archGate":
		var xs: Array[float]=[]
		for room in design.get("rooms",[]):
			if room.type!="rect":continue
			for point in [room.a,room.b]:xs.append(model.local(Fence.Plan.point(point)).x)
		xs.sort()
		if xs.size()==4: gate_width=clampf(xs[2]-xs[1],.9,6.5)
	var key:=[kind,v,ore_type,gate_width]
	if not assets.has(key):
		var kit:=Kit.new()
		kit.variation=v
		match kind:
			"romanTaberna","stall":counter(kit,kind=="romanTaberna")
			"waterwheel":wheel(kit)
			"archGate":gateway(kit,gate_width)
			"furnace","bronzeHearth":bloomery(kit,kind=="furnace")
			"forge":smithy(kit)
			"kiln","oven":oven(kit,kind=="kiln")
			"wellRoof","well":well(kit,kind=="wellRoof")
			"fruitTree":orchard_tree(kit)
			"romanColumn":kit.pillar(Vector3.ZERO,1.80,"ionic")
			"romanBasin":basin(kit)
			"millstone":handmill(kit)
			"anvil":anvil(kit)
			"jewelBench":jeweler(kit)
			"shaft":kit.hoist(false)
			"loom":kit.weaving_frame()
			"clothRack":kit.drying_cloth()
			"rock","ore":ore(kit,ore_type)
			"coalPile":charcoal(kit)
			"bronzeCrane":kit.quarry_shear()
			"bronzeBlocks","bronzeSledge","roadStones":kit.dressed_stone(kind)
			"quarrySite","claySite","bronzeOutcrop":kit.exposed_ledge(kind)
			"vegBed","flaxRow":kit.planted_bed(kind=="flaxRow")
			"sawBench":kit.trestle()
			"stockShelter","canopy":store_shelter(kit,kind=="stockShelter")
			"tower":watchtower(kit)
			"target":kit.woven_target()
			"banner":kit.standard()
		assets[key]=kit.meshes()
	if kind=="waterwheel":
		var mount:=Node3D.new()
		mount.name="RomanWatermill"
		mount.position=at
		var nearest:=INF
		if design.has("rooms"):
			var geometry:=Fence.Plan.plan_geometry(design)
			for edge in geometry.walls:
				if edge.group!="outer":continue
				var p:Vector2=model.origin+Vector2(at.x,at.z)*Fence.Plan.PX_PER_M
				var dist:=p.distance_squared_to(Fence.Plan.closest(p,edge.a,edge.b))
				if dist<nearest:
					nearest=dist
					var out:=Kit.Facade.exterior(edge,geometry.floors)
					mount.rotation.y=atan2(out.x,out.y)
		model.add_child(mount,true)
		var cradle:=Kit.new()
		wheel_support(cradle)
		Kit.install(mount,cradle.meshes(),Vector3.ZERO,"RomanMillRace")
		Kit.install(mount,assets[key],Vector3.UP*.94,"IronMillWheel")
		return true
	var angle:=0.0
	if kind=="tower":
		for pos in Fence.tower_positions(design):
			if pos.attached and model.local(pos.point).distance_squared_to(at)<.001:
				angle=-float(pos.angle)
				break
	Kit.install(model,assets[key],at,"Roman_"+kind,angle)
	return true

static func counter(kit:Kit,masonry:bool) -> void:
	var w:=1.90 if masonry else 1.74
	for x:float in [-w*.45,w*.45]:
		for z:float in [-.46,.46]:
			kit.beam(Vector3(x,0,z),Vector3(x,1.86 if z<0 else 1.68,z),.043,"wood",.034)
	kit.block(Vector3(0,.40,.02),Vector3(w*.95,.78,.67),"brick" if masonry else "wood")
	kit.block(Vector3(0,.79,.02),Vector3(w,.085,.76),"ashlar")
	if masonry:
		kit.block(Vector3(0,.45,.366),Vector3(w*.90,.43,.018),"redpaint")
		for x:float in [-.58,0,.58]:
			kit.vessel(Vector3(x,.83,.03),[Vector2(.18,0),Vector2(.19,.058),Vector2(.15,.074),Vector2(.13,.022),Vector2(.06,.013)],"kiln",0,16)
	else:
		for i in 3:
			kit.vessel(Vector3(-.58+i*.54,.83,.01),[Vector2(.08,0),Vector2(.16,.09),Vector2(.185,.145),Vector2(.13,.15),Vector2(.05,.065)],"kiln",0,12)
			for j in 4:
				var p:=Vector3(-.59+i*.54+.062*sin(j*2.3),.99,.01+.065*cos(j*2.3))
				kit.beam(p,p+Vector3.UP*.085,.055,"fruit",.024,7)
	kit.cover=true
	kit.sheet(Vector3.ZERO,w+.16,1.20,1.79,"linen","madder" if kit.variation%2==0 else "blue")

static func bloomery(kit:Kit,tall:bool) -> void:
	var h:=2.05 if tall else 1.39
	kit.block(Vector3(0,.08,0),Vector3(1.45,.16,1.32),"ashlar")
	kit.vessel(Vector3.ZERO,[Vector2(.62,.12),Vector2(.64,.43),Vector2(.56,.77),Vector2(.43,h*.65),Vector2(.30,h-.09),Vector2(.32,h),Vector2(.235,h+.025),Vector2(.21,h-.19)],"brick",.77,16)
	kit.arch(Vector3(0,.22,.55),Vector3.RIGHT,Vector3.BACK,.257,.34,.082,.20,"kiln",9)
	kit.block(Vector3(0,.156,.43),Vector3(.48,.045,.46),"charcoal")
	for i in 5:
		var at:=Vector3(-.17+.079*i,.193,.50+.045*sin(i*3.))
		kit.beam(at,at+Vector3.UP*.067,.067,"ember",.03,7)
	for y:float in [.45,h*.66,h-.14]:
		var r:=lerpf(.65,.30,clampf((y-.4)/(h-.4),0,1))
		kit.vessel(Vector3.ZERO,[Vector2(r,y),Vector2(r+.014,y+.023),Vector2(r+.014,y+.063),Vector2(r,y+.078)],"iron",0,16)
	kit.block(Vector3(.65,.12,.02),Vector3(.38,.24,.50),"ashlar")

static func smithy(kit:Kit) -> void:
	kit.block(Vector3(0,.31,0),Vector3(1.34,.62,.82),"brick")
	kit.block(Vector3(0,.67,.01),Vector3(1.46,.10,.92),"ashlar")
	kit.block(Vector3(0,.84,-.32),Vector3(1.33,.31,.16),"brick")
	for i in 15:
		var p:=Vector3(sin(i*2.17)*.35,.74+cos(i*4.)*.015,cos(i*3.17)*.17)
		kit.beam(p,p+Vector3.UP*.10,.10,"ember" if i%3==0 else "charcoal",.055,7)
	kit.block(Vector3(-.48,.81,.12),Vector3(.20,.10,.055),"iron",.23)

static func oven(kit:Kit,industrial:bool) -> void:
	kit.block(Vector3(0,.155,0),Vector3(1.45,.31,1.34),"brick")
	kit.vessel(Vector3.UP*.30,[Vector2(.61,.0),Vector2(.65,.26),Vector2(.59,.49),Vector2(.47,.67),Vector2(.29,.81),Vector2(.15,.89),Vector2(.14,.99),Vector2(.09,.99),Vector2(.08,.89)],"kiln",.49,16)
	kit.arch(Vector3(0,.38,.58),Vector3.RIGHT,Vector3.BACK,.32,.34,.117,.18,"brick",9)
	kit.block(Vector3(0,.343,.62),Vector3(.92,.071,.48),"ashlar")
	if industrial:
		for i in 5:
			kit.vessel(Vector3(.83+i%2*.22,.0,-.41+floori(i/2.)*.27),[Vector2(.075,0),Vector2(.13,.15),Vector2(.09,.25),Vector2(.076,.25)],"kiln",0,10)

static func wheel(kit:Kit) -> void:
	const COUNT:=16
	const RAD:=1.08
	for i in COUNT:
		var u:=TAU*i/COUNT
		var v:=TAU*(i+1)/COUNT
		var n:=Vector3(cos(u),sin(u),0)
		var t:=Vector3(cos(v),sin(v),0)
		for z:float in [-.16,.16]:
			var offset:=Vector3.BACK*z
			kit.beam(n*RAD+offset,t*RAD+offset,.057,"wood",.057,6)
			kit.beam(n*(RAD-.145)+offset,t*(RAD-.145)+offset,.049,"wood",.049,6)
			if i%2==0:kit.beam(offset+n*.14,offset+n*RAD,.045,"wood",.060,6)
		var rim:=kit.builder("blackwood")
		var tan:=Vector3(-n.y,n.x,0)*.09
		var root:=n*(RAD-.16)
		var edge:=n*(RAD+.075)+tan
		Mason.quad(rim,root+Vector3.FORWARD*.224,root+Vector3.BACK*.224,edge+Vector3.BACK*.224,edge+Vector3.FORWARD*.224,tan)
	kit.beam(Vector3.FORWARD*.95,Vector3.BACK*.44,.125,"blackwood",.125,12)

static func wheel_support(kit:Kit) -> void:
	# The water flows between the channel walls and blends into the river at each open end.
	var surface:=kit.builder("racewater")
	var x_positions:=[-1.27,-.88,.86,1.27]
	var opacities:=[.04,.76,.76,.04]
	for i in 3:
		for v in [[i,-.55],[i,.55],[i+1,.55],[i,-.55],[i+1,.55],[i+1,-.55]]:
			surface.set_normal(Vector3.UP)
			surface.set_color(Color(1,1,1,opacities[v[0]]))
			surface.set_uv(Vector2(x_positions[v[0]],v[1]))
			surface.add_vertex(Vector3(x_positions[v[0]],.065,v[1]))
	for z:float in [-.40,.40]:
		kit.block(Vector3(0,.25,z),Vector3(.39,.50,.26),"ashlar")
		kit.beam(Vector3(-.13,.50,z),Vector3(0,.93,z),.087,"wood")
		kit.beam(Vector3(.13,.50,z),Vector3(0,.93,z),.087,"wood")
		kit.block(Vector3(0,.95,z),Vector3(.28,.11,.18),"iron")
	for z:float in [-.64,.64]:
		kit.block(Vector3(0,.045,z),Vector3(2.55,.09,.22),"ashlar")

static func well(kit:Kit,covered:bool) -> void:
	kit.vessel(Vector3.ZERO,[Vector2(.63,.01),Vector2(.64,.18),Vector2(.56,.20),Vector2(.56,.67),Vector2(.63,.69),Vector2(.63,.79),Vector2(.445,.79),Vector2(.425,.61),Vector2(.42,.18)],"ashlar")
	kit.vessel(Vector3.ZERO,[Vector2(.43,.15),Vector2(.01,.15)],"water")
	for x:float in [-.50,.50]:
		kit.pillar(Vector3(x,.60,0),1.10,"doric")
	kit.beam(Vector3(-.64,1.49,0),Vector3(.70,1.49,0),.07,"wood")
	kit.beam(Vector3(.02,1.47,0),Vector3(.02,.40,0),.012,"rope")
	if covered:
		kit.cover=true
		small_roof(kit,1.67,1.29,1.81)

static func small_roof(kit:Kit,w:float,depth:float,y:float) -> void:
	var add:=Vector3.UP*(depth*.25)
	for sign_:float in [-1,1]:
		var z:=depth*.5*sign_
		kit.tiled_plane(Vector3(-w*.5,y,z),Vector3(w*.5,y,z),Vector3(w*.5,y,0)+add,Vector3(-w*.5,y,0)+add)
	kit.ridge(Vector3(-w*.5,y+.04,0)+add,Vector3(w*.5,y+.04,0)+add,.075)

static func basin(kit:Kit) -> void:
	kit.block(Vector3(0,.065,0),Vector3(1.68,.13,1.35),"brick")
	kit.block(Vector3(0,.14,0),Vector3(1.49,.033,1.18),"water")
	for x:float in [-.8,.8]:kit.block(Vector3(x,.163,0),Vector3(.114,.12,1.40),"ashlar")
	for z:float in [-.66,.66]:kit.block(Vector3(0,.163,z),Vector3(1.69,.12,.106),"ashlar")

static func handmill(kit:Kit) -> void:
	kit.vessel(Vector3.ZERO,[Vector2(.49,.0),Vector2(.52,.19),Vector2(.42,.28),Vector2(.43,.42),Vector2(.32,.66),Vector2(.24,.71),Vector2(.17,.61)],"ashlar")
	kit.vessel(Vector3.ZERO,[Vector2(.31,.46),Vector2(.22,.68),Vector2(.36,.89),Vector2(.39,.94),Vector2(.30,.95),Vector2(.19,.72)],"bedrock")
	kit.beam(Vector3(-.51,.61,0),Vector3(.52,.61,0),.045,"wood")

static func anvil(kit:Kit) -> void:
	kit.vessel(Vector3.ZERO,[Vector2(.23,0),Vector2(.19,.43),Vector2(.15,.45)],"wood",0,10)
	kit.block(Vector3(0,.49,0),Vector3(.46,.13,.25),"iron")
	kit.block(Vector3(0,.59,0),Vector3(.28,.11,.18),"iron")
	kit.block(Vector3(0,.68,0),Vector3(.51,.095,.24),"iron")
	kit.beam(Vector3(-.25,.68,0),Vector3(-.48,.69,0),.099,"iron",.026,7)

static func jeweler(kit:Kit) -> void:
	kit.block(Vector3(0,.74,0),Vector3(1.14,.08,.66),"wood")
	for x:float in [-.45,.45]:
		for z:float in [-.24,.24]:kit.beam(Vector3(x,0,z),Vector3(x,.74,z),.05)
	kit.block(Vector3(.19,.81,-.09),Vector3(.32,.067,.30),"ashlar")
	for i in 5:
		var p:=Vector3(-.33+i*.124,.795,.12)
		kit.vessel(p,[Vector2(.045,.00),Vector2(.043,.02),Vector2(.023,.024),Vector2(.022,.01)],"bronze",0,12)
	kit.beam(Vector3(-.44,.81,-.10),Vector3(-.14,.81,-.24),.017,"iron",.011,6)

static func orchard_tree(kit:Kit) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=4759+kit.variation*817
	var tall:=rng.randf_range(1.60,1.95)
	kit.beam(Vector3.ZERO,Vector3(.07,tall*.64,.02),.119,"wood",.065,9)
	for i in 8:
		var angle:=TAU*i/8+rng.randf_range(-.19,.19)
		var n:=Vector3(sin(angle),0,cos(angle))
		var branch:=n*rng.randf_range(.44,.73)+Vector3.UP*rng.randf_range(tall*.74,tall*1.04)
		kit.beam(Vector3(.06,tall*.52,0),branch,.052,"wood",.024,7)
		for j in 15:
			var p:=branch+Vector3(rng.randf_range(-.27,.27),rng.randf_range(-.20,.26),rng.randf_range(-.27,.27))
			var axis:=Vector3(cos(j),rng.randf_range(-.32,.32),sin(j)).normalized()
			var side:=axis.cross(Vector3.UP)*rng.randf_range(.09,.16)
			var tip:=axis*rng.randf_range(.16,.30)
			var leaf:=kit.builder("leaf")
			leaf.set_color(Color("95a46d").lerp(Color("e7e4af"),rng.randf()))
			Mason.quad(leaf,p-tip,p+side+Vector3.UP*.052,p+tip,p-side,Vector3.UP*.85+n*.35)
		for j in 3:
			var p:=branch+Vector3(rng.randf_range(-.18,.18),rng.randf_range(-.24,-.075),rng.randf_range(-.18,.18))
			kit.vessel(p,[Vector2(.015,0),Vector2(.066,.046),Vector2(.064,.095),Vector2(.018,.114)],"fruit",0,7)

static func charcoal(kit:Kit) -> void:
	kit.vessel(Vector3.ZERO,[Vector2(.59,.0),Vector2(.57,.16),Vector2(.40,.38),Vector2(.18,.49),Vector2(.055,.51)],"charcoal",0,13)
	for i in 9:
		var a:=TAU*i/9
		kit.beam(Vector3(cos(a)*.48,.091,sin(a)*.48),Vector3(cos(a)*.24,.426,sin(a)*.24),.049,"blackwood",.031,6)

static func ore(kit:Kit,kind:String) -> void:
	if kind in ["coppermine","tinmine"]:
		kit.ore_pile(kind=="coppermine")
		return
	for i in 13:
		var p:=Vector3(sin(i*1.72)*.37,.03,cos(i*1.3)*.32)
		var h:=.14+.12*absf(sin(i*8.))
		kit.vessel(p,[Vector2(.17,.0),Vector2(.19,h*.4),Vector2(.13,h*.8),Vector2(.03,h)],"bedrock" if kind!="gem_mine" else "tin",0,7)

static func store_shelter(kit:Kit,backed:bool) -> void:
	for x:float in [-.91,.91]:
		for z:float in [-.55,.55]:kit.pillar(Vector3(x,0,z),1.57,"post")
	if backed:kit.block(Vector3(0,.53,-.56),Vector3(1.93,1.06,.13),"brick")
	kit.cover=true
	small_roof(kit,2.13,1.39,1.64)

static func watchtower(kit:Kit) -> void:
	for x:float in [-.64,.64]:
		for z:float in [-.64,.64]:kit.block(Vector3(x,1.66,z),Vector3(.16,3.32,.16),"wood")
	for z:float in [-.64,.64]:
		kit.beam(Vector3(-.64,.33,z),Vector3(.64,2.13,z),.065)
		kit.beam(Vector3(.64,.33,z),Vector3(-.64,2.13,z),.065)
	for i in 10:
		kit.block(Vector3(-.75+i*.166,2.14,0),Vector3(.16,.095,1.64),"wood")
	for z:float in [-.72,.72]:
		kit.block(Vector3(0,2.49,z),Vector3(1.62,.58,.11),"lime")
		kit.block(Vector3(0,2.83,z),Vector3(1.67,.096,.14),"brick")
	for x:float in [-.72,.72]:kit.block(Vector3(x,2.49,0),Vector3(.10,.58,1.41),"lime")
	for x:float in [-.22,.22]:kit.beam(Vector3(x,0,1.09),Vector3(x,2.21,.70),.041)
	for i in 8:
		var p:=Vector3(0,.20+i*.24,1.06-i*.040)
		kit.beam(p+Vector3.LEFT*.235,p+Vector3.RIGHT*.235,.032)
	kit.cover=true
	small_roof(kit,1.92,1.92,3.46)

static func gateway(kit:Kit,width:float) -> void:
	var half:=width*.5
	var jamb:=minf(.27,width*.10)
	var radius:=half-jamb
	var spring:=1.40
	var rise:=minf(1.35,radius*.78)
	var mid:=Vector3.UP*spring
	for side:float in [-1,1]:
		var p:=Vector3(side*(half-jamb*.5),0,0)
		kit.block(p+Vector3.UP*(spring*.5),Vector3(jamb,spring,.56),"ashlar")
		kit.block(p+Vector3.UP*(spring-.055),Vector3(jamb+.095,.12,.68),"brick")
	kit.arch(mid,Vector3.RIGHT,Vector3.BACK,radius,rise,.22,.60,"brick",15)
	var top:=spring+rise+.19
	for i in 20:
		var t0:=PI*i/20
		var t1:=PI*(i+1)/20
		var a:=Vector3(cos(t0)*radius,spring+sin(t0)*rise,0)
		var b:=Vector3(cos(t1)*radius,spring+sin(t1)*rise,0)
		for z:float in [-.23,.23]:
			var side:=Vector3.BACK*z
			Mason.quad(kit.builder("ashlar"),a+side,b+side,Vector3(b.x,top,z),Vector3(a.x,top,z),side.normalized())
	kit.block(Vector3(0,top+.085,0),Vector3(width+.13,.17,.70),"ashlar")
	kit.block(Vector3(0,top+.20,0),Vector3(width+.20,.07,.76),"tile")
