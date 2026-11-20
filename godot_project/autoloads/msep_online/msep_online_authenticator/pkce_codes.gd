class_name PkceCodes extends RefCounted
## Generates random values and code challenges of OAuth logins secured with PKCE (Proof Key for
## Code Exchange).


static func random_urlsafe(in_byte_count: int) -> String:
	return base64url(Crypto.new().generate_random_bytes(in_byte_count))


static func base64url(in_bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(in_bytes).replace("+", "-").replace("/", "_").replace("=", "")


static func challenge_for(in_verifier: String) -> String:
	return base64url(in_verifier.sha256_buffer())
