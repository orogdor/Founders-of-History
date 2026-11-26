extends SceneTree

const FOLDER := "res://assets/surface_detail/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "materials.json"))
	if not manifest is Dictionary or manifest.size() < 100:
		printerr("Enhanced material manifest missing or incomplete")
		quit(1)
		return
	var grass: Texture2D = load("res://assets/ground/grass-color.webp")
	var terrain_height: Texture2D = load("res://assets/ground/ground-height.webp")
	var pine = load("res://assets/sapling-trees/pine_01/near.glb").instantiate()
	var pine_materials: Array[StandardMaterial3D] = []
	find_materials(pine, pine_materials)
	var has_relief := false
	for material in pine_materials:
		if material.normal_enabled and material.normal_texture != null:
			has_relief = true
	pine.free()
	if grass.get_width() < 1024 or terrain_height.get_width() < 1024 or not has_relief:
		printerr("Enhanced ground or imported tree relief missing: ", grass.get_width(), ", ", terrain_height.get_width(), ", ", has_relief)
		quit(1)
		return
	print("SURFACE_UPGRADE_OK material_sources=", manifest.size())
	quit()

func find_materials(node: Node, results: Array[StandardMaterial3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var material = node.get_active_material(index)
			if material is StandardMaterial3D:
				results.append(material)
	for child in node.get_children():
		find_materials(child, results)
