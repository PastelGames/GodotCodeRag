class_name DataManager
extends RefCounted

static func get_index_file_path() -> String:
	var project_path := ProjectSettings.get_setting("editor/external_path", "")
	if project_path.is_empty():
		project_path = OS.get_exe_path().get_base_dir()

	var data_dir := project_path.path_join("data")
	if not DirAccess.dir_exists_absolute(data_dir):
		DirAccess.make_dir_recursive_absolute(data_dir)

	return data_dir.path_join("rag_index.yaml")

static func save_index(data: Dictionary) -> bool:
	var file_path := get_index_file_path()
	var file := FileAccess.open(file_path, FileAccess.WRITE)

	if file == null:
		push_error("DataManager: Cannot open file for writing: " + file_path)
		return false

	var yaml_content := _dict_to_yaml(data)
	file.store_string(yaml_content)
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

	return _yaml_to_dict(content)

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

static func _dict_to_yaml(data: Dictionary, indent: int = 0) -> String:
	var result := ""
	var indent_str := "  ".repeat(indent)

	for key in data.keys():
		var value = data[key]

		if value is Dictionary:
			result += "%s%s:\n" % [indent_str, key]
			result += _dict_to_yaml(value, indent + 1)
		elif value is Array:
			result += "%s%s:\n" % [indent_str, key]
			for item in value:
				if item is Dictionary:
					result += "  %s- \n" % indent_str
					result += _dict_to_yaml(item, indent + 2)
				elif item is String:
					result += "  %s- \"%s\"\n" % [indent_str, item.replace("\\", "\\\\").replace("\"", "\\\"")]
				elif item is int or item is float:
					result += "  %s- %s\n" % [indent_str, str(item)]
				elif item == null:
					result += "  %s- null\n" % indent_str
				else:
					result += "  %s- %s\n" % [indent_str, str(item)]
		elif value is String:
			result += "%s%s: \"%s\"\n" % [indent_str, key, value.replace("\\", "\\\\").replace("\"", "\\\"")]
		elif value is int or value is float:
			result += "%s%s: %s\n" % [indent_str, key, str(value)]
		elif value == null:
			result += "%s%s: null\n" % [indent_str, key]
		else:
			result += "%s%s: %s\n" % [indent_str, key, str(value)]

	return result

static func _yaml_to_dict(content: String) -> Dictionary:
	var lines := content.split("\n", false)
	var result := {}
	var stack: Array[Dictionary] = [result]
	var indent_stack: Array[int] = [0]
	var array_stack: Array = []

	var i := 0
	while i < lines.size():
		var line := lines[i]
		var raw_indent := line.find(line.lstrip(" "))

		if line.strip_edges(true, true).is_empty():
			i += 1
			continue

		line = line.lstrip(" ")

		if line.begins_with("#"):
			i += 1
			continue

		var is_array_item := false
		if line.begins_with("- "):
			is_array_item = true
			line = line.substr(2)

		var colon_pos := line.find(":")
		if colon_pos == -1:
			i += 1
			continue

		var key: String = line.substr(0, colon_pos).strip_edges()
		var value_str: String = line.substr(colon_pos + 1).strip_edges()

		while indent_stack.size() > 1 and raw_indent <= indent_stack.back():
			stack.pop_back()
			indent_stack.pop_back()

		if array_stack.size() > 0 and raw_indent <= indent_stack.back():
			array_stack.clear()

		var current_dict: Dictionary = stack.back()

		if is_array_item:
			if not current_dict.has(key):
				current_dict[key] = []

			var array: Array = current_dict[key]

			if value_str.is_empty():
				array_stack.append(key)
				stack.append({})
				array.append({})
				indent_stack.append(raw_indent + 2)
			else:
				var value: Variant = _parse_yaml_value(value_str)
				array.append(value)
		else:
			if value_str.is_empty():
				stack.append({})
				indent_stack.append(raw_indent + 2)
				current_dict[key] = {}
			else:
				var value: Variant = _parse_yaml_value(value_str)
				current_dict[key] = value

		i += 1

	return result

static func _parse_yaml_value(value_str: String) -> Variant:
	if value_str == "null":
		return null
	if value_str == "true":
		return true
	if value_str == "false":
		return false
	if value_str.is_valid_int():
		return value_str.to_int()
	if value_str.is_valid_float():
		return value_str.to_float()

	if value_str.begins_with("\"") and value_str.ends_with("\""):
		return value_str.substr(1, value_str.length() - 2).replace("\\\"", "\"").replace("\\\\", "\\")

	if value_str.begins_with("[") and value_str.ends_with("]"):
		var inner := value_str.substr(1, value_str.length() - 2)
		if inner.is_empty():
			return []
		var parts := inner.split(",")
		var array: Array = []
		for part in parts:
			part = part.strip_edges()
			if part.is_valid_int():
				array.append(part.to_int())
			elif part.is_valid_float():
				array.append(part.to_float())
			elif part.begins_with("\"") and part.ends_with("\""):
				array.append(part.substr(1, part.length() - 2))
			else:
				array.append(part)
		return array

	return value_str