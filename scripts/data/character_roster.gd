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
	{"id": &"leo", "data": "res://data/characters/leo.tres",
		"tagline": "Holy bruiser · all-rounder", "art": "sprites"},
	{"id": &"groban", "data": "res://data/characters/groban.tres",
		"tagline": "Baritone · zoner", "art": "sprites"},
	{"id": &"tim", "data": "res://data/characters/tim.tres",
		"tagline": "Detective · grappler", "art": "sprites"},
	{"id": &"sundar", "data": "res://data/characters/sundar.tres",
		"tagline": "Doctor · cold hands", "art": "sprites"},
	{"id": &"kevin", "data": "res://data/characters/kevin.tres",
		"tagline": "Barefoot brawler · airstrikes", "art": "sprites"},
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


static var _showcase_cache: Dictionary = {}


## Large animated renders for menus: {"idle": [Texture2D], "victory": [Texture2D]},
## every frame cropped to the same rect (so poses don't jump). Empty when the
## character has no sprite art.
static func showcase(id: StringName) -> Dictionary:
	if _showcase_cache.has(id):
		return _showcase_cache[id]
	var result := {}
	var path := "res://art/characters/%s/animations.tres" % id
	var frames: SpriteFrames = load(path) if ResourceLoader.exists(path) else null
	if frames != null:
		var images := {}
		var union := Rect2i()
		for anim: StringName in [&"idle", &"victory"]:
			if not frames.has_animation(anim):
				continue
			images[anim] = []
			for i in frames.get_frame_count(anim):
				var img := frames.get_frame_texture(anim, i).get_image()
				if img == null:
					continue
				images[anim].append(img)
				var used := img.get_used_rect()
				union = used if union.size == Vector2i.ZERO else union.merge(used)
		union = union.grow(4).intersection(Rect2i(Vector2i.ZERO, (images.values()[0][0] as Image).get_size())) if not images.is_empty() else union
		for anim: StringName in images:
			result[anim] = images[anim].map(func(img: Image) -> Texture2D:
				return ImageTexture.create_from_image(img.get_region(union)))
	_showcase_cache[id] = result
	return result
