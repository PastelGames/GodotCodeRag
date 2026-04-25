@tool
class_name GodotRAG
extends EditorPlugin

var _dock: EditorDock
var _rag_explorer: Control

func _enter_tree() -> void:
	_rag_explorer = preload("res://rag_explorer.gd").new()
	_dock = EditorDock.new()
	_dock.add_child(_rag_explorer)
	_dock.title = "RAG Explorer"
	add_dock(_dock)

func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()