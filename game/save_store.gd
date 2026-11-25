extends RefCounted

const DIRECTORY := "user://saves"
const AUTO := "auto"
const VERSION := 2

func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 33 or file.get_length() > 65536:
		return {}
	var checksum := file.get_buffer(32)
	var payload := file.get_buffer(file.get_length() - 32)
	if _digest(payload) != checksum:
		return {}
	var value = bytes_to_var(payload)
	if not value is Dictionary or value.get("version") not in [1, VERSION]:
		return {}
	return value

func _digest(payload: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	return hash.finish()

func entries() -> Array:
	var latest := {}
	var directory := DirAccess.open(DIRECTORY)
	if directory == null:
		return []
	for filename in directory.get_files():
		if not filename.ends_with(".sav"):
			continue
		var entry := _read(DIRECTORY.path_join(filename))
		if entry.is_empty():
			continue
		var id: String = entry.id
		if not latest.has(id) or entry.order > latest[id].order:
			entry.filename = filename
			latest[id] = entry
	var sorted := latest.values()
	sorted.sort_custom(func(a, b): return a.order > b.order)
	return sorted

func write(id: String, caption: String, objective: String, state: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		return false
	var records := entries()
	var order := 1 if records.is_empty() else int(records[0].order) + 1
	var target := id + ".a.sav"
	for record in records:
		if record.id == id and record.filename == target:
			target = id + ".b.sav"
			break
	var entry := {"version": VERSION, "id": id, "name": caption, "objective": objective,
		"time": Time.get_datetime_string_from_system(false, true), "order": order, "state": state}
	var payload := var_to_bytes(entry)
	var temporary := DIRECTORY.path_join(new_id() + ".tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	var written := file.store_buffer(_digest(payload)) and file.store_buffer(payload)
	file.close()
	# Последняя целая версия остаётся в соседнем файле до следующей успешной записи.
	if written and _read(temporary) == entry:
		if DirAccess.rename_absolute(temporary, DIRECTORY.path_join(target)) == OK:
			return true
	DirAccess.remove_absolute(temporary)
	return false
