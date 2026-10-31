extends "res://scripts/presentation/placeholder_hud.gd"
## Uses the existing binding and match status contract; presentation only.
var damage_labels: Dictionary = {}
var stock_labels: Dictionary = {}
var name_labels: Dictionary = {}

func _ready() -> void:
    for player in [1, 2]:
        var origin := Vector2(28 if player == 1 else 952, 24)
        var panel := Panel.new()
        panel.position = origin
        panel.size = Vector2(300, 90)
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var box := StyleBoxFlat.new()
        box.bg_color = Color(0.025, 0.045, 0.08, 0.91)
        box.border_color = Color("8c805d")
        box.set_border_width_all(1)
        box.border_width_top = 3
        box.set_corner_radius_all(3)
        box.shadow_color = Color(0, 0, 0, 0.3)
        box.shadow_size = 8
        panel.add_theme_stylebox_override("panel", box)
        add_child(panel)
        var name_label := _label(origin + Vector2(18, 10), 17, Color("b8ddec") if player == 1 else Color("eab7ad"))
        name_labels[player] = name_label
        var damage_label := _label(origin + Vector2(16, 30), 36, Color("f6e9ce"))
        damage_labels[player] = damage_label
        var stocks := _label(origin + Vector2(140, 55), 15, Color("c8b67f"))
        stock_labels[player] = stocks
    _status = _label(Vector2(430, 31), 18, Color("e1c994"))
    _status.size = Vector2(420, 28)
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var subtitle := _label(Vector2(430, 64), 11, Color("8498b1"))
    subtitle.size = Vector2(420, 20)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.text = "T H E   T W I L I G H T   C I T A D E L"
    _result = _label(Vector2(140, 170), 40, Color("ead5a4"))
    _result.size = Vector2(1000, 110)
    _result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var footer := _label(Vector2(30, 686), 13, Color("a6b4c7"))
    footer.text = "P1  A / D · W · F attack · G special · R heavy · T shield          P2  ← / → · ↑ · K attack · L special · I heavy · O shield"
    var hint := _label(Vector2(1050, 686), 13, Color("a6b4c7"))
    hint.text = "ESC  Pause    F1  Hitboxes"

func _on_fighter_spawned(fighter: Fighter) -> void:
    name_labels[fighter.player_id].text = "P%d  /  %s" % [fighter.player_id, fighter.character.display_name.to_upper()]
    var damage_label: Label = damage_labels[fighter.player_id]
    var stocks: Label = stock_labels[fighter.player_id]
    var update := func(_value: Variant = null) -> void:
        damage_label.text = "%d%%" % roundi(fighter.damage)
        damage_label.add_theme_color_override("font_color", Color("f6e9ce").lerp(Color("f48269"), clampf(fighter.damage / 150.0, 0.0, 1.0)))
        stocks.text = "%s  %d LIVES" % ["◆".repeat(fighter.stocks), fighter.stocks]
    fighter.damage_changed.connect(update)
    fighter.stocks_changed.connect(update)
    update.call()
