extends Node2D
const Visual = preload("res://scripts/presentation/character_visual.gd")
const Effects = preload("res://scripts/presentation/effects_layer.gd")
const CharacterFrames = preload("res://art/characters/gandalf/animations.tres")
const EffectDefinition = preload("res://scripts/presentation/combat_effect.gd")
const NAMES: Array[StringName] = [&"idle", &"walk", &"run", &"jump", &"fall", &"staff_strike", &"heavy_staff", &"lightning", &"fireball", &"magic_push", &"hurt", &"knockback", &"defeat", &"victory"]
var figures: Array = []
var effects
var effect_menu: OptionButton
var status: Label
var chosen := 0
var reversed := false
var is_paused := false
var speed := 1.0

func _ready() -> void:
    effects = Effects.new()
    add_child(effects)
    var positions := [Vector2(200, 520), Vector2(640, 580), Vector2(1060, 520)]
    for i in range(3):
        var figure := Visual.new()
        figure.frames = CharacterFrames
        figure.position = positions[i]
        figure.scale = Vector2.ONE * (3.0 if i == 1 else 1.0)
        add_child(figure)
        figures.append(figure)
    _build_ui()
    _select_animation(0)

func _button(parent: Node, text: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text
    button.pressed.connect(callback)
    parent.add_child(button)

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var panel := VBoxContainer.new()
    panel.position = Vector2(32, 24)
    panel.size = Vector2(1216, 180)
    panel.add_theme_constant_override("separation", 10)
    ui.add_child(panel)
    var title := Label.new()
    title.text = "REALMS RUMBLE / CHARACTER ART LAB"
    title.add_theme_font_size_override("font_size", 26)
    panel.add_child(title)
    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 12)
    panel.add_child(controls)
    var animation_menu := OptionButton.new()
    for name in NAMES:
        animation_menu.add_item(str(name))
    animation_menu.item_selected.connect(_select_animation)
    controls.add_child(animation_menu)
    _button(controls, "Replay", _replay)
    _button(controls, "Flip", _flip)
    _button(controls, "Pause / Resume", _toggle_pause)
    var rate := HSlider.new()
    rate.min_value = 0.25
    rate.max_value = 2.0
    rate.step = 0.25
    rate.value = 1.0
    rate.custom_minimum_size = Vector2(140, 28)
    rate.value_changed.connect(_set_speed)
    controls.add_child(rate)
    effect_menu = OptionButton.new()
    for id in EffectDefinition.IDS:
        effect_menu.add_item(str(id))
    controls.add_child(effect_menu)
    _button(controls, "Play effect", _play_effect)
    status = Label.new()
    panel.add_child(status)
    var note := Label.new()
    note.text = "Gandalf: 14 review animations / Vader art: unavailable (generation blocked)\nLeft: 1x | Center: 3x | Right: mirrored 1x. Effects are visual-only. No combat is running."
    note.add_theme_color_override("font_color", Color(0.7, 0.76, 0.86))
    panel.add_child(note)

func _select_animation(index: int) -> void:
    chosen = index
    for figure in figures:
        figure.animation_requested(NAMES[index], 0, CharacterFrames.get_animation_loop(NAMES[index]))
    _apply_facing()
    _update_status()

func _replay() -> void:
    _select_animation(chosen)

func _flip() -> void:
    reversed = not reversed
    _apply_facing()

func _apply_facing() -> void:
    for i in range(figures.size()):
        figures[i].facing_changed((-1 if reversed else 1) * (-1 if i == 2 else 1))

func _toggle_pause() -> void:
    is_paused = not is_paused
    for figure in figures:
        figure.playback_paused = is_paused
    effects.set_frozen(is_paused)
    _update_status()

func _set_speed(value: float) -> void:
    speed = value
    for figure in figures:
        figure.playback_speed = value
    _update_status()

func _update_status() -> void:
    if status == null:
        return
    var id := NAMES[chosen]
    status.text = "%s / %d frames / %.1f fps / %.2fx speed / %s" % [id, CharacterFrames.get_frame_count(id), CharacterFrames.get_animation_speed(id), speed, "PAUSED" if is_paused else "PLAYING"]

func _play_effect() -> void:
    var id: StringName = EffectDefinition.IDS[effect_menu.selected]
    effects.effect_requested(id, Vector2(820, 420), Vector2.LEFT if reversed else Vector2.RIGHT, {"duration": 0.7, "length": 160.0})
    effects.set_frozen(is_paused)

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.055, 0.075, 0.115))
    for x in range(0, 1280, 32):
        draw_line(Vector2(x, 215), Vector2(x, 680), Color(0.075, 0.1, 0.14))
    for y in range(232, 680, 32):
        draw_line(Vector2(0, y), Vector2(1280, y), Color(0.075, 0.1, 0.14))
    draw_line(Vector2(100, 520), Vector2(300, 520), Color(0.3, 0.5, 0.65))
    draw_line(Vector2(430, 580), Vector2(850, 580), Color(0.3, 0.5, 0.65))
    draw_line(Vector2(960, 520), Vector2(1160, 520), Color(0.3, 0.5, 0.65))
