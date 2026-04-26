class_name DataManager
extends RefCounted

static func get_index_file_path() -> String:
	var data_dir: String = ProjectSettings.globalize_path("user://").path_join("rag_data")
	var dir := DirAccess.open(ProjectSettings.globalize_path("user://"))
	if dir:
		if not dir.dir_exists("rag_data"):
			dir.make_dir("rag_data")
	else:
		DirAccess.make_dir_recursive_absolute(data_dir)

	return data_dir.path_join("rag_index.json")

static func save_index(data: Dictionary) -> bool:
	var file_path := get_index_file_path()
	var file := FileAccess.open(file_path, FileAccess.WRITE)

	if file == null:
		push_error("DataManager: Cannot open file for writing: " + file_path)
		return false

	var json_string := JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

	return true

static func load_index() -> Dictionary:
	var file_path := get_index_file_path()

	if not FileAccess.file_exists(file_path):
		return _default_config()

	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("DataManager: Cannot open file for reading: " + file_path)
		return _default_config()

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		push_error("DataManager: JSON parse error")
		return _default_config()

	return json.get_data()

static func delete_index() -> bool:
	var file_path := get_index_file_path()

	if not FileAccess.file_exists(file_path):
		return true

	var dir := DirAccess.open(file_path.get_base_dir())
	if dir:
		dir.remove(file_path)

	return true

static func _default_config() -> Dictionary:
	return {
		"version": "1.0",
		"config": {
			"ignored_folders": [".git", ".godot", "node_modules"],
			"ignored_files": [],
			"chunk_size": 50,
			"chunk_overlap": 10
		},
		"last_indexed": "",
		"indexes": []
	}
