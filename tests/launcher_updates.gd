extends SceneTree

const Launcher = preload("res://scripts/launcher_updates.gd")
const MARKER := "res://launcher_test/version.txt"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var launcher := Launcher.new()
	launcher.cache_dir = "user://launcher_updates_test_"+str(OS.get_process_id())
	root.add_child(launcher)
	if not expect(DirAccess.make_dir_recursive_absolute(launcher.cache_dir)==OK,"Create isolated cache"):return
	var base := make_pack(launcher,"base","android-launcher-base-v1","android-base.pck")
	var patch := make_pack(launcher,"update","android-launcher-update-2-1","android-patch.pck")
	if not expect(not base.is_empty() and not patch.is_empty(),"Create test packs"):return
	var manifest := {"schema":1,"runtime":Launcher.RUNTIME,"revision":2,"base":base,"patch":patch}
	if not expect(not Launcher.validate_manifest(manifest).is_empty(),"Validate approved manifest"):return
	var invalid := manifest.duplicate(true)
	invalid.patch.url = Launcher.RELEASES+"other-file/android-patch.pck"
	if not expect(Launcher.validate_manifest(invalid).is_empty(),"Reject unexpected release"):return
	if not expect(not Launcher.verify_pack(launcher.pack_path(patch),patch.size,base.sha256),"Reject wrong digest"):return
	if not expect(Launcher.verify_pack(launcher.pack_path(base),base.size,base.sha256),"Verify baseline"):return
	if not expect(launcher.cached(manifest),"Cached baseline and patch are available"):return
	launcher.request_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(manifest).to_utf8_buffer())
	if not expect(not launcher.starting and FileAccess.get_file_as_string(MARKER)=="update","Mount baseline before patch"):return
	var restored := Launcher.new()
	restored.cache_dir = launcher.cache_dir
	root.add_child(restored)
	if not expect(int(restored.active.get("revision",0))==2,"Persist selected revision"):return
	restored.request_completed(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())
	if not expect(not restored.starting,"Launch the cached revision when offline"):return
	print("ANDROID_LAUNCHER_UPDATES_OK")
	quit()

func make_pack(launcher: Node, content: String, tag: String, filename: String) -> Dictionary:
	var source: String = launcher.cache_dir.path_join(content+".txt")
	var file := FileAccess.open(source,FileAccess.WRITE)
	if file == null:return {}
	file.store_string(content)
	file.close()
	var temporary: String = launcher.cache_dir.path_join(content+".pck")
	var pack := PCKPacker.new()
	if pack.pck_start(temporary)!=OK or pack.add_file(MARKER,source)!=OK or pack.flush()!=OK:return {}
	var info := {"url":Launcher.RELEASES+tag+"/"+filename,"size":FileAccess.open(temporary,FileAccess.READ).get_length(),"sha256":FileAccess.get_sha256(temporary)}
	if DirAccess.rename_absolute(temporary,launcher.pack_path(info))!=OK:return {}
	return info

func expect(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
