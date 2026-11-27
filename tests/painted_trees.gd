extends SceneTree

const Trees = preload("res://scripts/painted_tree_models.gd")


func _initialize() -> void:
	for kind: String in Trees.HEIGHTS:
		var species_shapes: Dictionary = {}
		for variant in 5:
			var near := Trees.mesh_for(kind,variant,"near") as ArrayMesh
			var mid := Trees.mesh_for(kind,variant,"mid") as ArrayMesh
			var far := Trees.mesh_for(kind,variant,"far") as ArrayMesh
			assert(near == Trees.mesh_for(kind,variant,"near"))
			var near_count := near.surface_get_array_len(0)/3
			var mid_count := mid.surface_get_array_len(0)/3
			var far_count := far.surface_get_array_len(0)/3
			assert(near.get_surface_count()==1 and mid.get_surface_count()==1 and far.get_surface_count()==1)
			assert(near_count>mid_count and mid_count>far_count)
			assert(near_count<=1400 and mid_count<=380 and far_count<=110)
			assert(absf(near.get_aabb().size.y-Trees.HEIGHTS[kind])<Trees.HEIGHTS[kind]*0.19)
			assert(absf(far.get_aabb().size.y-near.get_aabb().size.y)<Trees.HEIGHTS[kind]*0.16)
			species_shapes[near.get_aabb().size] = true
		assert(species_shapes.size()>1)
	assert(Trees.grass_mesh(false).get_surface_count()==1)
	assert(Trees.grass_mesh(true).get_aabb().size.y>Trees.grass_mesh(false).get_aabb().size.y)
	print("PAINTED_TREES_OK 30 VARIANTS 3 LODS")
	quit()
