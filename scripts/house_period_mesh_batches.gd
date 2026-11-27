extends RefCounted
## Merge decorative meshes after the live plan has been resolved in-game.
## The editor still keeps its individual wall and roof pieces for toggling.
static func compact(parent: Node3D) -> void:
	var batches: Dictionary={}
	for node in parent.get_children():
		if node.name=="SecondStorey" and node is Node3D:
			compact(node)
		if not node is MeshInstance3D or not node.has_meta("period_static"):
			continue
		if node.mesh==null or node.mesh.get_surface_count()!=1 or not node.visible:
			continue
		var material: Material=node.get_active_material(0)
		if not material is BaseMaterial3D or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var key: Array=[material.get_instance_id(),node.mesh.get_class(),node.cast_shadow,node.get_meta("period_static")]
		if not batches.has(key):
			batches[key]={"material":material,"parts":[]}
		batches[key].parts.append(node)
	for key in batches:
		var members: Array=batches[key].parts
		if members.size()<3:
			continue
		var geometry:=SurfaceTool.new()
		geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
		var picking: Array[Dictionary]=[]
		for part: MeshInstance3D in members:
			geometry.append_from(part.mesh,0,part.transform)
			picking.append({"box":part.mesh.get_aabb(),"pose":part.transform,"inverse":part.transform.affine_inverse()})
		geometry.set_material(batches[key].material)
		var mesh:=geometry.commit()
		if mesh==null or mesh.get_surface_count()==0:
			continue
		var result:=MeshInstance3D.new()
		result.name="PeriodBatch_"+str(key[3])
		result.mesh=mesh
		result.cast_shadow=key[2]
		result.set_meta("period_pick_bounds",picking)
		parent.add_child(result)
		for part in members:
			part.free()

