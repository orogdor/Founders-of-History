extends "res://scripts/bronze_age_map_mesh.gd"
## Provincial town buildings retain the player's rooms, courtyards and workshops at campaign scale.
const LIME := Color("e3d4ad")
const ASHLAR := Color("afa797")
const BRICK := Color("b76b52")
const TILE := Color("ba6550")
const DADO := Color("9a5143")

func ground_color(plan: Dictionary) -> Color:
	return Color("b1a085") if plan.get("ironFamily","") in ["civic","house","trade","scribe"] else Color("a29476")

func add_storey(plan: Dictionary, lift: float) -> void:
	var height := storey_height(plan)
	var cover := str(plan.get("roofForm","hip"))
	var facade := str(plan.get("wallStyle","romanStucco"))
	var color := wall_color(facade)
	var roof_mat := str(plan.get("roofMat","romanTile"))
	var roof_tint := REED if roof_mat in ["reed","thatch"] else ASHLAR.darkened(0.28) if roof_mat in ["slate","stone","tech"] else WOOD if roof_mat in ["wood","plank","shingle"] else TILE
	for room in plan.get("rooms",[]):
		var raw := Plan.room_polygon(room)
		var outline := PackedVector2Array()
		for i in raw.size():
			if room.type != "round" or i%3==0: outline.append(raw[i]/Plan.PX_PER_M)
		if outline.size()<3: continue
		var top := lift + height*float(room.get("heightFactor",1))
		if plan.get("build","wall")=="open":
			for corner in outline: post(corner,lift,top-lift,0.20)
		else:
			prism(outline,lift,top,color)
			prism(expand(outline,0.028),lift,lift+minf(top-lift,.28),ASHLAR)
			if top-lift>1.0 and color==LIME:
				prism(expand(outline,0.014),lift+.27,lift+minf(.80,height*.32),DADO,2)
			if top-lift>1.4:
				prism(expand(outline,0.036),top-.17,top-.05,BRICK if color!=WOOD else ASHLAR,2)
		var overlapped := false
		if is_zero_approx(lift) and plan.get("upper") is Dictionary:
			for upper_room in plan.upper.get("rooms",[]):
				if not Geometry2D.intersect_polygons(raw,Plan.room_polygon(upper_room)).is_empty():
					overlapped=true
					break
		if cover=="none" or overlapped:continue
		var roof := expand(outline,.12)
		if cover=="battlement":
			prism(roof,top,top+.16,ASHLAR)
			for edge in Plan.edges(outline):
				var count:=maxi(1,roundi(edge.a.distance_to(edge.b)/1.0))
				for n in count:
					rail(edge.a.lerp(edge.b,(n+.08)/count),edge.a.lerp(edge.b,(n+.60)/count),.23,top+.12,.35,ASHLAR)
		elif cover in ["flat","terrace","roofTerrace","earthenShed"]:
			shed(roof,top,roof_tint,.03 if cover=="earthenShed" else 0.)
		elif room.type=="rect":
			var box:=Rect2(roof[0],Vector2.ZERO)
			for p in roof: box=box.expand(p)
			var rise:=clampf(minf(box.size.x,box.size.y)*.23,.32,1.55)*float(plan.get("roofHeight",100))/100.0
			tiled_roof(box,top,rise,roof_tint,cover=="hip",color)
		else:
			var center:=Vector2.ZERO
			for p in roof: center+=p
			center/=roof.size()
			for i in roof.size():
				face(v(roof[i],top),v(roof[(i+1)%roof.size()],top),v(center,top+.78),Vector3.UP,roof_tint,1)
	for run in plan.get("wallRuns",[]):
		for i in range(1,run.size()):
			var edge:={"a":Plan.point(run[i-1]),"b":Plan.point(run[i]),"group":"outer"}
			for part in Plan.split_wall(edge,plan):
				if not part.has("type"):rail(part.a/Plan.PX_PER_M,part.b/Plan.PX_PER_M,.18,lift,height,wall_color(part.finish))
	if not plan.get("wallFinishes",[]).is_empty():
		for edge in Plan.plan_geometry(plan).walls:
			if edge.group!="outer":continue
			for part in Plan.split_wall(edge,plan):
				if part.has("type") or part.finish==facade:continue
				rail(part.a/Plan.PX_PER_M,part.b/Plan.PX_PER_M,.10,lift+.04,height-.08,wall_color(part.finish))
	add_openings(plan,lift)

func wall_color(finish:String) -> Color:
	match finish:
		"romanBrick","brick","mudbrick":return BRICK
		"romanTravertine","stone","cutstone","limestone","reticulatum","marble":return ASHLAR
		"wood","plank","halftimber":return WOOD
		"romanRed","fresco":return DADO
	return LIME

func tiled_roof(box: Rect2, height: float, rise: float, tint: Color, hip: bool, end_tint: Color) -> void:
	var along := Vector2.RIGHT if box.size.x>=box.size.y else Vector2.DOWN
	var side := along.orthogonal()
	var center := box.get_center()
	var half_length := maxf(box.size.x,box.size.y)*.5
	var half_width := minf(box.size.x,box.size.y)*.5
	var ridge_half := maxf(.07,half_length-(half_width*.73 if hip else 0.0))
	var ridge_a := center-along*ridge_half
	var ridge_b := center+along*ridge_half
	for sign_:float in [-1.0,1.0]:
		var front := along*half_length
		var a:=center-front+side*half_width*sign_
		var b:=center+front+side*half_width*sign_
		panel(v(a,height),v(b,height),v(ridge_b,height+rise),v(ridge_a,height+rise),Vector3.UP,tint,1)
		rail(a,b,.10,height-.07,.08,tint.darkened(.16))
	for sign_:float in [-1.0,1.0]:
		var end:=center+along*half_length*sign_
		var ridge:=center+along*ridge_half*sign_
		face(v(end-side*half_width,height),v(end+side*half_width,height),v(ridge,height+rise),Vector3.UP if hip else v(along*sign_,0),tint if hip else end_tint,1 if hip else 0)
	rail(ridge_a,ridge_b,.15,height+rise-.045,.09,tint.lightened(.10))

func draw_opening(c: Vector2, axis: Vector2, width: float, base: float, top: float, door: bool, style: String) -> void:
	var half:=width*.5
	if not door:
		rail(c-axis*half,c+axis*half,.075,base,top-base,OPENING)
		rail(c-axis*(half+.07),c+axis*(half+.07),.14,base-.05,.08,ASHLAR)
		return
	var spring:=top-minf(.44,width*.38) if style in ["arch","arched","romanArch","stoneArch"] else top
	rail(c-axis*half,c+axis*half,.14,base,spring-base,OPENING)
	if spring<top:
		var outer:=v(c,spring)
		for i in 7:
			var a:=PI*i/7.
			var b:=PI*(i+1)/7.
			var at:=v(c+axis*(cos(a)*half),spring+sin(a)*(top-spring))
			var bt:=v(c+axis*(cos(b)*half),spring+sin(b)*(top-spring))
			face(outer,bt,at,v(axis.orthogonal(),0),OPENING,2)
	else:
		rail(c-axis*(half+.10),c+axis*(half+.10),.16,top,.13,ASHLAR)

func porch(c: Vector2, axis: Vector2, n: Vector2, width: float, lift: float, top: float, plan: Dictionary) -> void:
	var civic: bool = plan.get("ironFamily","") in ["civic","scribe","trade"]
	var half := width*.5+(.80 if civic else .30)
	var projection := 1.10 if civic else .77
	var front := c+n*projection
	var columns:=4 if civic and width>1.30 else 2
	for i in columns:
		var p:=front+axis*lerpf(-half,half,float(i)/(columns-1))
		round_taper(p,lift,.13,.19,.19,ASHLAR)
		round_taper(p,lift+.13,top-lift-.21,.145,.115,LIME)
		round_taper(p,top-.08,.16,.15,.20,ASHLAR)
	rail(front-axis*(half+.13),front+axis*(half+.13),.24,top+.05,.18,LIME)
	var footprint:=PackedVector2Array([c-axis*(half+.27),c+axis*(half+.27),front+axis*(half+.27)+n*.16,front-axis*(half+.27)+n*.16])
	shed(footprint,top+.25,TILE,.12)

func fixture(id: String,p: Vector2,kind: String) -> void:
	match id:
		"romanColumn":
			round_taper(p,0,.15,.24,.24,ASHLAR)
			round_taper(p,.15,1.70,.16,.13,LIME)
			round_taper(p,1.85,.20,.17,.23,LIME)
		"romanBasin","basin":
			prism(rect(p,1.45,1.0),.01,.17,ASHLAR)
			prism(rect(p,1.23,.79),.17,.18,Color("698d8e"),0)
		"stall","romanTaberna","periodMarket":
			shelter(p,1.60,1.20,1.51,CLOTH)
			for i in 3:
				var q:=p+Vector2((i-1)*.49,0)
				shed(rect(q,.22,1.18),1.525,DADO,.12)
			prism(rect(p+Vector2(0,.35),1.40,.55),.03,.63,WOOD)
		"waterwheel":
			mill_wheel(p)
		"forge","furnace","bronzeHearth","periodForge","kiln","oven":
			var h:=1.7 if id in ["furnace","forge","bronzeHearth"] else 1.05
			round_taper(p,0,.32,.67,.71,ASHLAR)
			round_taper(p,.32,h,.71,.27,BRICK)
			round_taper(p,h+.32,.09,.22,.17,OPENING)
			prism(rect(p+Vector2(0,.62),.39,.08),.15,.52,OPENING)
		"anvil","ingots","ironIngots","workbench","bronzeToolBench","romanJeweler":
			prism(rect(p,.81,.53),.02,.56,WOOD)
			prism(rect(p,.91,.63),.56,.67,Color("585656") if id=="anvil" else ASHLAR,2)
		"charcoalPile","charcoal","coalPile","charcoalMound","clamp":
			round_taper(p,.02,.64,1.06,.58,Color("595751"))
			round_taper(p,.66,.22,.58,.15,Color("514c43"))
		"bridgeSpan":
			rail(p-Vector2(1.8,0),p+Vector2(1.8,0),.96,.70,.24,ASHLAR)
			for side:float in [-1.,1.]:
				rail(p+Vector2(-1.8,side*.47),p+Vector2(1.8,side*.47),.12,.94,.22,ASHLAR)
			for x:float in [-1.67,0.,1.67]:
				prism(rect(p+Vector2(x,0),.32,1.02),.02,.70,ASHLAR)
		"bronzeBoat","romanBoat":
			super.fixture("bronzeBoat",p,kind)
			post(p,0.25,1.73,.09)
			prism(rect(p-Vector2(0,.1),1.12,.06),.98,1.82,CLOTH,2)
		"archGate":
			stone_arch(p)
		"millstone","quern":
			round_taper(p,0,.30,.43,.46,ASHLAR)
			round_taper(p,.30,.18,.37,.27,ASHLAR.darkened(.19))
		"cart","wheelParts","catapult":
			prism(rect(p,1.58,.69),.24,.54,WOOD,2)
			for offset:float in [-.53,.53]:
				for side:float in [-.38,.38]:
					var c:=p+Vector2(offset,side)
					var spoke_center:=v(c,.28)
					for i in 8:
						var a:=TAU*i/8.
						var b:=TAU*(i+1)/8.
						face(spoke_center,spoke_center+Vector3(cos(a),sin(a),0)*.27,spoke_center+Vector3(cos(b),sin(b),0)*.27,Vector3.BACK,WOOD.darkened(.20),2)
			if id=="catapult":
				prism(rect(p+Vector2(-.34,0),.27,.58),.5,1.05,WOOD)
				panel(v(p+Vector2(-.65,-.12),.70),v(p+Vector2(-.65,.12),.70),v(p+Vector2(.84,.12),1.68),v(p+Vector2(.84,-.12),1.68),Vector3.UP,WOOD,2)
		"jewelBench","sawBench","desk","table","breadBoard":
			prism(rect(p,1.0,.47),.03,.54,WOOD,2)
			prism(rect(p,1.14,.59),.54,.65,ASHLAR if id=="jewelBench" else WOOD.lightened(.14),2)
		"gems":
			for i in 3:round_taper(p+Vector2(i*.19-.19,0),.05,.25,.17,.03,Color("698d81"),2)
		"jar","barrel","basket":
			round_taper(p,.02,.28,.19,.27,BRICK if id=="jar" else WOOD,2)
			round_taper(p,.30,.18,.27,.16,BRICK if id=="jar" else WOOD,2)
		"loom":
			for side:float in [-.42,.42]:post(p+Vector2(side,0),.02,1.34,.11)
			prism(rect(p,.76,.08),.38,1.20,CLOTH,2)
		"crate","chest","grain":
			prism(rect(p,.61,.51),.01,.47,REED if id=="grain" else WOOD,2)
		"horse","horsePen":
			prism(rect(p,.48,.88),.58,.99,Color("89664c"))
			round_taper(p+Vector2(0,.35),.89,.42,.21,.13,Color("89664c"))
		_:
			super.fixture(id,p,kind)

func stone_arch(p:Vector2) -> void:
	const R_IN:=.72
	const R_OUT:=1.09
	const SPRING:=1.04
	for side:float in [-1.,1.]:
		prism(rect(p+Vector2(side*(R_IN+R_OUT)*.5,0),R_OUT-R_IN,.81),0,SPRING,ASHLAR)
	for i in 9:
		var a:=PI*i/9.
		var b:=PI*(i+1)/9.
		var outer_a:=Vector3(p.x+cos(a)*R_OUT,SPRING+sin(a)*R_OUT,p.y)
		var outer_b:=Vector3(p.x+cos(b)*R_OUT,SPRING+sin(b)*R_OUT,p.y)
		var inner_a:=Vector3(p.x+cos(a)*R_IN,SPRING+sin(a)*R_IN,p.y)
		var inner_b:=Vector3(p.x+cos(b)*R_IN,SPRING+sin(b)*R_IN,p.y)
		var depth:=Vector3.BACK*.41
		var tint:=ASHLAR.lightened(.08 if i%2==0 else 0.)
		for side:float in [-1.,1.]:
			panel(inner_a+depth*side,inner_b+depth*side,outer_b+depth*side,outer_a+depth*side,Vector3.BACK*side,tint,0)
		panel(outer_a-depth,outer_b-depth,outer_b+depth,outer_a+depth,Vector3(cos((a+b)*.5),sin((a+b)*.5),0),tint,0)
		panel(inner_a-depth,inner_b-depth,inner_b+depth,inner_a+depth,Vector3(-cos((a+b)*.5),-sin((a+b)*.5),0),tint,0)

func mill_wheel(p: Vector2) -> void:
	var center:=Vector3(p.x,.91,p.y)
	for i in 12:
		var a:=TAU*i/12.
		var b:=TAU*(i+1)/12.
		var dir_a:=Vector3(0,cos(a),sin(a))
		var dir_b:=Vector3(0,cos(b),sin(b))
		for x:float in [-.22,.22]:
			var offset:=center+Vector3.RIGHT*x
			panel(offset+dir_a*.81,offset+dir_b*.81,offset+dir_b*.99,offset+dir_a*.99,Vector3.RIGHT,WOOD,2)
			if i%2==0:
				face(offset-dir_b*.08,offset+dir_a*.87,offset+dir_b*.08,Vector3.RIGHT,WOOD,2)
		panel(center+dir_a*.96-Vector3.RIGHT*.23,center+dir_a*.96+Vector3.RIGHT*.23,center+dir_b*.99+Vector3.RIGHT*.23,center+dir_b*.99-Vector3.RIGHT*.23,dir_a,WOOD,2)

func barrier(f: Dictionary, kind: String) -> void:
	if f.kind not in ["highStone","rampart","stoneLine"]:
		super.barrier(f,kind)
		return
	var a:=Plan.point(f.a)/Plan.PX_PER_M
	var b:=Plan.point(f.b)/Plan.PX_PER_M
	var h:=2.20 if f.kind=="highStone" else 1.55 if f.kind=="rampart" or kind=="stonewall" else .54
	var width:=.63 if h>1.0 else .33
	rail(a,b,width,0,h,ASHLAR)
	rail(a,b,width+.04,h*.48,.12,BRICK)
	rail(a,b,width+.07,h-.09,.13,ASHLAR.lightened(.09))
	if f.kind=="highStone":
		var n:=maxi(1,roundi(a.distance_to(b)/1.05))
		for i in n:
			rail(a.lerp(b,(i+.05)/n),a.lerp(b,(i+.55)/n),width*.58,h+.04,.31,ASHLAR)

