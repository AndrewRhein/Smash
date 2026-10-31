extends RefCounted
## Clone only presentation-bearing resources; never mutate shared gameplay data.
const GandalfScene = preload("res://scenes/presentation/gandalf_visual.tscn")
const FireballScene = preload("res://scenes/presentation/fireball_visual.tscn")
const ElonScene = preload("res://scenes/presentation/elon_visual.tscn")
## Additional characters: id -> [fighter visual scene path, {move id: projectile visual scene path}].
const CHARACTER_ART := {
    &"leo": ["res://scenes/presentation/leo_visual.tscn", {&"special_2": "res://scenes/presentation/holy_light_visual.tscn"}],
    &"groban": ["res://scenes/presentation/groban_visual.tscn", {&"special_2": "res://scenes/presentation/sound_wave_visual.tscn"}],
    &"tim": ["res://scenes/presentation/tim_visual.tscn", {&"special_2": "res://scenes/presentation/drone_visual.tscn",
        &"special_3": "res://scenes/presentation/castle_visual.tscn"}],
    &"sundar": ["res://scenes/presentation/sundar_visual.tscn", {&"special_2": "res://scenes/presentation/vial_visual.tscn"}],
}

static func with_art(source: CharacterData) -> CharacterData:
    if CHARACTER_ART.has(source.id):
        return _with_registered_art(source, CHARACTER_ART[source.id])
    if source.id == &"elon":
        var elon := source.duplicate() as CharacterData
        elon.visual_scene = ElonScene
        return elon
    if source.id != &"gandalf":
        return source
    var result := source.duplicate() as CharacterData
    result.visual_scene = GandalfScene
    var moves: Array[MoveData] = []
    for original in source.moves:
        var move := original.duplicate() as MoveData
        var projectiles: Array[ProjectileData] = []
        for original_projectile in original.projectiles:
            var projectile := original_projectile.duplicate() as ProjectileData
            if original.id == &"special_2":
                projectile.visual_scene = FireballScene
            projectiles.append(projectile)
        move.projectiles = projectiles
        moves.append(move)
    result.moves = moves
    return result


## Clone `source`, attach its fighter visual and any projectile visuals.
static func _with_registered_art(source: CharacterData, art: Array) -> CharacterData:
    var result := source.duplicate() as CharacterData
    result.visual_scene = load(art[0])
    var projectile_art: Dictionary = art[1]
    var moves: Array[MoveData] = []
    for original in source.moves:
        var move := original.duplicate() as MoveData
        if projectile_art.has(original.id):
            var projectiles: Array[ProjectileData] = []
            for original_projectile in original.projectiles:
                var projectile := original_projectile.duplicate() as ProjectileData
                projectile.visual_scene = load(projectile_art[original.id])
                projectiles.append(projectile)
            move.projectiles = projectiles
        moves.append(move)
    result.moves = moves
    return result
