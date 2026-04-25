class_name RAGExplorer
extends Control

signal indexing_progress(current: int, total: int, file: String)
signal search_completed(results: Array[Dictionary])

const DEFAULT_TOP_K := 10

var _scanner: CodeScanner
var _embedder: Embedder
var _vector_store: VectorStore
var _data_manager: DataManager

var _search_input: LineEdit
var _top_k_spin: SpinBox
var _results_container: ScrollContainer
var _results_vbox: VBoxContainer
var _status_label: Label
var _progress_bar: ProgressBar
var _index_button: Button
var _search_button: Button
var _copy_all_button: Button
var _copy_prompt_button: Button
var _clear_button: Button
var _settings_button: Button
var _settings_dialog: SettingsDialog

var _current_results: Array[Dictionary] = []
var _current_config: Dictionary = {}
var _is_indexing: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(300, 400)
	_scanner = CodeScanner.new()
	_embedder = Embedder.new()
	_vector_store = VectorStore.new()
	_data_manager = DataManager.new()
	add_child(_embedder)

func _ready() -> void:
	_current_config = _data_manager.load_index()
	_apply_config(_current_config)
	_load_existing_indexes()

	_create_ui()
	_update_status()

func _create_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_theme_constant_override("margin_top", 8)
	main_vbox.add_theme_constant_override("margin_left", 8)
	main_vbox.add_theme_constant_override("margin_right", 8)
	main_vbox.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(main_vbox)

	_create_header(main_vbox)
	_create_search_section(main_vbox)
	_create_results_section(main_vbox)
	_create_action_buttons(main_vbox)
	_create_settings_dialog()

func _create_header(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()

	var title := Label.new()
	title.text = "RAG Explorer"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	_settings_button = Button.new()
	_settings_button.text = "Settings"
	_settings_button.pressed.connect(_on_settings_pressed)
	hbox.add_child(_settings_button)

	parent.add_child(hbox)

func _create_search_section(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = "Search:"
	label.custom_minimum_size.x = 60
	hbox.add_child(label)

	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_submitted.connect(_on_search_submitted)
	hbox.add_child(_search_input)

	_search_button = Button.new()
	_search_button.text = "Search"
	_search_button.pressed.connect(_on_search_pressed)
	hbox.add_child(_search_button)

	parent.add_child(hbox)

	var controls_hbox := HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 8)

	var top_k_label := Label.new()
	top_k_label.text = "Top K:"
	controls_hbox.add_child(top_k_label)

	_top_k_spin = SpinBox.new()
	_top_k_spin.min_value = 1
	_top_k_spin.max_value = 50
	_top_k_spin.value = DEFAULT_TOP_K
	_top_k_spin.value_changed.connect(_on_top_k_changed)
	controls_hbox.add_child(_top_k_spin)

	controls_hbox.add_child(Control.new())

	var index_label := Label.new()
	index_label.text = "Index:"
	index_label.custom_minimum_size.x = 60
	controls_hbox.add_child(index_label)

	_index_button = Button.new()
	_index_button.text = "Index"
	_index_button.pressed.connect(_on_index_pressed)
	controls_hbox.add_child(_index_button)

	parent.add_child(controls_hbox)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 20
	_progress_bar.visible = false
	parent.add_child(_progress_bar)

func _create_results_section(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "Results:"
	parent.add_child(label)

	_results_container = ScrollContainer.new()
	_results_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_container.custom_minimum_size.y = 200
	parent.add_child(_results_container)

	_results_vbox = VBoxContainer.new()
	_results_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_vbox.add_theme_constant_override("separation", 4)
	_results_container.add_child(_results_vbox)

func _create_action_buttons(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()

	_copy_all_button = Button.new()
	_copy_all_button.text = "Copy All"
	_copy_all_button.pressed.connect(_on_copy_all_pressed)
	hbox.add_child(_copy_all_button)

	_copy_prompt_button = Button.new()
	_copy_prompt_button.text = "Copy Prompt"
	_copy_prompt_button.pressed.connect(_on_copy_prompt_pressed)
	hbox.add_child(_copy_prompt_button)

	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.pressed.connect(_on_clear_pressed)
	hbox.add_child(_clear_button)

	hbox.add_child(Control.new())

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_status_label)

	parent.add_child(hbox)

func _create_settings_dialog() -> void:
	_settings_dialog = SettingsDialog.new()
	_settings_dialog.settings_saved.connect(_on_settings_saved)
	add_child(_settings_dialog)

func _load_existing_indexes() -> void:
	var indexes: Array = _current_config.get("indexes", [])
	if indexes.is_empty():
		return

	_vector_store.load_from_data(indexes)
	print("Loaded %d chunks from index" % _vector_store.get_chunk_count())

func _apply_config(config: Dictionary) -> void:
	var cfg := config.get("config", {})
	
	var raw_ignored_folders: Array[String] = []
	for f in cfg.get("ignored_folders", [".git", ".godot", "node_modules"]):
		raw_ignored_folders.append(String(f))
	var ignored_folders: Array[String] = []
	for f in raw_ignored_folders:
		ignored_folders.append(String(f))
	var raw_ignored_files: Array[String] = []
	for f in cfg.get("ignored_files", []):
		raw_ignored_files.append(String(f))
	var ignored_files: Array[String] = []
	for f in raw_ignored_files:
		ignored_files.append(String(f))
	var chunk_size: int = cfg.get("chunk_size", 50)
	var chunk_overlap: int = cfg.get("chunk_overlap", 10)
	var top_k: int = cfg.get("top_k_default", 10)
	var ollama_url: String = cfg.get("ollama_url", "http://localhost:11434")

	_scanner.set_ignored_folders(ignored_folders)
	_scanner.set_ignored_files(ignored_files)
	_scanner.set_chunk_size(chunk_size)
	_scanner.set_chunk_overlap(chunk_overlap)

	_embedder.set_ollama_url(ollama_url)

	if _top_k_spin:
		_top_k_spin.value = top_k

func _update_status() -> void:
	var chunk_count := _vector_store.get_chunk_count()
	var file_count := _get_unique_file_count()

	_status_label.text = "Files: %d | Chunks: %d" % [file_count, chunk_count]

func _get_unique_file_count() -> int:
	var files := {}
	for chunk in _vector_store.get_chunks():
		files[chunk.path] = true
	return files.size()

func _on_index_pressed() -> void:
	if _is_indexing:
		return

	_is_indexing = true
	_progress_bar.visible = true
	_index_button.disabled = true

	var project_dir := ProjectSettings.get_setting("editor/external_path", "")
	if project_dir.is_empty():
		project_dir = OS.get_executable_path().get_base_dir()

	print("Starting indexing of: " + project_dir)

	var chunks: Array = await _scanner.scan_directory(project_dir)
	var total_chunks := chunks.size()

	print("Found %d chunks to embed" % total_chunks)

	_progress_bar.max_value = total_chunks

	var indexes: Array[Dictionary] = []

	for i in total_chunks:
		_progress_bar.value = i + 1
		await get_tree().process_frame

		var chunk: Dictionary = chunks[i]
		var embedding := await _embedder.generate_embedding(chunk["content"])

		if embedding.is_empty():
			print("Failed to embed chunk %d" % i)
			continue

		var entry: Dictionary = {
			"path": chunk["path"],
			"chunk_id": chunk["chunk_id"],
			"start_line": chunk["start_line"],
			"end_line": chunk["end_line"],
			"content": chunk["content"],
			"embedding": Array(embedding)
		}

		indexes.append(entry)

		_vector_store.add_chunk(
			chunk["path"],
			chunk["chunk_id"],
			chunk["start_line"],
			chunk["end_line"],
			chunk["content"],
			embedding
		)

	_progress_bar.visible = false
	_index_button.disabled = false
	_is_indexing = false

	_current_config["indexes"] = indexes
	_current_config["last_indexed"] = Time.get_datetime_string_from_system()

	_data_manager.save_index(_current_config)

	_update_status()
	print("Indexing complete: %d chunks" % indexes.size())

func _on_search_submitted(_text: String) -> void:
	_on_search_pressed()

func _on_search_pressed() -> void:
	var query := _search_input.text.strip_edges()
	if query.is_empty() or _vector_store.get_chunk_count() == 0:
		return

	var query_embedding := await _embedder.generate_embedding(query)

	if query_embedding.is_empty():
		push_error("Failed to generate query embedding")
		return

	var top_k := int(_top_k_spin.value)
	_current_results = _vector_store.search(query_embedding, top_k)

	_display_results()
	search_completed.emit(_current_results)

func _display_results() -> void:
	for child in _results_vbox.get_children():
		child.queue_free()

	for result in _current_results:
		var item := _create_result_item(result)
		_results_vbox.add_child(item)

func _create_result_item(result: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 80

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "%s:%d-%d (%.3f)" % [
		result["path"],
		result["start_line"],
		result["end_line"],
		result["similarity"]
	]
	header.add_theme_font_size_override("font_size", 12)
	vbox.add_child(header)

	var content_label := Label.new()
	content_label.text = result["content"].left(200)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_label)

	return panel

func _on_top_k_changed(_value: float) -> void:
	pass

func _on_settings_pressed() -> void:
	_settings_dialog.load_config(_current_config)
	_settings_dialog.popup_centered()

func _on_settings_saved(config: Dictionary) -> void:
	_current_config["config"] = config.get("config", {})
	_apply_config(_current_config)
	_data_manager.save_index(_current_config)

func _on_copy_all_pressed() -> void:
	if _current_results.is_empty():
		return

	var snippets: PackedStringArray = []
	for result in _current_results:
		snippets.append("%s:%d-%d\n%s" % [
			result["path"],
			result["start_line"],
			result["end_line"],
			result["content"]
		])

	var text: String = ""
	for j in snippets.size():
		if j > 0:
			text += "\n---\n"
		text += snippets[j]
	DisplayServer.clipboard_set(text)

func _on_copy_prompt_pressed() -> void:
	if _current_results.is_empty():
		return

	var snippets: PackedStringArray = []
	for result in _current_results:
		snippets.append("%s:%d-%d\n%s" % [
			result["path"],
			result["start_line"],
			result["end_line"],
			result["content"]
		])

	var context: String = ""
	for j in snippets.size():
		if j > 0:
			context += "\n---\n"
		context += snippets[j]
	var query := _search_input.text.strip_edges()

	var prompt := "## Context\n%s\n\n## Query\n%s\n\n## Response" % [context, query]
	DisplayServer.clipboard_set(prompt)

func _on_clear_pressed() -> void:
	_vector_store.clear()
	_current_config["indexes"] = []
	_current_config["last_indexed"] = ""
	_data_manager.save_index(_current_config)
	_current_results.clear()

	for child in _results_vbox.get_children():
		child.queue_free()

	_update_status()
