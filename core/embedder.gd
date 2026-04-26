class_name Embedder
extends Node

const DEFAULT_OLLAMA_URL := "http://127.0.0.1:11434"
const EMBEDDING_MODEL := "nomic-embed-text:latest"

var _ollama_url: String = DEFAULT_OLLAMA_URL

signal progress_updated(current: int, total: int)

func set_ollama_url(url: String) -> void:
	_ollama_url = url

func generate_embedding(text: String) -> PackedFloat32Array:
	var http_request := HTTPRequest.new()
	http_request.timeout = 30
	add_child(http_request)

	var url := "%s/api/embeddings" % _ollama_url
	var headers := ["Content-Type: application/json"]
	var payload := JSON.stringify({
		"model": EMBEDDING_MODEL,
		"prompt": text
	})

	var error := http_request.request(url, headers, HTTPClient.METHOD_POST, payload)

	if error != OK:
		push_error("Embedder: HTTP request failed with error: " + str(error))
		http_request.queue_free()
		return PackedFloat32Array()

	var response = await http_request.request_completed

	http_request.queue_free()

	if response[0] != HTTPRequest.RESULT_SUCCESS:
		push_error("Embedder: Request failed: " + str(response[0]))
		return PackedFloat32Array()

	var body: String = response[3].get_string_from_utf8()
	var json := JSON.new()
	var parse_result := json.parse(body)

	if parse_result != OK:
		push_error("Embedder: JSON parse error: " + body)
		return PackedFloat32Array()

	var data: Dictionary = json.get_data()

	if not data.has("embedding"):
		push_error("Embedder: No embedding in response")
		return PackedFloat32Array()

	var embed_array: Array = data["embedding"]
	var result := PackedFloat32Array()

	for val in embed_array:
		result.append(float(val))

	return result

func check_ollama_available(url: String = DEFAULT_OLLAMA_URL) -> bool:
	var http_request := HTTPRequest.new()
	add_child(http_request)

	var check_url := "%s/api/tags" % url
	var error := http_request.request(check_url, [], HTTPClient.METHOD_GET)

	if error != OK:
		http_request.queue_free()
		return false

	var response = await http_request.request_completed
	http_request.queue_free()

	return response[1] == HTTPRequest.RESULT_SUCCESS
