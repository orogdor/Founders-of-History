extends SceneTree
## The rendered crossing must have a continuous deck, and only its owner's period is visible.
const Crossings = preload("res://scripts/period_river_crossing.gd")
const StoneBridge = preload("res://scripts/iron_river_bridge.gd")

func hits_deck(triangles: PackedVector3Array, x: float) -> bool:
	var start := Vector3(x,4.0,0.09)
	var finish := start - Vector3.UP*8.0
	for i in range(0,triangles.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,finish,triangles[i],triangles[i+1],triangles[i+2])
		if hit != null and hit.y > 0.1:
			return true
	return false

func _initialize() -> void:
	var bridge := StoneBridge.create_span(34.0,5.2,1.25)
	var vaults := bridge.get_node("AshlarPiersAndVaults") as MeshInstance3D
	var triangles := vaults.mesh.get_faces()
	for i in 39:
		var x := lerpf(-16.8,16.8,(i+0.37)/39)
		if not hits_deck(triangles,x):
			push_error("Bridge deck is missing at %.2f metres" % x)
			bridge.free()
			quit(1)
			return
	bridge.free()
	var crossing := Node3D.new()
	var original := Node3D.new()
	crossing.add_child(original)
	crossing.scale = Vector3(13.0,0.3,12.0)
	for age in [2,1,2,3,1,0]:
		Crossings.set_period(crossing,age)
		var bronze := crossing.get_node_or_null("BronzeTimberBridge") as Node3D
		var iron := crossing.get_node_or_null("IronArchBridge") as Node3D
		if original.visible != (age not in [1,2]) or (bronze != null and bronze.visible) != (age == 1) or (iron != null and iron.visible) != (age == 2):
			push_error("Incorrect bridge after switching to age %d" % age)
			crossing.free()
			quit(1)
			return
	crossing.free()
	print("PERIOD_RIVER_CROSSING_OK 39 deck samples and 6 age transitions")
	quit()

