class_name VectorStore
extends RefCounted

class ChunkEntry extends RefCounted:
	var path: String
	var chunk_id: int
	var start_line: int
	var end_line: int
	var content: String
	var embedding: PackedFloat32Array

	func _init(p := "", cid := 0, start := 0, end_line := 0, content := "", embed := PackedFloat32Array()) -> void:
		path = p
		chunk_id = cid
		start_line = start
		end_line = end_line
		content = content
		embedding = embed

var _chunks: Array[ChunkEntry] = []

func add_chunk(path: String, chunk_id: int, start_line: int, end_line: int, content: String, embedding: PackedFloat32Array) -> void:
	var entry := ChunkEntry.new(path, chunk_id, start_line, end_line, content, embedding)
	_chunks.append(entry)

func search(query_embedding: PackedFloat32Array, top_k: int) -> Array[Dictionary]:
	if _chunks.is_empty() or query_embedding.is_empty():
		return []

	var results: Array[Dictionary] = []

	for chunk in _chunks:
		var similarity := _cosine_similarity(query_embedding, chunk.embedding)
		results.append({
			"path": chunk.path,
			"chunk_id": chunk.chunk_id,
			"start_line": chunk.start_line,
			"end_line": chunk.end_line,
			"content": chunk.content,
			"similarity": similarity
		})

	results.sort_custom(func(a, b): return a["similarity"] > b["similarity"])

	return results.slice(0, min(top_k, results.size()))

func clear() -> void:
	_chunks.clear()

func get_chunk_count() -> int:
	return _chunks.size()

func get_chunks() -> Array[ChunkEntry]:
	return _chunks

func load_from_data(indexes: Array[Dictionary]) -> void:
	_chunks.clear()

	for entry in indexes:
		if not entry.has_all(["path", "chunk_id", "start_line", "end_line", "content", "embedding"]):
			continue

		var embed_array: Array = entry["embedding"]
		var embedding := PackedFloat32Array()
		for val in embed_array:
			embedding.append(float(val))

		add_chunk(
			entry["path"],
			entry["chunk_id"],
			entry["start_line"],
			entry["end_line"],
			entry["content"],
			embedding
		)

func to_data() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for chunk in _chunks:
		results.append({
			"path": chunk.path,
			"chunk_id": chunk.chunk_id,
			"start_line": chunk.start_line,
			"end_line": chunk.end_line,
			"content": chunk.content,
			"embedding": Array(chunk.embedding)
		})

	return results

static func _cosine_similarity(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0

	var dot_product := 0.0
	for i in a.size():
		dot_product += a[i] * b[i]

	var mag_a := sqrt(_sqr_magnitude(a))
	var mag_b := sqrt(_sqr_magnitude(b))

	if mag_a == 0.0 or mag_b == 0.0:
		return 0.0

	return dot_product / (mag_a * mag_b)

static func _sqr_magnitude(vec: PackedFloat32Array) -> float:
	var sum := 0.0
	for val in vec:
		sum += val * val
	return sum
