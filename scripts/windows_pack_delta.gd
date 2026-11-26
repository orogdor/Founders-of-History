extends RefCounted

const HEADER_SIZE := 16
const LITERAL := 0xffffffff
const CHUNK_SIZE := 1024 * 1024

static func rebuild(delta_path: String, source_path: String, output_path: String, transfer: Dictionary, target: Dictionary) -> bool:
	var delta := FileAccess.open(delta_path,FileAccess.READ)
	var source := FileAccess.open(source_path,FileAccess.READ)
	if delta == null or source == null or delta.get_length() != int(transfer.size):
		return false
	if FileAccess.get_sha256(delta_path) != transfer.sha256 or delta.get_buffer(4).get_string_from_ascii() != "FHD1":
		return false
	var old_size := delta.get_32()
	var new_size := delta.get_32()
	var runs := delta.get_32()
	if old_size != source.get_length() or new_size != int(target.size) or runs <= 0 or runs > (delta.get_length()-HEADER_SIZE)/8.0:
		return false
	var output := FileAccess.open(output_path,FileAccess.WRITE)
	var hash := HashingContext.new()
	if output == null or hash.start(HashingContext.HASH_SHA256) != OK:
		return false
	var written := 0
	for index in runs:
		if delta.get_length()-delta.get_position() < 8:
			return false
		var offset := delta.get_32()
		var length := delta.get_32()
		if length <= 0 or length > new_size-written:
			return false
		var input := delta if offset == LITERAL else source
		if offset != LITERAL:
			input.seek(offset)
		if length > input.get_length()-input.get_position():
			return false
		var remaining := length
		while remaining > 0:
			var amount := mini(remaining,CHUNK_SIZE)
			var bytes := input.get_buffer(amount)
			if bytes.size() != amount or not output.store_buffer(bytes) or hash.update(bytes) != OK:
				return false
			remaining -= amount
		written += length
	output.flush()
	return (written == new_size and delta.get_position() == delta.get_length()
		and output.get_error() == OK and hash.finish().hex_encode() == target.sha256)
