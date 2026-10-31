# Character art integration contract

Work lives on `codex/visuals`. No gameplay files were edited for this visual milestone.

## Files and geometry

Load `res://art/characters/gandalf/animations.tres`. Every frame is 256x256 with a feet pivot of (128,208). The standing character is approximately 112 pixels high. Render with nearest filtering. Each PNG is a single horizontal strip. `manifest.json` records fps, loop flags, frame counts, source boxes/pivots, scale, pose holds and checksums.

This supersedes the earlier proposed 192x192 cell / (96,160) pivot. It changes only visual framing; no physics dimensions should change. The larger transparent cell accommodates staff poses. `idle.tres` is a compatibility copy of the full resource, and `idle.json` describes the new idle strip. Use `animations.tres` for new integration.

## Attach

```
var visual = preload("res://scripts/presentation/character_visual.gd").new()
visual.frames = preload("res://art/characters/gandalf/animations.tres")
$VisualRoot.add_child(visual)
visual.bind_fighter(self)
```

Do this after the fighter's VisualRoot is in the scene tree. Remove/disable the starter's placeholder drawing in gameplay when replacing its presentation; the adapter does not modify fighter.gd for you. Mirror the visual pivot only. Do not flip the CharacterBody2D or resize hitboxes to sprite bounds.

The adapter connects to `animation_requested(animation_id, duration_ticks, loop)` and `facing_changed(facing)`. It polls `get_presentation_snapshot()` for `hitstop_remaining_ticks`, `current_move_id`, `move_tick` and `facing` if the method exists. Claude should reconcile its actual snapshot getter with this name. Bind before the first animation transition; late binding currently needs an explicit animation request to initialize the current state.

Positive duration stretches the equal-duration visual frames across that many physics ticks at 60 Hz. Zero duration uses the SpriteFrames fps and supplied loop flag. Nonlooping animations hold the last pose. The adapter never emits hits or changes recovery. All included SpriteFrames use equal per-frame duration. Future unequal frame durations require updating the adapter's frame selection.

Missing IDs warn once and display idle. This is an explicit diagnostic fallback, not a completed missing animation. Do not attach this Gandalf resource to Vader.

## Animation IDs

Shared: idle, walk, run, jump, fall, hurt, knockback, defeat, victory.

Gandalf: staff_strike, heavy_staff, lightning, fireball, magic_push.

Vader (manifest only; no artwork): saber_slash, heavy_saber, force_push, force_choke, force_guard.

## Effects

Add `effects_layer.gd` to a Node2D above the stage background and connect each fighter's `effect_requested` signal to its `effect_requested` method. It accepts the proposed signature `(effect_id, world_position, direction, payload)`.

Available effect IDs: staff_strike, heavy_staff, lightning, fireball, magic_push, saber_slash, heavy_saber, force_push, force_choke, force_guard, hit, respawn.

Payload: `duration` in seconds (default .35, minimum .05); `length` in world pixels (default120, clamped8–600). Direction controls visual rotation; position is world-space. No hitboxes, forces, or damage are created.

The fireball effect is a stationary visual: parent/attach it to the gameplay projectile for travel. Choke and guard visuals require gameplay to own their attachment and cancellation. `effect_requested` returns the effect node so gameplay can cancel or follow a target. Call `clear_effects()` on rematch and `set_frozen(bool)` during global hitstop. If hitstop is per-actor, freeze only effects owned by that actor; ownership is not implemented in this generic layer.

## Validation and remaining work

`verify_character_pack.py` checks state coverage, checksum integrity, atlas dimensions, frame bounds, binary alpha, resource paths and missing Vader status. This does not test GDScript or gameplay. Godot execution and temporal/art approval are pending. Procedural effects are implemented but not engine-render-tested.

The asset pack intentionally does not replace Claude's match scene, input code, controller, movesets or tests. Integrate through a reviewed merge after the gameplay API is ready.
