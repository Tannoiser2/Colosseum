extends SceneTree
## Fotografie del tabellone 3D da vicino (serve un display, anche virtuale: xvfb-run).
## Uso: xvfb-run godot --path . -s tests/shot3d.gd -- <cartella>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/shots3d"
	DirAccess.make_dir_recursive_absolute(out)
	_run(out)


func _snap(out: String, name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _run(out: String) -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	var seats := []
	for i in 4:
		seats.append({"name": "", "ai": i != 0, "level": 1, "color": i})
	main.start_game({"seats": seats, "ai_delay": 0.0, "anim": 0.0, "view3d": true, "seed": 11})
	var g = main.current
	await create_timer(0.5).timeout
	while not (g.engine.round_n == 2 and g.engine.phase == "hire"):
		var req: Dictionary = g.pending
		if not req.is_empty():
			g._submit(g.engine.ais[0].decide(g.engine, 0, req))
		await process_frame
	await create_timer(0.5).timeout
	await _snap(out, "panoramica")
	var b = g.board3d
	for v in [[0.0, 0.7, 7.0, Vector3(0, 0, -1.5)], [0.9, 0.55, 6.0, Vector3(2.5, 0, 0)], [-2.2, 0.5, 6.0, Vector3(-2, 0, 1.5)], [3.1, 0.45, 5.5, Vector3(0, 0, 2.5)]]:
		b.yaw = v[0]
		b.pitch = v[1]
		b.dist = v[2]
		b.target = v[3]
		b._update_cam()
		await create_timer(0.4).timeout
		await _snap(out, "vista_%d" % int(v[0] * 10))
	quit()
