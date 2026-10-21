extends SceneTree
## What the game can reach, for the export's exclude list (release_polish_plan.md
## §2, 2026-10-22): every res:// path the code, scenes and resources name
## (format strings and folder prefixes widened to the files they can match),
## closed over ResourceLoader.get_dependencies. Writes the list to
## _shots_tmp/rel/needs.txt and prints a CASE line for every path named in
## another case than on the disk (the pack is case-sensitive, the Mac is not).
##
##     godot --headless --path . --script res://tools/pack_needs.gd
## then: python3 tools/pck_sizes.py <pack.pck> _shots_tmp/rel/needs.txt
const SKIP := ["res://tests/", "res://tools/", "res://_shots_tmp/", "res://xcode/", "res://build/", "res://.godot/", "res://relay/"]
var _all_files: PackedStringArray = []
var _need := {}
var _queue: Array[String] = []
var _exact := {}

func _initialize() -> void:
	_walk("res://")
	for f in _all_files:
		_exact[f] = true
	# roots: project settings, every script and scene of ours
	_add(ProjectSettings.get_setting("application/run/main_scene"))
	for f in _all_files:
		var e := f.get_extension()
		if (e == "gd" or e == "gdshader" or e == "gdshaderinc") and not _skipped(f):
			_add(f)
		if f.begins_with("res://scenes/") and (e == "tscn" or e == "tres"):
			_add(f)
	_add("res://project.godot")
	var re := RegEx.new()
	re.compile("res://[^\"'\\s)]*")
	while not _queue.is_empty():
		var f: String = _queue.pop_back()
		var e := f.get_extension()
		if e in ["gd", "tscn", "tres", "gdshader", "gdshaderinc", "godot", "cfg"]:
			var text := FileAccess.get_file_as_string(f)
			for m in re.search_all(text):
				_literal(m.get_string())
		if ResourceLoader.exists(f):
			for d in ResourceLoader.get_dependencies(f):
				var parts := d.split("::")
				var p := parts[parts.size() - 1] if parts.size() > 0 else d
				if p.begins_with("uid://"):
					p = ResourceUID.uid_to_path(p)
				if not p.begins_with("res://"):
					p = parts[0]
					if p.begins_with("uid://"):
						p = ResourceUID.uid_to_path(p)
				if FileAccess.file_exists(p) and not _exact.has(p):
					print("CASE ", p, " <- ", f)
				_add(p)
	DirAccess.make_dir_recursive_absolute("res://_shots_tmp/rel")
	var out := FileAccess.open("res://_shots_tmp/rel/needs.txt", FileAccess.WRITE)
	var keys := _need.keys()
	keys.sort()
	for k in keys:
		out.store_line(k)
	print("NEEDS ", keys.size())
	quit()

func _skipped(f: String) -> bool:
	for s in SKIP:
		if f.begins_with(s):
			return true
	return false

func _walk(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	for f in d.get_files():
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		_all_files.append(dir.path_join(f))
	for s in d.get_directories():
		var p := dir.path_join(s)
		if p == "res://.godot" or FileAccess.file_exists(p + "/.gdignore"):
			continue
		_walk(p)

func _add(p: String) -> void:
	if p == "" or _need.has(p) or _skipped(p):
		return
	if not FileAccess.file_exists(p) and not ResourceLoader.exists(p):
		return
	_need[p] = true
	_queue.append(p)

## A literal: a file, a folder (every file under it), or a pattern with %s/%d
## (every file it could match).
func _literal(s: String) -> void:
	s = s.trim_suffix("\\")
	if s.length() <= 7:
		return
	if s.contains("%"):
		var head := s.get_slice("%", 0)
		var tail := s.get_slice("%", s.count("%"))
		tail = tail.substr(1)
		for f in _all_files:
			if f.begins_with(head) and f.ends_with(tail) and not f.substr(head.length()).contains("/"):
				_add(f)
		return
	if s.ends_with("/"):
		for f in _all_files:
			if f.begins_with(s):
				_add(f)
		return
	if FileAccess.file_exists(s) or ResourceLoader.exists(s):
		_add(s)
		return
	# a prefix used as "DIR + name": files whose path begins with it
	if s.length() > 12:
		for f in _all_files:
			if f.begins_with(s) and not f.substr(s.length()).contains("/"):
				_add(f)
