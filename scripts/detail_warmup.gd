extends RefCounted
## CPU-only preparation for the next detail tile. Rendering resources are
## uploaded by the owner only after the tile is requested.

const Neighbors=preload("res://scripts/detail_neighbors.gd")
var worker: Thread
var active_key:=""
var ready: Dictionary={}

func poll() -> void:
	if worker==null or worker.is_alive():return
	var result: Dictionary=worker.wait_to_finish()
	worker=null
	ready[active_key]=result
	while ready.size()>3:ready.erase(ready.keys()[0])

func begin(host: Node,at: Vector2i) -> void:
	var key: String=host.detail_visual_key(at.x,at.y)
	if worker!=null or ready.has(key):return
	var inputs:=Neighbors.copy_tile_inputs(host.grid,host.world_river_graph,at,true)
	worker=Thread.new()
	active_key=key
	var error:=worker.start(Neighbors.prepare_chunk.bind(inputs.cells,inputs.graph,host.world_height_samples,int(host.game.seed),at,true,{},""))
	if error!=OK:worker=null

func clear() -> void:
	if worker!=null:
		worker.wait_to_finish()
		worker=null
	ready.clear()
	active_key=""

