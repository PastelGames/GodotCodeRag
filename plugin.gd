@tool
class_name GodotRAG
extends EditorPlugin

var _rag_explorer: Control
var _dock: EditorDock

func _enter_tree() -> void:
	_rag_explorer = preload("res://addons/godot_code_rag/rag_explorer.gd").new()
	
	_dock = EditorDock.new()
	_dock.add_child(_rag_explorer)
	_dock.title = "RAG Explorer"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	
	add_dock(_dock)

func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()
