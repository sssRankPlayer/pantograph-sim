extends Node3D

const SPAN := 50.0
const WIRE_H := 5.3
const BASE_H := 4.06
const SUB := 10
const MH := 5.0
const MF := 15.0
const KH := 8000.0
const CH := 60.0
const CF := 80.0
const F0 := 110.0
const L0 := 0.15
const G := 9.81

class Graph extends Control:
    var data := PackedFloat32Array()

    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
        var n := data.size()
        if n < 2:
            return
        var pts := PackedVector2Array()
        for i in n:
            var v := clampf(data[i] / 250.0, 0.0, 1.0)
            pts.append(Vector2(size.x * float(i) / float(n - 1), size.y * (1.0 - v)))
        draw_polyline(pts, Color(1, 0.85, 0.2), 2.0)
        var y70 := size.y * (1.0 - 70.0 / 250.0)
        draw_line(Vector2(0, y70), Vector2(size.x, y70), Color(1, 1, 1, 0.4), 1.0)

var speed := 30.0
var wind := 0.0
var vis := 6.0
var s := 0.0
var h := 0.0
var vh := 0.0
var f := 0.0
var vf := 0.0
var fc := 0.0
var lost := 0
var was_contact := true
var arc_t := 0.0
var cam_mode := 0
var cam_pos := Vector3(5.5, 5.4, 5.0)
var cam_tgt := Vector3(0, 4.8, 0)

var cam: Camera3D
var head: MeshInstance3D
var arm1: MeshInstance3D
var arm2: MeshInstance3D
var wire_mesh: ImmediateMesh
var poles: Array = []
var sleepers: Array = []
var sparks: CPUParticles3D
var label: Label
var graph

func wire_y(p: float) -> float:
    var u := fposmod(p, SPAN) / SPAN
    var y := WIRE_H - 0.10 * 4.0 * u * (1.0 - u)
    y += 0.005 * sin(TAU * p / 10.0)
    y += 0.004 * sin(p * 2.1) + 0.003 * sin(p * 5.3 + 1.0) + 0.002 * sin(p * 11.7)
    return y

func wire_k(p: float) -> float:
    return 3000.0 * (1.0 + 0.4 * cos(TAU * p / SPAN))

func wire_x(p: float) -> float:
    return 0.3 * cos(PI * p / SPAN)

func _mat(c: Color, emissive := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    if emissive:
        m.emission_enabled = true
        m.emission = c
        m.emission_energy_multiplier = 3.0
    return m

func _box(parent: Node, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = _mat(c)
    mi.position = pos
    parent.add_child(mi)
    return mi

func _bar(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
    var d := b - a
    var ln := d.length()
    var y := d / ln
    var x := Vector3.RIGHT
    var z := x.cross(y).normalized()
    mi.transform = Transform3D(Basis(x, y * ln, z), (a + b) * 0.5)

func _ready() -> void:
    Engine.physics_ticks_per_second = 120
    _build_world()
    _build_ui()
    h = wire_y(0.0) + 0.024
    f = h - L0 + (F0 + 0.012 * speed * speed) / KH

func _build_world() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.55, 0.7, 0.9)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.8, 0.85, 0.9)
    env.ambient_light_energy = 0.6
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 60.0
    add_child(sun)

    _box(self, Vector3(120, 0.2, 400), Vector3(0, -0.1, 0), Color(0.3, 0.5, 0.25))
    _box(self, Vector3(4, 0.2, 400), Vector3(0, 0.05, 0), Color(0.45, 0.43, 0.4))
    _box(self, Vector3(0.08, 0.15, 400), Vector3(-0.72, 0.2, 0), Color(0.6, 0.6, 0.65))
    _box(self, Vector3(0.08, 0.15, 400), Vector3(0.72, 0.2, 0), Color(0.6, 0.6, 0.65))
    for i in 60:
        sleepers.append(_box(self, Vector3(2.6, 0.12, 0.3), Vector3(0, 0.16, 0), Color(0.25, 0.2, 0.15)))

    _box(self, Vector3(3.0, 3.0, 16.0), Vector3(0, 2.5, 0), Color(0.8, 0.15, 0.15))
    _box(self, Vector3(2.4, 0.6, 2.0), Vector3(0, 0.5, 5.0), Color(0.15, 0.15, 0.18))
    _box(self, Vector3(2.4, 0.6, 2.0), Vector3(0, 0.5, -5.0), Color(0.15, 0.15, 0.18))
    _box(self, Vector3(1.4, 0.12, 1.2), Vector3(0, 4.0, 0), Color(0.2, 0.2, 0.2))

    arm1 = _box(self, Vector3(0.06, 1.0, 0.06), Vector3.ZERO, Color(0.75, 0.75, 0.8))
    arm2 = _box(self, Vector3(0.06, 1.0, 0.06), Vector3.ZERO, Color(0.75, 0.75, 0.8))
    head = _box(self, Vector3(1.6, 0.05, 0.12), Vector3(0, 5.3, 0), Color(0.05, 0.05, 0.05))

    for k in 5:
        var root := Node3D.new()
        add_child(root)
        _box(root, Vector3(0.3, 7.0, 0.3), Vector3(4.0, 3.5, 0), Color(0.5, 0.5, 0.55))
        _box(root, Vector3(4.0, 0.15, 0.15), Vector3(2.0, 6.6, 0), Color(0.5, 0.5, 0.55))
        poles.append(root)

    wire_mesh = ImmediateMesh.new()
    var wi := MeshInstance3D.new()
    wi.mesh = wire_mesh
    var wm := _mat(Color(0.95, 0.55, 0.2))
    wm.cull_mode = BaseMaterial3D.CULL_DISABLED
    wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    wi.material_override = wm
    add_child(wi)

    sparks = CPUParticles3D.new()
    sparks.amount = 80
    sparks.lifetime = 0.5
    sparks.emitting = false
    sparks.direction = Vector3.UP
    sparks.spread = 180.0
    sparks.initial_velocity_min = 1.5
    sparks.initial_velocity_max = 5.0
    sparks.gravity = Vector3(0, -9.8, 0)
    var sm := SphereMesh.new()
    sm.radius = 0.02
    sm.height = 0.04
    sm.material = _mat(Color(1, 0.8, 0.3), true)
    sparks.mesh = sm
    add_child(sparks)

    cam = Camera3D.new()
    cam.fov = 60.0
    add_child(cam)

func _slider(parent: Node, text: String, minv: float, maxv: float, val: float, cb: Callable) -> void:
    var row := HBoxContainer.new()
    var l := Label.new()
    l.text = text
    l.custom_minimum_size = Vector2(300, 0)
    l.add_theme_font_size_override("font_size", 22)
    var sl := HSlider.new()
    sl.min_value = minv
    sl.max_value = maxv
    sl.step = 0.5
    sl.value = val
    sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sl.custom_minimum_size = Vector2(0, 44)
    sl.value_changed.connect(cb)
    row.add_child(l)
    row.add_child(sl)
    parent.add_child(row)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    label = Label.new()
    label.position = Vector2(20, 10)
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_shadow_color", Color.BLACK)
    layer.add_child(label)
    graph = Graph.new()
    graph.position = Vector2(20, 120)
    graph.size = Vector2(360, 100)
    layer.add_child(graph)
    var box := VBoxContainer.new()
    layer.add_child(box)
    box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    box.offset_left = 20
    box.offset_right = -20
    box.offset_top = -250
    box.offset_bottom = -10
    _slider(box, "Скорость, м/с", 0.0, 100.0, speed, func(v): speed = v)
    _slider(box, "Встречный ветер, м/с", 0.0, 30.0, wind, func(v): wind = v)
    _slider(box, "Масштаб колебаний", 1.0, 15.0, vis, func(v): vis = v)
    var b := Button.new()
    b.text = "Камера"
    b.custom_minimum_size = Vector2(0, 52)
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(func(): cam_mode = (cam_mode + 1) % 3)
    box.add_child(b)

func _physics_process(delta: float) -> void:
    var dt := delta / float(SUB)
    for i in SUB:
        s += speed * dt
        var wy := wire_y(s)
        var kw := wire_k(s)
        var air := speed + wind
        var fa := 0.012 * air * air
        var x := h - f - L0
        var vx := vh - vf
        var fs := -KH * x - CH * vx
        var pen := h - wy
        fc = 0.0
        if pen > 0.0:
            fc = maxf(0.0, kw * pen + 40.0 * vh)
        var ah := (fs - MH * G - fc) / MH
        var ff := -fs + F0 + fa - CF * vf
        if f > 6.0:
            ff -= 50000.0 * (f - 6.0)
        if f < 4.7:
            ff += 50000.0 * (4.7 - f)
        vh += ah * dt
        h += vh * dt
        vf += (ff / MF) * dt
        f += vf * dt
        var contact_now := fc > 0.0
        if not contact_now:
            arc_t = 0.15
            if was_contact:
                lost += 1
        was_contact = contact_now

func _process(delta: float) -> void:
    var hy := WIRE_H + (h - WIRE_H) * vis
    head.position = Vector3(0, hy, 0)
    var d := hy - BASE_H
    var kz := sqrt(maxf(1.96 - d * d * 0.25, 0.05))
    var knee := Vector3(0, BASE_H + d * 0.5, -kz)
    _bar(arm1, Vector3(0, BASE_H, 0), knee)
    _bar(arm2, knee, Vector3(0, hy, 0))

    sparks.position = Vector3(wire_x(s), hy + 0.05, 0)
    sparks.emitting = arc_t > 0.0
    arc_t -= delta

    var contact := fc > 0.0
    wire_mesh.clear_surfaces()
    for pass_i in 2:
        wire_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
        for zi in range(-90, 91, 2):
            var z := float(zi)
            var p := s + z
            var y := WIRE_H + (wire_y(p) - WIRE_H) * vis
            if contact:
                y = lerpf(y, hy + 0.03, clampf(1.0 - absf(z) / 3.0, 0.0, 1.0))
            var x := wire_x(p)
            if pass_i == 0:
                wire_mesh.surface_add_vertex(Vector3(x - 0.03, y, z))
                wire_mesh.surface_add_vertex(Vector3(x + 0.03, y, z))
            else:
                wire_mesh.surface_add_vertex(Vector3(x, y - 0.03, z))
                wire_mesh.surface_add_vertex(Vector3(x, y + 0.03, z))
        wire_mesh.surface_end()

    var m := fposmod(s, SPAN)
    for k in poles.size():
        poles[k].position.z = float(k - 2) * SPAN - m
    for i in sleepers.size():
        sleepers[i].position.z = fposmod(float(i) - s, 60.0) - 30.0

    var cams := [[Vector3(5.5, 5.4, 5.0), Vector3(0, 4.8, 0)], [Vector3(0, 6.5, -9.0), Vector3(0, 4.8, 0)], [Vector3(2.5, 5.0, 2.2), Vector3(0, 4.9, 0)]]
    var cp: Vector3 = cams[cam_mode][0]
    var ct: Vector3 = cams[cam_mode][1]
    cam_pos = cam_pos.lerp(cp, 0.08)
    cam_tgt = cam_tgt.lerp(ct, 0.08)
    cam.look_at_from_position(cam_pos, cam_tgt, Vector3.UP)

    graph.data.append(fc)
    if graph.data.size() > 240:
        graph.data.remove_at(0)
    graph.queue_redraw()
    label.text = ("%d км/ч" % int(speed * 3.6)) + char(10) + ("Контактная сила: %d Н" % int(fc)) + char(10) + ("Отрывы полоза: %d" % lost)
