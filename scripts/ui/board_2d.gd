extends Control
## Tabellone 2D: l'immagine originale con sopra le pedine originali (cancelli, pilastri, templi, corone
## d'alloro, tessere degli artisti) e i nobili disegnati come busti di bronzo, argento e oro.
## Le coordinate «del tabellone» sono i pixel dell'immagine originale (3000 × 2344).

const D = preload("res://scripts/data/cs_data.gd")
const BW := 3000.0
const BH := 2344.0

var e: CSEngine
var view                       # game_view: highlight e clic
var tex: Texture2D
var zoom := 1.0
var pan := Vector2.ZERO
var base_scale := 1.0
var origin := Vector2.ZERO
var _drag := false
var _drag_from := Vector2.ZERO
var _moved := 0.0
var nob_disp: Array = []        # posizione mostrata dei nobili (pixel del tabellone)
var anims: Array = []           # {i, pts, t, dur}
var hover := -1
var flash := {}                 # mercato -> tempo (lampeggio dopo un'asta)
var t_now := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tex = UI.tex("res://assets/tabellone/tabellone.jpg")
	resized.connect(fit)


func set_engine(eng: CSEngine) -> void:
	e = eng
	nob_disp.clear()
	for i in 6:
		nob_disp.append(noble_px(e.nobles[i]))
	e.fx.connect(_on_fx)


func fit() -> void:
	if size.x <= 0:
		return
	base_scale = minf(size.x / BW, size.y / BH)
	_clamp()
	queue_redraw()


func _clamp() -> void:
	var s := base_scale * zoom
	var sz := Vector2(BW, BH) * s
	origin = (size - sz) * 0.5 + pan
	if zoom <= 1.0:
		pan = Vector2.ZERO
		origin = (size - sz) * 0.5


func to_screen(p: Vector2) -> Vector2:
	return origin + p * base_scale * zoom


func to_board(p: Vector2) -> Vector2:
	return (p - origin) / (base_scale * zoom)


func L(key: String, i: int) -> Vector2:
	var a = e.layout[key][i]
	return Vector2(float(a[0]) * BW, float(a[1]) * BH)


func noble_px(pos: int) -> Vector2:
	return L("noble", pos)


func gate_px(g: int) -> Vector2:
	return L("gates", g)


func market_px(m: int, k: int) -> Vector2:
	var a = e.layout["markets"][m][k]
	return Vector2(float(a[0]) * BW, float(a[1]) * BH)


func market_rot(m: int, k: int) -> float:
	var r = e.layout.get("market_rot", [])
	return deg_to_rad(float(r[m][k])) if r.size() > m else 0.0


func market_center(m: int) -> Vector2:
	var c := Vector2.ZERO
	for k in 3:
		c += market_px(m, k)
	return c / 3.0


func acclaim_px(v: int) -> Vector2:
	return L("acclaim", posmod(v, 100))


func temple_px(i: int) -> Vector2:
	return L("temples", i)


# ================================================================ animazioni

func _on_fx(kind: String, data: Dictionary) -> void:
	if kind == "noble":
		var pts := []
		for p in data["path"]:
			pts.append(noble_px(int(p)))
		var dur := (0.12 + 0.07 * pts.size()) / maxf(0.3, e.anim)
		if e.headless or e.anim <= 0.0:
			dur = 0.0
		anims.append({"i": int(data["i"]), "pts": pts, "t": 0.0, "dur": dur})
	elif kind == "won":
		flash[int(data["m"])] = 1.0
	queue_redraw()


func _process(dt: float) -> void:
	t_now += dt
	var busy := false
	if e != null:
		for a in anims:
			if a["i"] >= 0:
				busy = true
		var rest := []
		for a in anims:
			a["t"] += dt
			var pts: Array = a["pts"]
			if a["dur"] <= 0.0 or a["t"] >= a["dur"]:
				nob_disp[a["i"]] = pts[-1]
			else:
				var f: float = a["t"] / a["dur"] * (pts.size() - 1)
				var k := int(f)
				nob_disp[a["i"]] = (pts[k] as Vector2).lerp(pts[mini(k + 1, pts.size() - 1)], ease(f - k, -1.6))
				rest.append(a)
		anims = rest
		if anims.is_empty():
			for i in 6:
				var tgt := noble_px(e.nobles[i])
				if nob_disp[i].distance_to(tgt) > 1.0:
					nob_disp[i] = tgt
		for m in flash.keys():
			flash[m] -= dt
			if flash[m] <= 0:
				flash.erase(m)
	if busy or not flash.is_empty() or (view != null and not view.hl.is_empty()):
		queue_redraw()


# ================================================================ disegno

func _draw() -> void:
	if e == null or e.layout.is_empty():
		return
	var s := base_scale * zoom
	draw_rect(Rect2(origin - Vector2(6, 6), Vector2(BW, BH) * s + Vector2(12, 12)), Color(0, 0, 0, 0.5))
	draw_texture_rect(tex, Rect2(origin, Vector2(BW, BH) * s), false)
	# templi
	for spot in e.temple_spots:
		var p: int = e.temple_spots[spot]
		var td := deg_to_rad(float(e.layout.get("temple_dir", [0, 0, 0, 0, 0])[int(spot)]))
		_draw_piece("res://assets/segnalini/tempio_b.png", temple_px(spot), 135.0, UI.pcolor(e, p), td - PI * 0.5)
	# cancelli
	for g in e.gate_owner:
		var p: int = e.gate_owner[g]
		var ang := deg_to_rad(float(e.layout["gate_angle"][g]))
		_draw_piece("res://assets/segnalini/cancello_b.png", gate_px(g), 88.0, UI.pcolor(e, p), ang)
	# mercati
	for m in 5:
		var lot: Array = e.markets[m]
		for k in lot.size():
			var c := market_px(m, k)
			var t := UI.tile_tex(lot[k])
			var sz := 96.0 * s
			draw_set_transform(to_screen(c), market_rot(m, k), Vector2.ONE)
			var r := Rect2(-Vector2(sz, sz) * 0.5, Vector2(sz, sz))
			draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.45))
			draw_texture_rect(t, r, false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if flash.has(m):
			var c := to_screen(market_center(m))
			draw_circle(c, 120 * s, Color(UI.GOLD_L, 0.35 * flash[m]))
		if e.pillar_at.has(m):
			_draw_piece("res://assets/segnalini/pilastro_b.png", market_center(m) + Vector2(0, -10), 110.0, UI.pcolor(e, e.pillar_at[m]))
	# Mercurio accanto al lotto all'asta
	if e.mercury >= 0:
		var c := market_center(e.mercury)
		var dir := (c - Vector2(1500, 1100)).normalized()
		_draw_mercury(c - dir * 120.0)
	else:
		_draw_mercury(Vector2(1500, 1060))
	# nobili
	for i in 6:
		_draw_noble(i, nob_disp[i])
	# corone sul tracciato dell'Acclamazione
	var stack := {}
	var order := range(e.n)
	order.sort_custom(func(a, b): return e.ps[a]["aseq"] < e.ps[b]["aseq"])
	for p in order:
		var v: int = int(e.ps[p]["acclaim"])
		var k: int = stack.get(posmod(v, 100), 0)
		stack[posmod(v, 100)] = k + 1
		var c := acclaim_px(v) + Vector2(0, -14 * k)
		var t := UI.wreath_tex(e, p)
		var sz := 66.0 * s
		draw_texture_rect(t, Rect2(to_screen(c) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false)
		if v >= 100:
			_text(to_screen(c) + Vector2(0, 4), "+%d" % (v / 100 * 100), 13, Color.WHITE)
	# evidenziazioni
	if view != null:
		var pulse := 0.6 + 0.4 * sin(t_now * 5.0)
		for h in view.hl:
			var c := to_screen(h["pos"])
			var r: float = h.get("r", 50.0) * s
			var col: Color = h.get("col", UI.GOLD_L)
			draw_circle(c, r, Color(col, 0.22 + 0.16 * pulse))
			draw_arc(c, r, 0, TAU, 48, Color(0, 0, 0, 0.7), maxf(4.0, 14.0 * s))
			draw_arc(c, r, 0, TAU, 48, Color(col, 0.75 + 0.25 * pulse), maxf(2.5, 8.0 * s))
			if h.get("label", "") != "":
				_text(c + Vector2(0, -r - 4), h["label"], maxi(13, int(30 * s)), col, true)


func _draw_piece(path: String, at: Vector2, h: float, col: Color, ang := 0.0) -> void:
	var t := UI.tex(path)
	if t == null:
		return
	var s := base_scale * zoom
	var sz := Vector2(t.get_width(), t.get_height()) * (h / t.get_height()) * s
	var c := to_screen(at)
	draw_set_transform(c, ang, Vector2.ONE)
	draw_texture_rect(t, Rect2(-sz * 0.5 + Vector2(3, 4), sz), false, Color(0, 0, 0, 0.45))
	draw_texture_rect(t, Rect2(-sz * 0.5, sz), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const NOBLE_COL := [Color("#e8bf45"), Color("#c9ccd0"), Color("#c9ccd0"), Color("#b77744"), Color("#b77744"), Color("#b77744")]
const NOBLE_DARK := [Color("#8a6410"), Color("#6c7076"), Color("#6c7076"), Color("#6b3d1c"), Color("#6b3d1c"), Color("#6b3d1c")]


## un busto stilizzato su una base tonda
func _draw_noble(i: int, at: Vector2) -> void:
	var s := base_scale * zoom
	var c := to_screen(at)
	var r := (46.0 if i == 0 else 40.0) * s
	var col: Color = NOBLE_COL[i]
	var dk: Color = NOBLE_DARK[i]
	draw_circle(c + Vector2(3, 5) * s * 2, r, Color(0, 0, 0, 0.45))
	draw_circle(c, r, dk)
	draw_circle(c, r * 0.86, col)
	# spalle e testa
	var sh := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		sh.append(c + Vector2(cos(a) * r * 0.62, r * 0.5 + sin(a) * r * 0.42))
	draw_colored_polygon(sh, dk)
	draw_circle(c + Vector2(0, -r * 0.18), r * 0.3, dk)
	if i == 0:
		# corona d'alloro dell'Imperatore
		draw_arc(c + Vector2(0, -r * 0.2), r * 0.36, PI * 1.05, PI * 1.95, 10, Color("#4d6b1f"), maxf(1.5, r * 0.12))
	var nm := "I" if i == 0 else ("C" if i < 3 else "S")
	_text(c + Vector2(r * 0.7, r * 0.62), nm, maxi(13, int(r * 0.8)), Color.WHITE, true)


func _draw_mercury(at: Vector2) -> void:
	var s := base_scale * zoom
	var c := to_screen(at)
	var r := 30.0 * s
	draw_circle(c + Vector2(2, 3), r, Color(0, 0, 0, 0.4))
	draw_circle(c, r, Color("#2f7f7a"))
	draw_circle(c, r * 0.8, Color("#57b8b1"))
	# il petaso alato
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, 0), c + Vector2(r * 0.5, 0), c + Vector2(0, -r * 0.45)]), Color("#1d4f4b"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.1), c + Vector2(-r * 0.95, -r * 0.5), c + Vector2(-r * 0.55, r * 0.15)]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.4, -r * 0.1), c + Vector2(r * 0.95, -r * 0.5), c + Vector2(r * 0.55, r * 0.15)]), Color.WHITE)


func _text(at: Vector2, t: String, sz: int, col: Color, outline := false) -> void:
	var f: Font = UI.font_head
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var p := at - Vector2(w * 0.5, -sz * 0.35)
	if outline:
		draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, maxi(3, sz / 5), Color(0, 0, 0, 0.85))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


# ================================================================ input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_drag_from = mb.position
				_moved = 0.0
			else:
				_drag = false
				if _moved < 8.0 and view != null:
					view.on_board_click(to_board(mb.position))
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = mb.pressed
			_drag_from = mb.position
			_moved = 99.0
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag and zoom > 1.0:
			_moved += mm.relative.length()
			if _moved >= 8.0:
				pan += mm.relative
				_clamp()
				queue_redraw()
		elif _drag:
			_moved += mm.relative.length()
		if view != null:
			view.on_board_hover(to_board(mm.position), mm.position + global_position)
	elif ev is InputEventMagnifyGesture:
		_zoom_at((ev as InputEventMagnifyGesture).position, (ev as InputEventMagnifyGesture).factor)
	elif ev is InputEventPanGesture:
		if zoom > 1.0:
			pan -= (ev as InputEventPanGesture).delta * 20.0
			_clamp()
			queue_redraw()


func _zoom_at(p: Vector2, f: float) -> void:
	var before := to_board(p)
	zoom = clampf(zoom * f, 1.0, 3.5)
	_clamp()
	if zoom > 1.0:
		var after := to_screen(before)
		pan += p - after
		_clamp()
	queue_redraw()


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	fit()
