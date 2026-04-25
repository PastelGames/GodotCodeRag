class_name CodeScanner
extends RefCounted

const SUPPORTED_EXTENSIONS := [".gd", ".tscn", ".tres", ".shader", ".gdshader", ".gml", ".cfg", ".ini", ".json", ".md", ".txt", ".yaml", ".yml"]

var _ignored_folders: Array[String] = [".git", ".godot", "node_modules"]
var _ignored_files: Array[String] = []
var _chunk_size: int = 50
var _chunk_overlap: int = 10
var _delimiter: String = " "

signal progress_updated(current: int, total: int, file_path: String)

func set_ignored_folders(folders: Array[String]) -> void:
	_ignored_folders = folders

func set_ignored_files(files: Array[String]) -> void:
	_ignored_files = files

static func is_valid_extension(ext: String) -> bool:
	var Extension := "." + ext.lstrip(".")
	return Extension in SUPPORTED_EXTENSIONS

func set_chunk_size(size: int) -> void:
	_chunk_size = max(1, size)

func set_chunk_overlap(overlap: int) -> void:
	_chunk_overlap = overlap

func scan_directory(root_path: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(root_path)

	if dir == null:
		push_error("CodeScanner: Cannot open directory: " + root_path)
		return results

	dir.include_hidden = false
	dir.include_access_reversed = false

	var all_files := _collect_files(dir, root_path)
	var total_files := all_files.size()
	var current := 0

	for file_path in all_files:
		current += 1
		progress_updated.emit(current, total_files, file_path)

		var chunks := _chunk_file(file_path)
		for i in chunks.size():
			chunks[i]["chunk_id"] = i
			chunks[i]["path"] = file_path

		results.append_array(chunks)

	return results

func _collect_files(dir: DirAccess, root_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir_path := dir.get_current_dir()

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := dir_path.path_join(file_name)

		if dir.current_is_dir():
			if file_name in _ignored_folders:
				file_name = dir.get_next()
				continue

			var sub_dir := DirAccess.open(full_path)
			if sub_dir:
				results.append_array(_collect_files(sub_dir, root_path))
		else:
			if file_name in _ignored_files:
				file_name = dir.get_next()
				continue

			var ext := file_name.get_extension()
			if ext.is_valid_extension():
				if not full_path.is_valid_resource_path():
					full_path = _make_resource_path(full_path, root_path)
				results.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return results

func _chunk_file(file_path: String) -> Array[Dictionary]:
	var chunks: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("CodeScanner: Cannot read file: " + file_path)
		return chunks

	var lines: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line()
		lines.append(line)

	file.close()

	if lines.is_empty():
		return chunks

	var total_lines := lines.size()
	var start_line := 1
	var line_num := 1

	while start_line <= total_lines:
		var end_line := min(start_line + _chunk_size - 1, total_lines)
		var chunk_content := _extract_chunk_content(lines, start_line - 1, end_line - 1)

		chunks.append({
			"start_line": start_line,
			"end_line": end_line,
			"content": chunk_content
		})

		start_line += _chunk_size - _chunk_overlap
		if start_line < 1:
			start_line = 1

	return chunks

func _extract_chunk_content(lines: Array[String], start: int, end: int) -> String:
	var chunk_lines: PackedStringArray = []

	for i in range(start, min(end + 1, lines.size())):
		chunk_lines.append(lines[i])

	return String.join(_delimiter, chunk_lines)

func _make_resource_path(absolute_path: String, root_path: String) -> String:
	var relative := absolute_path.trim_prefix(root_path)
	if relative.begins_with("/") or relative.begins_with("\\"):
		relative = relative.substr(1)

	return "res://" + relative.replace("\\", "/")