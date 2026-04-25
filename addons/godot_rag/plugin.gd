@tool
class_name GodotRAG
extends EditorPlugin

var _rag_explorer: Control

func _enter_tree() -> void:
	_rag_explorer = preload("res://addons/godot_rag/rag_explorer.gd").new()
	add_dock(_rag_explorer, DOCK_SLOT_LEFT_UL)

func _exit_tree() -> void:
	if is_instance_valid(_rag_explorer):
		remove_dock(_rag_explorer)
		_rag_explorer.free()