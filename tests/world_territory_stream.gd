extends SceneTree

const Grid=preload("res://scripts/campaign_grid.gd")
const Territory=preload("res://scripts/world_territory.gd")

func _initialize() -> void:
	var ground:=PackedFloat32Array()
	ground.resize(Grid.COLS*Grid.ROWS)
	ground.fill(8.0)
	var owned: Dictionary={"20:20":{"id":1,"team":0},"21:20":{"id":1,"team":0},"20:21":{"id":1,"team":0},"24:20":{"id":2,"team":1}}
	var urban: Dictionary={"1":{"20:20":true},"2":{"24:20":true}}
	var explored: Dictionary={"20:20":true,"21:20":true,"20:21":true}
	var limited:=Territory.prepare(Territory.snapshot(owned,urban,explored,false),ground,null)
	assert(limited.size()==4,"The explored corner has two fills and two outlines")
	for surface in limited:
		assert(int(surface.team)==0,"The outline and fill must respect fog")
		var vertices: PackedVector3Array=surface.arrays[Mesh.ARRAY_VERTEX]
		assert(not vertices.is_empty())
		for point in vertices:
			var x:=point.x/2.0+Grid.COLS/2.0
			var z:=point.z/2.0+Grid.ROWS/2.0
			assert(x>19.5 and x<22.5 and z>19.5 and z<22.5)
	var full:=Territory.prepare(Territory.snapshot(owned,urban,explored,true),ground,null)
	assert(full.size()==7,"The revealed second city should add one fill and two outlines")
	var parent:=Node3D.new()
	Territory.attach(parent,full)
	assert(parent.get_child_count()==7)
	parent.free()
	print("WORLD_TERRITORY_STREAM_OK")
	quit()
