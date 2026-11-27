extends SceneTree
const Period=preload("res://scripts/house_period_styles.gd")
const Detail=preload("res://scripts/detail_view.gd")
const Model=preload("res://scripts/house_plan_model.gd")
const Painted=preload("res://scripts/painted_building_materials.gd")
const Plan=preload("res://scripts/house_plan_geometry.gd")
const PlanCollision=preload("res://scripts/house_plan_collision.gd")
const Contacts=preload("res://scripts/house_collision.gd")
const LOD=preload("res://scripts/house_period_city_lod.gd")
const Ships=preload("res://scripts/period_ship_visuals.gd")
const Freight=preload("res://scripts/period_freight_visuals.gd")
const Lights=preload("res://scripts/detail_lights.gd")
const Paths=preload("res://scripts/detail_period_path_materials.gd")
const Rails=preload("res://scripts/detail_period_rail.gd")
const Grid=preload("res://scripts/campaign_grid.gd")
const Rules=preload("res://data/build_rules.json")
const Economy=preload("res://data/economy.json")
const People=preload("res://scripts/human_factory.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	assert(Period.campaign_age({"ages":[1],"research":[{"known":[]}]},0)==1)
	assert(Period.campaign_age({"ages":[3],"research":[{"known":["iron_crafts"]}]},0)==3)
	assert(Period.campaign_age({"research":[{"known":["bronze_crafts"]}]},0)==1)
	assert(Period.get_plan("house")==Period.Defaults.data.house)
	assert(not Period.get_plan("house").has("periodStyle"))
	var old_plan: Dictionary=Period.Defaults.data["house@5"].duplicate(true)
	var old_geometry:=PlanCollision.walls(old_plan)
	var edited:=Model.new()
	edited.rebuild(old_plan,3)
	assert(edited.material_for("brick").albedo_texture==Painted.texture("period_millBrick",3))
	assert(not old_plan.has("periodStyle") and PlanCollision.walls(old_plan)==old_geometry)
	edited.free()
	var cases := [
		["hall",1,"aegeanPlaster","BronzePorch"],
		["house",1,"aegeanPlaster","DwellingDoorTimbers"],
		["house",2,"romanStucco","RoofDeck"],
		["house",3,"norseTimber","RoofTrim"],
		["harbor",4,"navalPlank","PeriodShip"],
		["steelworks",5,"millBrick","RoofClerestory"],
		["barracks",5,"sootBrick","RoofGableEnds"],
		["laboratory",6,"darkCladding","SolarPanel"],
	]
	var detail:=Detail.new()
	for entry in cases:
		var kind: String=entry[0]
		var age: int=entry[1]
		var plan:=Period.get_plan(Detail.designer_id(kind,age))
		assert(plan.wallStyle==entry[2],kind)
		assert(int(plan.periodStyle)==age,kind)
		var model:=detail.create_designed_building(kind,age,{},1,4)
		assert(model!=null and model.find_child(entry[3],true,false)!=null,kind)
		model.free()
	# Homes and halls must remain distinct in both city views. The store roof
	# must remain lower when the editor scales the walls of the entire house.
	var household := Period.get_plan("house@1").duplicate(true)
	household.wallScale = 135
	var dwelling := detail.create_designed_building("house", 1, household)
	assert(dwelling.find_child("ColumnCapital", true, false) == null)
	var decks := dwelling.find_children("RoofDeck*", "MeshInstance3D", true, false)
	assert(decks.size() == 2)
	var taller: AABB = decks[0].mesh.get_aabb()
	var lower: AABB = decks[1].mesh.get_aabb()
	assert(taller.end.y - lower.end.y > 0.30 and decks[1].get_meta("house_roof", false))
	assert(LOD.category("house", 1) != LOD.category("hall", 1))
	assert(LOD.mesh(1, LOD.category("house", 1)).get_surface_count() == 1)
	dwelling.free()
	var harbor: Dictionary=Period.get_plan("harbor@4")
	var coast_angle:=0.47
	var rotated:=coast_angle+Period.coast_yaw(harbor)
	var harbour_object:={"type":"harbor","x":2.0,"z":-7.0,"ready":true,"shoreAngle":coast_angle}
	var native:=detail.create_designed_building("harbor",4)
	detail.configure_wall_transform(native,harbour_object)
	assert(is_equal_approx(native.rotation.y,rotated))
	var midpoint:=(Plan.point(harbor.pier.a)+Plan.point(harbor.pier.b))/2.0
	var local: Vector2=(midpoint-PlanCollision.origin(harbor))/Plan.PX_PER_M
	var fit: Dictionary=Detail.MODEL_FITS.data["harbor@4"]
	var transformed: Vector2=local*Vector2(fit.scale[0],fit.scale[2])+Vector2(fit.offset[0],fit.offset[2])
	var at:=Vector2(2,-7)+transformed.rotated(-rotated)
	assert(Contacts.pier_surface(detail,harbour_object,4,at.x,at.y)!=null)
	assert(transformed.rotated(-rotated).dot(Vector2(sin(coast_angle),cos(coast_angle)))<0.0)
	native.free()
	detail.free()
	var templates:=0
	for age in range(1,7):
		for kind in Economy.data.buildings:
			if int(Rules.data.age.get(kind,0))>age or kind=="bridge":
				continue
			var id:=Period.designer_id(kind,age)
			assert(Period.age_of(id)==age, id)
			assert(Period.get_plan(id).periodStyle==age, id)
			templates+=1
		for category in ["home","dock","guard","civic","works","yard"]:
			assert(LOD.mesh(age,category).get_surface_count()==1,category)
		for texture in ["walls","roofs","accents"]:
			var atlas: Texture2D=LOD.material(age).get_shader_parameter(texture)
			if age==1 and texture=="roofs":
				assert(atlas==Painted.atlas(Painted.SOIL))
			else:
				assert(atlas!=null and atlas.get_size()==Vector2(624,312))
		for kind in ["transport","warship"]:
			var ship:=Ships.visual(kind,0,age,0.04,3)
			assert(ship!=null and ship.get_child_count()>3)
			ship.free()
		var street:=Paths.finish(age,4,"9e9585")
		assert(street.albedo_texture!=null and street.heightmap_texture!=null)
	assert(Paths.finish(0,3,"9e9585").albedo_texture==null)
	for work in ["rail","air"]:
		var freight:=Node3D.new()
		assert(Freight.freight(freight,work,5,1))
		assert(Freight.freight(freight,work,6,1))
		freight.free()
	var cars:=Node3D.new()
	assert(not Freight.road_vehicle(cars,0,0,1.0,0) and cars.get_child_count()==0)
	for age in range(1,7):
		assert(Freight.road_vehicle(cars,age,3,1.0,age))
	assert(cars.get_child_count()==6)
	cars.free()
	assert(Plan.window_span(6,"pictureWindow").x<Plan.window_span(6,"glazed").x)
	var first:=4*Grid.COLS+2
	var key:="%d:%d" % [first,first+1]
	var state:={"railEdges":{key:0},"explored":[{"2:4":true}]}
	assert(Rails.available_edges(state,Vector2i(2,4),false).is_empty())
	assert(Rails.available_edges(state,Vector2i(18,14),true).is_empty())
	state.explored[0]["3:4"]=true
	var edges:=Rails.available_edges(state,Vector2i(2,4),false)
	assert(edges.size()==1)
	var railway:=Node3D.new()
	Rails.build(railway,edges,func(_x,_z):return 1.0,4)
	assert(railway.get_child_count()==3 and railway.get_node("RidingRails").mesh.get_surface_count()==1)
	railway.free()
	var spread:={}
	for x in 8:
		var walk:=Paths.finish(6,4,"555555",Paths.variant_at(Vector2i(x,4)))
		spread[walk.heightmap_texture.resource_path]=true
	assert(spread.size()==8)
	var b:={"type":"house","x":0.0,"z":0.0,"hp":100.0,"ready":true,"buildingRotationV228":0.4}
	for age in range(1,7):
		var sites:=Lights.locations([b],true,age)
		assert(not sites.is_empty())
		assert(Vector2(sites[0].x,sites[0].z).length()>1.0)
	for era in range(1,7):
		for body in ["man","woman","boy","girl"]:
			for id in People.outfit_items(body,era,"",9):
				assert(ResourceLoader.exists("res://assets/people/clothes/%s/%s.glb" % [id,body]),"%s %s" % [id,body])
	var covered:=0
	for family in Period.NAMES:
		for variant in Painted.VARIANTS:
			var folder:=Painted.ROOT+"period_%s_%d" % [family,variant]
			assert(ResourceLoader.exists(folder+".png"),folder)
			assert(ResourceLoader.exists(folder+"_height.png"),folder)
			assert(ResourceLoader.exists(folder+"_normal.png"),folder)
			covered+=1
	Model.clear_cache()
	print("HISTORICAL_PERIODS_OK ",templates," editable plans / ",covered," color-height pairs")
	quit()

