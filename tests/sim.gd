extends SceneTree
## Partite simulate fra IA, senza grafica: controlla che le regole reggano e misura punteggi e durata.
## Uso: godot --headless --path . -s tests/sim.gd -- [giocatori 3-5] [partite] [livello]
## CS_LOG=1 stampa il diario della prima partita.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var np := int(args[0]) if args.size() > 0 else 4
	var games := int(args[1]) if args.size() > 1 else 4
	var lv := int(args[2]) if args.size() > 2 else 1
	_run(np, games, lv)


func _run(np: int, games: int, lv: int) -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var wins := {}
	var tot := 0.0
	for g in games:
		var eng := CSEngine.new()
		eng.headless = true
		root.add_child(eng)
		var seats := []
		for i in np:
			var l := lv if lv >= 0 else i % 3
			seats.append({"name": "IA%d-L%d" % [i, l], "ai": true, "level": l, "color": i})
		eng.setup({"seats": seats, "seed": 1000 + g})
		for i in np:
			eng.ais[i] = CSAI.new(int(seats[i]["level"]), 50 + g * 7 + i)
		if OS.get_environment("CS_LOG") == "1" and g == 0:
			eng.log_added.connect(func(t): print(t))
		await eng.run()
		var w: int = eng.result.get("winner", -9)
		wins[seats[w]["name"]] = wins.get(seats[w]["name"], 0) + 1
		var line := []
		for p in np:
			var st: Dictionary = eng.ps[p]
			line.append("%d(m%d g%d pr%d sp%d/%d)" % [st["acclaim"], st["coins"], st["gates"].size(), st["promoters"], st["done"].size(), st["plan"].size()])
			tot += st["acclaim"]
		print("  partita %d: vince %s — %s" % [g, seats[w]["name"], "  ".join(line)])
		eng.queue_free()
	print("Vittorie %s, Acclamazione media %.1f, %d ms" % [wins, tot / (games * np), Time.get_ticks_msec() - t0])
	quit()
