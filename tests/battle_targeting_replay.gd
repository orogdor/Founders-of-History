extends SceneTree
const Sim=preload("res://scripts/battle_simulation.gd")
const Formations=preload("res://scripts/battle_formations.gd")

class LegacyTargeting extends RefCounted:
 var agents:Array=[]
 func rebuild(value:Array)->void:agents=value
 func update_agent(_index:int)->void:pass
 func query(actor:Dictionary)->Dictionary:
  var man:Dictionary=actor.m;var unit:Dictionary=actor.u
  var enemy:Variant=null;var best:=INF;var threat:Variant=null;var threat_distance:=INF
  for p in agents:
   if p.u.team==unit.team or float(p.m.hp)<=0 or p.m.get("escaped",false) or p.u.get("retreated",false):continue
   if unit.get("attackTargetSource")!=null and p.u.source!=unit.attackTargetSource:continue
   if unit.get("combatMode","auto")=="manual" and unit.get("attackTargetSource")==null:continue
   var dx:=float(man.x)-float(p.m.x);var dz:=float(man.z)-float(p.m.z)
   var d:=sqrt(dx*dx+dz*dz);var score:float=d+(-1.2 if man.get("targetId")==p.m.id else 0)+absf(float(p.m.z)-float(man.z))*0.15
   if not p.u.get("routing",false) and not p.m.get("routing",false) and d<threat_distance:threat=p.m;threat_distance=d
   if score<best:best=score;enemy=p
  return {"enemy":enemy,"best":best,"threat":threat,"threat_distance":threat_distance}

var compared_steps:=0
var failed:=false

func _initialize():call_deferred("run_test")

func command(battle:Dictionary,value:Dictionary)->void:
 var unit:Dictionary={}
 for candidate in battle.squads:
  if int(candidate.source)==int(value.source):unit=candidate;break
 if unit.is_empty():return
 if value.kind=="manual_move":
  unit.combatMode="manual";unit.target={"x":value.x,"z":value.z};unit.attackTargetSource=null;unit.manualOrder=true;unit.advance=false
 elif value.kind=="auto":
  unit.combatMode="auto";unit.target=null;unit.attackTargetSource=null;unit.manualOrder=false;unit.anchor={"x":unit.x,"z":unit.z};unit.advance=true
 elif value.kind=="formation":Formations.set_formation(unit,value.value,float(battle.elapsed),true)

func close_battle(initial:Dictionary)->Dictionary:
 var battle:=initial.duplicate(true)
 battle.initialMen=32
 battle.deploymentGap={"minX":-1.0,"maxX":1.0}
 for unit in battle.squads:
  unit.men=unit.men.slice(0,8);unit.menCount=8;unit.menAlive=8;unit.startMen=8
  var x:float=(-1.0 if unit.team==0 else 1.0)*(4.0 if unit.kind=="infantry" else 12.0)
  var offset:float=x-float(unit.x);unit.x=x;unit.anchor.x=x;unit.deployment.x=x
  unit.hp=0.0;unit.maxHp=0.0
  for man in unit.men:
   man.x=float(man.x)+offset;man.hp=2.0;unit.hp+=float(man.hp);unit.maxHp+=float(man.maxHp)
 return battle

func first_difference(a:Variant,b:Variant,path:String="battle")->String:
 if typeof(a)!=typeof(b):return path+" differs in type"
 if a is Dictionary:
  if a.size()!=b.size():return path+" differs in key count"
  for key in a:
   if not b.has(key):return path+" missing key "+str(key)
   if a[key]!=b[key]:return first_difference(a[key],b[key],path+"."+str(key))
 elif a is Array:
  if a.size()!=b.size():return path+" differs in length"
  for i in a.size():
   if a[i]!=b[i]:return first_difference(a[i],b[i],path+"["+str(i)+"]")
 return path+" expected="+str(a)+" actual="+str(b)

func replay(label:String,initial:Dictionary,commands:Array,limit:int,close:bool)->void:
 var old_state:=initial.duplicate(true);var new_state:=initial.duplicate(true)
 var old_sim=Sim.new();old_sim.targeting=LegacyTargeting.new();var new_sim=Sim.new()
 var next_command:=0;var attack_seen:=false;var death_seen:=false;var routing_seen:=false;var local_steps:=0
 for step in limit:
  while next_command<commands.size() and float(commands[next_command].at)<=float(old_state.elapsed)+0.00000001:
   command(old_state,commands[next_command]);command(new_state,commands[next_command]);next_command+=1
  # A controlled morale shock exercises routing with live shared unit references.
  if close and step==180:
   for state in [old_state,new_state]:
    state.squads[1].moraleShock=100.0
    for man in state.squads[1].men:
     if float(man.hp)>0:man.morale=12.0
  old_sim.step(old_state,0.1,[1,1],null);new_sim.step(new_state,0.1,[1,1],null)
  compared_steps+=1;local_steps+=1
  if old_state!=new_state or JSON.stringify(old_state)!=JSON.stringify(new_state):
   push_error(label+" diverged at step "+str(step)+": "+first_difference(old_state,new_state));failed=true;return
  for unit in new_state.squads:
   routing_seen=routing_seen or unit.get("routing",false)
   for man in unit.get("men",[]):
    attack_seen=attack_seen or man.has("attackTime")
    death_seen=death_seen or float(man.hp)<=0.0
    routing_seen=routing_seen or man.get("routing",false)
  if new_state.get("result")!=null:break
 if close and not (attack_seen and death_seen and routing_seen):
  push_error("Close replay must exercise attacks, casualties and routing");failed=true
 print("BATTLE_TARGETING_REPLAY ",JSON.stringify({"case":label,"steps":local_steps,"commands":next_command,"attacks":attack_seen,"casualties":death_seen,"routing":routing_seen,"result":new_state.get("result"),"identical":not failed}))

func run_test():
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/battle_fixture.json"))
 replay("existing 96-agent fixture",fixture.initial,fixture.commands,400,false)
 if not failed:replay("close 32-agent wounded battle",close_battle(fixture.initial),[],400,true)
 print("BATTLE_TARGETING_REPLAY_TOTAL ",compared_steps," exact full-state comparisons")
 quit(1 if failed else 0)
