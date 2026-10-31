extends RefCounted
## Clone only presentation-bearing resources; never mutate shared gameplay data.
const GandalfScene = preload("res://scenes/presentation/gandalf_visual.tscn")
const FireballScene = preload("res://scenes/presentation/fireball_visual.tscn")
const ElonScene = preload("res://scenes/presentation/elon_visual.tscn")

static func with_art(source: CharacterData) -> CharacterData:
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
