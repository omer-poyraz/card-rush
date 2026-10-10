class_name Features
extends RefCounted
## Which menu features are actually implemented and usable in this build.
## Anything false is shown as "Soon" and disabled — never as a fake screen.

const AVAILABLE := {
	"quick_play": true,
	"bots": true,
	"create_room": true,
	"join_room": true,
	"friends": false,
	"profile": true,
	"collection": false,
	"missions": false,
	"store": false,
	"settings": true,
	"help": true,
	"voice": true,
}


static func available(key: String) -> bool:
	return bool(AVAILABLE.get(key, false))
