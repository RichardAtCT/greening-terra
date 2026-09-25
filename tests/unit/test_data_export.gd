extends GutTest
## Guards against a Godot 4.7 export fault: a packed-array export declared with an empty
## initializer ("= []") comes out empty in exported (web) builds when a .tres sets it, though the
## editor and these tests see the value. The UPGRADE pads vanished on the web that way. (A
## non-empty default, like TerraformDef.stage_limits, exports fine.)

const SCRIPTS := "res://scripts/data/"
const DATA := "res://data/"


func test_no_data_file_sets_a_packed_array_declared_with_an_empty_initializer() -> void:
	var risky := {}
	var re := RegEx.create_from_string("@export var (\\w+): Packed\\w+Array\\s*=\\s*(\\[\\s*\\]|Packed\\w+Array\\(\\s*\\))")
	for f in DirAccess.get_files_at(SCRIPTS):
		if f.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string(SCRIPTS + f)):
				risky[m.get_string(1)] = f
	var set_in := []
	for path in _tres_files(DATA):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var name := line.split(" = ", false, 1)[0].strip_edges() if " = " in line else ""
			if risky.has(name):
				set_in.append("%s sets %s (declared with an empty initializer in %s)" % [path, name, risky[name]])
	assert_eq(set_in, [], "drop the empty initializer")


func _tres_files(dir: String) -> Array:
	var out := []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_tres_files(dir + sub + "/"))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir + f)
	return out
