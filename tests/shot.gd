extends SceneTree
## Fotografie dell'interfaccia (serve un display, anche virtuale: xvfb-run).
## Uso: xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s tests/shot.gd -- <cartella> [giocatori] [3d]
## La persona (Rosso) lascia decidere all'IA; si fotografano le varie fasi.

var out := "/tmp/shots"
var taken := {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var np := int(args[1]) if args.size() > 1 else 4
	var v3 := args.size() > 2 and args[2] == "3d"
	DirAccess.make_dir_recursive_absolute(out)
	_run(np, v3)


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _run(np: int, v3: bool) -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	await _snap("menu")
	var seats := []
	for i in np:
		seats.append({"name": "Stefano" if i == 0 else "", "ai": i != 0, "level": 1, "color": i})
	main.start_game({"seats": seats, "ai_delay": 0.0, "anim": 3.0, "view3d": v3, "seed": 7})
	var g = main.current
	await create_timer(1.5).timeout
	var guard := 0
	while guard < 400:
		guard += 1
		if g.engine.phase == "over":
			break
		var req: Dictionary = g.pending
		if req.is_empty():
			await create_timer(0.3).timeout
			continue
		var t: String = req["type"]
		var key := "%s_%d" % [t, g.engine.round_n]
		if not taken.has(t) or (t in ["invest", "nobles", "perform"] and not taken.has(key)):
			taken[t] = true
			taken[key] = true
			if t == "invest" and g.engine.round_n == 1:
				g._gallery(true)
				await create_timer(0.4).timeout
				await _snap("galleria")
				g._close_popup()
			if t == "trade":
				g._trade_composer()
				g.aux["to"] = 1
				await create_timer(0.3).timeout
				await _snap("scambio")
				g._close_popup()
			if t == "auction":
				g._select_market(req["markets"][0])
			if t == "nobles":
				var pl = g.aux["plans"][0]
				g.aux["sel"] = int(pl[0][0])
				g._nobles_ui()
			await create_timer(0.4).timeout
			await _snap("%s_g%d" % [t, g.engine.round_n])
			if g.engine.round_n == 2 and t == "perform":
				g.view3d = not g.view3d
				g._apply_view()
				await create_timer(0.8).timeout
				await _snap("altra_vista")
				g.view3d = not g.view3d
				g._apply_view()
		var r = g.engine.ais[0].decide(g.engine, 0, req)
		g._submit(r)
		await create_timer(0.25).timeout
	await create_timer(1.0).timeout
	await _snap("fine")
	g._close_popup()
	g._player_popup(0)
	await create_timer(0.4).timeout
	await _snap("impresario")
	quit()
