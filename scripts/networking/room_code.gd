class_name RoomCode
extends RefCounted
## Room codes: 6 characters from an unambiguous 30-letter alphabet
## (30^6 ≈ 729 million combinations), generated from the OS crypto RNG.
## Private rooms only broadcast a salted hash of their code on the LAN, so
## the code itself never travels in clear text over discovery.

const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ2345679"
const LENGTH := 6


static func generate(taken: Dictionary = {}) -> String:
	var crypto := Crypto.new()
	for _attempt in 32:
		var code := ""
		while code.length() < LENGTH:
			for b in crypto.generate_random_bytes(LENGTH * 2):
				# rejection sampling: 240 = 8 * 30, so accepted bytes are unbiased
				if b < 240 and code.length() < LENGTH:
					code += ALPHABET[b % ALPHABET.length()]
		if not taken.has(code):
			return code
	push_error("RoomCode: could not find a free code")
	return ""


## Upper-cases and drops separators/unknown characters (spaces, dashes...).
static func normalize(raw: String) -> String:
	var out := ""
	for ch in raw.to_upper():
		if ALPHABET.contains(ch):
			out += ch
	return out


static func is_valid(code: String) -> bool:
	return code.length() == LENGTH and normalize(code) == code


## Short hash broadcast by private rooms (salted per room session).
static func hash_code(code: String, salt: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((salt + ":" + code).to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


## Constant-time string comparison (avoids leaking how many characters matched).
static func equals(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var diff := 0
	for i in a.length():
		diff |= a.unicode_at(i) ^ b.unicode_at(i)
	return diff == 0


static func new_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
