extends SubViewportContainer
## Tabellone 3D: il tabellone originale sul tavolo, con i pezzi in rilievo — archi dei cancelli nel colore
## dell'impresario, templi con colonne e frontone, busti dei nobili in oro, argento e bronzo, pilastri, corone
## d'alloro, tessere degli artisti nei mercati e le Stelle in piedi accanto ai cancelli di chi le possiede.
## Trascina per ruotare, tasto destro (o Maiusc) per spostare, rotella per lo zoom.

const D = preload("res://scripts/data/cs_data.gd")
const SW := 12.8
const SH := 12.8 * 2344.0 / 3000.0

var e: CSEngine
var view
var vp: SubViewport
var cam: Camera3D
var world: Node3D
var pieces: Node3D
var hl_node: Node3D
var nobles: Array = []
var mercury_node: Node3D
var yaw := 0.0
var pitch := 0.95
var dist := 15.0
var target := Vector3(0, 0, 0.6)
var _drag := 0
var _from := Vector2.ZERO
var _moved := 0.0
var _active := false
var _mats := {}


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var en := Environment.new()
	en.background_mode = Environment.BG_COLOR
	en.background_color = Color("#140d08")
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color("#f2ece2")
	en.ambient_light_energy = 0.38
	en.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = en
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.62
	sun.light_color = Color("#fff6ea")
	sun.shadow_enabled = true
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	_build_table()
	pieces = Node3D.new()
	world.add_child(pieces)
	hl_node = Node3D.new()
	world.add_child(hl_node)
	_update_cam()


func set_engine(eng: CSEngine) -> void:
	e = eng
	for i in 6:
		var b := _bust(i)
		world.add_child(b)
		nobles.append(b)
	mercury_node = _mercury()
	world.add_child(mercury_node)
	refresh()


func set_active(on: bool) -> void:
	_active = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		refresh()
		refresh_hl()


func fit() -> void:
	pass


func px3(px: Vector2, y := 0.0) -> Vector3:
	return Vector3((px.x / 3000.0 - 0.5) * SW, y, (px.y / 2344.0 - 0.5) * SH)


func from3(p: Vector3) -> Vector2:
	return Vector2((p.x / SW + 0.5) * 3000.0, (p.z / SH + 0.5) * 2344.0)


# ================================================================ materiali e pezzi

## modello della versione deluxe (estratto dal modulo TTS), alto 1 e appoggiato a terra
func model(name: String, col: Color, h: float, metal := 0.0, rough := 0.6) -> MeshInstance3D:
	var m: Mesh = load("res://assets/modelli/%s.obj" % name)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mt := mat(col, metal, rough)
	mi.material_override = mt
	mi.scale = Vector3.ONE * h
	return mi


## sagoma estrusa (Stelle e promotori) con l'immagine sulle due facce
func cutout(name: String, tex: Texture2D, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://assets/modelli/%s.obj" % name)
	var k := "tx/" + name
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.roughness = 0.75
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[k] = m
	mi.material_override = _mats[k]
	mi.scale = Vector3.ONE * h
	return mi


func mat(col: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var k := "%s/%.2f/%.2f" % [col.to_html(), metal, rough]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.metallic = metal
		m.roughness = rough
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[k] = m
	return _mats[k]


func _tile_mat(t: String) -> StandardMaterial3D:
	var k := "tile/" + t
	if not _mats.has(k):
		_mats[k] = tex_mat(UI.tile_tex(t))
	return _mats[k]


func tex_mat(t: Texture2D, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh(m: Mesh, mt: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mt
	mi.position = pos
	return mi


func _build_table() -> void:
	var table := PlaneMesh.new()
	table.size = Vector2(60, 60)
	var tm := mat(Color("#3a2416"), 0.0, 0.9)
	world.add_child(_mesh(table, tm, Vector3(0, -0.2, 0)))
	var base := BoxMesh.new()
	base.size = Vector3(SW + 0.3, 0.2, SH + 0.3)
	world.add_child(_mesh(base, mat(Color("#1d140e")), Vector3(0, -0.1, 0)))
	var board := PlaneMesh.new()
	board.size = Vector2(SW, SH)
	var bm := tex_mat(UI.tex("res://assets/tabellone/tabellone.jpg"))
	world.add_child(_mesh(board, bm, Vector3(0, 0.001, 0)))


func _bust(i: int) -> Node3D:
	var root := Node3D.new()
	var names := ["imperatore", "console", "console", "senatore", "senatore", "senatore"]
	var cols := [Color("#e0b23a"), Color("#c9ccd2"), Color("#c9ccd2"), Color("#b0703e"), Color("#b0703e"), Color("#b0703e")]
	var n := model(names[i], cols[i], 0.62 if i == 0 else 0.56, 0.8, 0.38)
	root.add_child(n)
	return root


func _bust_body(i: int) -> Node3D:
	var cols := [Color("#d9a933"), Color("#c3c7cc"), Color("#c3c7cc"), Color("#a8683a"), Color("#a8683a"), Color("#a8683a")]
	var m := mat(cols[i], 0.85, 0.32)
	var n := Node3D.new()
	n.name = "busto"
	var k := 1.15 if i == 0 else 1.0
	var base := CylinderMesh.new()
	base.top_radius = 0.14 * k
	base.bottom_radius = 0.16 * k
	base.height = 0.07
	n.add_child(_mesh(base, m, Vector3(0, 0.035, 0)))
	var body := CylinderMesh.new()
	body.top_radius = 0.06 * k
	body.bottom_radius = 0.12 * k
	body.height = 0.17 * k
	n.add_child(_mesh(body, m, Vector3(0, 0.07 + 0.085 * k, 0)))
	var head := SphereMesh.new()
	head.radius = 0.065 * k
	head.height = 0.14 * k
	n.add_child(_mesh(head, m, Vector3(0, 0.07 + 0.17 * k + 0.06 * k, 0)))
	if i == 0:
		var crown := TorusMesh.new()
		crown.inner_radius = 0.055
		crown.outer_radius = 0.075
		n.add_child(_mesh(crown, mat(Color("#4d6b1f"), 0.2, 0.5), Vector3(0, 0.07 + 0.17 * k + 0.09 * k, 0)))
	return n


func _mercury() -> Node3D:
	var root := Node3D.new()
	root.add_child(model("mercurio", Color("#4fb3ab"), 0.6, 0.2, 0.45))
	return root


func _mercury_old() -> Node3D:
	var n := Node3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.11
	c.height = 0.26
	n.add_child(_mesh(c, mat(Color("#3f9f98"), 0.3, 0.4), Vector3(0, 0.13, 0)))
	var h := SphereMesh.new()
	h.radius = 0.07
	h.height = 0.14
	n.add_child(_mesh(h, mat(Color("#3f9f98"), 0.3, 0.4), Vector3(0, 0.31, 0)))
	for s in [-1, 1]:
		var w := PrismMesh.new()
		w.size = Vector3(0.12, 0.08, 0.02)
		var wi := _mesh(w, mat(Color.WHITE), Vector3(0.08 * s, 0.34, 0))
		wi.rotation_degrees = Vector3(0, 0, -60 * s)
		n.add_child(wi)
	return n


func _gate(col: Color) -> Node3D:
	var root := Node3D.new()
	var g := model("cancello", col, 0.3, 0.0, 0.6)
	g.rotation.y = PI * 0.5
	root.add_child(g)
	return root


func _gate_old(col: Color) -> Node3D:
	var n := Node3D.new()
	var m := mat(col, 0.0, 0.6)
	for s in [-1, 1]:
		var pl := BoxMesh.new()
		pl.size = Vector3(0.08, 0.22, 0.1)
		n.add_child(_mesh(pl, m, Vector3(0.14 * s, 0.11, 0)))
	var top := BoxMesh.new()
	top.size = Vector3(0.38, 0.07, 0.12)
	n.add_child(_mesh(top, m, Vector3(0, 0.255, 0)))
	var arch := CylinderMesh.new()
	arch.top_radius = 0.1
	arch.bottom_radius = 0.1
	arch.height = 0.1
	var ai := _mesh(arch, m, Vector3(0, 0.2, 0))
	ai.rotation_degrees = Vector3(90, 0, 0)
	ai.scale = Vector3(1, 1, 0.5)
	n.add_child(ai)
	return n


func _temple(col: Color) -> Node3D:
	var root := Node3D.new()
	root.add_child(model("tempio", col.lerp(Color.WHITE, 0.15), 0.36, 0.0, 0.6))
	return root


func _temple_old(col: Color) -> Node3D:
	var n := Node3D.new()
	var m := mat(col.lerp(Color.WHITE, 0.25), 0.0, 0.6)
	var base := BoxMesh.new()
	base.size = Vector3(0.46, 0.06, 0.34)
	n.add_child(_mesh(base, m, Vector3(0, 0.03, 0)))
	for x in [-0.17, -0.06, 0.06, 0.17]:
		var c := CylinderMesh.new()
		c.top_radius = 0.022
		c.bottom_radius = 0.026
		c.height = 0.22
		n.add_child(_mesh(c, m, Vector3(x, 0.17, 0.12)))
		n.add_child(_mesh(c, m, Vector3(x, 0.17, -0.12)))
	var roof := PrismMesh.new()
	roof.size = Vector3(0.5, 0.12, 0.38)
	n.add_child(_mesh(roof, m, Vector3(0, 0.34, 0)))
	return n


func _pillar(col: Color) -> Node3D:
	var root := Node3D.new()
	root.add_child(model("pilastro", col, 0.5, 0.0, 0.55))
	return root


func _pillar_old(col: Color) -> Node3D:
	var n := Node3D.new()
	var m := mat(col, 0.0, 0.55)
	var c := CylinderMesh.new()
	c.top_radius = 0.055
	c.bottom_radius = 0.06
	c.height = 0.4
	n.add_child(_mesh(c, m, Vector3(0, 0.2, 0)))
	var cap := BoxMesh.new()
	cap.size = Vector3(0.16, 0.04, 0.16)
	n.add_child(_mesh(cap, m, Vector3(0, 0.42, 0)))
	n.add_child(_mesh(cap, m, Vector3(0, 0.02, 0)))
	return n


# ================================================================ aggiornamento

func refresh() -> void:
	if e == null or not _active or e.layout.is_empty():
		return
	for c in pieces.get_children():
		c.queue_free()
	var b2 = view.board2d
	for g in e.gate_owner:
		var p: int = e.gate_owner[g]
		var n := _gate(UI.pcolor(e, p))
		n.position = px3(b2.gate_px(int(g)))
		n.rotation.y = -deg_to_rad(float(e.layout["gate_angle"][g]))
		pieces.add_child(n)
	for spot in e.temple_spots:
		var n := _temple(UI.pcolor(e, e.temple_spots[spot]))
		n.position = px3(b2.temple_px(int(spot)))
		pieces.add_child(n)
	for m in 5:
		for k in e.markets[m].size():
			var t := BoxMesh.new()
			t.size = Vector3(0.4, 0.035, 0.4)
			var mi := _mesh(t, mat(Color("#c9b48c")), px3(b2.market_px(m, k), 0.0175))
			mi.rotation.y = -b2.market_rot(m, k)
			var top := PlaneMesh.new()
			top.size = Vector2(0.4, 0.4)
			var ti := _mesh(top, _tile_mat(e.markets[m][k]), Vector3(0, 0.0185, 0))
			mi.add_child(ti)
			pieces.add_child(mi)
		if e.pillar_at.has(m):
			var n := _pillar(UI.pcolor(e, e.pillar_at[m]))
			n.position = px3(b2.market_center(m), 0.0)
			pieces.add_child(n)
	# corone d'alloro sul tracciato
	var stack := {}
	var order := range(e.n)
	order.sort_custom(func(a, c): return e.ps[a]["aseq"] < e.ps[c]["aseq"])
	for p in order:
		var v := posmod(int(e.ps[p]["acclaim"]), 100)
		var k: int = stack.get(v, 0)
		stack[v] = k + 1
		var tor := TorusMesh.new()
		tor.inner_radius = 0.07
		tor.outer_radius = 0.13
		var mi := _mesh(tor, mat(UI.pcolor(e, p), 0.1, 0.5), px3(b2.acclaim_px(v), 0.03 + 0.06 * k))
		pieces.add_child(mi)
	# davanti ai cancelli di ogni impresario: le sue Stelle, i promotori e il segnalino del primo giocatore
	for p in e.n:
		if e.ps[p]["gates"].is_empty():
			continue
		var gs: Array = e.ps[p]["gates"]
		var gp: Vector2 = (b2.gate_px(int(gs[0])) + b2.gate_px(int(gs[-1]))) * 0.5
		var out := (gp - Vector2(1500, 1100)).normalized()
		var side := Vector2(-out.y, out.x)
		var face := atan2(out.x * SW / 3000.0, out.y * SH / 2344.0)
		var ss := e.stars_of(p)
		for k in ss.size():
			var st := cutout("stella_" + ss[k], UI.star_tex(ss[k]), 0.36)
			var at := gp + out * 160.0 + side * (k - (ss.size() - 1) * 0.5) * 75.0
			st.position = px3(at, 0.0)
			st.rotation.y = face
			pieces.add_child(st)
		var np: int = e.ps[p]["promoters"]
		for k in np:
			var pr := cutout("promotore%d" % (k % 3 + 1), UI.tex("res://assets/segnalini/promotore%d.png" % (k % 3 + 1)), 0.26)
			var at := gp + out * (250.0 if not ss.is_empty() else 160.0) + side * (k - (np - 1) * 0.5) * 50.0
			pr.position = px3(at, 0.0)
			pr.rotation.y = face
			pieces.add_child(pr)
		if p == e.first:
			var fm := model("primo_giocatore", Color("#d1a446"), 0.2, 0.6, 0.4)
			fm.position = px3(gp - side * 170.0 + out * 90.0, 0.0)
			fm.rotation.y = face
			pieces.add_child(fm)


func refresh_hl() -> void:
	if not _active or view == null:
		return
	for c in hl_node.get_children():
		c.queue_free()
	for h in view.hl:
		var r: float = float(h.get("r", 50.0)) / 3000.0 * SW
		var tor := TorusMesh.new()
		tor.inner_radius = r * 0.86
		tor.outer_radius = r
		tor.rings = 48
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var col: Color = h.get("col", UI.GOLD_L)
		m.albedo_color = col
		var mi := _mesh(tor, m, px3(h["pos"], 0.03))
		mi.scale = Vector3(1, 0.7, 1)
		hl_node.add_child(mi)
		var disc := CylinderMesh.new()
		disc.top_radius = r * 0.8
		disc.bottom_radius = r * 0.8
		disc.height = 0.01
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(col, 0.16)
		hl_node.add_child(_mesh(disc, dm, px3(h["pos"], 0.02)))
		if str(h.get("label", "")) != "":
			var l := Label3D.new()
			l.text = h["label"]
			l.font = UI.font_head
			l.font_size = 64
			l.pixel_size = 0.004
			l.outline_size = 16
			l.modulate = col.lightened(0.2)
			l.outline_modulate = Color(0, 0, 0, 0.9)
			l.double_sided = true
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = px3(h["pos"], 0.45)
			l.no_depth_test = true
			hl_node.add_child(l)


func _process(dt: float) -> void:
	if not _active or e == null:
		return
	var b2 = view.board2d
	for i in 6:
		if i < b2.nob_disp.size():
			nobles[i].position = px3(b2.nob_disp[i])
	var mp: Vector2
	if e.mercury >= 0:
		var c: Vector2 = b2.market_center(e.mercury)
		mp = c - (c - Vector2(1500, 1100)).normalized() * 130.0
	else:
		mp = Vector2(1500, 1060)
	mercury_node.position = mercury_node.position.lerp(px3(mp), minf(1.0, dt * 6.0))
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 160.0)
	for c in hl_node.get_children():
		if c is MeshInstance3D and c.mesh is TorusMesh:
			c.scale = Vector3(pulse, 0.7, pulse)


# ================================================================ telecamera e input

func _update_cam() -> void:
	pitch = clampf(pitch, 0.25, 1.45)
	dist = clampf(dist, 4.0, 26.0)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			dist *= 0.9
			_update_cam()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			dist /= 0.9
			_update_cam()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = 2 if mb.shift_pressed else 1
				_from = mb.position
				_moved = 0.0
			else:
				if _moved < 8.0:
					var px := _pick(mb.position)
					if px.x > -9000 and view != null:
						view.on_board_click(px)
				_drag = 0
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = 2 if mb.pressed else 0
			_moved = 99.0
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag != 0:
			_moved += mm.relative.length()
			if _moved >= 8.0:
				if _drag == 1:
					yaw -= mm.relative.x * 0.006
					pitch += mm.relative.y * 0.005
				else:
					var right := cam.global_transform.basis.x
					var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
					target -= right * mm.relative.x * dist * 0.0012
					target += fwd * mm.relative.y * dist * 0.0012
					target.x = clampf(target.x, -SW * 0.6, SW * 0.6)
					target.z = clampf(target.z, -SH * 0.6, SH * 0.6)
				_update_cam()
		elif view != null:
			var px := _pick(mm.position)
			if px.x > -9000:
				view.on_board_hover(px, mm.position + global_position)
	elif ev is InputEventMagnifyGesture:
		dist /= (ev as InputEventMagnifyGesture).factor
		_update_cam()


## punto del tabellone sotto il mouse (in pixel dell'immagine), oppure (-9999, -9999)
func _pick(pos: Vector2) -> Vector2:
	var k := Vector2(vp.size) / size
	var p := pos * k
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	if absf(d.y) < 0.0001:
		return Vector2(-9999, -9999)
	var t := -o.y / d.y
	if t < 0:
		return Vector2(-9999, -9999)
	return from3(o + d * t)


func reset_view() -> void:
	yaw = 0.0
	pitch = 0.95
	dist = 15.0
	target = Vector3(0, 0, 0.6)
	_update_cam()
