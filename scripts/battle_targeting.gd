class_name BattleTargeting
extends RefCounted

# Transient spatial index for the existing, ordered list of live battle agents.
# The two queries have different metrics: a preferred attack target and the
# nearest non-routing threat. Neither query has a maximum search distance.
const LEAF_SIZE:=8
const BOUND_SLACK:=0.000000001
var agents: Array=[]
var nodes: Array=[]
var leaves:=PackedInt32Array()
var root: int=-1

var query_x: float
var query_z: float
var query_team: Variant
var query_source: Variant
var previous_target: Variant
var enemy: Variant
var best: float
var threat: Variant
var threat_distance: float
var enemy_order: int
var threat_order: int

func rebuild(ordered_agents: Array) -> void:
 agents=ordered_agents
 nodes.clear()
 leaves.resize(agents.size())
 var indices: Array=[]
 for i in agents.size():indices.append(i)
 root=build_node(indices,-1) if not indices.is_empty() else -1

func build_node(indices: Array,parent: int) -> int:
 var first: Dictionary=agents[indices[0]]
 var min_x:=float(first.m.x);var max_x:=min_x
 var min_z:=float(first.m.z);var max_z:=min_z
 var common_unit: Variant=first.u
 for index in indices:
  var actor: Dictionary=agents[index]
  min_x=minf(min_x,float(actor.m.x));max_x=maxf(max_x,float(actor.m.x))
  min_z=minf(min_z,float(actor.m.z));max_z=maxf(max_z,float(actor.m.z))
  if common_unit!=null and not is_same(common_unit,actor.u):common_unit=null
 var id:=nodes.size()
 var node: Dictionary={"min_x":min_x,"max_x":max_x,"min_z":min_z,"max_z":max_z,"parent":parent,"unit":common_unit,"left":-1,"right":-1,"indices":[]}
 nodes.append(node)
 if indices.size()<=LEAF_SIZE:
  node.indices=indices
  for index in indices:leaves[index]=id
 else:
  var axis: String="x" if max_x-min_x>=max_z-min_z else "z"
  indices.sort_custom(func(a,b):
   var av:=float(agents[a].m[axis]);var bv:=float(agents[b].m[axis])
   return a<b if av==bv else av<bv)
  var middle:=indices.size()/2
  node.left=build_node(indices.slice(0,middle),id)
  node.right=build_node(indices.slice(middle),id)
 return id

func update_agent(index: int) -> void:
 # Fighters move sequentially. Later queries must see every earlier move,
 # including movement across the original split. Expanded boxes stay safe;
 # the next step's rebuild makes them tight again.
 var man: Dictionary=agents[index].m
 var x:=float(man.x);var z:=float(man.z)
 var id:=leaves[index]
 while id>=0:
  var node: Dictionary=nodes[id]
  if x>=float(node.min_x) and x<=float(node.max_x) and z>=float(node.min_z) and z<=float(node.max_z):break
  node.min_x=minf(float(node.min_x),x);node.max_x=maxf(float(node.max_x),x)
  node.min_z=minf(float(node.min_z),z);node.max_z=maxf(float(node.max_z),z)
  id=int(node.parent)

func query(actor: Dictionary) -> Dictionary:
 enemy=null;best=INF;threat=null;threat_distance=INF
 enemy_order=agents.size();threat_order=agents.size()
 var unit: Dictionary=actor.u;var man: Dictionary=actor.m
 query_source=unit.get("attackTargetSource")
 if root>=0 and not (unit.get("combatMode","auto")=="manual" and query_source==null):
  query_x=float(man.x);query_z=float(man.z);query_team=unit.team
  previous_target=man.get("targetId")
  visit(root)
 return {"enemy":enemy,"best":best,"threat":threat,"threat_distance":threat_distance}

func distance_squared_to(node: Dictionary) -> float:
 var dx:=maxf(0.0,maxf(float(node.min_x)-query_x,query_x-float(node.max_x)))
 var dz:=maxf(0.0,maxf(float(node.min_z)-query_z,query_z-float(node.max_z)))
 return dx*dx+dz*dz

func visit(id: int) -> void:
 var node: Dictionary=nodes[id]
 # A homogeneous subtree can use its live unit reference for these filters.
 # HP, escape and routing remain live per-man checks: earlier fighters can
 # kill enemies or cause a whole army to retreat during this same step.
 var unit: Variant=node.unit
 if unit!=null:
  if unit.team==query_team or unit.get("retreated",false):return
  if query_source!=null and unit.source!=query_source:return
 var dz:=maxf(0.0,maxf(float(node.min_z)-query_z,query_z-float(node.max_z)))
 var lower_distance:=sqrt(distance_squared_to(node))
 # Any member could have the previous-target discount. This conservative
 # lower bound is allowed to be negative; an exact candidate score can be.
 var lower_score:=lower_distance-1.2+dz*0.15
 # Strict, padded bounds keep equal-score candidates available for the
 # original agents-order tie-break. Padding never changes final scores.
 var slack:=BOUND_SLACK*maxf(1.0,lower_distance)
 var routing_unit: bool=unit!=null and unit.get("routing",false)
 if lower_score>best+slack and (routing_unit or lower_distance>threat_distance+slack):return
 if int(node.left)<0:
  visit_leaf(node.indices)
  return
 var left:=int(node.left);var right:=int(node.right)
 if distance_squared_to(nodes[left])<=distance_squared_to(nodes[right]):
  visit(left);visit(right)
 else:
  visit(right);visit(left)

func visit_leaf(indices: Array) -> void:
 for index in indices:
  var candidate: Dictionary=agents[index]
  var unit: Dictionary=candidate.u;var man: Dictionary=candidate.m
  if unit.team==query_team or float(man.hp)<=0 or man.get("escaped",false) or unit.get("retreated",false):continue
  if query_source!=null and unit.source!=query_source:continue
  # Keep the old distance and score operation order, not Vector2/float32 or
  # squared scores. Small numeric changes can alter a later battle outcome.
  var dx:=query_x-float(man.x);var dz:=query_z-float(man.z)
  var distance:=sqrt(dx*dx+dz*dz)
  var score: float=distance+(-1.2 if previous_target==man.id else 0)+absf(float(man.z)-query_z)*0.15
  if not unit.get("routing",false) and not man.get("routing",false) and (distance<threat_distance or (threat!=null and distance==threat_distance and index<threat_order)):
   threat=man;threat_distance=distance;threat_order=index
  if score<best or (enemy!=null and score==best and index<enemy_order):
   enemy=candidate;best=score;enemy_order=index
