extends RefCounted

const Blueprints=preload("res://data/house_default_designs.json")
const Catalog=preload("res://data/house_editor_catalog.json")
const Fits=preload("res://data/building_fits.json")
const NAMES:=["Kiviaeg","Pronksiaeg","Rauaaeg","Keskaeg","Renessanss","Tööstusaeg","Moodne aeg"]
const LIMITS:=[8.5,10.5,12.3,13.5,14.5,15.5,16.0]
const DOORS:=["hide","mycenaean","greek","plank","arched","double","double"]
const NEW_WALLS:=[["halftimber","medievalRubble"],["renaissanceLime","renaissanceAshlar"],["industrialBrick","industrialIron"],["modernConcrete","modernPanel"]]
const WALL_LABELS:={
 "medievalRubble":"Paekivist müür",
 "renaissanceLime":"Lubikrohv",
 "renaissanceAshlar":"Rustikakivi",
 "industrialBrick":"Põletatud punatellis",
 "industrialIron":"Needidega raudpaneel",
 "modernConcrete":"Valubetoon",
 "modernPanel":"Keraamiline fassaadipaneel"
}
const NEW_ROOFS:=[["slate","Kiltkivi",3],["terracotta","Terrakota",4],["seamMetal","Valtsplekk",5],["membrane","Katusemembraan",6]]
const ROOFS:=["slate","terracotta","seamMetal","membrane"]
const ROOF_FORMS:=["gable","hip","gable","flat"]
const UNCHANGED_TYPES:=["palisade","stonewall","reinforced_wall","woodgate","gatehouse","stonetower","bridge"]
static var variants:Dictionary={}
static var default_cache:Dictionary={}

static func base_id(id: String) -> String:
 return id.get_slice("@",0)

static func fit_id(type: String,age: int) -> String:
 var tier:=clampi(age,0,2)
 for era in range(tier,0,-1):
  var candidate:=type+"@"+str(era)
  if Fits.data.has(candidate):return candidate
 if Fits.data.has(type):return type
 for era in range(tier+1,3):
  var candidate:=type+"@"+str(era)
  if Fits.data.has(candidate):return candidate
 return ""

static func project_id(type: String,age: int) -> String:
 var source:=fit_id(type,age)
 if age<3 or source.is_empty() or type in UNCHANGED_TYPES:return source
 var plan:Dictionary=Blueprints.data.get(source,{})
 if plan.get("rooms",[]).is_empty() or plan.get("build","wall")=="tower":return source
 return type+"@"+str(clampi(age,3,6))

static func definition(id: String) -> Dictionary:
 if Catalog.data.catalog.has(id):return Catalog.data.catalog[id]
 var type:=base_id(id);var age:=int(id.get_slice("@",1))
 if age<3 or project_id(type,age)!=id:return {}
 var entry:Dictionary=Catalog.data.catalog.get(fit_id(type,age),{}).duplicate()
 entry.era=age
 return entry

static func walls(age: int) -> Array:
 if age<3:return Catalog.data.ERA_WALLS[age]
 return NEW_WALLS[age-3]+Catalog.data.ERA_WALLS[2]

static func projects(age: int) -> Array:
 if not variants.has(age):
  var projects_in_age:=Blueprints.data.keys().filter(func(id):return int(Catalog.data.catalog.get(id,{}).get("era",-1))==age) if age<3 else []
  if age>=3:
   for id in Blueprints.data:
    var type:=base_id(id)
    if id!=fit_id(type,age):continue
    var variant:=project_id(type,age)
    if id!=variant:projects_in_age.append(variant)
  variants[age]=projects_in_age
 return variants[age]

static func default_plan(id: String) -> Dictionary:
 if Blueprints.data.has(id):return Blueprints.data[id]
 if not default_cache.has(id):
  var def:=definition(id)
  if def.is_empty():return {}
  var design:Dictionary=Blueprints.data[fit_id(base_id(id),int(def.era))]
  default_cache[id]=adapt(design,id)
 return default_cache[id]

static func adapt(original: Dictionary,id: String) -> Dictionary:
 if original.is_empty():return {}
 var previous:=str(original.get("id",""))
 if previous==id:return original
 if base_id(previous)!=base_id(id) or definition(id).is_empty():return {}
 var age:=int(definition(id).era)
 var previous_age:=int(definition(previous).get("era",0))
 if age<=previous_age:return {}
 var design:=original.duplicate(true)
 design.id=id
 if age>=3:
  var type:=base_id(id)
  var civic:=str(definition(id).get("kind","")) in ["Civic","Knowledge and trade"] or type=="hall"
  update_finish(design,age,civic,false)
  if design.get("upper") is Dictionary:update_finish(design.upper,age,civic,true)
 else:
  var reference:Dictionary=Blueprints.data[id]
  for property in ["wallStyle","roofMat","columns"]:
   if reference.has(property):design[property]=reference[property]
 return design

static func update_finish(plan: Dictionary,age: int,civic: bool,upper: bool) -> void:
 var index:=age-3
 var heavy:=str(plan.get("wallStyle","")) in ["stone","cutstone","marble","romanbrick","reticulatum"]
 plan.wallStyle=NEW_WALLS[index][int(civic or heavy)]
 plan.roofMat=ROOFS[index]
 if str(plan.get("roofForm",""))!="battlement":
  plan.roofForm=ROOF_FORMS[index]
  plan.roofHeight=[105,68,74,70][index]
 plan.columns="post"
 plan.porch="none" if upper or age>=5 else str(plan.get("porch","none"))
 if age>=5:plan.wallScale=100
 plan.erase("courtyardStyle");plan.erase("decor")
 for finish in plan.get("wallFinishes",[]):
  finish.finish=NEW_WALLS[index][int(str(finish.finish) in ["stone","cutstone","marble","cyclopean","romanbrick"])]
 for opening in plan.get("openings",[]):
  if opening.get("type","")=="door":opening.style=DOORS[age]
  elif age>=5:opening.style="glazed"

static func live_plan(type: String,age: int,design: Dictionary,prefer_imported_default:=false) -> Dictionary:
 var id:=project_id(type,age)
 if id.is_empty():return {}
 var custom:=adapt(design,id)
 if not custom.is_empty():return custom
 # Keep the authored mesh for rendering while callers such as collision can
 # still use the updated default plan, including its walkable entrances.
 if prefer_imported_default:return {}
 var reference:=default_plan(id)
 if age>=3 and id!=fit_id(type,age) and type!="mill":return reference
 if age<=2 and reference.get("build","wall")=="wall" and reference.get("openings",[]).any(func(opening):return opening.get("type","")=="door"):
  return reference
 return {}
