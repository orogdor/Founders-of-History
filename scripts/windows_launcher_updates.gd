extends Node
signal status_changed(text: String)
signal ready_to_play
const CHANNEL:= "https://raw.githubusercontent.com/orogdor/Founders-of-History/windows-launcher-channel/manifest.json"
const RELEASES:= "https://github.com/orogdor/Founders-of-History/releases/download/"
const RUNTIME:= "godot-4.7.2-windows-v1"
const MAX_PACK_SIZE:= 1610612736
const LEGACY_CACHE := "founders_windows_launcher"
const MANIFEST_BYTES:= 32768
const PackDelta = preload("res://scripts/windows_pack_delta.gd")
var request: HTTPRequest
var starting:= true
var busy:= false
var download_size:= 0
var active: Dictionary = {}
var previous: Dictionary = {}
var mounted: Dictionary = {}
var candidate: Dictionary = {}
var downloading: Dictionary = {}
var transfer: Dictionary = {}
var verification: Thread
var cache_dir := "user://founders_windows_launcher"
var lock_dir := ""
var startup_error := ""

func _ready() -> void:
	var legacy_dir := ""
	if OS.has_feature("windows_download_launcher"):
		legacy_dir = OS.get_user_data_dir()
		if not setup_portable(legacy_dir):return
	request = HTTPRequest.new()
	request.use_threads = true
	request.accept_gzip = false
	request.max_redirects = 5
	add_child(request)
	request.request_completed.connect(request_completed)
	read_state()
	if active.is_empty() and not legacy_dir.is_empty():
		import_legacy_game(legacy_dir.path_join(LEGACY_CACHE))

func setup_portable(legacy_dir: String) -> bool:
	var install_dir := OS.get_executable_path().get_base_dir()
	cache_dir = install_dir.path_join("Game")
	var saves_dir := install_dir.path_join("Saves")
	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK or DirAccess.make_dir_recursive_absolute(saves_dir) != OK:
		startup_error = "Launcher vajab kirjutusõigust oma kaustas. Tõsta EXE kirjutatavasse kausta."
		return false
	if not acquire_install_lock():
		startup_error = "Mäng on juba sellest kaustast käivitatud või kaust ei ole kirjutatav."
		return false
	remove_temp()
	if not prepare_saves(legacy_dir, saves_dir):
		startup_error = "Salvestuste kausta ei saanud ette valmistada: " + saves_dir
		return false
	OS.set_environment("APPDATA", install_dir)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "Saves")
	print_verbose("Founders of History: saves at " + ProjectSettings.globalize_path("user://"))
	return true

func acquire_install_lock() -> bool:
	var path := cache_dir.path_join("launcher-lock")
	var owner_path := path.path_join("owner")
	if DirAccess.dir_exists_absolute(path):
		var owner := int(FileAccess.get_file_as_string(owner_path)) if FileAccess.file_exists(owner_path) else 0
		if owner > 0 and OS.is_process_running(owner):
			return false
		if owner <= 0 and Time.get_unix_time_from_system() - FileAccess.get_modified_time(path) < 60:
			return false
		if FileAccess.file_exists(owner_path) and DirAccess.remove_absolute(owner_path) != OK:
			return false
		if DirAccess.remove_absolute(path) != OK:
			return false
	if DirAccess.make_dir_absolute(path) != OK:
		return false
	var owner_file := FileAccess.open(owner_path, FileAccess.WRITE)
	if owner_file == null:
		DirAccess.remove_absolute(path)
		return false
	owner_file.store_string(str(OS.get_process_id()))
	owner_file.close()
	lock_dir = path
	return true

func prepare_saves(legacy_dir: String, saves_dir: String) -> bool:
	var marker := saves_dir.path_join(".initialized")
	if FileAccess.file_exists(marker):
		return true
	var names: Array[String] = ["kuningriigid_godot_settings.cfg", "kuningriigid_godot_partial_v1.json", "kuningriigid_godot_partial_v1.json.bak"]
	for slot in range(1, 4):
		names.append("kuningriigid_godot_slot_%d.json" % slot)
		names.append("kuningriigid_godot_slot_%d.json.bak" % slot)
	for filename in names:
		var source := legacy_dir.path_join(filename)
		var target := saves_dir.path_join(filename)
		if FileAccess.file_exists(source) and not FileAccess.file_exists(target):
			if not copy_into_place(source, target):
				return false
	var file := FileAccess.open(marker, FileAccess.WRITE)
	return file != null and file.store_string("1")

func copy_into_place(source: String, target: String) -> bool:
	var temp := target + ".importing"
	if DirAccess.copy_absolute(source, temp) != OK or DirAccess.rename_absolute(temp, target) != OK:
		if FileAccess.file_exists(temp):
			DirAccess.remove_absolute(temp)
		return false
	return true

func read_state() -> void:
	var state:= ConfigFile.new()
	if state.load(cache_dir.path_join("active.cfg")) == OK:
		active = validate_manifest(state.get_value("launcher", "active", {}))
		previous = validate_manifest(state.get_value("launcher", "previous", {}))
	if not cached(active):
		active = previous if cached(previous) else {}
		previous = {}

func import_legacy_game(legacy_cache: String) -> void:
	var state := ConfigFile.new()
	if state.load(legacy_cache.path_join("active.cfg")) != OK:
		return
	var old_active := validate_manifest(state.get_value("launcher", "active", {}))
	var old_previous := validate_manifest(state.get_value("launcher", "previous", {}))
	if import_version(legacy_cache, old_previous):
		save_state(old_previous)
	if import_version(legacy_cache, old_active):
		save_state(old_active)

func import_version(legacy_cache: String, manifest: Dictionary) -> bool:
	if manifest.is_empty():
		return false
	for key in ["base", "patch"]:
		var pack: Variant = manifest.get(key)
		if pack == null or cached_pack(pack):
			continue
		var target := pack_path(pack)
		var source := legacy_cache.path_join(target.get_file())
		if not verify_pack(source, int(pack.size), pack.sha256) or not copy_into_place(source, target):
			return false
	return cached(manifest)
static func validate_manifest(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema") != 1 or value.get("runtime") != RUNTIME:
		return {}
	var number: Variant = value.get("revision")
	if not(number is int or number is float) or number < 1 or number > 2147483647 or int(number) != number:
		return {}
	if not valid_pack(value.get("base"), "windows-launcher-base-v1", "windows-base.pck"):
		return {}
	var patch: Variant = value.get("patch")
	if patch != null and not valid_pack(patch, "windows-launcher-update-", "windows-patch.pck"):
		return {}
	return value
static func valid_pack(info: Variant, tag_pattern: String, filename: String) -> bool:
	if not info is Dictionary or not info.get("url") is String or not info.get("sha256") is String:
		return false
	var size: Variant = info.get("size")
	if not(size is int or size is float) or size < 104 or size > MAX_PACK_SIZE or int(size) != size:
		return false
	if not valid_digest(info.sha256):return false
	var url: String = info.url
	if not url.begins_with(RELEASES): return false
	var parts:= url.trim_prefix(RELEASES).split("/")
	if parts.size() != 2 or parts[1] != filename: return false
	if filename == "windows-base.pck": return parts[0] == tag_pattern
	if not parts[0].begins_with(tag_pattern): return false
	var build:= parts[0].trim_prefix(tag_pattern).split("-")
	return build.size() == 2 and build[0].is_valid_int() and build[1].is_valid_int() and int(build[0]) > 0 and int(build[1]) > 0

static func valid_digest(digest: Variant) -> bool:
	if not digest is String or digest.length()!=64:return false
	for character in digest:
		if character not in "0123456789abcdef":return false
	return true

static func valid_delta(info: Variant, target: Dictionary) -> bool:
	if not info is Dictionary or not info.get("url") is String or not valid_digest(info.get("sha256")):
		return false
	var origin: Variant=info.get("from")
	var size: Variant=info.get("size")
	if not (size is int or size is float) or size<24 or size>=int(target.size) or int(size)!=size:
		return false
	if not valid_pack(origin,"windows-launcher-update-","windows-patch.pck"):
		return false
	var tag: String=origin.url.trim_prefix(RELEASES).get_slice("/",0)
	var suffix:=tag.trim_prefix("windows-launcher-update-")
	var expected: String=target.url.get_base_dir()+"/windows-delta-"+suffix+".bin"
	return info.url==expected and origin.sha256!=target.sha256

func select_delta(target: Dictionary) -> Dictionary:
	var options: Variant=candidate.get("deltas",[])
	var selected: Dictionary={}
	if not options is Array:return selected
	for info in options:
		if not valid_delta(info,target) or not cached_pack(info.from):continue
		if selected.is_empty() or int(info.size)<int(selected.size):selected=info
	return selected
func check() -> void:
	if not startup_error.is_empty():
		status_changed.emit(startup_error)
		return
	if busy: return
	busy = true
	request.timeout = 8
	request.body_size_limit = MANIFEST_BYTES
	request.download_file = ""
	status_changed.emit("Kontrollin GitHubist mänguversiooni…")
	if request.request(CHANNEL, ["Cache-Control: no-cache"]) != OK:
		fail("GitHubiga ei saanud ühendust.")
func request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		fail("Uuendust ei õnnestunud alla laadida.")
		return
	if not downloading.is_empty():
		var path:= cache_dir.path_join("download.tmp")
		var verify:=verify_pack.bind(path,int(downloading.size),downloading.sha256)
		if not transfer.is_empty():
			verify=PackDelta.rebuild.bind(path,pack_path(transfer.from),cache_dir.path_join("rebuilt.tmp"),transfer,downloading)
		status_changed.emit("Kontrollin allalaaditud mängufaile…" if transfer.is_empty() else "Koostan uuendust olemasolevatest failidest…")
		download_size = 0
		verification = Thread.new()
		if verification.start(verify) != OK:
			verification = null
			fail("Mängufaili kontrolli ei saanud käivitada.")
		return
	candidate = validate_manifest(JSON.parse_string(body.get_string_from_utf8()))
	if candidate.is_empty():
		fail("Ühilduvat GitHubi mängupakki ei leitud.")
		return
	if cached(active) and int(candidate.revision) <= int(active.revision):
		busy = false
		if starting: play_cached()
		else: status_changed.emit("Mäng on ajakohane.")
		return
	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK:
		fail("Mängu salvestuskausta ei saanud luua.")
		return
	download_next()
func download_next() -> void:
	for key in["base", "patch"]:
		var pack: Variant = candidate.get(key)
		if pack == null or cached_pack(pack): continue
		downloading = pack
		transfer = select_delta(pack) if key=="patch" else {}
		if key=="base":begin_download(pack,"Laen mängu esimest korda alla…")
		elif transfer.is_empty():begin_download(pack,"Laen GitHubist mängu uuendust alla…")
		else:begin_download(transfer,"Laen muutunud mängufaile alla…")
		return
	if not save_state(candidate):
		fail("Mänguversiooni ei saanud salvestada.")
		return
	busy = false
	if starting: play_cached()
	else: status_changed.emit("Uuendus on valmis. Ava mäng uuesti, et see kasutusele võtta.")

func begin_download(package: Dictionary,message: String) -> void:
	download_size = int(package.size)
	request.timeout = 2700
	request.body_size_limit = download_size
	request.download_file = cache_dir.path_join("download.tmp")
	status_changed.emit(message)
	if request.request(package.url) != OK:fail("Allalaadimist ei saanud alustada.")
static func verify_pack(path: String, size: int, digest: String) -> bool:
	var file:= FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != size or file.get_buffer(4).get_string_from_ascii() != "GDPC":
		return false
	file.close()
	return FileAccess.get_sha256(path) == digest
func _process(_delta: float) -> void:
	if verification == null or verification.is_alive(): return
	var valid: bool = verification.wait_to_finish()
	verification = null
	if not valid:
		if not transfer.is_empty():
			transfer = {}
			remove_temp()
			begin_download(downloading,"Osalist uuendust ei saanud rakendada. Laen täispaki alla…")
			return
		fail("Allalaaditud mängufaili kontrollsumma ei klapi.")
		return
	var temp:="download.tmp" if transfer.is_empty() else "rebuilt.tmp"
	if DirAccess.rename_absolute(cache_dir.path_join(temp), pack_path(downloading)) != OK:
		fail("Mängufaili ei saanud salvestada.")
		return
	downloading = {}
	transfer = {}
	remove_temp()
	download_next()
func _exit_tree() -> void:
	if verification != null:
		verification.wait_to_finish()
	if not lock_dir.is_empty():
		if request != null:
			request.cancel_request()
		remove_temp()
		DirAccess.remove_absolute(lock_dir.path_join("owner"))
		DirAccess.remove_absolute(lock_dir)
func fail(message: String) -> void:
	busy = false
	download_size = 0
	downloading = {}
	transfer = {}
	remove_temp()
	if starting and cached(active): play_cached()
	else: status_changed.emit(message)
func remove_temp() -> void:
	for name in ["download.tmp","rebuilt.tmp"]:
		var path:=cache_dir.path_join(name)
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
func play_offline() -> void:
	if not starting or verification != null or not cached(active): return
	request.cancel_request()
	busy = false
	download_size = 0
	downloading = {}
	transfer = {}
	remove_temp()
	play_cached()
func play_cached() -> void:
	if not starting: return
	for manifest in[active, previous]:
		if not cached(manifest): continue
		if not ProjectSettings.load_resource_pack(pack_path(manifest.base), true): continue
		var patch: Variant = manifest.get("patch")
		if patch != null and not ProjectSettings.load_resource_pack(pack_path(patch), true): continue
		if not ResourceLoader.exists("res://main.tscn"): continue
		mounted = manifest
		starting = false
		status_changed.emit("Mänguversioon on valmis.")
		ready_to_play.emit()
		return
	status_changed.emit("Salvestatud mängupakki ei saanud avada.")
func pack_path(pack: Dictionary) -> String:
	return cache_dir.path_join(str(pack.sha256) + ".pck")
func cached_pack(pack: Dictionary) -> bool:
	var file:= FileAccess.open(pack_path(pack), FileAccess.READ)
	return file != null and file.get_length() == int(pack.size)
func cached(manifest: Dictionary) -> bool:
	if manifest.is_empty() or not cached_pack(manifest.base): return false
	var patch: Variant = manifest.get("patch")
	return patch == null or cached_pack(patch)
func save_state(manifest: Dictionary) -> bool:
	var state:= ConfigFile.new()
	state.set_value("launcher", "active", manifest)
	state.set_value("launcher", "previous", active)
	var target:= cache_dir.path_join("active.cfg")
	if state.save(target + ".tmp") != OK or DirAccess.rename_absolute(target + ".tmp", target) != OK:
		return false
	previous = active
	active = manifest
	var keep: Array[String] = []
	for version in[active, previous, mounted]:
		for key in["base", "patch"]:
			var pack: Variant = version.get(key)
			if pack != null: keep.append(pack_path(pack).get_file())
	for filename in DirAccess.get_files_at(cache_dir):
		if filename.ends_with(".pck") and filename.length() == 68 and filename not in keep:
			DirAccess.remove_absolute(cache_dir.path_join(filename))
	return true
