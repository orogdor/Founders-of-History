extends SceneTree
const Targeting=preload("res://scripts/battle_targeting.gd")
const Doctrine=preload("res://scripts/battle_doctrine.gd")
var checks:=0
var failures:Array=[]

func make_index(agents:Array):
 var index=Targeting.new();index.rebuild(agents);index.set_meta("test_agents",agents);return index
func selection(index,actor:Dictionary)->Dictionary:
 return index.query(actor)
func update_position(index,actor:Dictionary)->void:
 var agents:Array=index.get_meta("test_agents")
 for ordinal in agents.size():
  if is_same(agents[ordinal],actor):
   index.update_agent(ordinal);return
 failures.append("Updated actor missing from test agents")

func _initialize():call_deferred("run_test")

func actor(id:String,team:int,source:int,x:float,z:float)->Dictionary:
 return {"u":{"team":team,"source":source,"hp":100.0,"combatMode":"auto","attackTargetSource":null},"m":{"id":id,"x":x,"z":z,"hp":100.0}}

func oracle(subject:Dictionary,agents:Array)->Dictionary:
 var man:Dictionary=subject.m;var unit:Dictionary=subject.u
 var enemy:Variant=null;var best:=INF;var threat:Variant=null;var threat_distance:=INF
 # Intentionally preserve the old full scan, original order and strict comparisons.
 for p in agents:
  if p.u.team==unit.team or float(p.m.hp)<=0 or p.m.get("escaped",false) or p.u.get("retreated",false):continue
  if unit.get("attackTargetSource")!=null and p.u.source!=unit.attackTargetSource:continue
  if unit.get("combatMode","auto")=="manual" and unit.get("attackTargetSource")==null:continue
  var d:=Doctrine.distance(man,p.m);var score:float=d+(-1.2 if man.get("targetId")==p.m.id else 0)+absf(float(p.m.z)-float(man.z))*0.15
  if not p.u.get("routing",false) and not p.m.get("routing",false) and d<threat_distance:threat=p.m;threat_distance=d
  if score<best:best=score;enemy=p
 return {"enemy":enemy,"best":best,"threat":threat,"threat_distance":threat_distance}

func verify(label:String,index,subject:Dictionary,agents:Array)->void:
 checks+=1
 var expected:=oracle(subject,agents);var actual:=selection(index,subject)
 for key in ["enemy","threat"]:
  if not is_same(expected[key],actual.get(key)):
   failures.append(label+" identity mismatch: "+key)
 for key in ["best","threat_distance"]:
  if expected[key]!=actual.get(key):
   failures.append(label+" numeric mismatch: "+key+" expected="+str(expected[key])+" actual="+str(actual.get(key)))

func check_case(label:String,subject:Dictionary,agents:Array)->void:
 verify(label,make_index(agents),subject,agents)

func named_cases()->void:
 var subject:=actor("self",0,0,0.0,0.0)
 check_case("empty",subject,[])
 check_case("only self",subject,[subject])
 var left:=actor("left",1,1,-8.0,0.0);var right:=actor("right",1,2,8.0,0.0)
 check_case("equal score original left first",subject,[subject,left,right])
 check_case("equal score original right first",subject,[subject,right,left])
 var tied:=actor("same location",2,3,8.0,0.0)
 check_case("coincident enemies different teams",subject,[subject,tied,right,left])
 var nearer:=actor("nearer",1,1,10.0,0.0);var previous:=actor("previous",1,2,10.8,0.0)
 subject.m.targetId="previous"
 check_case("previous target bonus beats nearer enemy",subject,[subject,nearer,previous])
 previous.m.x=11.200000000001
 check_case("previous target just outside score threshold",subject,[subject,previous,nearer])
 previous.m.x=11.199999999999
 check_case("previous target just inside score threshold",subject,[subject,nearer,previous])
 subject.m.erase("targetId")
 var off_axis:=actor("off axis",1,1,0.0,10.0);var on_axis:=actor("on axis",1,2,10.2,0.0)
 check_case("weighted enemy differs from nearest threat",subject,[subject,off_axis,on_axis])
 var routed:=actor("routing",1,3,0.5,0.0);routed.m.routing=true
 check_case("routed man can be target but not threat",subject,[subject,routed,off_axis,on_axis])
 routed.m.routing=false;routed.u.routing=true
 check_case("routed squad can be target but not threat",subject,[subject,routed,off_axis,on_axis])
 off_axis.u.routing=true;on_axis.m.routing=true
 check_case("all enemies routing has no threat",subject,[subject,routed,off_axis,on_axis])
 routed.u.routing=false;off_axis.u.routing=false;on_axis.m.routing=false
 var dead:=actor("dead",1,4,0.1,0.0);dead.m.hp=0
 var escaped:=actor("escaped",1,5,0.2,0.0);escaped.m.escaped=true
 var retreated:=actor("retreated",1,6,0.3,0.0);retreated.u.retreated=true
 check_case("filtered closer enemies",subject,[dead,escaped,retreated,routed,subject])
 subject.u.combatMode="manual"
 check_case("manual without order has no target or threat",subject,[subject,routed,on_axis])
 subject.u.attackTargetSource=2
 check_case("manual explicit source filters target and threat",subject,[subject,routed,on_axis])
 subject.u.attackTargetSource=999
 check_case("unavailable explicit source",subject,[subject,routed,on_axis])
 subject.u.combatMode="auto";subject.u.attackTargetSource=2
 check_case("automatic explicit source filters threat too",subject,[subject,routed,on_axis])
 subject.u.attackTargetSource=null
 var far:=actor("far",1,8,550.0,460.0)
 check_case("large empty gaps",subject,[subject,far])
 var negative:=actor("negative",1,9,-0.000000000001,-8.0)
 check_case("negative boundary",subject,[subject,negative,left,right])
 var near_tie:=actor("near tie",1,10,8.000000000001,0.0)
 check_case("near tie must not become tie",subject,[subject,near_tie,right])
 var zero_hp_squad:=actor("unit hp zero but live man in agents",1,11,0.5,0.0);zero_hp_squad.u.hp=0
 check_case("do not invent unit-hp candidate filter",subject,[subject,zero_hp_squad,right])
 var guard:=actor("guard",1,12,0.25,0.0);guard.u.guardPost=true
 check_case("guard post remains a target and threat",subject,[subject,guard,right])
 guard.u.reserve=true
 check_case("do not invent reserve filter for supplied agents",subject,[subject,guard,right])
 var duplicate_a:=actor("duplicate",1,13,-9.0,0.0);var duplicate_b:=actor("duplicate",1,14,9.0,0.0)
 subject.m.targetId="duplicate"
 check_case("duplicate previous target IDs retain agents order",subject,[subject,duplicate_b,duplicate_a])
 subject.m.erase("targetId")
 var overflow:=actor("overflow",1,15,1e200,1e200)
 check_case("infinite score does not choose an initial target",subject,[subject,overflow])
 # More than one leaf: the first original candidate can be visited last.
 var split_agents:Array=[subject,right,left]
 for i in 24:split_agents.append(actor("padding-"+str(i),1,100+i,(-1.0 if i%2==0 else 1.0)*(100.0+i*7.0),0.0))
 check_case("equal score across split nodes keeps original order",subject,split_agents)
 split_agents[1]=left;split_agents[2]=right
 check_case("reverse tie order across split nodes",subject,split_agents)
 subject.m.targetId="right";right.m.x=8.9
 check_case("previous target bonus across split nodes",subject,split_agents)
 subject.m.erase("targetId");right.m.x=8.0

func dynamic_cases()->void:
 var subject:=actor("self",0,0,0.0,0.0);var first:=actor("first",1,1,160.0,0.0);var second:=actor("second",1,2,24.0,0.0)
 var agents:Array=[subject,first,second]
 for i in 24:agents.append(actor("dynamic-padding-"+str(i),1,100+i,(-1.0 if i%2==0 else 1.0)*(350.0+i*7.0),360.0))
 var index=make_index(agents)
 verify("dynamic before movement",index,subject,agents)
 first.m.x=0.5;update_position(index,first)
 verify("earlier agent moves across many cells into nearest",index,subject,agents)
 first.m.x=-240.0;first.m.z=-120.0;update_position(index,first)
 verify("earlier agent moves away across negative cells",index,subject,agents)
 second.m.hp=0
 verify("candidate dies after index build",index,subject,agents)
 second.m.hp=100;second.m.routing=true
 verify("man routes after index build",index,subject,agents)
 second.m.routing=false;second.u.routing=true
 verify("squad routes after index build",index,subject,agents)
 second.u.routing=false;second.m.escaped=true
 verify("candidate escapes after index build",index,subject,agents)
 second.m.escaped=false;second.u.retreated=true
 verify("squad retreats after index build",index,subject,agents)
 second.u.retreated=false
 subject.m.x=300.0;subject.m.z=250.0;update_position(index,subject)
 verify("query actor moves after index build",index,subject,agents)
 first.m.x=300.1;first.m.z=250.0;update_position(index,first)
 verify("candidate crosses into actor new area",index,subject,agents)
 var home:=actor("home",0,0,0.0,0.0);var grouped:Array=[home]
 var shared:Dictionary={"team":1,"source":1,"hp":100.0}
 for i in 24:
  var p:=actor("shared-"+str(i),1,1,-20.0-i,0.0);p.u=shared;grouped.append(p)
 grouped.append(actor("other group",2,2,100.0,0.0))
 var group_index=make_index(grouped)
 verify("homogeneous live unit initial",group_index,home,grouped)
 shared.routing=true
 verify("homogeneous unit starts routing",group_index,home,grouped)
 shared.routing=false
 verify("homogeneous unit stops routing",group_index,home,grouped)
 shared.retreated=true
 verify("homogeneous unit retreats",group_index,home,grouped)
 shared.retreated=false;shared.team=0
 verify("homogeneous unit team changes",group_index,home,grouped)
 shared.team=1;shared.source=99;home.u.attackTargetSource=99
 verify("homogeneous live source changes",group_index,home,grouped)

func randomized_cases()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=723401728
 for count in [1,24,96,192,500]:
  for layout in 4:
   for iteration in 5:
    var agents:Array=[];var squads:Dictionary={}
    for i in count:
     var x:=rng.randf_range(-540.0,540.0);var z:=rng.randf_range(-460.0,460.0)
     if layout==1:x=rng.randf_range(-5.0,5.0)+(i%3-1)*120.0;z=rng.randf_range(-5.0,5.0)
     elif layout==2:x=float(i-count/2)*1.05;z=0.0
     elif layout==3:x=float(rng.randi_range(-40,40))*8.0;z=float(rng.randi_range(-40,40))*8.0
     var source:int=i/12
     var p:=actor(str(i),source%3,source,x,z)
     if squads.has(source):p.u=squads[source]
     else:squads[source]=p.u
     if rng.randf()<0.08:p.m.hp=0.0
     if rng.randf()<0.06:p.m.escaped=true
     if rng.randf()<0.15:p.m.routing=true
     if rng.randf()<0.08:p.u.routing=true
     if rng.randf()<0.03:p.u.retreated=true
     agents.append(p)
    var index=make_index(agents)
    for query in 8:
     var subject:Dictionary=agents[rng.randi_range(0,agents.size()-1)]
     subject.u.combatMode="manual" if query%4==1 else "auto"
     subject.u.attackTargetSource=agents[rng.randi_range(0,agents.size()-1)].u.source if query%3==0 else null
     subject.m.targetId=agents[rng.randi_range(0,agents.size()-1)].m.id if query%2==0 else null
     verify("random %d/%d/%d/%d"%[count,layout,iteration,query],index,subject,agents)
     var mover:Dictionary=agents[rng.randi_range(0,agents.size()-1)]
     mover.m.x=rng.randf_range(-540.0,540.0);mover.m.z=rng.randf_range(-460.0,460.0);update_position(index,mover)
     if query%2==0:mover.m.hp=0.0
     else:mover.m.routing=not mover.m.get("routing",false)
     verify("random dynamic %d/%d/%d/%d"%[count,layout,iteration,query],index,subject,agents)

func run_test():
 named_cases();dynamic_cases();randomized_cases()
 for failure in failures:push_error(failure)
 print("BATTLE_TARGETING_ORACLE ",checks," queries; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
