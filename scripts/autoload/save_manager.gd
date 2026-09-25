extends Node
## Reads and writes profile saves as JSON in user:// (IndexedDB on web).

const SAVE_VERSION := 1

var active_profile: int = 1


func profile_path(profile: int) -> String:
	return "user://profile_%d.json" % profile


func has_save(profile: int) -> bool:
	return FileAccess.file_exists(profile_path(profile))


func save_state(profile: int, state: WorldState) -> bool:
	var data := {"version": SAVE_VERSION, "saved_at": Time.get_unix_time_from_system(), "world": state.to_dict()}
	var f := FileAccess.open(profile_path(profile), FileAccess.WRITE)
	if f == null:
		push_warning("Could not save profile %d: %s" % [profile, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data))
	# Closing flushes the file; on web this also syncs it to IndexedDB.
	f.close()
	return true


func load_state(profile: int) -> WorldState:
	if not has_save(profile):
		return null
	var text := FileAccess.get_file_as_string(profile_path(profile))
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("world"):
		push_warning("Profile %d save is unreadable; starting fresh." % profile)
		return null
	return WorldState.from_dict(migrate(data)["world"])


## Upgrades an older save dictionary to SAVE_VERSION.
func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version < 1:
		data["version"] = 1
	return data
