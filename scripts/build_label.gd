extends RefCounted

static func mounted_build(tree: SceneTree) -> Dictionary:
	var updates:=tree.root.get_node_or_null("GameUpdates")
	if updates!=null and is_instance_valid(updates.launcher):return updates.launcher.mounted
	return {}

static func short_text(tree: SceneTree) -> String:
	var build:=mounted_build(tree)
	if not build.is_empty():return "Mäng v%d" % int(build.revision)
	var version:=str(ProjectSettings.get_setting("application/config/version",""))
	return "Mäng v"+version if not version.is_empty() else "Kohalik ehitus"

static func detailed_text(tree: SceneTree) -> String:
	var source:=str(mounted_build(tree).get("source",""))
	return short_text(tree)+(" · "+source.left(8) if not source.is_empty() else "")

static func update_text(updates: Node) -> String:
	if not is_instance_valid(updates.launcher):return updates.status
	var launcher: Node=updates.launcher
	var running:=int(launcher.mounted.get("revision",0))
	var installed:=int(launcher.active.get("revision",0))
	if installed>running:
		return "Mäng v%d töötab. Uuendus v%d on alla laaditud ja avaneb järgmisel käivitamisel." % [running,installed]
	return updates.status
