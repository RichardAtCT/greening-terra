extends Node
## Profiles, saves and settings, all as JSON in user:// (IndexedDB on web).
## Each profile's world lives in user://profile_N.json; names/colours in user://profiles.json;
## settings in user://settings.json.

signal profiles_changed

const SAVE_VERSION := 1
const PROFILE_COUNT := 3
const EXPORT_PREFIX := "GT1:"
const PROFILES_PATH := "user://profiles.json"
const SETTINGS_PATH := "user://settings.json"
const DEFAULT_NAMES := ["Explorer 1", "Explorer 2", "Explorer 3"]
const COLORS := ["f2b35b", "86e07c", "8fe3ff", "d9794a", "c9a0ff", "ff8fb1"]
const DEFAULT_SETTINGS := {"music_volume": 0.8, "sfx_volume": 0.9, "haptics": true, "reduced_effects": false}

var active_profile: int = 1
## Profile index (1-based) -> {"name": String, "color": String hex}.
var profiles: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()


func _ready() -> void:
	_load_profiles()
	_load_settings()


func profile_path(profile: int) -> String:
	return "user://profile_%d.json" % profile


func has_save(profile: int) -> bool:
	return FileAccess.file_exists(profile_path(profile))


func save_state(profile: int, state: WorldState) -> bool:
	return _write_json(profile_path(profile), make_save_dict(state))


func load_state(profile: int) -> WorldState:
	if not has_save(profile):
		return null
	return state_from_save_dict(_read_json(profile_path(profile)))


func delete_save(profile: int) -> void:
	if has_save(profile):
		DirAccess.remove_absolute(profile_path(profile))
		_sync_web()
	profiles_changed.emit()


static func make_save_dict(state: WorldState) -> Dictionary:
	return {"version": SAVE_VERSION, "saved_at": Time.get_unix_time_from_system(), "world": state.to_dict()}


## Returns null for anything that isn't a readable save.
static func state_from_save_dict(data) -> WorldState:
	if typeof(data) != TYPE_DICTIONARY or not data.has("world") or typeof(data["world"]) != TYPE_DICTIONARY:
		return null
	return WorldState.from_dict(migrate(data)["world"])


## Upgrades an older save dictionary to SAVE_VERSION. Add a step here whenever the format changes.
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version < 1:
		# v0 (pre-release) saves had no version field; the world layout is the same.
		version = 1
	data["version"] = version
	return data


## Save as a single line of text for copying somewhere safe (backup against Safari clearing data).
static func export_text(state: WorldState) -> String:
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(make_save_dict(state), "", true, true))


## Parses text from export_text(); returns null if it isn't a valid save.
static func import_text(text: String) -> WorldState:
	text = text.strip_edges()
	if not text.begins_with(EXPORT_PREFIX):
		return null
	var body := text.substr(EXPORT_PREFIX.length())
	var b64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if body.length() % 4 != 0 or b64.search(body) == null:
		return null
	var json := Marshalls.base64_to_utf8(body)
	return state_from_save_dict(JSON.parse_string(json)) if json != "" else null


# --- Profiles -------------------------------------------------------------

func profile_name(profile: int) -> String:
	return profiles.get(profile, {}).get("name", DEFAULT_NAMES[profile - 1])


func profile_color(profile: int) -> Color:
	return Color(profiles.get(profile, {}).get("color", COLORS[profile - 1]))


func set_profile(profile: int, p_name: String, color_hex: String) -> void:
	profiles[profile] = {"name": p_name.strip_edges().left(20), "color": color_hex}
	_write_json(PROFILES_PATH, _profiles_to_json())
	profiles_changed.emit()


func _profiles_to_json() -> Dictionary:
	var out := {}
	for k in profiles:
		out[str(k)] = profiles[k]
	return out


func _load_profiles() -> void:
	profiles.clear()
	var data = _read_json(PROFILES_PATH)
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			if typeof(data[k]) == TYPE_DICTIONARY:
				profiles[int(k)] = data[k]


# --- Settings -------------------------------------------------------------

func set_setting(key: String, value) -> void:
	settings[key] = value
	_write_json(SETTINGS_PATH, settings)


func _load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var data = _read_json(SETTINGS_PATH)
	if typeof(data) == TYPE_DICTIONARY:
		for k in DEFAULT_SETTINGS:
			if data.has(k):
				settings[k] = data[k]


# --- Files ----------------------------------------------------------------

func _write_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "", true, true))
	# Closing flushes the file; on web this also syncs it to IndexedDB.
	f.close()
	return true


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _sync_web() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (typeof FS !== 'undefined' && FS.syncfs) { FS.syncfs(false, function(){}); }", true)
