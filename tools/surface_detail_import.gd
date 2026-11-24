@tool
extends EditorScenePostImport

const SurfaceDetail = preload("res://scripts/surface_detail.gd")

func _post_import(scene: Node) -> Object:
	var materials: Dictionary = {}
	apply_to_meshes(scene, materials)
	return scene

func apply_to_meshes(node: Node, materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var material = node.get_active_material(index)
			if material is StandardMaterial3D and not materials.has(material):
				materials[material] = true
				SurfaceDetail.apply(material, OS.get_environment("FOH_SURFACE_PROFILE") != "mobile")
	for child in node.get_children():
		apply_to_meshes(child, materials)
