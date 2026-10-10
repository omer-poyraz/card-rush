class_name ImaAdpcm
extends RefCounted
## IMA ADPCM speech codec (4 bits/sample, 4:1 vs 16-bit PCM). Pure GDScript,
## runs on every platform without native plugins. Each packet carries its own
## predictor/index header, so a lost packet never desynchronises the decoder.
## Packet layout: [pred_lo, pred_hi, index, count_lo, count_hi, nibbles...]

const INDEX_TABLE := [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
const STEP_TABLE := [
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
	50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230,
	253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963,
	1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327,
	3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487,
	12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
]

var _pred := 0
var _index := 0


## samples: float -1..1. Returns one self-contained packet.
func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var n := samples.size()
	var out := PackedByteArray()
	out.resize(5 + (n + 1) / 2)
	out[0] = _pred & 0xFF
	out[1] = (_pred >> 8) & 0xFF
	out[2] = _index
	out[3] = n & 0xFF
	out[4] = (n >> 8) & 0xFF
	var pred := _pred
	var index := _index
	for i in n:
		var s := clampi(int(samples[i] * 32767.0), -32768, 32767)
		var step: int = STEP_TABLE[index]
		var diff := s - pred
		var code := 0
		if diff < 0:
			code = 8
			diff = -diff
		var delta := step >> 3
		if diff >= step:
			code |= 4
			diff -= step
			delta += step
		step >>= 1
		if diff >= step:
			code |= 2
			diff -= step
			delta += step
		step >>= 1
		if diff >= step:
			code |= 1
			delta += step
		pred = clampi(pred - delta if code & 8 else pred + delta, -32768, 32767)
		index = clampi(index + INDEX_TABLE[code], 0, 88)
		var byte_i := 5 + (i >> 1)
		if i & 1:
			out[byte_i] = out[byte_i] | (code << 4)
		else:
			out[byte_i] = code
	_pred = pred
	_index = index
	return out


## Decodes a packet produced by encode(). Returns float samples (empty on error).
static func decode(packet: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if packet.size() < 5:
		return out
	var pred := packet[0] | (packet[1] << 8)
	if pred >= 32768:
		pred -= 65536
	var index := clampi(packet[2], 0, 88)
	var n := packet[3] | (packet[4] << 8)
	if n > (packet.size() - 5) * 2 or n > 4096:
		return out
	out.resize(n)
	for i in n:
		var b := packet[5 + (i >> 1)]
		var code := (b >> 4) & 0xF if i & 1 else b & 0xF
		var step: int = STEP_TABLE[index]
		var delta := step >> 3
		if code & 4:
			delta += step
		if code & 2:
			delta += step >> 1
		if code & 1:
			delta += step >> 2
		pred = clampi(pred - delta if code & 8 else pred + delta, -32768, 32767)
		index = clampi(index + INDEX_TABLE[code], 0, 88)
		out[i] = pred / 32768.0
	return out
