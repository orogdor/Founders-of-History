extends Node

signal status_changed(text: String)
signal ready_to_play

const CHANNEL := "https://raw.githubusercontent.com/orogdor/Founders-of-History/android-launcher-channel/manifest.json"
const RELEASES := "https://github.com/orogdor/Founders-of-History/releases/download/"
const RUNTIME := "godot-4.7.2-android-v1"
const MAX_PACK_SIZE := 1_610_612_736
const CACHE := "user://founders_launcher"
const MANIFEST_BYTES := 32_768

var request: HTTPRequest
var starting := true
var busy := false
var download_size := 0
var active: Dictionary = {}
var previous: Dictionary = {}
var mounted: Dictionary = {}
var candidate: Dictionary = {}
var downloading: Dictionary = {}
var verification: Thread
var cache_dir := CACHE

func _ready() -> void:
	request = HTTPRequest.new()
	request.use_threads = true
	request.accept_gzip = false
	request.max_redirects = 5
	add_child(request)
	request.request_completed.connect(request_completed)
	var state := ConfigFile.new()
	if state.load(cache_dir.path_join("active.cfg")) == OK:
		active = validate_manifest(state.get_value("launcher","active",{}))
		previous = validate_manifest(state.get_value("launcher","previous",{}))
	if not cached(active):
		active = previous if cached(previous) else {}
		previous = {}

static func validate_manifest(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema") != 1 or value.get("runtime") != RUNTIME:
		return {}
	var number: Variant = value.get("revision")
	if not (number is int or number is float) or number < 1 or number > 2_147_483_647 or int(number) != number:
		return {}
	if not valid_pack(value.get("base"),"android-launcher-base-v1","android-base.pck"):
		return {}
	var patch: Variant = value.get("patch")
	if patch != null and not valid_pack(patch,"android-launcher-update-","android-patch.pck"):
		return {}
	return value

static func valid_pack(info: Variant,tag_pattern: String,filename: String) -> bool:
	if not info is Dictionary or not info.get("url") is String or not info.get("sha256") is String:
		return false
	var size: Variant = info.get("size")
	if not (size is int or size is float) or size < 104 or size > MAX_PACK_SIZE or int(size) != size:
		return false
	if info.sha256.length() != 64:
		return false
	for character in info.sha256:
		if character not in "0123456789abcdef":return false
	var url: String = info.url
	if not url.begins_with(RELEASES):return false
	var parts := url.trim_prefix(RELEASES).split("/")
	if parts.size() != 2 or parts[1] != filename:return false
	if filename == "android-base.pck":return parts[0] == tag_pattern
	if not parts[0].begins_with(tag_pattern):return false
	var build := parts[0].trim_prefix(tag_pattern).split("-")
	return build.size()==2 and build[0].is_valid_int() and build[1].is_valid_int() and int(build[0])>0 and int(build[1])>0

func check() -> void:
	if busy:return
	busy = true
	request.timeout = 8
	request.body_size_limit = MANIFEST_BYTES
	request.download_file = ""
	status_changed.emit("Kontrollin GitHubist mänguversiooni…")
	if request.request(CHANNEL,["Cache-Control: no-cache"]) != OK:
		fail("GitHubiga ei saanud ühendust.")

func request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		fail("Uuendust ei õnnestunud alla laadida.")
		return
	if not downloading.is_empty():
		var path := cache_dir.path_join("download.tmp")
		var size := int(downloading.size)
		var digest: String = downloading.sha256
		status_changed.emit("Kontrollin allalaaditud mängufaile…")
		download_size = 0
		verification = Thread.new()
		if verification.start(verify_pack.bind(path,size,digest)) != OK:
			verification = null
			fail("Mängufaili kontrolli ei saanud käivitada.")
		return
	candidate = validate_manifest(JSON.parse_string(body.get_string_from_utf8()))
	if candidate.is_empty():
		fail("Ühilduvat GitHubi mängupakki ei leitud.")
		return
	if cached(active) and int(candidate.revision) <= int(active.revision):
		busy = false
		if starting:play_cached()
		else:status_changed.emit("Mäng on ajakohane.")
		return
	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK:
		fail("Mängu salvestuskausta ei saanud luua.")
		return
	download_next()

func download_next() -> void:
	for key in ["base","patch"]:
		var pack: Variant = candidate.get(key)
		if pack == null or cached_pack(pack):continue
		downloading = pack
		download_size = int(pack.size)
		request.timeout = 2700
		request.body_size_limit = download_size
		request.download_file = cache_dir.path_join("download.tmp")
		status_changed.emit("Laen mängu esimest korda alla…" if key=="base" else "Laen GitHubist mängu uuendust alla…")
		if request.request(pack.url) != OK:fail("Allalaadimist ei saanud alustada.")
		return
	if not save_state(candidate):
		fail("Mänguversiooni ei saanud salvestada.")
		return
	busy = false
	if starting:play_cached()
	else:status_changed.emit("Uuendus on valmis. Ava mäng uuesti, et see kasutusele võtta.")

static func verify_pack(path: String, size: int, digest: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() != size or file.get_buffer(4).get_string_from_ascii() != "GDPC":
		return false
	file.close()
	return FileAccess.get_sha256(path) == digest

func _process(_delta: float) -> void:
	if verification == null or verification.is_alive():return
	var valid: bool = verification.wait_to_finish()
	verification = null
	if not valid:
		fail("Allalaaditud mängufaili kontrollsumma ei klapi.")
		return
	if DirAccess.rename_absolute(cache_dir.path_join("download.tmp"),pack_path(downloading)) != OK:
		fail("Mängufaili ei saanud salvestada.")
		return
	downloading = {}
	download_next()

func _exit_tree() -> void:
	if verification != null:verification.wait_to_finish()

func fail(message: String) -> void:
	busy = false
	download_size = 0
	downloading = {}
	remove_temp()
	if starting and cached(active):play_cached()
	else:status_changed.emit(message)

func remove_temp() -> void:
	var path := cache_dir.path_join("download.tmp")
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)

func play_offline() -> void:
	if not starting or verification != null or not cached(active):return
	request.cancel_request()
	busy = false
	download_size = 0
	downloading = {}
	remove_temp()
	play_cached()

func play_cached() -> void:
	if not starting:return
	for manifest in [active,previous]:
		if not cached(manifest):continue
		if not ProjectSettings.load_resource_pack(pack_path(manifest.base),true):continue
		var patch: Variant = manifest.get("patch")
		if patch != null and not ProjectSettings.load_resource_pack(pack_path(patch),true):continue
		if not ResourceLoader.exists("res://main.tscn"):continue
		mounted = manifest
		starting = false
		status_changed.emit("Mänguversioon on valmis.")
		ready_to_play.emit()
		return
	status_changed.emit("Salvestatud mängupakki ei saanud avada.")

func pack_path(pack: Dictionary) -> String:
	return cache_dir.path_join(str(pack.sha256)+".pck")

func cached_pack(pack: Dictionary) -> bool:
	var file := FileAccess.open(pack_path(pack),FileAccess.READ)
	return file != null and file.get_length() == int(pack.size)

func cached(manifest: Dictionary) -> bool:
	if manifest.is_empty() or not cached_pack(manifest.base):return false
	var patch: Variant = manifest.get("patch")
	return patch == null or cached_pack(patch)

func save_state(manifest: Dictionary) -> bool:
	var state := ConfigFile.new()
	state.set_value("launcher","active",manifest)
	state.set_value("launcher","previous",active)
	var target := cache_dir.path_join("active.cfg")
	if state.save(target+".tmp") != OK or DirAccess.rename_absolute(target+".tmp",target) != OK:
		return false
	previous = active
	active = manifest
	var keep: Array[String] = []
	for version in [active,previous,mounted]:
		for key in ["base","patch"]:
			var pack: Variant = version.get(key)
			if pack != null:keep.append(pack_path(pack).get_file())
	for filename in DirAccess.get_files_at(cache_dir):
		if filename.ends_with(".pck") and filename.length()==68 and filename not in keep:
			DirAccess.remove_absolute(cache_dir.path_join(filename))
	return true
