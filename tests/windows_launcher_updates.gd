extends SceneTree

const Launcher = preload("res://scripts/windows_launcher_updates.gd")
const Delta = preload("res://scripts/windows_pack_delta.gd")
const MARKER := "res://launcher_test/version.txt"

class TestLauncher extends Launcher:
	var downloads: Array[String] = []
	func begin_download(package: Dictionary,_message: String) -> void:
		downloads.append(package.url)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var launcher := Launcher.new()
	launcher.cache_dir = "user://launcher_updates_test_"+str(OS.get_process_id())
	root.add_child(launcher)
	if not expect(DirAccess.make_dir_recursive_absolute(launcher.cache_dir)==OK,"Create isolated cache"):return
	var base := make_pack(launcher,"base","windows-launcher-base-v1","windows-base.pck")
	var patch := make_pack(launcher,"update","windows-launcher-update-2-1","windows-patch.pck")
	if not expect(not base.is_empty() and not patch.is_empty(),"Create test packs"):return
	var manifest := {"schema":1,"runtime":Launcher.RUNTIME,"revision":2,"base":base,"patch":patch}
	if not expect(not Launcher.validate_manifest(manifest).is_empty(),"Validate approved manifest"):return
	var invalid := manifest.duplicate(true)
	invalid.patch.url = Launcher.RELEASES+"other-file/windows-patch.pck"
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
	if not await test_delta(launcher):return
	print("WINDOWS_LAUNCHER_UPDATES_OK")
	quit()

func make_pack(launcher: Node, content: String, tag: String, filename: String) -> Dictionary:
	var source: String = launcher.cache_dir.path_join(content+".txt")
	var file := FileAccess.open(source,FileAccess.WRITE)
	if file == null:return {}
	file.store_string(content)
	file.close()
	var temporary: String = launcher.cache_dir.path_join(content+".pck")
	var pack := PCKPacker.new()
	var shared: String=launcher.cache_dir.path_join("shared.txt")
	var shared_file:=FileAccess.open(shared,FileAccess.WRITE)
	shared_file.store_buffer(PackedByteArray([1,2,3,4]))
	shared_file.close()
	if pack.pck_start(temporary)!=OK or pack.add_file(MARKER,source)!=OK or pack.add_file("res://launcher_test/shared.txt",shared)!=OK or pack.flush()!=OK:return {}
	var info := {"url":Launcher.RELEASES+tag+"/"+filename,"size":FileAccess.open(temporary,FileAccess.READ).get_length(),"sha256":FileAccess.get_sha256(temporary)}
	if DirAccess.rename_absolute(temporary,launcher.pack_path(info))!=OK:return {}
	return info

func test_delta(original: Node) -> bool:
	var launcher := TestLauncher.new()
	launcher.cache_dir = original.cache_dir
	root.add_child(launcher)
	var old: Dictionary = launcher.active.patch
	var base: Dictionary = launcher.active.base
	var target:=make_pack(launcher,"latest","windows-launcher-update-3-1","windows-patch.pck")
	var target_path: String=launcher.pack_path(target)
	var old_bytes:=FileAccess.get_file_as_bytes(launcher.pack_path(old))
	var target_bytes:=FileAccess.get_file_as_bytes(target_path)
	var point:=0
	while point<old_bytes.size() and point<target_bytes.size() and old_bytes[point]==target_bytes[point]:
		point+=1
	if not expect(point>32,"Fixture has reusable content"):return false
	var delta_path: String=launcher.cache_dir.path_join("delta-test.bin")
	var file:=FileAccess.open(delta_path,FileAccess.WRITE)
	file.store_buffer("FHD1".to_ascii_buffer())
	file.store_32(old_bytes.size())
	file.store_32(target_bytes.size())
	file.store_32(2)
	file.store_32(0)
	file.store_32(point)
	file.store_32(Delta.LITERAL)
	file.store_32(target_bytes.size()-point)
	file.store_buffer(target_bytes.slice(point))
	file.close()
	var delta:={"url":Launcher.RELEASES+"windows-launcher-update-3-1/windows-delta-2-1.bin",
		"from":old,"size":FileAccess.get_file_as_bytes(delta_path).size(),"sha256":FileAccess.get_sha256(delta_path)}
	if not expect(Launcher.valid_delta(delta,target),"Accept a smaller transfer for the expected release"):return false
	var foreign:=delta.duplicate()
	foreign.url=Launcher.RELEASES+"windows-launcher-update-3-1/another.bin"
	if not expect(not Launcher.valid_delta(foreign,target),"Reject unexpected transfer URL"):return false
	if not expect(DirAccess.remove_absolute(target_path)==OK,"Remove installed target fixture"):return false
	var manifest:={"schema":1,"runtime":Launcher.RUNTIME,"revision":3,"base":base,"patch":target,"deltas":[delta]}
	launcher.request_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(manifest).to_utf8_buffer())
	if not expect(launcher.downloads==[delta.url],"Request only the matching delta"):return false
	var download_path: String=launcher.cache_dir.path_join("download.tmp")
	if not expect(DirAccess.copy_absolute(delta_path,download_path)==OK,"Stage test download"):return false
	launcher.request_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),PackedByteArray())
	while launcher.verification!=null:await process_frame
	if not expect(launcher.downloads.size()==1 and not launcher.starting and launcher.active.revision==3,"Install without requesting the full pack"):return false
	if not expect(FileAccess.get_sha256(target_path)==target.sha256,"Rebuild byte-for-byte"):return false
	if not expect(FileAccess.get_file_as_string(MARKER)=="latest","Launch the rebuilt pack"):return false
	var invalid_target:=target.duplicate()
	invalid_target.sha256=old.sha256
	var rejected_path: String=launcher.cache_dir.path_join("invalid-rebuilt.tmp")
	return expect(not Delta.rebuild(delta_path,launcher.pack_path(old),rejected_path,delta,invalid_target),"Reject the wrong reconstructed checksum")

func expect(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
