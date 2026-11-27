extends Node3D

var speed: float = 25.0
var wind: float = 0.3
var gain: float = 8.0
var span: float = 50.0
var sag: float = 0.12
var zig: float = 0.3

const MH := 8.0
const MF := 15.0
const KH := 8000.0
const KF := 5000.0
const CH := 60.0
const CF := 100.0
const F0 := 70.0
const WIRE_Y := 5.5
const ROOF_Y := 4.0
const ARM_L := 1.0

var yh: float = 0.0
var vh: float = 0.0
var yf: float = 0.0
var vf: float = 0.0
var xt: float = 0.0
var gust: float = 0.0
var fc: float = 0.0
var lost: bool = false

var yaw: float = 0.7
var pitch: float = 0.2
var dist: float = 10.0

var cam: Camera3D
var head: MeshInstance3D
var arm1: MeshInstance3D
var arm2: MeshInstance3D
var wire_mi: MeshInstance3D
var imm: ImmediateMesh
var sparks: CPUParticles3D
var lbl: Label
var poles: Array = []
var sleepers: Array = []


func w_prof(p: float) -> float:
	var u: float = fposmod(p, span) / span
	var v: float = -sag * 4.0 * u * (1.0 - u)
	v += 0.004 * cos(TAU * p / 5.0)
	return v


func kw(p: float) -> float:
	var u: float = fposmod(p, span) / span
	return 3000.0 * (1.0 + 0.4 * cos(TAU * u))


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(size: Vector3, color: Color, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = pos
	if parent == null:
		add_child(mi)
	else:
		parent.add_child(mi)
	return mi


func _ready() -> void:
	Engine.physics_ticks_per_second = 120
	yh = w_prof(0.0) + F0 / kw(0.0)
	yf = 0.0

	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.material_override = _mat(Color(0.28, 0.4, 0.22))
	add_child(ground)

	_box(Vector3(400, 0.08, 3.4), Color(0.45, 0.42, 0.4), Vector3(0, 0.04, 0))
	_box(Vector3(400, 0.12, 0.08), Color(0.6, 0.6, 0.62), Vector3(0, 0.14, 0.72))
	_box(Vector3(400, 0.12, 0.08), Color(0.6, 0.6, 0.62), Vector3(0, 0.14, -0.72))
	for i in 120:
		sleepers.append(_box(Vector3(0.25, 0.1, 2.6), Color(0.3, 0.22, 0.15), Vector3(0, 0.1, 0)))

	_box(Vector3(14, 2.8, 2.8), Color(0.75, 0.1, 0.1), Vector3(0, 2.6, 0))
	_box(Vector3(14.02, 0.5, 2.82), Color(0.9, 0.9, 0.9), Vector3(0, 2.2, 0))
	_box(Vector3(10, 0.7, 2.0), Color(0.15, 0.15, 0.15), Vector3(0, 0.75, 0))
	_box(Vector3(14, 0.1, 2.0), Color(0.2, 0.2, 0.2), Vector3(0, 4.05, 0))

	for i in 4:
		var pole := Node3D.new()
		add_child(pole)
		_box(Vector3(0.3, 7.0, 0.3), Color(0.5, 0.5, 0.52), Vector3(0, 3.5, -2.8), pole)
		_box(Vector3(0.1, 0.1, 2.8), Color(0.5, 0.5, 0.52), Vector3(0, 6.3, -1.4), pole)
		poles.append(pole)

	head = _box(Vector3(0.2, 0.05, 1.6), Color(0.1, 0.1, 0.1), Vector3(0, WIRE_Y, 0))
	arm1 = _box(Vector3(0.06, 0.06, 1.0), Color(0.8, 0.8, 0.85), Vector3.ZERO)
	arm2 = _box(Vector3(0.06, 0.06, 1.0), Color(0.8, 0.8, 0.85), Vector3.ZERO)

	imm = ImmediateMesh.new()
	wire_mi = MeshInstance3D.new()
	wire_mi.mesh = imm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(1.0, 0.6, 0.2)
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wire_mi.material_override = wm
	add_child(wire_mi)

	sparks = CPUParticles3D.new()
	sparks.amount = 60
	sparks.lifetime = 0.35
	sparks.emitting = false
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.gravity = Vector3(0, -9.8, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.015
	sm.height = 0.03
	var spm := StandardMaterial3D.new()
	spm.albedo_color = Color(0.6, 0.8, 1.0)
	spm.emission_enabled = true
	spm.emission = Color(0.6, 0.8, 1.0)
	spm.emission_energy_multiplier = 4.0
	sm.material = spm
	sparks.mesh = sm
	add_child(sparks)

	cam = Camera3D.new()
	cam.far = 500.0
	add_child(cam)

	_build_ui()


func _slider(vb: VBoxContainer, text: String, mn: float, mx: float, val: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	vb.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = (mx - mn) / 200.0
	s.value = val
	s.custom_minimum_size = Vector2(380, 32)
	s.value_changed.connect(cb)
	vb.add_child(s)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var vb := VBoxContainer.new()
	vb.position = Vector2(16, 12)
	layer.add_child(vb)
	lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	vb.add_child(lbl)
	_slider(vb, "Скорость, м/с", 0.0, 90.0, speed, func(v: float): speed = v)
	_slider(vb, "Ветер / порывы", 0.0, 1.0, wind, func(v: float): wind = v)
	_slider(vb, "Усиление колебаний (визуально)", 1.0, 30.0, gain, func(v: float): gain = v)
	_slider(vb, "Провис провода, м", 0.0, 0.4, sag, func(v: float): sag = v)


func _physics_process(dt: float) -> void:
	xt += speed * dt
	gust += (randf_range(-1.0, 1.0) - gust) * 0.05
	var w: float = w_prof(xt)
	var vw: float = (w_prof(xt + 0.01) - w) / 0.01 * speed
	var pen: float = yh - w
	if pen > 0.0:
		fc = max(0.0, kw(xt) * pen + 30.0 * (vh - vw))
	else:
		fc = 0.0
	lost = fc <= 0.0 and (w - yh) > 0.001
	var aero: float = 0.01 * speed * speed * (1.0 + 2.0 * wind * gust)
	var fh: float = -KH * (yh - yf) - CH * (vh - vf) + F0 + aero - fc
	var ff: float = KH * (yh - yf) + CH * (vh - vf) - KF * yf - CF * vf
	vh += fh / MH * dt
	yh += vh * dt
	vf += ff / MF * dt
	yf += vf * dt


func _link(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	(mi.mesh as BoxMesh).size = Vector3(0.06, 0.06, d.length())
	var up: Vector3 = Vector3.UP
	if absf(d.normalized().dot(up)) > 0.99:
		up = Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d.normalized(), up), (a + b) * 0.5)


func _process(_dt: float) -> void:
	var lat: float = zig * sin(TAU * xt / span)
	var head_y: float = clampf(WIRE_Y + yh * gain, ROOF_Y + 0.4, ROOF_Y + 1.9)
	head.position = Vector3(0, head_y, lat)
	var half: float = (head_y - ROOF_Y) * 0.5
	var off: float = sqrt(maxf(ARM_L * ARM_L - half * half, 0.0))
	var base_p := Vector3(0, ROOF_Y, 0)
	var knee := Vector3(-off, ROOF_Y + half, lat * 0.5)
	_link(arm1, base_p, knee)
	_link(arm2, knee, Vector3(0, head_y, lat))

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var s: float = -40.0
	while s <= 40.0:
		var p: float = xt + s
		var wz: float = zig * sin(TAU * p / span)
		imm.surface_add_vertex(Vector3(s, WIRE_Y + w_prof(p) * gain, wz))
		s += 0.5
	imm.surface_end()

	var base: int = floori(xt / span)
	for i in poles.size():
		var pn: Node3D = poles[i]
		pn.position.x = (base + i - 1) * span - xt

	for i in sleepers.size():
		var sl: MeshInstance3D = sleepers[i]
		sl.position.x = fposmod(i * 0.7 - xt, 84.0) - 42.0

	sparks.position = Vector3(0, head_y + 0.05, lat)
	sparks.emitting = lost

	var target := Vector3(0, 4.8, 0)
	cam.position = target + dist * Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	cam.look_at(target)

	lbl.text = "%.0f км/ч | контактная сила: %.0f Н | %s" % [speed * 3.6, fc, "ОТРЫВ, искрение!" if lost else "контакт есть"]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenDrag:
		yaw -= e.relative.x * 0.005
		pitch = clampf(pitch + e.relative.y * 0.005, 0.02, 1.4)
	elif e is InputEventMagnifyGesture:
		dist = clampf(dist / e.factor, 3.0, 40.0)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist * 0.9, 3.0, 40.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist * 1.1, 3.0, 40.0)
