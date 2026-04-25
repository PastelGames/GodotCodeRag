class_name SettingsDialog
extends ConfirmationDialog

signal settings_saved(config: Dictionary)

var _ignored_folders_input: TextEdit
var _ignored_files_input: TextEdit
var _chunk_size_spin: SpinBox
var _chunk_overlap_spin: SpinBox
var _top_k_spin: SpinBox
var _ollama_url_input: LineEdit
var _vbox: VBoxContainer

var _current_config: Dictionary = {}

func _init() -> void:
	title = "RAG Settings"
	ok_button_text = "Save"
	cancel_button_text = "Cancel"

func _ready() -> void:
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(400, 350)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 10)

	scroll.add_child(_vbox)
	add_child(scroll)

	_create_folder_input()
	_create_file_input()
	_create_size_inputs()
	_create_top_k_input()
	_create_ollama_input()
	_create_reset_button()

func _create_folder_input() -> void:
	var label := Label.new()
	label.text = "Ignored Folders (one per line):"
	_vbox.add_child(label)

	_ignored_folders_input = TextEdit.new()
	_ignored_folders_input.custom_minimum_size = Vector2(0, 60)
	_ignored_folders_input.wrap_mode = TextEdit.LINE_WRAPPING_DISABLED
	_vbox.add_child(_ignored_folders_input)

	var hint := Label.new()
	hint.text = "Default: .git, .godot, node_modules"
	hint.add_theme_font_size_override("font_size", 10)
	_vbox.add_child(hint)

func _create_file_input() -> void:
	var label := Label.new()
	label.text = "Ignored Files (one per line):"
	_vbox.add_child(label)

	_ignored_files_input = TextEdit.new()
	_ignored_files_input.custom_minimum_size = Vector2(0, 60)
	_ignored_files_input.wrap_mode = TextEdit.LINE_WRAPPING_DISABLED
	_vbox.add_child(_ignored_files_input)

	var hint := Label.new()
	hint.text = "Example: test.gd, debug.tscn"
	hint.add_theme_font_size_override("font_size", 10)
	_vbox.add_child(hint)

func _create_size_inputs() -> void:
	var size_hbox := HBoxContainer.new()

	var chunk_label := Label.new()
	chunk_label.text = "Chunk Size:"
	chunk_label.custom_minimum_size.x = 100
	size_hbox.add_child(chunk_label)

	_chunk_size_spin = SpinBox.new()
	_chunk_size_spin.min_value = 10
	_chunk_size_spin.max_value = 200
	_chunk_size_spin.value = 50
	_chunk_size_spin.custom_minimum_size.x = 80
	size_hbox.add_child(_chunk_size_spin)

	var overlap_label := Label.new()
	overlap_label.text = "  Chunk Overlap:"
	overlap_label.custom_minimum_size.x = 100
	size_hbox.add_child(overlap_label)

	_chunk_overlap_spin = SpinBox.new()
	_chunk_overlap_spin.min_value = 0
	_chunk_overlap_spin.max_value = 50
	_chunk_overlap_spin.value = 10
	_chunk_overlap_spin.custom_minimum_size.x = 80
	size_hbox.add_child(_chunk_overlap_spin)

	_vbox.add_child(size_hbox)

func _create_top_k_input() -> void:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = "Default Top K:"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	_top_k_spin = SpinBox.new()
	_top_k_spin.min_value = 1
	_top_k_spin.max_value = 50
	_top_k_spin.value = 10
	_top_k_spin.custom_minimum_size.x = 80
	hbox.add_child(_top_k_spin)

	_vbox.add_child(hbox)

func _create_ollama_input() -> void:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = "Ollama URL:"
	label.custom_minimum_size.x = 100
	hbox.add_child(label)

	_ollama_url_input = LineEdit.new()
	_ollama_url_input.text = "http://localhost:11434"
	_ollama_url_input.custom_minimum_size.x = 200
	hbox.add_child(_ollama_url_input)

	_vbox.add_child(hbox)

func _create_reset_button() -> void:
	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.pressed.connect(_on_reset_pressed)
	_vbox.add_child(reset_btn)

func load_config(config: Dictionary) -> void:
	_current_config = config

	var cfg := config.get("config", {})

	_ignored_folders_input.text = _array_to_text(cfg.get("ignored_folders", [".git", ".godot", "node_modules"]))
	_ignored_files_input.text = _array_to_text(cfg.get("ignored_files", []))
	_chunk_size_spin.value = cfg.get("chunk_size", 50)
	_chunk_overlap_spin.value = cfg.get("chunk_overlap", 10)
	_top_k_spin.value = cfg.get("top_k_default", 10)
	_ollama_url_input.text = cfg.get("ollama_url", "http://localhost:11434")

func get_config() -> Dictionary:
	return {
		"version": "1.0",
		"config": {
			"ignored_folders": _text_to_array(_ignored_folders_input.text),
			"ignored_files": _text_to_array(_ignored_files_input.text),
			"chunk_size": int(_chunk_size_spin.value),
			"chunk_overlap": int(_chunk_overlap_spin.value),
			"top_k_default": int(_top_k_spin.value),
			"ollama_url": _ollama_url_input.text
		}
	}

func _array_to_text(arr: Array[String]) -> String:
	var result := ""
	for i in arr.size():
		if i > 0:
			result += "\n"
		result += arr[i]
	return result

func _text_to_array(text: String) -> Array[String]:
	var lines := text.split("\n", false)
	var result: Array[String] = []
	for line in lines:
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result

func _on_confirmed() -> void:
	settings_saved.emit(get_config())

func _on_canceled() -> void:
	load_config(_current_config)

func _on_reset_pressed() -> void:
	_ignored_folders_input.text = ".git\n.godot\nnode_modules"
	_ignored_files_input.text = ""
	_chunk_size_spin.value = 50
	_chunk_overlap_spin.value = 10
	_top_k_spin.value = 10
	_ollama_url_input.text = "http://localhost:11434"