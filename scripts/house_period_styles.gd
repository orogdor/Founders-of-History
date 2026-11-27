extends RefCounted
## Shared art direction for all views, with legacy saved room geometry kept.
const Defaults=preload("res://data/house_default_designs.json")
const Plan=preload("res://scripts/house_plan_geometry.gd")
const Catalogue=preload("res://data/house_editor_catalog.json")
const BronzePlans=preload("res://scripts/bronze_age_plans.gd")
const IronPlans=preload("res://scripts/iron_age_plans.gd")
const Production=preload("res://scripts/production_bonuses.gd")

const NAMES := {
	"aegeanStone":"Mükeene suurkivi", "aegeanPlaster":"Soe lubikrohv",
	"aegeanBlue":"Egeuse sinine", "aegeanFrieze":"Maalitud friis", "aegeanRed":"Punane maalitud puit", "aegeanSlab":"Liivakiviplaat",
	"romanBrick":"Rooma õhuke tellis", "romanTravertine":"Travertiin", "romanStucco":"Rooma krohv",
	"romanRed":"Pompei punane", "romanTile":"Rooma katusekivi", "romanMosaic":"Kivimosaiik",
	"norseTimber":"Tume viikingilaudis", "norseShingle":"Lõhestatud puitsindel", "medievalMasonry":"Keskaegne kivimüür",
	"medievalLime":"Lubjatud sõrestik", "norsePaint":"Madarapunane puit",
	"lappedPine":"Horisontaalne laudis", "navalPlank":"Sadamalaudis", "maritimePaint":"Sinakashall värvitud laudis",
	"portBrick":"Sadama tellis", "slate":"Kiltkivi", "millBrick":"Vabrikutellis", "sootBrick":"Tahmunud tellis",
	"corrugation":"Laineplekk", "castIron":"Malm", "khakiCanvas":"Present",
	"boardConcrete":"Rakisejäljega betoon", "darkCladding":"Tume fassaadipaneel",
	"membrane":"Katusekate", "metalTrim":"Anodeeritud metall", "modernCedar":"Seedripuit",
	"pavingSetts":"Sillutuskivi", "aegeanGravel":"Egeuse kruus", "romanBasalt":"Rooma basalttee",
	"railBallast":"Raudteekillustik", "asphalt":"Asfalt",
	"cutClay":"Kuiv savikiht", "dampClay":"Niiske savikiht",
}

const WALLS := [
	[],["aegeanStone","aegeanPlaster","aegeanBlue","aegeanFrieze","aegeanRed","aegeanSlab"],
	["romanBrick","romanTravertine","romanStucco","romanRed","romanMosaic"],
	["norseTimber","medievalMasonry","medievalLime","norsePaint"],
	["lappedPine","navalPlank","maritimePaint","portBrick","romanTravertine"],
	["millBrick","sootBrick","corrugation","castIron","khakiCanvas"],
	["boardConcrete","darkCladding","metalTrim","modernCedar","romanStucco"],
]

const ROOM_FLOORS := ["floor","aegeanSlab","romanMosaic","norseTimber","navalPlank","lappedPine","boardConcrete"]

const ROOFS := [
	[],["romanTile","aegeanSlab"],["romanTile","aegeanSlab"],
	["norseShingle","slate"],["slate","norseShingle","corrugation"],
	["slate","corrugation","khakiCanvas"],["membrane","darkCladding","metalTrim"],
]

const CIVIC := ["hall","academy","study","library","school","public_school","high_school","university","polytechnic","guildhall","chapel","monastery","observatory","market","printer","scriptorium"]
const COUNTRYSIDE := ["house","hunter","farm","lumber","forester","dairy","fisher","stable","bakery","windmill","watermill","saw"]
const INDUSTRY := ["steelworks","engineworks","smelter","smith","powdermill","powerplant","autofactory","refinery","electronics_factory","laboratory","railstation","airfield","chocolatier","master_workshop"]
const COAST := ["fisher","harbor","warehouse","trade_yard","road_depot"]
const MILITARY := ["barracks","archery","stable","armor_workshop","crossbow_range","siegeworkshop"]
const DEFENSE := ["keep","stonewall","reinforced_wall","watchtower","stonetower","gatehouse","woodgate","palisade"]
const EXTRACTION := ["claypit","quarry","coppermine","tinmine","mine","gem_mine","coal","nitrate"]
const ARTWORK := [
	"","Egeuse pronksiaeg","Rooma linnad","Keskaeg ja viikingid",
	"Napoleoni aeg, kodusõda ja kaaperdajad","Tööstus ja Esimese maailmasõja aeg","Tänapäev",
]

const DETAIL_MATERIALS := [
	{},
	{"stone":"aegeanStone","cutstone":"aegeanSlab","marble":"aegeanSlab","minoanRed":"aegeanRed","plaster":"aegeanPlaster"},
	{"stone":"romanTravertine","cutstone":"romanTravertine","brick":"romanBrick","plaster":"romanStucco","tile":"romanTile","marble":"romanTravertine"},
	{"wood":"norseTimber","stone":"medievalMasonry","cutstone":"medievalMasonry","plaster":"medievalLime"},
	{"wood":"navalPlank","stone":"pavingSetts","cutstone":"romanTravertine","plaster":"romanStucco","brick":"portBrick"},
	{"brick":"millBrick","stone":"pavingSetts","cutstone":"sootBrick","metal":"castIron","ironTrim":"castIron"},
	{"metal":"metalTrim","ironTrim":"metalTrim","stone":"boardConcrete","cutstone":"boardConcrete","wood":"modernCedar"},
]
const SAVED_FINISHES := {
	"clay":"plaster","mudbrick":"brick","cyclopean":"stone","cutstone":"stone","limestone":"stone",
	"reticulatum":"stone","marble":"stone","prestigePlaster":"plaster","fresco":"plaster","halftimber":"plaster",
	"plank":"wood","stave":"wood","roofplank":"wood",
}
const SURFACE_GROUPS := [
	{},
	{"stone":"aegeanStone","plaster":"aegeanPlaster","brick":"aegeanSlab","wood":"aegeanRed","tile":"romanTile","shingle":"norseShingle"},
	{"stone":"romanTravertine","plaster":"romanStucco","brick":"romanBrick","wood":"navalPlank","tile":"romanTile","shingle":"norseShingle"},
	{"stone":"medievalMasonry","plaster":"medievalLime","brick":"medievalMasonry","wood":"norseTimber","tile":"slate","shingle":"norseShingle"},
	{"stone":"pavingSetts","plaster":"romanStucco","brick":"portBrick","wood":"navalPlank","tile":"slate","shingle":"slate"},
	{"stone":"pavingSetts","plaster":"romanStucco","brick":"millBrick","wood":"lappedPine","tile":"slate","shingle":"slate"},
	{"stone":"boardConcrete","plaster":"romanStucco","brick":"portBrick","wood":"modernCedar","tile":"membrane","shingle":"membrane"},
]

static func detail_material(style: String,age: int) -> String:
	return str(DETAIL_MATERIALS[clampi(age,0,6)].get(style,style))

static func saved_surface(style: String,age: int) -> String:
	var group: String=SAVED_FINISHES.get(style,style)
	return str(SURFACE_GROUPS[age].get(group,detail_material(style,age)))

static var plans: Dictionary={}

static func campaign_age(state: Dictionary,team: int) -> int:
	var ages: Array=state.get("ages",[])
	if team>=0 and team<ages.size():
		return clampi(int(ages[team]),0,6)
	var research: Array=state.get("research",[])
	return Production.upgrade_level(state,team) if team>=0 and team<research.size() else 0

static func age_of(id: String) -> int:
	return clampi(int(Catalogue.data.catalog.get(id,{}).get("era",0)),0,6)

static func texture_family(style: String) -> String:
	return "period_"+style if NAMES.has(style) else ""

static func portrait_path(id: String) -> String:
	if id.is_empty() or age_of(id)==0:
		return ""
	var path:="res://assets/house_designer/period_portraits/"+id+".jpg"
	return path if ResourceLoader.exists(path) else ""

static func label_for(style: String) -> String:
	return NAMES.get(style,style)

static func wall_choices(age: int) -> Array:
	return WALLS[age]+Catalogue.data.ERA_WALLS[age]

static func designer_id(kind: String,age: int) -> String:
	for era in range(clampi(age,0,6),0,-1):
		var key:=kind+"@"+str(era)
		if Defaults.data.has(key):
			return key
	return kind if Defaults.data.has(kind) else ""

static func get_plan(id: String) -> Dictionary:
	if not Defaults.data.has(id):
		return {}
	var source: Dictionary=Defaults.data[id]
	var age:=age_of(id)
	if age==0:
		return source
	if not plans.has(id):
		var plan:=source.duplicate(true)
		style_plan(plan,id.get_slice("@",0),age)
		plans[id]=plan
	return plans[id]

static func coast_yaw(design: Dictionary) -> float:
	var pier: Variant=design.get("pier")
	if int(design.get("periodStyle",0))<=0 or not pier is Dictionary:
		return 0.0
	var start:=Plan.point(pier.a)
	var end:=Plan.point(pier.b)
	var inland_center:=Vector2.ZERO
	var rooms: Array=design.get("rooms",[])
	var count:=0
	for room_def in rooms:
		for vertex in Plan.room_polygon(room_def):
			inland_center+=vertex
			count+=1
	if count>0:
		inland_center/=count
	else:
		inland_center=Vector2(480,312)
	var water_direction: Vector2=end-start if end.distance_squared_to(inland_center)>=start.distance_squared_to(inland_center) else start-end
	return PI-atan2(water_direction.x,water_direction.y) if water_direction.length_squared()>0.001 else 0.0

static func point(x: float,y: float) -> Dictionary:
	return {"x":x,"y":y}

static func room(ax: float,ay: float,bx: float,by: float) -> Dictionary:
	return {"type":"rect","a":point(ax,ay),"b":point(bx,by)}

static func opening(kind: String,x: float,y: float,style: String) -> Dictionary:
	return {"type":kind,"group":"outer","point":point(x,y),"style":style}

static func item(kind: String,x: float,y: float) -> Dictionary:
	return {"type":kind,"point":point(x,y)}

static func frontage(plan: Dictionary, styles: Array) -> void:
	for entry in plan.get("openings",[]):
		if entry.get("group","")!="outer":
			continue
		if entry.get("type","")=="door" and not styles[0].is_empty():
			entry["style"]=styles[0]
		elif entry.get("type","")=="window" and not styles[1].is_empty():
			entry["style"]=styles[1]

static func style_plan(plan: Dictionary,kind: String,age: int) -> void:
	plan["periodStyle"]=age
	var roof: String
	var wall: String
	var shape: String
	var upper: Variant=plan.get("upper")
	var open_site: bool=plan.get("rooms",[]).is_empty()
	var special_roof: bool=plan.get("build","wall")=="tower" or plan.get("roofForm","") in ["battlement","none"]
	match age:
		1:
			if kind == "house":
				make_aegean_house(plan)
			else:
				BronzePlans.apply(plan, kind)
			return
		2:
			IronPlans.apply(plan, kind)
			return
		3:
			var longhouse:=kind in COUNTRYSIDE+MILITARY+["hall"] and not plan.get("pier") is Dictionary
			wall="norseTimber" if longhouse else "medievalMasonry" if kind in DEFENSE+["chapel","monastery"] else "medievalLime"
			roof="norseShingle" if longhouse else "slate"
			shape="norse" if longhouse else "gable"
			if kind in ["house","hall","barracks","stable","farm"] and longhouse:
				make_longhouse(plan,kind)
				upper=null
			elif longhouse:
				plan["roofHeight"]=118
			elif kind=="chapel":
				plan["roofHeight"]=150
		4:
			var maritime:=kind in COAST
			wall="navalPlank" if maritime else "portBrick" if kind in DEFENSE+MILITARY+INDUSTRY+["market","printer"] else "romanTravertine" if kind in CIVIC else "lappedPine"
			roof="norseShingle" if maritime else "slate"
			shape="pediment" if kind in ["hall","academy","guildhall","university","public_school"] else "gable" if maritime or kind in MILITARY else "hip"
			if shape=="pediment" and not special_roof:
				plan["porch"]="front"
				plan["columns"]="doric"
				plan["base"]="steps"
			if kind in CIVIC+["house","inn","barracks"]:
				frontage(plan,["double","sash"])
			elif maritime:
				frontage(plan,["double","shutter"])
		5:
			var industrial:=kind in INDUSTRY
			wall="millBrick" if industrial or kind in CIVIC+["house","inn"] else "sootBrick" if kind in DEFENSE+MILITARY else "lappedPine"
			roof="corrugation" if industrial or kind in MILITARY else "slate"
			shape="sawtooth" if kind in ["steelworks","engineworks","refinery","powerplant","autofactory","electronics_factory","master_workshop"] else "gable"
			if kind in ["barracks","crossbow_range","powdermill"]:
				shape="barrelRoof"
				roof="corrugation"
			if industrial or kind in CIVIC:
				frontage(plan,["double","factoryWindow"])
			elif kind=="house":
				frontage(plan,["","sash"])
		_:
			wall="darkCladding" if kind in INDUSTRY+COAST else "boardConcrete"
			roof="membrane"
			shape="roofTerrace"
			if kind in ["house","inn","market"]:
				wall="modernCedar"
			if kind in INDUSTRY+COAST+CIVIC+["house","inn","market","barracks"]:
				frontage(plan,["double","pictureWindow" if kind in ["market","laboratory","university","high_school","public_school","polytechnic","infirmary"] else "glazed"])
	plan["wallStyle"]=wall
	if not special_roof and not open_site:
		plan["roofMat"]=roof
		plan["roofForm"]=shape
	if age>=4 and shape not in ["flat","pediment"]:
		plan["porch"]="none"
	if upper is Dictionary:
		upper["wallStyle"]="boardConcrete" if age==6 else wall
		upper["roofMat"]=roof
		upper["roofForm"]=shape
		upper["porch"]="none"
		upper["base"]="none"
		if age>=4:
			frontage(upper,["","glazed" if age==6 else "sash"])
	# Keep modern additions and historic wall finishes distinct from the
	# textures found in the old blueprints.
	if kind=="house":
		match age:
			4: make_officers_house(plan)
			5: make_industrial_house(plan)
			6: make_modern_house(plan)
	add_architecture(plan,kind,age)
	decorate_workplace(plan,kind,age)

static func make_longhouse(plan: Dictionary,kind: String) -> void:
	var wide:=kind in ["hall","barracks"]
	var left:=185.0 if wide else 218.0
	var right:=775.0 if wide else 742.0
	var top:=165.0 if wide else 180.0
	var bottom:=458.0 if wide else 443.0
	plan["rooms"]=[room(left,top,right,bottom)]
	plan["inner"]=[]
	plan["openings"]=[opening("door",480,bottom,"double"),opening("door",right,(top+bottom)/2.0,"plank")]
	plan["yard"]=[point(left-60,top-53),point(right+60,top-53),point(right+60,bottom+70),point(left-60,bottom+70)]
	plan["wallRuns"]=[]
	plan["wallFinishes"]=[]
	plan["base"]="none"
	plan["porch"]="none"
	plan["wallScale"]=110 if wide else 103
	plan["roofHeight"]=132 if wide else 120
	plan.erase("upper")
	plan.erase("courtyardStyle")
	plan["items"]=[item("norseHearth",479,(top+bottom)/2.0),item("norseSleepingBench",350,top+48),
		item("norseSleepingBench",609,top+48),item("bench",left+80,bottom-78),item("chest",right-84,bottom-73)]
	if kind in ["farm","stable"]:
		plan["items"].append(item("trough",right-75,top+55))
	elif kind in ["house","hall"]:
		plan["items"].append(item("norseLoom",480,top+39))

static func set_house(plan: Dictionary, rooms: Array, entrances: Array, yard: Array, things: Array) -> void:
	plan["rooms"]=rooms
	plan["inner"]=[]
	plan["openings"]=entrances
	plan["yard"]=yard
	plan["items"]=things
	plan["fences"]=[]
	plan["wallRuns"]=[]
	plan["wallFinishes"]=[]
	plan["porch"]="none"
	plan.erase("upper")
	plan.erase("courtyardStyle")
	plan.erase("bronzePrestige")

static func make_aegean_house(plan: Dictionary) -> void:
	var store:=room(590,157,744,369)
	store.heightFactor=0.72
	var passage:=opening("door",590,265,"plank")
	passage.group="inner"
	set_house(plan,[room(216,125,590,411),store],
		[opening("door",443,411,"timberLintel"),opening("window",295,411,"hole"),
		opening("window",665,369,"hole"),opening("window",216,230,"hole"),passage],
		[point(180,104),point(786,104),point(786,558),point(180,558)],
		[item("bed",312,179),item("fire",469,216),item("periodHearthKit",530,171),
		item("basket",687,210),item("jar",657,306),
		item("saddleQuern",621,415),item("householdJar",678,408),item("householdJar",728,425)])
	plan.inner=[{"a":point(590,157),"b":point(590,369)}]
	plan.fences=[
		{"kind":"stoneLine","a":point(197,412),"b":point(197,540)},
		{"kind":"stoneLine","a":point(197,540),"b":point(389,540)},
		{"kind":"stoneLine","a":point(497,540),"b":point(769,540)},
		{"kind":"stoneLine","a":point(769,540),"b":point(769,369)}]
	plan.wallStyle="aegeanPlaster"
	plan.wallScale=155
	plan.roofForm="earthenShed"
	plan.roofMat="earth"
	plan.base="plinth"
	plan.columns="post"
	plan.periodOrnament="aegeanHousehold"

static func make_officers_house(plan: Dictionary) -> void:
	set_house(plan,[room(252,169,708,413),room(562,120,708,169)],
		[opening("door",481,413,"double"),opening("window",335,413,"sash"),opening("window",625,413,"sash"),
		opening("window",252,292,"sash"),opening("window",708,290,"sash"),
		opening("window",421,169,"sash"),opening("window",641,120,"sash")],
		[point(183,87),point(775,87),point(775,544),point(183,544)],
		[item("bed",336,225),item("table",536,296),item("hearthStove",654,212),item("bench",325,479),
		item("barrel",750,463),item("desk",663,138)])
	plan["wallStyle"]="lappedPine"
	plan["roofForm"]="hip"
	plan["roofMat"]="slate"
	plan["roofHeight"]=124
	plan["wallScale"]=129

static func make_industrial_house(plan: Dictionary) -> void:
	set_house(plan,[room(210,158,750,431),room(527,104,750,158)],
		[opening("door",292,431,"plank"),opening("window",403,431,"sash"),opening("window",561,431,"sash"),
		opening("door",667,431,"plank"),opening("window",318,158,"sash"),opening("window",634,104,"sash"),
		opening("window",750,301,"sash")],
		[point(151,59),point(804,59),point(804,507),point(151,507)],
		[item("hearthStove",449,213),item("hearthStove",644,215),item("bed",290,231),item("table",579,320),
		item("bench",503,491),item("workerChimney",658,163),item("workerChimney",405,158)])
	plan["inner"]=[{"a":point(487,158),"b":point(487,431)}]
	plan["wallStyle"]="millBrick"
	plan["roofMat"]="slate"
	plan["roofForm"]="gable"
	plan["roofHeight"]=129
	plan["wallScale"]=139

static func make_modern_house(plan: Dictionary) -> void:
	set_house(plan,[room(205,156,501,444),room(501,156,754,359)],
		[opening("door",477,444,"plank"),opening("window",308,444,"pictureWindow"),opening("window",205,290,"glazed"),
		opening("window",617,359,"pictureWindow"),opening("window",754,252,"glazed"),
		opening("door",615,156,"double")],
		[point(142,87),point(817,87),point(817,537),point(142,537)],
		[item("bed",306,242),item("table",410,317),item("desk",658,239),item("bench",644,409),item("modernPlanter",759,427)])
	plan["wallStyle"]="boardConcrete"
	plan["roofForm"]="roofTerrace"
	plan["roofMat"]="membrane"
	plan["wallScale"]=129
	plan["wallFinishes"]=[
		{"group":"outer","a":point(205,444),"b":point(501,444),"finish":"modernCedar"}
	]

static func add_architecture(plan: Dictionary,kind: String,age: int) -> void:
	# Additional ornaments do not replace the designer's interactive items.
	# They are placed from the edited plan by HousePeriodDetails.
	if age==3 and kind in COUNTRYSIDE+MILITARY+["hall"]:
		plan["periodOrnament"]="norse"
	elif age==3 and kind in ["chapel","monastery"]:
		plan["items"].append(item("medievalBelfry",335,244))
	elif age==4 and kind in COAST:
		plan["periodOrnament"]="dock"
		if kind in ["harbor","warehouse"]:
			var cargo: Array=[]
			for entry in plan["items"]:
				if str(entry.get("type","")).begins_with("bronze"):
					if entry.type in ["bronzeCargo","bronzeNet"]:
						cargo.append({"type":"crate" if entry.type=="bronzeCargo" else "net","point":entry.point})
				else:
					cargo.append(entry)
			plan["items"]=cargo
			plan["items"].append(item("dockCrane",681,458))
			plan["items"].append(item("barrel",681,519))
	elif age==4 and kind in ["house","inn","barracks","stable","hall"]:
		plan["periodOrnament"]="veranda"
	elif age==4 and kind in ["academy","guildhall","university","public_school"]:
		plan["items"].append(item("civicClock",480,275))
	elif age==5 and kind in MILITARY+DEFENSE:
		plan["periodOrnament"]="camp"
		if kind in ["barracks","archery","crossbow_range"]:
			plan["items"].append(item("canvasShelter",656,464))
	elif age==5 and kind in INDUSTRY:
		plan["periodOrnament"]="factory"
		if kind=="railstation":
			plan["items"].append(item("civicClock",480,295))
	elif age==6 and kind in CIVIC+INDUSTRY+["house","market","inn","barracks"]:
		plan["periodOrnament"]="modern"
		plan["items"]=plan.get("items",[]).filter(func(entry):return entry.get("type","")!="factoryChimney" or kind in ["powerplant","steelworks","refinery"])


static func scaled_location(plan: Dictionary,kind: String,u: float,v: float) -> Dictionary:
	for floor in plan.get("rooms",[]):
		if floor.get("type","")=="rect":
			var a:=Plan.point(floor.a)
			var b:=Plan.point(floor.b)
			return item(kind,lerpf(a.x,b.x,u),lerpf(a.y,b.y,v))
		var outline:=Plan.room_polygon(floor)
		if outline.size()>0:
			var center:=Vector2.ZERO
			for vertex in outline:center+=vertex
			center/=outline.size()
			return item(kind,center.x+0.8,center.y-35.0)
	return item(kind,490,318)

static func decorate_workplace(plan: Dictionary,kind: String,age: int) -> void:
	if age>=5 and kind in EXTRACTION:
		for entry in plan["items"]:
			if entry.type=="canopy":
				entry.type="siteShelter"
			elif age==6 and entry.type=="cart":
				entry.type="wheelLoader"
	if age==3 and kind in ["weaver","silk_weaver"]:
		plan["items"].append(scaled_location(plan,"norseLoom",0.76,0.30))
	elif age==4 and kind in ["harbor","warehouse","trade_yard"]:
		if kind=="warehouse":
			plan["items"].append(scaled_location(plan,"navalBales",0.52,0.62))
			plan["items"].append(scaled_location(plan,"navalBales",0.26,0.48))
		else:
			plan["items"].append(item("navalBales",670,404))
	elif age==5 and kind in ["steelworks","engineworks","powerplant","master_workshop","refinery","autofactory","electronics_factory"]:
		plan["items"].append(scaled_location(plan,"factoryLathe",0.49,0.38))
		plan["items"].append(scaled_location(plan,"factorySwitchboard",0.17,0.50))
		plan["items"].append(scaled_location(plan,"factoryDrive",0.77,0.35))
		frontage(plan,["loadingDoor",""])
	elif age==6:
		if kind in ["laboratory","polytechnic","infirmary","public_school","high_school","research"]:
			var replaced:=["bench","table","desk","chest","workbench","shelf","jar"]
			plan["items"]=plan.get("items",[]).filter(func(entry):return entry.get("type","") not in replaced)
			plan["items"].append(scaled_location(plan,"labStation",0.72,0.44))
			plan["items"].append(scaled_location(plan,"labStation",0.48,0.70))
			plan["items"].append(scaled_location(plan,"labCabinet",0.22,0.20))
		if kind in ["warehouse","autofactory","airfield","harbor","electronics_factory","refinery"]:
			plan["items"].append(scaled_location(plan,"loadingPallet",0.77,0.48))
			frontage(plan,["loadingDoor",""])
		if kind=="airfield":
			plan["items"].append(item("airfieldPlane",662,514))
		if kind=="powerplant":
			plan["items"]=plan["items"].filter(func(entry):return entry.type not in ["furnace","wheelParts","coalPile"])
			plan["items"].append(item("substation",775,468))
		if kind=="refinery":
			plan["items"]=plan["items"].filter(func(entry):return entry.type not in ["furnace","storageTank"])
			plan["items"].append(item("processVessels",785,349))
