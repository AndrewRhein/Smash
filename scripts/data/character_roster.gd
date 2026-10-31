class_name CharacterRoster
extends RefCounted
## The list of selectable fighters, in select-screen order.
##
## Adding a character:
##   1. data/characters/<id>.tres (CharacterData; must pass validate()).
##   2. Register the id and move animation ids in scripts/data/game_ids.gd.
##   3. Optional art: art/characters/<id>/portrait.png (select screen + title),
##      and a visual scene wired in scripts/presentation/presentation_setup.gd.
##   4. Optional audio: audio/voice/<id>/... (see docs/AUDIO.md).
##   5. Add one entry below.

const ENTRIES := [
	{"id": &"gandalf", "data": "res://data/characters/gandalf.tres",
		"tagline": "Wizard · zoner", "art": "sprites"},
	{"id": &"elon", "data": "res://data/characters/elon.tres",
		"tagline": "Tech brawler · grappler", "art": "sprites"},
	{"id": &"vader", "data": "res://data/characters/vader.tres",
		"tagline": "Dark knight · grappler", "art": "placeholder"},
]
## Default picks (Player 1, Player 2).
const DEFAULT_PICKS := [&"gandalf", &"elon"]


static func ids() -> Array:
	return ENTRIES.map(func(e: Dictionary) -> StringName: return e.id)


static func entry(id: StringName) -> Dictionary:
	for e: Dictionary in ENTRIES:
		if e.id == id:
			return e
	return {}


static func has(id: StringName) -> bool:
	return not entry(id).is_empty()


static func load_character(id: StringName) -> CharacterData:
	var e := entry(id)
	return load(e.data) as CharacterData if not e.is_empty() else null


static func portrait_path(id: StringName) -> String:
	return "res://art/characters/%s/portrait.png" % id


static func portrait(id: StringName) -> Texture2D:
	var path := portrait_path(id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
