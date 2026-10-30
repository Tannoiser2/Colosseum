extends Control
## La partita: tabellone 2D o 3D, le plance degli impresari, i comandi della fase, il diario e le tessere
## Spettacolo del giocatore. Le scelte sul tabellone (cancelli, lotti, nobili) si fanno toccando le caselle
## evidenziate.

const D = preload("res://scripts/data/cs_data.gd")
const PANEL_W := 600.0
const TOP_H := 60.0
const HAND_H := 150.0

var main
var config := {}
var engine: CSEngine
var online: OnlineSession
var local_seats: Array = []
var board2d
var board3d
var view3d := false
var board_area: Control
var hand_box: HBoxContainer
var hand_panel: PanelContainer
var right: VBoxContainer
var cards_box: VBoxContainer
var act_box: VBoxContainer
var phase_lbl: Label
var round_lbl: Label
var status_lbl: Label
var log_lbl: RichTextLabel
var tip: Label
var banner: Control

var pending := {}
var hl: Array = []               # evidenziazioni sul tabellone: {pos, r, label, col, kind, idx, data}
var mode := ""
var aux := {}
var ended := false
var _dirty := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engine = CSEngine.new()
	add_child(engine)
	online = config.get("online", null)
	if online != null:
		add_child(online)
		online.view = self
		engine.online = online
	engine.setup(config)
	for s in engine.n:
		var p: Dictionary = engine.players[s]
		engine.ais[s] = CSAI.new(int(p.get("level", 1)), int(config.get("seed", 0)) * 7 + s + 1 if config.has("seed") else randi())
		if online != null:
			if s == online.seat:
				local_seats.append(s)
		elif not p["ai"]:
			local_seats.append(s)
	view3d = bool(config.get("view3d", false))
	_build()
	engine.changed.connect(func(): _dirty = true)
	engine.log_added.connect(_on_log)
	engine.decision_requested.connect(_on_decision)
	engine.game_ended.connect(_on_end)
	engine.fx.connect(_on_fx)
	board2d.set_engine(engine)
	board3d.set_engine(engine)
	_apply_view()
	_refresh()
	if online != null and online.role != "host":
		online.heartbeat_loop()
	engine.run.call_deferred()


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_refresh()


## il giocatore di cui si mostrano le tessere Spettacolo in basso
func viewer() -> int:
	if not pending.is_empty() and int(pending["seat"]) in local_seats:
		return int(pending["seat"])
	if local_seats.size() == 1:
		return local_seats[0]
	if engine.active >= 0 and (local_seats.is_empty() or engine.active in local_seats):
		return engine.active
	if not local_seats.is_empty():
		if engine.current in local_seats:
			return engine.current
		return local_seats[0]
	return maxi(0, engine.current)


# ================================================================ costruzione

func _build() -> void:
	# barra in alto
	var top := PanelContainer.new()
	var ts := UI.panel_style(Color(UI.PANEL, 0.97), Color(UI.GOLD, 0.6), 0, 0)
	ts.border_width_bottom = 2
	ts.content_margin_top = 4
	ts.content_margin_bottom = 4
	top.add_theme_stylebox_override("panel", ts)
	top.anchor_right = 1.0
	top.offset_bottom = TOP_H
	add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 16)
	top.add_child(th)
	th.add_child(UI.title("Colosseum", 30))
	round_lbl = UI.label("", 24, UI.GOLD_L, UI.font_head)
	th.add_child(round_lbl)
	phase_lbl = UI.label("", 22, UI.STONE, UI.font_semi)
	phase_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_lbl.clip_text = true
	th.add_child(phase_lbl)
	var b_disp := UI.button("Spettacoli in vendita", 0, 46, 19)
	b_disp.pressed.connect(func(): _gallery(false))
	th.add_child(b_disp)
	var b_view := UI.button("2D / 3D", 110, 46, 19)
	b_view.pressed.connect(func():
		view3d = not view3d
		_apply_view())
	th.add_child(b_view)
	var b_rules := UI.button("Regole", 110, 46, 19)
	b_rules.pressed.connect(_show_rules_popup)
	th.add_child(b_rules)
	var b_menu := UI.button("Menu", 100, 46, 19)
	b_menu.pressed.connect(_confirm_menu)
	th.add_child(b_menu)

	# tabellone
	board_area = Control.new()
	board_area.anchor_right = 1.0
	board_area.anchor_bottom = 1.0
	board_area.offset_top = TOP_H
	board_area.offset_right = -PANEL_W
	board_area.offset_bottom = -HAND_H
	add_child(board_area)
	board2d = preload("res://scripts/ui/board_2d.gd").new()
	board2d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board2d.view = self
	board_area.add_child(board2d)
	board3d = preload("res://scripts/ui/board_3d.gd").new()
	board3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board3d.view = self
	board_area.add_child(board3d)

	# tessere Spettacolo del giocatore
	hand_panel = PanelContainer.new()
	var hs := UI.panel_style(Color(UI.BG, 0.96), Color(UI.GOLD, 0.5), 0, 0)
	hs.border_width_top = 2
	hs.set_content_margin_all(8)
	hand_panel.add_theme_stylebox_override("panel", hs)
	hand_panel.anchor_top = 1.0
	hand_panel.anchor_bottom = 1.0
	hand_panel.anchor_right = 1.0
	hand_panel.offset_top = -HAND_H
	hand_panel.offset_right = -PANEL_W
	add_child(hand_panel)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	hand_panel.add_child(hand_box)

	# pannello a destra
	var rp := PanelContainer.new()
	var rs := UI.panel_style(Color(UI.PANEL, 0.98), Color(UI.GOLD, 0.6), 0, 0)
	rs.border_width_left = 2
	rs.set_content_margin_all(8)
	rp.add_theme_stylebox_override("panel", rs)
	rp.anchor_left = 1.0
	rp.anchor_right = 1.0
	rp.anchor_bottom = 1.0
	rp.offset_left = -PANEL_W
	rp.offset_top = TOP_H
	add_child(rp)
	right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	rp.add_child(right)
	cards_box = VBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 5)
	right.add_child(cards_box)
	var ap := PanelContainer.new()
	ap.add_theme_stylebox_override("panel", UI.stone_style(6))
	right.add_child(ap)
	act_box = VBoxContainer.new()
	act_box.add_theme_constant_override("separation", 8)
	ap.add_child(act_box)
	status_lbl = UI.label("", 19, UI.GOLD_L, UI.font_italic)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status_lbl)
	log_lbl = RichTextLabel.new()
	log_lbl.bbcode_enabled = true
	log_lbl.scroll_following = true
	log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_lbl.add_theme_font_size_override("normal_font_size", 18)
	log_lbl.add_theme_font_size_override("bold_font_size", 18)
	log_lbl.add_theme_color_override("default_color", Color(UI.TEXT, 0.85))
	right.add_child(log_lbl)

	tip = UI.label("", 18, UI.INK, UI.font_semi)
	var tps := UI.stone_style(4)
	tps.set_content_margin_all(6)
	tip.add_theme_stylebox_override("normal", tps)
	tip.visible = false
	tip.z_index = 50
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip)


func _apply_view() -> void:
	board2d.visible = not view3d
	board3d.visible = view3d
	board3d.set_active(view3d)
	await get_tree().process_frame
	board2d.fit()


# ================================================================ aggiornamento

const PHASE_NAME := {"setup": "Preparazione", "invest": "Fase 1 · Investimenti", "hire": "Fase 2 · Ingaggio degli artisti",
	"trade": "Fase 3 · Scambi", "perform": "Fase 4 · Spettacoli", "closing": "Fase 5 · Cerimonie di chiusura",
	"over": "Fine della partita"}


func _refresh() -> void:
	var e := engine
	round_lbl.text = "Giornata %d/%d" % [maxi(1, e.round_n), D.ROUNDS] if e.round_n > 0 else ""
	var ph: String = PHASE_NAME.get(e.phase, "")
	if e.active >= 0 and e.phase in ["hire", "trade", "perform"]:
		ph += "  ·  di turno: %s" % e.pname(e.active)
	phase_lbl.text = ph
	_build_cards()
	_build_hand()
	if pending.is_empty():
		_waiting_text()
	board2d.queue_redraw()
	board3d.refresh()


func _build_cards() -> void:
	var e := engine
	for c in cards_box.get_children():
		c.queue_free()
	var compact := e.n >= 5
	for p: int in e.order_from(0):
		var st: Dictionary = e.ps[p]
		var card := PanelContainer.new()
		var is_cur := p == e.current and e.phase != "over"
		var cs := UI.panel_style(Color(UI.PANEL_L, 0.95), UI.pcolor(e, p), 4 if is_cur else 2, 6)
		cs.set_content_margin_all(6)
		cs.content_margin_left = 10
		if is_cur:
			cs.shadow_color = Color(UI.pcolor(e, p), 0.5)
			cs.shadow_size = 8
		card.add_theme_stylebox_override("panel", cs)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var pk := p
		card.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_player_popup(pk))
		cards_box.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vb)
		var r1 := HBoxContainer.new()
		r1.add_theme_constant_override("separation", 8)
		r1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(r1)
		r1.add_child(UI.icon_rect(UI.wreath_tex(e, p), Vector2(30, 30)))
		var nm := UI.label(e.pname(p), 22, UI.STONE, UI.font_head)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		r1.add_child(nm)
		if p == e.first:
			var fi := UI.icon_rect(UI.tex("res://assets/segnalini/primo_giocatore.png"), Vector2(28, 28))
			fi.tooltip_text = "Primo giocatore"
			r1.add_child(fi)
		r1.add_child(_stat("res://assets/monete/m5.png", str(st["coins"]), "Monete"))
		r1.add_child(_stat("res://assets/segnalini/aquila.png", str(st["aquila"]), "Aquile"))
		var acc := UI.label("%d" % st["acclaim"], 26, UI.GOLD_L, UI.font_head)
		acc.tooltip_text = "Acclamazione"
		acc.custom_minimum_size.x = 44
		acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r1.add_child(acc)
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 6)
		r2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(r2)
		var info := "%d/4 cancelli · %d promot. · %d doni%s · %d spett." % [st["gates"].size(), st["promoters"], st["gifts"],
			" · tempio" if st["temple"] >= 0 else "", e.all_spects(p).size()]
		if e.phase == "hire" and not st["pillar"]:
			info += " · senza pilastro"
		var il := UI.label(info, 17, UI.MUTED, UI.font_semi)
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r2.add_child(il)
		for t in e.stars_of(p):
			var si := UI.icon_rect(UI.star_tex(t), Vector2(20, 24))
			si.tooltip_text = "Stella %s" % D.TYPE_STAR[t]
			si.mouse_filter = Control.MOUSE_FILTER_PASS
			r2.add_child(si)
		var r3 := HBoxContainer.new()
		r3.add_theme_constant_override("separation", 2)
		r3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(r3)
		for t in D.TYPES + [D.WILD]:
			var k: int = st["tiles"].get(t, 0)
			if k <= 0:
				continue
			r3.add_child(_tile_chip(t, k, 26 if compact else 30))
		if e.tile_count(p) == 0:
			r3.add_child(UI.label("nessun artista", 16, UI.MUTED, UI.font_italic))
	# Stelle ancora sul tabellone
	var free := []
	for t in D.TYPES:
		if e.stars[t] < 0:
			free.append(t)
	if not free.is_empty():
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 3)
		r.add_child(UI.label("Stelle libere:", 16, UI.MUTED, UI.font_semi))
		for t in free:
			var si := UI.icon_rect(UI.star_tex(t), Vector2(22, 26))
			si.tooltip_text = "Stella %s: va a chi ha almeno 3 tessere del tipo e più di tutti" % D.TYPE_STAR[t]
			si.mouse_filter = Control.MOUSE_FILTER_PASS
			r.add_child(si)
		cards_box.add_child(r)


func _stat(icon: String, v: String, tt: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.tooltip_text = tt
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(UI.icon_rect(UI.tex(icon), Vector2(24, 24)))
	h.add_child(UI.label(v, 20, UI.STONE, UI.font_head))
	return h


func _tile_chip(t: String, k: int, sz := 30) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.tooltip_text = "%d %s" % [k, D.TYPE_NAME[t].to_lower() if k > 1 else D.TYPE_ONE[t]]
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var ic := UI.icon_rect(UI.tile_tex(t), Vector2(sz, sz))
	c.add_child(ic)
	if k > 1:
		var l := UI.label(str(k), int(sz * 0.55), Color.WHITE, UI.font_head)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 5)
		l.position = Vector2(sz * 0.5, sz * 0.32)
		c.add_child(l)
	return c


## le tessere Spettacolo del giocatore che si sta guardando
func _build_hand() -> void:
	var e := engine
	for c in hand_box.get_children():
		c.queue_free()
	var p := viewer()
	var head := VBoxContainer.new()
	head.custom_minimum_size.x = 150
	head.add_child(UI.label("Spettacoli di", 17, UI.MUTED, UI.font_italic))
	var nm := UI.label(e.pname(p), 21, UI.pcolor(e, p), UI.font_head)
	nm.clip_text = true
	head.add_child(nm)
	head.add_child(UI.label("%d cancell%s" % [e.gates_of(p), "o" if e.gates_of(p) == 1 else "i"], 17, UI.MUTED, UI.font_semi))
	hand_box.add_child(head)
	var ids: Array = e.ps[p]["plan"].duplicate()
	if e.ps[p]["cur"] != "":
		ids.append(e.ps[p]["cur"])
	ids.append_array(e.ps[p]["done"])
	var choosing: bool = not pending.is_empty() and pending["type"] == "perform" and int(pending["seat"]) == p
	for id in ids:
		var cb := Callable()
		if choosing and pending["options"].has(id):
			var k: String = id
			cb = func():
				aux["id"] = k
				_perform_list()
		hand_box.add_child(_spect_card(p, id, 128.0, cb))
	if ids.is_empty():
		hand_box.add_child(UI.label("nessuno", 18, UI.MUTED, UI.font_italic))


func _spect_card(p: int, id: String, h: float, on_click: Callable = Callable()) -> Control:
	var e := engine
	var s := D.spect(id)
	var done: bool = id in e.ps[p]["done"]
	var cur: bool = e.ps[p]["cur"] == id
	var t := UI.spect_tex(id, done or cur)
	var w := h * float(t.get_width()) / float(t.get_height())
	var pc := PanelContainer.new()
	var bc := UI.GOLD_L if cur else (UI.TEAL_L if done else Color(UI.STONE_D, 0.6))
	var ps_ := UI.panel_style(Color.BLACK, bc, 3 if (cur or done) else 1, 4)
	ps_.set_content_margin_all(2)
	pc.add_theme_stylebox_override("panel", ps_)
	var cc := Control.new()
	cc.custom_minimum_size = Vector2(w, h)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(cc)
	cc.add_child(UI.icon_rect(t, Vector2(w, h)))
	var ev := e.evaluate(p, id)
	var need: int = D.SIZE_GATES[s["size"]]
	var txt := ""
	if done:
		txt = "fatto (+5)"
	elif cur:
		txt = "in scena"
	if e.gates_of(p) < need:
		txt += ("" if txt == "" else " · ") + "servono %d cancelli" % need
	elif ev["ok"]:
		txt += ("" if txt == "" else " · ") + ("completo: %d" % ev["acclaim"] if ev["missing"] == 0 else "ora %d (−%d)" % [ev["acclaim"], ev["missing"]])
	else:
		txt += ("" if txt == "" else " · ") + "troppi artisti mancanti"
	var tl := UI.label(txt, 15, Color.WHITE, UI.font_semi)
	tl.add_theme_color_override("font_outline_color", Color.BLACK)
	tl.add_theme_constant_override("outline_size", 6)
	tl.position = Vector2(4, h - 22)
	tl.size = Vector2(w - 8, 20)
	tl.clip_text = true
	cc.add_child(tl)
	pc.tooltip_text = "%s (%s, %s)\nRichiede: %s\n%s" % [s["name"], s["orig"], D.SIZE_NAME[s["size"]], _req_text(s), txt]
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	if on_click.is_valid():
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pc.gui_input.connect(func(evn):
			if evn is InputEventMouseButton and evn.pressed and evn.button_index == MOUSE_BUTTON_LEFT:
				on_click.call())
	return pc


func _req_text(s: Dictionary) -> String:
	var parts := []
	for k in s["req"]:
		parts.append("%d %s" % [s["req"][k], D.TYPE_NAME[k].to_lower() if int(s["req"][k]) > 1 else D.TYPE_ONE[k]])
	return ", ".join(parts)


func _on_log(t: String) -> void:
	var col := "#f3e9d2"
	if t.begins_with("—"):
		col = "#f3cf72"
		t = "[b]%s[/b]" % t
	elif "la Stella" in t or "La Stella" in t:
		col = "#e8bf45"
	elif t.begins_with("  "):
		col = "#cdbb98"
	log_lbl.append_text("[color=%s]%s[/color]\n" % [col, t])


# ================================================================ effetti

func _on_fx(kind: String, data: Dictionary) -> void:
	_dirty = true
	if kind == "perform":
		_show_banner(data)
	elif kind == "gift":
		_flash_msg("L'Imperatore offre un Dono a %s" % engine.pname(int(data["p"])), UI.GOLD_L)
	elif kind == "dice":
		_flash_msg("%s tira %d e %d" % [engine.pname(int(data["p"])), data["dice"][0], data["dice"][1]], UI.STONE)


func _show_banner(data: Dictionary) -> void:
	if engine.anim <= 0.0:
		return
	if is_instance_valid(banner):
		banner.queue_free()
	var p := int(data["p"])
	var id: String = data["id"]
	banner = PanelContainer.new()
	var bs := UI.panel_style(Color(UI.BG, 0.94), UI.pcolor(engine, p), 4, 10)
	bs.shadow_color = Color(0, 0, 0, 0.7)
	bs.shadow_size = 24
	banner.add_theme_stylebox_override("panel", bs)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	banner.add_child(vb)
	var t := UI.spect_tex(id, true)
	vb.add_child(UI.icon_rect(t, Vector2(560, 560.0 * t.get_height() / t.get_width())))
	var l1 := UI.label("%s mette in scena «%s»" % [engine.pname(p), D.spect(id)["name"]], 26, UI.STONE, UI.font_head)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l1)
	var l2 := UI.label("%d di Acclamazione" % int(data["total"]), 34, UI.GOLD_L, UI.font_title)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l2)
	board_area.add_child(banner)
	await get_tree().process_frame
	if not is_instance_valid(banner):
		return
	banner.position = (board_area.size - banner.size) * 0.5
	banner.modulate.a = 0.0
	var b := banner
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.6 / maxf(0.5, engine.anim))
	tw.tween_property(b, "modulate:a", 0.0, 0.4)
	tw.tween_callback(b.queue_free)


func _flash_msg(t: String, col: Color) -> void:
	if engine.anim <= 0.0:
		return
	var l := UI.label(t, 30, col, UI.font_head)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(l)
	await get_tree().process_frame
	l.position = Vector2((board_area.size.x - l.size.x) * 0.5, 16)
	var tw := l.create_tween()
	tw.tween_interval(1.4 / maxf(0.5, engine.anim))
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


# ================================================================ decisioni

func _clear_box() -> void:
	for c in act_box.get_children():
		c.queue_free()


func _prompt(t: String, sub := "") -> void:
	_clear_box()
	var who := ""
	if not pending.is_empty() and (local_seats.size() > 1):
		who = "%s — " % engine.pname(int(pending["seat"]))
	act_box.add_child(UI.wrap(UI.label(who + t, 22, UI.INK, UI.font_head), PANEL_W - 50))
	if sub != "":
		act_box.add_child(UI.wrap(UI.label(sub, 19, Color("#4a3423"), UI.font_body), PANEL_W - 50))


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	act_box.add_child(h)
	return h


func _ai_button(h: HBoxContainer) -> void:
	var b := UI.button("Decida l'IA", 0, 44, 18)
	b.tooltip_text = "Fa scegliere al computer per questa volta"
	b.pressed.connect(func():
		if pending.is_empty():
			return
		_submit(engine.ais[int(pending["seat"])].decide(engine, int(pending["seat"]), pending)))
	h.add_child(b)


func _on_decision(req: Dictionary) -> void:
	pending = req
	mode = ""
	aux = {}
	hl = []
	_dirty = true
	match req["type"]:
		"start_gates":
			_d_start_gates()
		"invest":
			_d_invest()
		"auction":
			_d_auction()
		"bid":
			_d_bid()
		"trade":
			_d_trade()
		"trade_answer":
			_d_trade_answer()
		"nobles":
			_d_nobles()
		"aquila_move":
			_d_aquila()
		"perform":
			_d_perform()
		"retire":
			_d_pick_tile("Ritira un artista", "Uno degli artisti dello spettacolo appena messo in scena torna nella scatola.", req["options"])
		"steal":
			_d_pick_tile("Sottrai un artista a %s" % engine.pname(int(req["from"])), "Come impresario meno acclamato prendi una tessera a scelta dal più acclamato.", req["options"])
		"first":
			_d_first()
	board3d.refresh_hl()


func _submit(r) -> void:
	if pending.is_empty():
		return
	pending = {}
	hl = []
	mode = ""
	status_lbl.text = ""
	_clear_box()
	_close_popup()
	board3d.refresh_hl()
	engine.provide_decision(r)


## mostra chi sta decidendo quando non tocca a una persona su questo dispositivo
func _waiting_text() -> void:
	if not pending.is_empty():
		return
	var e := engine
	if e.phase == "over" or e.current < 0:
		return
	_clear_box()
	var t := "Tocca a %s…" % e.pname(e.current)
	if e.phase == "hire" and e.mercury >= 0:
		t = "Asta del lotto %s: offerta più alta %d (%s)." % [["I", "II", "III", "IV", "V"][e.mercury], e.high_bid, e.pname(e.high_by)]
	act_box.add_child(UI.wrap(UI.label(t, 21, UI.INK, UI.font_semi), PANEL_W - 50))


# ---------------------------------------------------------------- cancelli di partenza

func _d_start_gates() -> void:
	_prompt("Scegli dove mettere i tuoi due cancelli di partenza", "Tocca sul tabellone una delle coppie di caselle evidenziate (sono quelle con i pallini del numero di giocatori).")
	for pair in pending["pairs"]:
		var a: Vector2 = board2d.gate_px(int(pair[0]))
		var b: Vector2 = board2d.gate_px(int(pair[1]))
		hl.append({"pos": (a + b) * 0.5, "r": 70.0, "kind": "pair", "data": pair, "col": UI.GOLD_L})
	_ai_button(_row())


# ---------------------------------------------------------------- investimenti

func _d_invest() -> void:
	var e := engine
	var p := int(pending["seat"])
	var o: Dictionary = pending["options"]
	_prompt("Investimenti: ne restano %d" % int(pending["left"]),
		"Hai %d monete e %d Aquile (ogni Aquila vale 6 monete). Ogni investimento una sola volta per turno." % [e.ps[p]["coins"], e.ps[p]["aquila"]])
	var g1 := GridContainer.new()
	g1.columns = 2
	g1.add_theme_constant_override("h_separation", 8)
	g1.add_theme_constant_override("v_separation", 8)
	act_box.add_child(g1)
	var bg := UI.button("Cancello · 10", 260, 50, 20)
	bg.disabled = o["gate"].is_empty()
	bg.tooltip_text = "Un cancello in più accanto ai tuoi: 3 cancelli per gli spettacoli medi, 4 per i grandi."
	bg.pressed.connect(func():
		mode = "gate"
		hl = []
		for s in o["gate"]:
			hl.append({"pos": board2d.gate_px(int(s)), "r": 60.0, "kind": "gate", "idx": int(s), "col": UI.GOLD_L})
		board3d.refresh_hl()
		status_lbl.text = "Tocca la casella dove costruire il cancello.")
	g1.add_child(bg)
	var bp := UI.button("Promotore · 7", 260, 50, 20)
	bp.disabled = not o["promoter"]
	bp.tooltip_text = "+5 di Acclamazione in ogni esibizione (ne restano %d)." % e.promoters_left()
	bp.pressed.connect(func(): _submit({"k": "promoter"}))
	g1.add_child(bp)
	var bt := UI.button("Tempio della Fortuna · 7", 260, 50, 20)
	bt.disabled = not o["temple"]
	bt.tooltip_text = "Con il tempio i dadi dei nobili valgono da 1 al numero uscito."
	bt.pressed.connect(func(): _submit({"k": "temple"}))
	g1.add_child(bt)
	var bs := UI.button("Spettacolo…", 260, 50, 20)
	bs.disabled = o["spect"].is_empty()
	bs.pressed.connect(func(): _gallery(true))
	g1.add_child(bs)
	var h := _row()
	var b_pass := UI.primary(UI.button("Basta così", 200, 48, 20))
	b_pass.pressed.connect(func(): _submit({"k": "pass"}))
	h.add_child(b_pass)
	_ai_button(h)


## galleria degli spettacoli in vendita; buy = si sta scegliendo cosa comprare
func _gallery(buy: bool) -> void:
	var e := engine
	var p := viewer()
	var pop := _popup("Spettacoli in vendita" if not buy else "Pianifica uno spettacolo", 1500)
	var sub := "Medi (3 cancelli) e grandi (4 cancelli). Tra parentesi quanto renderebbero ora con gli artisti di %s." % e.pname(p)
	pop.add_child(UI.wrap(UI.label(sub, 19, UI.MUTED, UI.font_italic), 1440))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1460, 700)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pop.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(grid)
	var allowed: Array = pending["options"]["spect"] if buy and not pending.is_empty() and pending["type"] == "invest" else []
	for id in e.display:
		var s := D.spect(id)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		var t := UI.spect_tex(id)
		var w := 350.0
		var tr := UI.icon_rect(t, Vector2(w, w * t.get_height() / t.get_width()))
		vb.add_child(tr)
		var ev := e.evaluate(p, id)
		var now := "ora %d, mancano %d" % [ev["acclaim"], ev["missing"]] if ev["ok"] else "ora non eseguibile (mancano %d)" % ev["missing"]
		var lab := UI.wrap(UI.label("%s · costo %d\n%s" % [s["name"], s["cost"], now], 17, UI.STONE, UI.font_semi), w)
		vb.add_child(lab)
		if buy:
			var b := UI.button("Compra · %d" % s["cost"], w, 40, 18)
			b.disabled = not id in allowed
			var k: String = id
			b.pressed.connect(func(): _submit({"k": "spect", "id": k}))
			vb.add_child(b)
		grid.add_child(vb)


# ---------------------------------------------------------------- aste

const MNAME := ["I", "II", "III", "IV", "V"]


func _d_auction() -> void:
	var e := engine
	var p := int(pending["seat"])
	_prompt("Ingaggio: metti all'asta un lotto", "Tocca un mercato sul tabellone e fai l'offerta di apertura (almeno 8). Puoi spendere fino a %d (monete + Aquile)." % e.budget(p))
	for m in pending["markets"]:
		hl.append({"pos": board2d.market_center(m), "r": 150.0, "kind": "market", "idx": m, "label": MNAME[m], "col": UI.GOLD_L})
	aux["bid"] = D.MIN_BID
	aux["m"] = -1
	var info := UI.label("Nessun lotto scelto", 20, UI.INK, UI.font_semi)
	act_box.add_child(info)
	aux["info"] = info
	var lot_row := HBoxContainer.new()
	act_box.add_child(lot_row)
	aux["lot"] = lot_row
	_bid_spinner(D.MIN_BID, e.budget(p))
	var h := _row()
	var b_go := UI.primary(UI.button("Apri l'asta", 200, 48, 20))
	b_go.pressed.connect(func():
		if int(aux["m"]) < 0:
			status_lbl.text = "Scegli prima un lotto sul tabellone."
			return
		_submit({"m": int(aux["m"]), "bid": int(aux["bid"])}))
	h.add_child(b_go)
	var b_pass := UI.button("Passa", 120, 48, 20)
	b_pass.pressed.connect(func(): _submit({"pass": true}))
	h.add_child(b_pass)
	_ai_button(h)


func _select_market(m: int) -> void:
	aux["m"] = m
	(aux["info"] as Label).text = "Lotto %s:" % MNAME[m]
	var row: HBoxContainer = aux["lot"]
	for c in row.get_children():
		c.queue_free()
	for t in engine.markets[m]:
		var chip := _tile_chip(t, 1, 54)
		row.add_child(chip)
	for h in hl:
		h["col"] = UI.GOLD_L if h["idx"] != m else UI.GREEN
	board3d.refresh_hl()


func _bid_spinner(lo: int, hi: int) -> void:
	var h := _row()
	h.add_child(UI.label("Offerta:", 21, UI.INK, UI.font_semi))
	var val := UI.label(str(aux["bid"]), 30, UI.TERRA_D, UI.font_head)
	val.custom_minimum_size.x = 60
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for d in [-5, -1]:
		var b := UI.button(str(d), 56, 44, 19)
		var k: int = d
		b.pressed.connect(func():
			aux["bid"] = clampi(int(aux["bid"]) + k, lo, hi)
			val.text = str(aux["bid"]))
		h.add_child(b)
	h.add_child(val)
	for d in [1, 5]:
		var b := UI.button("+%d" % d, 56, 44, 19)
		var k: int = d
		b.pressed.connect(func():
			aux["bid"] = clampi(int(aux["bid"]) + k, lo, hi)
			val.text = str(aux["bid"]))
		h.add_child(b)


func _d_bid() -> void:
	var e := engine
	var p := int(pending["seat"])
	var m := int(pending["m"])
	var high := int(pending["high"])
	_prompt("Asta del lotto %s" % MNAME[m], "Offerta più alta: %d di %s. Puoi spendere fino a %d (monete + Aquile come credito)." % [high, e.pname(int(pending["by"])), e.budget(p)])
	var row := _row()
	for t in e.markets[m]:
		row.add_child(_tile_chip(t, 1, 54))
	hl.append({"pos": board2d.market_center(m), "r": 150.0, "kind": "none", "idx": m, "col": UI.GREEN})
	aux["bid"] = high + 1
	_bid_spinner(high + 1, e.budget(p))
	var h := _row()
	var b_go := UI.primary(UI.button("Rilancia", 180, 48, 20))
	b_go.pressed.connect(func(): _submit({"bid": int(aux["bid"])}))
	h.add_child(b_go)
	var b_pass := UI.button("Passa", 120, 48, 20)
	b_pass.pressed.connect(func(): _submit({"pass": true}))
	h.add_child(b_pass)
	_ai_button(h)


# ---------------------------------------------------------------- scambi

func _d_trade() -> void:
	_prompt("Scambi: sei l'impresario attivo", "Proponi scambi di artisti, monete e Aquile a un altro impresario (al massimo %d proposte). Quando hai finito, chiudi il tuo turno." % CSEngine.MAX_OFFERS)
	var h := _row()
	var b1 := UI.primary(UI.button("Proponi uno scambio…", 280, 50, 20))
	b1.pressed.connect(_trade_composer)
	h.add_child(b1)
	var b2 := UI.button("Fine degli scambi", 220, 50, 20)
	b2.pressed.connect(func(): _submit({"end": true}))
	h.add_child(b2)
	_ai_button(_row())


func _trade_composer() -> void:
	var e := engine
	var p := int(pending["seat"])
	var pop := _popup("Proposta di scambio", 1300)
	aux["to"] = -1
	aux["give"] = {}
	aux["get"] = {}
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 10)
	pop.add_child(hr)
	hr.add_child(UI.label("Con chi:", 22, UI.STONE, UI.font_semi))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	var give_box := VBoxContainer.new()
	var get_box := VBoxContainer.new()
	var summary := UI.label("", 21, UI.GOLD_L, UI.font_semi)
	var refresh_cols := func():
		for b in [give_box, get_box]:
			for c in b.get_children():
				c.queue_free()
		give_box.add_child(UI.heading("Dai", 24))
		get_box.add_child(UI.heading("Chiedi a %s" % (e.pname(int(aux["to"])) if aux["to"] >= 0 else "…"), 24))
		_trade_side(give_box, p, aux["give"], summary)
		if aux["to"] >= 0:
			_trade_side(get_box, int(aux["to"]), aux["get"], summary)
		_trade_summary(summary)
	for q in e.order_from((p + 1) % e.n):
		if q == p:
			continue
		var b := UI.button(e.pname(q), 0, 46, 20)
		b.add_theme_color_override("font_color", UI.pcolor(e, q))
		var k: int = q
		b.pressed.connect(func():
			aux["to"] = k
			aux["get"] = {}
			refresh_cols.call())
		hr.add_child(b)
	pop.add_child(cols)
	give_box.custom_minimum_size.x = 600
	get_box.custom_minimum_size.x = 600
	cols.add_child(give_box)
	cols.add_child(get_box)
	pop.add_child(summary)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pop.add_child(h)
	var b_ok := UI.primary(UI.button("Proponi", 220, 52, 22))
	b_ok.pressed.connect(func():
		var o := {"to": int(aux["to"]), "give": _clean(aux["give"]), "get": _clean(aux["get"])}
		if not engine.valid_offer(p, o):
			summary.text = "Scegli con chi e cosa scambiare."
			return
		_submit(o))
	h.add_child(b_ok)
	var b_no := UI.button("Annulla", 160, 52, 20)
	b_no.pressed.connect(_close_popup)
	h.add_child(b_no)
	refresh_cols.call()


func _clean(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if int(d[k]) > 0:
			out[k] = int(d[k])
	return out


## una colonna dello scambio: le tessere e le monete di q, con i contatori
func _trade_side(box: VBoxContainer, q: int, sel: Dictionary, summary: Label) -> void:
	var e := engine
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	var items := []
	for t in D.TYPES + [D.WILD]:
		if int(e.ps[q]["tiles"].get(t, 0)) > 0:
			items.append([t, int(e.ps[q]["tiles"][t])])
	items.append(["coins", int(e.ps[q]["coins"])])
	items.append(["aquila", int(e.ps[q]["aquila"])])
	for it in items:
		var k: String = it[0]
		var mx: int = it[1]
		if mx <= 0:
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		if k == "coins":
			h.add_child(UI.icon_rect(UI.tex("res://assets/monete/m5.png"), Vector2(34, 34)))
		elif k == "aquila":
			h.add_child(UI.icon_rect(UI.tex("res://assets/segnalini/aquila.png"), Vector2(34, 34)))
		else:
			h.add_child(UI.icon_rect(UI.tile_tex(k), Vector2(34, 34)))
		var nl := UI.label("%d" % int(sel.get(k, 0)), 22, UI.GOLD_L, UI.font_head)
		nl.custom_minimum_size.x = 34
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bm := UI.button("−", 40, 38, 20)
		var bp := UI.button("+", 40, 38, 20)
		var step := 1
		bm.pressed.connect(func():
			sel[k] = maxi(0, int(sel.get(k, 0)) - step)
			nl.text = str(sel[k])
			_trade_summary(summary))
		bp.pressed.connect(func():
			sel[k] = mini(mx, int(sel.get(k, 0)) + step)
			nl.text = str(sel[k])
			_trade_summary(summary))
		h.add_child(bm)
		h.add_child(nl)
		h.add_child(bp)
		var nm: String = "monete" if k == "coins" else ("Aquile" if k == "aquila" else D.TYPE_NAME[k])
		h.add_child(UI.label("%s (%d)" % [nm, mx], 18, UI.MUTED, UI.font_semi))
		grid.add_child(h)


func _trade_summary(l: Label) -> void:
	var e := engine
	if aux.get("to", -1) < 0:
		l.text = "Scegli l'impresario con cui trattare."
		return
	l.text = "Dai: %s  ·  ricevi: %s" % [e.items_text(_clean(aux["give"])), e.items_text(_clean(aux["get"]))]


func _d_trade_answer() -> void:
	var e := engine
	var fr := int(pending["from"])
	_prompt("%s ti propone uno scambio" % e.pname(fr), "Ricevi: %s.\nIn cambio dai: %s." % [e.items_text(pending["give"]), e.items_text(pending["get"])])
	var h := _row()
	var b1 := UI.primary(UI.button("Accetta", 180, 50, 21))
	b1.pressed.connect(func(): _submit({"ok": true}))
	h.add_child(b1)
	var b2 := UI.button("Rifiuta", 160, 50, 21)
	b2.pressed.connect(func(): _submit({"ok": false}))
	h.add_child(b2)
	_ai_button(h)


# ---------------------------------------------------------------- nobili

func _d_nobles() -> void:
	var d: Array = pending["dice"]
	var temple: bool = pending["temple"]
	aux["plans"] = _all_plans(d, temple)
	aux["chosen"] = []
	aux["sel"] = -1
	_nobles_ui()


## tutti i piani validi senza togliere i doppioni (servono le sequenze di mosse)
func _all_plans(d: Array, temple: bool) -> Array:
	var out := []
	var tot := int(d[0]) + int(d[1])
	for i in 6:
		if temple:
			for s in range(2, tot + 1):
				out.append([[i, s]])
		else:
			out.append([[i, tot]])
	var pairs := []
	if temple:
		for x in range(1, int(d[0]) + 1):
			for y in range(1, int(d[1]) + 1):
				pairs.append([x, y])
				pairs.append([y, x])
	else:
		pairs.append([int(d[0]), int(d[1])])
		pairs.append([int(d[1]), int(d[0])])
	for i in 6:
		for j in 6:
			if i != j:
				for pr in pairs:
					out.append([[i, pr[0]], [j, pr[1]]])
	return out


func _nobles_ui() -> void:
	var e := engine
	var p := int(pending["seat"])
	var d: Array = pending["dice"]
	var temple: bool = pending["temple"]
	var chosen: Array = aux["chosen"]
	var sub := "Muovi un nobile del risultato di un dado e un altro nobile dell'altro, oppure un solo nobile della somma. Le caselle occupate si saltano."
	if temple:
		sub = "Con il Tempio della Fortuna ogni dado vale da 1 al numero uscito (un solo nobile: da 2 alla somma). Le caselle occupate si saltano."
	_prompt("I nobili si muovono", sub)
	var dr := _row()
	for v in d:
		dr.add_child(DieFace.new(int(v)))
	var pos: Array = e.apply_moves(chosen)
	var bonus := e.noble_bonus(p, pos)
	dr.add_child(UI.label("  Nobili ai tuoi cancelli: +%d" % bonus, 21, UI.TERRA_D, UI.font_head))
	for mv in chosen:
		act_box.add_child(UI.label("• %s: %d passi" % [D.NOBLE_CAP[int(mv[0])], int(mv[1])], 19, UI.INK, UI.font_semi))
	var complete := false
	for pl in aux["plans"]:
		if pl.size() == chosen.size() and _prefix(pl, chosen):
			complete = true
	var more := false
	for pl in aux["plans"]:
		if pl.size() > chosen.size() and _prefix(pl, chosen):
			more = true
	hl = []
	var sel := int(aux["sel"])
	if sel < 0 and more:
		# nobili che si possono muovere ora
		var ok := {}
		for pl in aux["plans"]:
			if pl.size() > chosen.size() and _prefix(pl, chosen):
				ok[int(pl[chosen.size()][0])] = true
		for i in ok:
			hl.append({"pos": board2d.noble_px(int(pos[i])), "r": 58.0, "kind": "noble", "idx": i, "col": UI.GOLD_L})
		status_lbl.text = "Tocca il nobile da muovere." if chosen.is_empty() else "Tocca il secondo nobile, oppure conferma."
	elif sel >= 0:
		var dests := {}
		for pl in aux["plans"]:
			if pl.size() > chosen.size() and _prefix(pl, chosen) and int(pl[chosen.size()][0]) == sel:
				var s := int(pl[chosen.size()][1])
				var dst := e.noble_dest(sel, s, pos)
				if not dests.has(dst):
					dests[dst] = s
		for dst in dests:
			var np := pos.duplicate()
			np[sel] = dst
			var gain := e.noble_bonus(p, np) - e.noble_bonus(p, pos)
			hl.append({"pos": board2d.noble_px(int(dst)), "r": 50.0, "kind": "dest", "idx": int(dests[dst]),
				"label": "%d%s" % [int(dests[dst]), (" (+%d)" % gain) if gain > 0 else ""], "col": UI.GREEN if gain > 0 else UI.GOLD_L})
		hl.append({"pos": board2d.noble_px(int(pos[sel])), "r": 60.0, "kind": "noble", "idx": sel, "col": UI.TEAL_L})
		status_lbl.text = "Tocca la casella d'arrivo %s." % D.NOBLE_DI[sel]
	board3d.refresh_hl()
	var h := _row()
	var b_ok := UI.primary(UI.button("Conferma", 170, 48, 20))
	b_ok.disabled = not complete
	b_ok.pressed.connect(func(): _submit({"moves": aux["chosen"]}))
	h.add_child(b_ok)
	var b_undo := UI.button("Ricomincia", 160, 48, 20)
	b_undo.disabled = chosen.is_empty() and sel < 0
	b_undo.pressed.connect(func():
		aux["chosen"] = []
		aux["sel"] = -1
		_nobles_ui())
	h.add_child(b_undo)
	_ai_button(h)


func _prefix(pl: Array, chosen: Array) -> bool:
	for k in chosen.size():
		if int(pl[k][0]) != int(chosen[k][0]) or int(pl[k][1]) != int(chosen[k][1]):
			return false
	return true


func _d_aquila() -> void:
	var e := engine
	var p := int(pending["seat"])
	aux["sel"] = -1
	_prompt("Vuoi spendere un'Aquila?", "Hai %d Aquil%s: ognuna sposta un nobile fino a 3 caselle, anche all'indietro (non dà Aquile). Nobili ai tuoi cancelli ora: +%d." % [e.ps[p]["aquila"], "a" if e.ps[p]["aquila"] == 1 else "e", e.noble_bonus(p)])
	hl = []
	for i in 6:
		hl.append({"pos": board2d.noble_px(int(e.nobles[i])), "r": 58.0, "kind": "anoble", "idx": i, "col": UI.TEAL_L})
	var h := _row()
	var b := UI.primary(UI.button("Non spendere", 200, 48, 20))
	b.pressed.connect(func(): _submit({"done": true}))
	h.add_child(b)
	_ai_button(h)
	status_lbl.text = "Tocca un nobile per spostarlo con un'Aquila, oppure prosegui."


func _aquila_dests(i: int) -> void:
	var e := engine
	var p := int(pending["seat"])
	aux["sel"] = i
	hl = []
	for s in [-3, -2, -1, 1, 2, 3]:
		var dst := e.noble_dest(i, s)
		var np := e.nobles.duplicate()
		np[i] = dst
		var gain := e.noble_bonus(p, np) - e.noble_bonus(p)
		hl.append({"pos": board2d.noble_px(dst), "r": 50.0, "kind": "adest", "idx": s,
			"label": ("%+d" % s) + ((" (+%d)" % gain) if gain > 0 else ""), "col": UI.GREEN if gain > 0 else UI.GOLD_L})
	hl.append({"pos": board2d.noble_px(int(e.nobles[i])), "r": 60.0, "kind": "anoble", "idx": i, "col": UI.TEAL_L})
	board3d.refresh_hl()
	status_lbl.text = "Tocca la casella d'arrivo (fino a 3 passi avanti o indietro)."


# ---------------------------------------------------------------- spettacolo

func _d_perform() -> void:
	var e := engine
	var p := int(pending["seat"])
	_prompt("Metti in scena uno spettacolo", "Scegli una tessera qui o in basso. Nobili ai tuoi cancelli: +%d." % e.noble_bonus(p))
	aux["aq"] = 0
	var opts: Dictionary = pending["options"]
	var best := ""
	var bv := -1
	for id in opts:
		if int(opts[id]["total"]) > bv:
			bv = int(opts[id]["total"])
			best = id
	aux["id"] = best
	var lst := VBoxContainer.new()
	lst.add_theme_constant_override("separation", 4)
	act_box.add_child(lst)
	aux["list"] = lst
	if e.ps[p]["aquila"] > 0:
		var h := _row()
		h.add_child(UI.label("Aquile da spendere (+3 l'una):", 19, UI.INK, UI.font_semi))
		var val := UI.label("0", 26, UI.TERRA_D, UI.font_head)
		var bm := UI.button("−", 44, 40, 20)
		var bp := UI.button("+", 44, 40, 20)
		bm.pressed.connect(func():
			aux["aq"] = maxi(0, int(aux["aq"]) - 1)
			val.text = str(aux["aq"])
			_perform_list())
		bp.pressed.connect(func():
			aux["aq"] = mini(int(e.ps[p]["aquila"]), int(aux["aq"]) + 1)
			val.text = str(aux["aq"])
			_perform_list())
		h.add_child(bm)
		h.add_child(val)
		h.add_child(bp)
	var h2 := _row()
	var b_ok := UI.primary(UI.button("Metti in scena", 220, 50, 21))
	b_ok.pressed.connect(func(): _submit({"id": aux["id"], "aq": int(aux["aq"])}))
	h2.add_child(b_ok)
	var b_no := UI.button("Non esibirti", 160, 50, 19)
	b_no.pressed.connect(func(): _submit({"id": "", "aq": 0}))
	h2.add_child(b_no)
	_ai_button(h2)
	_perform_list()


func _perform_list() -> void:
	var lst: VBoxContainer = aux["list"]
	for c in lst.get_children():
		c.queue_free()
	var opts: Dictionary = pending["options"]
	for id in opts:
		var sc: Dictionary = opts[id]
		var tot := int(sc["total"]) + 3 * int(aux["aq"])
		var parts := ["spettacolo %d%s" % [sc["base"], (" (mancano %d)" % sc["missing"]) if sc["missing"] > 0 else ""]]
		for k in [["prev", "repliche"], ["stars", "stelle"], ["nobles", "nobili"], ["promoters", "promotori"], ["gifts", "doni"]]:
			if int(sc[k[0]]) > 0:
				parts.append("%s %d" % [k[1], sc[k[0]]])
		var b := UI.button("%s — %d   (%s)" % [D.spect(id)["name"], tot, ", ".join(parts)], PANEL_W - 60, 44, 17)
		b.toggle_mode = true
		b.button_pressed = id == aux["id"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var k: String = id
		b.pressed.connect(func():
			aux["id"] = k
			_perform_list())
		lst.add_child(b)
	_build_hand_choose()


## nella fase di esibizione le tessere in basso si possono toccare per sceglierle
func _build_hand_choose() -> void:
	pass


# ---------------------------------------------------------------- chiusura

func _d_pick_tile(t: String, sub: String, options: Array) -> void:
	_prompt(t, sub)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	act_box.add_child(flow)
	for o in options:
		var b := Button.new()
		b.icon = UI.tile_tex(o)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(76, 76)
		b.tooltip_text = D.TYPE_ONE[o]
		var k: String = o
		b.pressed.connect(func(): _submit({"t": k}))
		flow.add_child(b)
	_ai_button(_row())


func _d_first() -> void:
	var e := engine
	_prompt("Scegli il primo giocatore della prossima giornata", "Come impresario meno acclamato decidi chi comincia (anche te stesso).")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	act_box.add_child(flow)
	for q in e.n:
		var b := UI.button(e.pname(q), 0, 46, 20)
		b.add_theme_color_override("font_color", UI.pcolor(e, q))
		var k: int = q
		b.pressed.connect(func(): _submit({"p": k}))
		flow.add_child(b)


# ================================================================ tabellone: clic e passaggio del mouse

func on_board_click(px: Vector2) -> void:
	var best := {}
	var bd := 1e9
	for h in hl:
		var d: float = (h["pos"] as Vector2).distance_to(px)
		if d <= float(h.get("r", 50.0)) * 1.25 and d < bd:
			bd = d
			best = h
	if best.is_empty() or pending.is_empty():
		return
	match best["kind"]:
		"pair":
			_submit({"pair": best["data"]})
		"gate":
			if mode == "gate":
				_submit({"k": "gate", "space": int(best["idx"])})
		"market":
			_select_market(int(best["idx"]))
		"noble":
			aux["sel"] = int(best["idx"]) if int(aux.get("sel", -1)) != int(best["idx"]) else -1
			_nobles_ui()
		"dest":
			var ch: Array = aux["chosen"]
			ch.append([int(aux["sel"]), int(best["idx"])])
			aux["sel"] = -1
			_nobles_ui()
			# se non resta altro da muovere conferma subito
			var more := false
			for pl in aux["plans"]:
				if pl.size() > ch.size() and _prefix(pl, ch):
					more = true
			if not more:
				_submit({"moves": ch})
		"anoble":
			_aquila_dests(int(best["idx"]))
		"adest":
			_submit({"done": false, "noble": int(aux["sel"]), "steps": int(best["idx"])})


func on_board_hover(px: Vector2, screen: Vector2) -> void:
	var e := engine
	var t := ""
	var bd := 60.0
	for i in 6:
		var d: float = board2d.noble_px(int(e.nobles[i])).distance_to(px)
		if d < bd:
			bd = d
			var g: int = e.gate_owner.get(int(e.nobles[i]), -1)
			t = "%s (+%d)%s" % [D.NOBLE_CAP[i], D.NOBLE_BONUS[i], (" al cancello di %s" % e.pname(g)) if g >= 0 else ""]
	if t == "":
		for g in e.gate_owner:
			if board2d.gate_px(int(g)).distance_to(px) < 50.0:
				t = "Cancello di %s" % e.pname(int(e.gate_owner[g]))
	if t == "":
		for m in 5:
			if board2d.market_center(m).distance_to(px) < 130.0 and not e.markets[m].is_empty():
				t = "Lotto %s: %s" % [MNAME[m], e._lot_text(e.markets[m])]
	if t == "":
		for i in e.layout.get("noble", []).size():
			if board2d.noble_px(i).distance_to(px) < 45.0 and e.is_aquila_space(i):
				t = "Casella dell'Aquila: chi vi porta un nobile con i dadi prende un'Aquila"
	if t == "":
		tip.visible = false
		return
	tip.text = t
	tip.visible = true
	tip.reset_size()
	var p := screen - global_position + Vector2(18, 18)
	p.x = minf(p.x, size.x - tip.size.x - 8)
	tip.position = p


# ================================================================ finestre

var popup: Control


func _popup(title: String, w := 1200.0) -> VBoxContainer:
	_close_popup()
	popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 20
	add_child(popup)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_popup())
	popup.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.dark_style(10, 0.98))
	box.custom_minimum_size = Vector2(w, 0)
	popup.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)
	var hr := HBoxContainer.new()
	vb.add_child(hr)
	var tl := UI.title(title, 36)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	var bx := UI.button("Chiudi", 120, 44, 19)
	bx.pressed.connect(_close_popup)
	hr.add_child(bx)
	_center_popup.call_deferred(box)
	return vb


func _center_popup(box: Control) -> void:
	if not is_instance_valid(box):
		return
	await get_tree().process_frame
	if is_instance_valid(box):
		var k := minf(1.0, minf((size.x - 40) / box.size.x, (size.y - 40) / box.size.y))
		box.scale = Vector2(k, k)
		box.position = (size - box.size * k) * 0.5


func _close_popup() -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = null


func _player_popup(p: int) -> void:
	var e := engine
	var st: Dictionary = e.ps[p]
	var vb := _popup("Impresario %s" % e.pname(p), 1300)
	var t := "Acclamazione %d · %d monete · %d Aquile · %d promotori · %d doni · %d cancelli%s" % [st["acclaim"], st["coins"], st["aquila"],
		st["promoters"], st["gifts"], st["gates"].size(), " · Tempio della Fortuna" if st["temple"] >= 0 else ""]
	vb.add_child(UI.label(t, 21, UI.STONE, UI.font_semi))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	for k in D.TYPES + [D.WILD]:
		var c: int = st["tiles"].get(k, 0)
		if c > 0:
			row.add_child(_tile_chip(k, c, 56))
	vb.add_child(row)
	if not e.stars_of(p).is_empty():
		var sr := HBoxContainer.new()
		sr.add_child(UI.label("Stelle:", 20, UI.STONE, UI.font_semi))
		for k in e.stars_of(p):
			sr.add_child(UI.icon_rect(UI.star_tex(k), Vector2(48, 56)))
		vb.add_child(sr)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	var ids: Array = st["plan"].duplicate()
	if st["cur"] != "":
		ids.append(st["cur"])
	ids.append_array(st["done"])
	for id in ids:
		flow.add_child(_spect_card(p, id, 170.0))
	vb.add_child(flow)


func _show_rules_popup() -> void:
	var r := preload("res://scripts/ui/rules_view.gd").new()
	r.main = main
	r.popup = true
	add_child(r)


func _confirm_menu() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Abbandonare la partita e tornare al menu?"
	dlg.ok_button_text = "Sì"
	dlg.cancel_button_text = "Annulla"
	add_child(dlg)
	dlg.confirmed.connect(func():
		engine.abort = true
		if not pending.is_empty():
			engine.provide_decision(null)
		if online != null:
			online.alive = false
		main.show_menu())
	dlg.popup_centered()


# ================================================================ fine

func _on_end(res: Dictionary) -> void:
	ended = true
	_dirty = true
	if online != null:
		online.finish()
	var e := engine
	var vb := _popup("Il Gran Impresario", 1000)
	var rank: Array = res.get("rank", [])
	for k in rank.size():
		var p: int = rank[k]
		var st: Dictionary = e.ps[p]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		h.add_child(UI.label("%d°" % (k + 1), 34 if k == 0 else 26, UI.GOLD_L, UI.font_title))
		h.add_child(UI.icon_rect(UI.wreath_tex(e, p), Vector2(52, 52)))
		var nm: Label = UI.label(e.pname(p), 30 if k == 0 else 24, UI.pcolor(e, p), UI.font_head)
		nm.custom_minimum_size.x = 330
		h.add_child(nm)
		h.add_child(UI.label("%d di Acclamazione" % st["acclaim"], 28 if k == 0 else 23, UI.STONE, UI.font_head))
		var ns := e.stars_of(p).size()
		h.add_child(UI.label("%d monete · %d stell%s · %d spettacoli" % [st["coins"], ns, "a" if ns == 1 else "e", st["done"].size()], 19, UI.MUTED, UI.font_semi))
		vb.add_child(h)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	var b1 := UI.primary(UI.button("Rivincita", 220, 56, 22))
	b1.pressed.connect(func():
		var cfg := config.duplicate()
		cfg.erase("seed")
		cfg.erase("online")
		main.start_game(cfg))
	b1.visible = online == null
	hb.add_child(b1)
	var b2 := UI.button("Menu", 160, 56, 22)
	b2.pressed.connect(func(): main.show_menu())
	hb.add_child(b2)
	var b3 := UI.button("Guarda il tabellone", 260, 56, 20)
	b3.pressed.connect(_close_popup)
	hb.add_child(b3)


# ================================================================ online

func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		status_lbl.text = ""
	else:
		status_lbl.text = "Aspetto %s…%s" % [engine.pname(s), " (lento)" if slow else ""]


func online_status(t: String) -> void:
	status_lbl.text = t


func online_cancel_decision(t: String) -> void:
	pending = {}
	hl = []
	_clear_box()
	_close_popup()
	status_lbl.text = t
	_dirty = true


func online_caught_up() -> void:
	status_lbl.text = "Partita ripresa."


## un dado disegnato con i suoi pallini
class DieFace extends Control:
	var v := 1

	func _init(val: int) -> void:
		v = val
		custom_minimum_size = Vector2(52, 52)

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(r, Color("#f6efe0"))
		draw_rect(r, Color("#7a2f1a"), false, 3.0)
		var c := size * 0.5
		var o := size.x * 0.26
		var pts := {1: [Vector2.ZERO], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)],
			4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
			5: [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)],
			6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
		for p in pts.get(v, []):
			draw_circle(c + p * o, size.x * 0.085, Color("#9c2a17"))
