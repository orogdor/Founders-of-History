extends SceneTree

const Eras=preload("res://scripts/house_eras.gd")
const Geometry=preload("res://scripts/house_plan_geometry.gd")
const PlanCollision=preload("res://scripts/house_plan_collision.gd")
const Collision=preload("res://scripts/house_collision.gd")
const Detail=preload("res://scripts/detail_view.gd")
const Model=preload("res://scripts/house_plan_model.gd")

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var view:=Detail.new()
 var original:=Eras.default_plan("house").duplicate(true)
 original.roofHeight=115
 for age in Eras.NAMES.size():
  var id:=Eras.project_id("house",age)
  var plan:=Eras.adapt(original,id)
  assert(int(Eras.definition(id).era)==age and id in Eras.projects(age))
  assert(plan.rooms==original.rooms and plan.id==id)
  if age>=3:
   assert(plan.wallStyle in Eras.walls(age))
   assert(plan.roofMat==Eras.ROOFS[age-3])
  var building:=view.create_designed_building("house",age,original)
  assert(building.get_meta("designer_id")==id)
  building.free()

 var doors_checked:=0
 for age in [0,1]:
  for id in Eras.projects(age):
   var type:=Eras.base_id(id)
   if Eras.fit_id(type,age)!=id:continue
   var plan:=Eras.live_plan(type,age,{})
   if plan.is_empty():continue
   var fit:Dictionary=Eras.Fits.data[id]
   var origin:=PlanCollision.origin(plan)
   var building:={"type":type,"ready":true,"hp":100,"x":0.0,"z":0.0}
   for wall in Geometry.plan_geometry(plan).walls:
    for span in Geometry.split_wall(wall,plan):
     if span.get("type","")!="door" or span.group!="outer":continue
     var center:Vector2=(span.a+span.b)/2
     if span.get("curved",false):
      center=Geometry.point(span.opening.point)
      if center.distance_to((span.a+span.b)/2)>14:continue
     var normal:Vector2=(span.b-span.a).normalized().orthogonal()
     for sample in range(-7,8):
      var point:Vector2=(center-origin)/Geometry.PX_PER_M+normal*(sample*0.1)
      var x:=point.x*float(fit.scale[0])+float(fit.offset[0])
      var z:=point.y*float(fit.scale[2])+float(fit.offset[2])
      assert(not Collision.hits(view,building,age,x,z),"Blocked entrance in "+id)
     assert(Geometry.door_height(age,str(span.opening.style))*float(fit.scale[1])>=1.7)
     doors_checked+=1
 assert(doors_checked>=30)
 view.free()
 Model.clear_cache()
 print("HOUSE_ERA_PROGRESSION_OK doors=",doors_checked)
 quit()
