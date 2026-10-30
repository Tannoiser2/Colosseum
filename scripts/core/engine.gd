class_name CSEngine
extends Node
## Motore delle regole di Colosseum: The Grand Spectacle (senza grafica).
## Ogni scelta passa da `decide()`: l'IA risponde subito; per le persone viene emesso `decision_requested`
## e si attende `provide_decision()`. Online le scelte viaggiano nel registro di mosse (OnlineSession):
## con lo stesso seme ogni dispositivo gioca la stessa partita.
##
## Richieste (req["type"]) e risposte:
##  - "start_gates": {"pairs": [[a, b], …]}                → {"pair": [a, b]}
##  - "invest":      {"left": n, "done": [tipi già fatti]} → {"k": "gate", "space": s} | {"k": "promoter"} |
##                                                            {"k": "temple"} | {"k": "spect", "id": id} | {"k": "pass"}
##  - "auction":     apertura di un'asta                    → {"m": mercato, "bid": n} | {"pass": true}
##  - "bid":         {"m", "high", "by"}                    → {"bid": n} | {"pass": true}
##  - "trade":       proposta del giocatore attivo           → {"to": p, "give": {…}, "get": {…}} | {"end": true}
##  - "trade_answer": {"from", "give", "get"}               → {"ok": bool}
##  - "nobles":      {"dice": [d1, d2], "temple": bool}     → {"moves": [[nobile, passi], …]}
##  - "aquila_move": un'Aquila per spostare un nobile        → {"noble": n, "steps": ±1..3} | {"done": true}
##  - "perform":     {"options": {id: punteggio}}           → {"id": id o "", "aq": aquile spese}
##  - "retire":      {"options": [tipi]}                     → {"t": tipo}
##  - "steal":       {"from": p, "options": [tipi]}          → {"t": tipo}
##  - "first":       scelta del primo giocatore             → {"p": giocatore}
## Le offerte di scambio contano tessere per tipo più "coins" e "aquila".

const D = preload("res://scripts/data/cs_data.gd")

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(result: Dictionary)
signal fx(kind: String, data: Dictionary)

var players: Array = []          # [{name, ai, level, color}]
var ais: Array = []
var online = null
var ai_delay := 0.6
var anim := 1.0
var headless := false
var abort := false
var rng := RandomNumberGenerator.new()
var n := 0

var ps: Array = []               # stato dei giocatori
var stars := {}                  # tipo -> giocatore (-1 sul tabellone)
var bag: Array = []
var markets: Array = []          # 5 mercati da 3 tessere
var display: Array = []          # spettacoli medi e grandi in vendita
var nobles: Array = []           # posizione dei 6 nobili sul tracciato (0-35)
var gate_owner := {}             # casella -> giocatore
var temple_spots := {}           # piazzola -> giocatore
var gifts_left := D.GIFTS
var round_n := 0
var phase := ""                  # "setup", "invest", "hire", "trade", "perform", "closing", "over"
var first := 0
var current := -1
var active := -1
var mercury := -1                # mercato dell'asta in corso (-1 = al centro)
var pillar_at := {}              # mercato -> giocatore che vi ha posato il pilastro
var high_bid := 0
var high_by := -1
var dice: Array = []
var seq := 0
var over := false
var result := {}
var log_lines: Array = []
var layout := {}
var history: Array = []          # istantanee per il riepilogo finale


# ================================================================ preparazione

func setup(cfg: Dictionary) -> void:
	players = cfg.get("seats", [])
	n = players.size()
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	ai_delay = float(cfg.get("ai_delay", 0.6))
	anim = float(cfg.get("anim", 1.0))
	var f := FileAccess.open("res://data/layout.json", FileAccess.READ)
	if f != null:
		layout = JSON.parse_string(f.get_as_text())
	ais.resize(n)
	ps.clear()
	for i in n:
		var t := {}
		for k in D.TYPES:
			t[k] = 0
		t[D.WILD] = 0
		ps.append({"coins": D.START_COINS, "aquila": 0, "tiles": t, "promoters": 0, "gates": [], "temple": -1,
			"pillar": true, "plan": [], "done": [], "cur": "", "used": {}, "acclaim": 0, "aseq": i - n,
			"gifts": 0, "stolen": 0, "last": 0})
	for k in D.TYPES:
		stars[k] = -1
	nobles = D.NOBLE_START.duplicate()
	for s in D.SPECTACLES:
		if s["size"] > 0:
			display.append(s["id"])
	for m in 5:
		markets.append([])


func pname(p: int) -> String:
	if p < 0 or p >= n:
		return "nessuno"
	var nm: String = str(players[p].get("name", ""))
	return nm if nm != "" else D.COLORS[pcol(p)]["name"]


func pcol(p: int) -> int:
	return int(players[p].get("color", p))


func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


func _pace(sec: float) -> void:
	if headless or anim <= 0.0 or abort or not is_inside_tree():
		return
	if online != null and online.catchup:
		return
	await get_tree().create_timer(sec / anim).timeout


# ================================================================ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	current = seat
	changed.emit()
	if abort:
		return ais[seat].decide(self, seat, req)
	var r
	if online != null:
		r = await online.decide(self, seat, req)
	elif players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay * (0.5 if req["type"] in ["bid", "trade_answer"] else 1.0)).timeout
		r = ais[seat].decide(self, seat, req)
	else:
		decision_requested.emit(req)
		r = await decision_provided
	if r == null:
		r = ais[seat].decide(self, seat, req)
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


# ================================================================ utilità

func order_from(p: int) -> Array:
	var out := []
	for i in n:
		out.append((p + i) % n)
	return out


func budget(p: int) -> int:
	return int(ps[p]["coins"]) + D.AQUILA_COINS * int(ps[p]["aquila"])


## paga con le monete; se non bastano converte le Aquile (6 monete l'una)
func pay(p: int, amount: int) -> void:
	var st: Dictionary = ps[p]
	while st["coins"] < amount and st["aquila"] > 0:
		st["aquila"] -= 1
		st["coins"] += D.AQUILA_COINS
		log_msg("%s spende un'Aquila per 6 monete." % pname(p))
	st["coins"] -= amount


func tile_count(p: int) -> int:
	var c := 0
	for k in ps[p]["tiles"]:
		c += int(ps[p]["tiles"][k])
	return c


func gates_of(p: int) -> int:
	return ps[p]["gates"].size()


func noble_at(pos: int) -> int:
	for i in 6:
		if nobles[i] == pos:
			return i
	return -1


## Destinazione di un nobile che si muove di `steps` caselle (positivi = senso orario): le caselle
## occupate da altri nobili si saltano e non contano.
func noble_dest(i: int, steps: int, pos_override := []) -> int:
	var pos: Array = pos_override if not pos_override.is_empty() else nobles
	var p: int = pos[i]
	var dir := 1 if steps > 0 else -1
	var left := absi(steps)
	var guard := 0
	while left > 0 and guard < 200:
		guard += 1
		p = posmod(p + dir, D.TRACK)
		var occ := false
		for j in 6:
			if j != i and pos[j] == p:
				occ = true
		if not occ:
			left -= 1
	return p


## percorso casella per casella (per le animazioni)
func noble_path(i: int, steps: int) -> Array:
	var out := [nobles[i]]
	var p: int = nobles[i]
	var dir := 1 if steps > 0 else -1
	var left := absi(steps)
	while left > 0:
		p = posmod(p + dir, D.TRACK)
		out.append(p)
		var occ := false
		for j in 6:
			if j != i and nobles[j] == p:
				occ = true
		if not occ:
			left -= 1
	return out


func is_aquila_space(pos: int) -> bool:
	return pos in layout.get("noble_aquila", [0, 6, 12, 18, 24, 30])


## bonus dei nobili ai cancelli del giocatore (con le posizioni indicate o quelle attuali)
func noble_bonus(p: int, pos: Array = []) -> int:
	var np: Array = pos if not pos.is_empty() else nobles
	var b := 0
	for i in 6:
		if gate_owner.get(int(np[i]), -1) == p:
			b += D.NOBLE_BONUS[i]
	return b


# ---------------------------------------------------------------- spettacoli

## Confronto fra artisti posseduti e richiesti: {matched, missing, used: {tipo: n}, ok, acclaim}
func evaluate(p: int, id: String, tiles: Dictionary = {}) -> Dictionary:
	var s := D.spect(id)
	var t: Dictionary = tiles if not tiles.is_empty() else ps[p]["tiles"]
	var used := {}
	var matched := 0
	var short := 0
	for k in s["req"]:
		var need: int = s["req"][k]
		var have: int = mini(need, int(t.get(k, 0)))
		if have > 0:
			used[k] = have
		matched += have
		short += need - have
	var wild: int = mini(short, int(t.get(D.WILD, 0)))
	if wild > 0:
		used[D.WILD] = wild
	matched += wild
	var missing := D.req_total(s) - matched
	var strip: Array = s["strip"]
	var slack: int = mini(strip.size(), D.SIZE_SLACK[s["size"]])
	var ok := matched >= 1 and missing <= slack
	var acc := 0
	if ok:
		acc = s["full"] if missing == 0 else int(strip[missing - 1])
	return {"matched": matched, "missing": missing, "used": used, "ok": ok, "acclaim": acc}


func can_perform(p: int, id: String) -> bool:
	var s := D.spect(id)
	if gates_of(p) < D.SIZE_GATES[s["size"]]:
		return false
	return evaluate(p, id)["ok"]


## Punteggio completo dell'esibizione (senza le Aquile spese): {base, prev, stars, nobles, promoters, gifts, total}
func score(p: int, id: String, pos: Array = [], tiles: Dictionary = {}) -> Dictionary:
	var st: Dictionary = ps[p]
	var s := D.spect(id)
	var ev := evaluate(p, id, tiles)
	var prev := 0
	for d in st["done"]:
		if d != id:
			prev += 5
	var sb := 0
	for k in s["req"]:
		if stars.get(k, -1) == p:
			sb += 4
	var nb := noble_bonus(p, pos)
	var out := {"base": ev["acclaim"], "missing": ev["missing"], "prev": prev, "stars": sb, "nobles": nb,
		"promoters": 5 * int(st["promoters"]), "gifts": 3 * int(st["gifts"]), "ok": ev["ok"]}
	out["total"] = out["base"] + prev + sb + nb + out["promoters"] + out["gifts"]
	return out


func all_spects(p: int) -> Array:
	var out: Array = ps[p]["plan"].duplicate()
	for d in ps[p]["done"]:
		if not d in out:
			out.append(d)
	return out


# ---------------------------------------------------------------- tessere e Stelle

func add_tile(p: int, t: String, k := 1) -> void:
	if t == D.AQUILA:
		ps[p]["aquila"] += k
		return
	ps[p]["tiles"][t] = int(ps[p]["tiles"].get(t, 0)) + k


func remove_tile(p: int, t: String, k := 1) -> void:
	ps[p]["tiles"][t] = maxi(0, int(ps[p]["tiles"].get(t, 0)) - k)


## Aggiorna le Stelle: chi ha almeno 3 tessere di un tipo e più di tutti gli altri prende la Stella.
## La si perde quando un altro ne ha di più (va a lui se è l'unico in testa, altrimenti torna sul tabellone)
## o quando se ne hanno 2 o meno.
func update_stars() -> void:
	for t in D.TYPES:
		var best := -1
		var best_n := -1
		var tie := false
		for p in n:
			var c: int = ps[p]["tiles"][t]
			if c > best_n:
				best_n = c
				best = p
				tie = false
			elif c == best_n:
				tie = true
		var h: int = stars[t]
		var nh := h
		if not tie and best_n >= 3:
			nh = best
		elif h >= 0:
			var hc: int = ps[h]["tiles"][t]
			if best_n > hc or hc <= 2:
				nh = -1
		if nh != h:
			stars[t] = nh
			if nh >= 0:
				log_msg("%s ottiene la Stella %s." % [pname(nh), D.TYPE_STAR[t]])
			else:
				log_msg("La Stella %s torna sul tabellone." % D.TYPE_STAR[t])
			fx.emit("star", {"t": t, "p": nh})


func stars_of(p: int) -> Array:
	var out := []
	for t in D.TYPES:
		if stars[t] == p:
			out.append(t)
	return out


func draw_tile() -> String:
	if bag.is_empty():
		return ""
	var i := rng.randi_range(0, bag.size() - 1)
	var t: String = bag[i]
	bag.remove_at(i)
	return t


func refill_markets() -> void:
	for m in 5:
		if markets[m].is_empty():
			for k in 3:
				var t := draw_tile()
				if t != "":
					markets[m].append(t)
	fx.emit("markets", {})


func market_ready(m: int) -> bool:
	return markets[m].size() == 3


# ================================================================ partita

func run() -> void:
	phase = "setup"
	await _setup_game()
	if abort:
		return
	while not over and not abort:
		round_n += 1
		log_msg("— Giornata %d di %d —" % [round_n, D.ROUNDS])
		_snap("round")
		await _phase_invest()
		if abort:
			return
		await _phase_hire()
		if abort:
			return
		await _phase_trade()
		if abort:
			return
		await _phase_perform()
		if abort or over:
			break
		await _phase_closing()
	if abort:
		return
	phase = "over"
	_snap("end")
	changed.emit()
	game_ended.emit(result)


func _snap(kind: String) -> void:
	var acc := []
	for p in n:
		acc.append(ps[p]["acclaim"])
	history.append({"k": kind, "round": round_n, "acclaim": acc})


func _setup_game() -> void:
	# sacchetto: tutte le tessere tranne quelle iniziali
	var start_pool := []
	for t in D.BAG_TOTAL:
		var k: int = D.BAG_TOTAL[t] - int(D.STARTING.get(t, 0))
		for i in k:
			bag.append(t)
	for t in D.STARTING:
		for i in D.STARTING[t]:
			start_pool.append(t)
	first = rng.randi_range(0, n - 1)
	log_msg("Primo giocatore: %s." % pname(first))
	# spettacoli piccoli: a ciascuno una coppia (cerchio bianco e nero, oppure triangolo bianco e nero)
	var piles := {"wc": [], "wt": [], "bc": [], "bt": []}
	for s in D.SPECTACLES:
		if s["size"] == 0:
			piles[s["set"]].append(s["id"])
	for k in piles:
		_shuffle(piles[k])
	for p in order_from(first):
		var kinds := []
		for k in ["c", "t"]:
			if not piles["w" + k].is_empty() and not piles["b" + k].is_empty():
				kinds.append(k)
		var kk: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		ps[p]["plan"].append(piles["w" + kk].pop_back())
		ps[p]["plan"].append(piles["b" + kk].pop_back())
	# artisti iniziali
	var draw: int = D.START_DRAW.get(n, 6)
	for p in order_from(first):
		for i in draw:
			var j := rng.randi_range(0, start_pool.size() - 1)
			add_tile(p, start_pool[j])
			start_pool.remove_at(j)
	bag.append_array(start_pool)
	update_stars()
	refill_markets()
	changed.emit()
	# cancelli iniziali, in ordine inverso
	var rev := order_from(first)
	rev.reverse()
	for p in rev:
		var pairs := start_pairs()
		var r = await decide(p, {"type": "start_gates", "pairs": pairs})
		if abort:
			return
		var pair = r.get("pair", []) if r is Dictionary else []
		if not (pair is Array and pair.size() == 2 and _pair_in(pairs, pair)):
			pair = pairs[0]
		for g in pair:
			_place_gate(p, int(g))
		log_msg("%s sceglie i cancelli di partenza." % pname(p))
		changed.emit()


func _pair_in(pairs: Array, pair: Array) -> bool:
	for q in pairs:
		if int(q[0]) == int(pair[0]) and int(q[1]) == int(pair[1]):
			return true
	return false


## coppie di caselle adiacenti libere con i pallini del numero di giocatori; se non ne restano, due caselle
## libere adiacenti lontane dai cancelli altrui
func start_pairs() -> Array:
	var out := []
	for a in D.TRACK:
		var b := (a + 1) % D.TRACK
		if gate_owner.has(a) or gate_owner.has(b):
			continue
		if n in D.START_GATES.get(a, []) and n in D.START_GATES.get(b, []):
			out.append([a, b])
	if out.is_empty():
		for a in D.TRACK:
			var b := (a + 1) % D.TRACK
			var c := posmod(a - 1, D.TRACK)
			var d := (a + 2) % D.TRACK
			if not gate_owner.has(a) and not gate_owner.has(b) and not gate_owner.has(c) and not gate_owner.has(d):
				out.append([a, b])
	if out.is_empty():
		for a in D.TRACK:
			var b := (a + 1) % D.TRACK
			if not gate_owner.has(a) and not gate_owner.has(b):
				out.append([a, b])
	return out


func _place_gate(p: int, g: int) -> void:
	gate_owner[g] = p
	ps[p]["gates"].append(g)
	fx.emit("gate", {"p": p, "space": g})


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ---------------------------------------------------------------- fase 1: investimenti

## caselle dove si può aggiungere un cancello
func gate_options(p: int) -> Array:
	var out := []
	if gates_of(p) >= 4:
		return out
	for g in ps[p]["gates"]:
		for d in [-1, 1]:
			var s := posmod(int(g) + d, D.TRACK)
			if not gate_owner.has(s) and not s in out:
				out.append(s)
	return out


func promoters_left() -> int:
	var c := 0
	for p in n:
		c += int(ps[p]["promoters"])
	return D.PROMOTERS - c


## investimenti possibili ora: {gate, promoter, temple, spect: [id]}
func invest_options(p: int, done: Array) -> Dictionary:
	var b := budget(p)
	var st: Dictionary = ps[p]
	var o := {"gate": [], "promoter": false, "temple": false, "spect": []}
	if not "gate" in done and b >= D.COST_GATE:
		o["gate"] = gate_options(p)
	if not "promoter" in done and b >= D.COST_PROMOTER and promoters_left() > 0:
		o["promoter"] = true
	if not "temple" in done and b >= D.COST_TEMPLE and st["temple"] < 0:
		o["temple"] = true
	if not "spect" in done:
		for id in display:
			if D.spect(id)["cost"] <= b:
				o["spect"].append(id)
	return o


func _phase_invest() -> void:
	phase = "invest"
	for p in order_from(first):
		var done := []
		while done.size() < 2 and not abort:
			var o := invest_options(p, done)
			if o["gate"].is_empty() and not o["promoter"] and not o["temple"] and o["spect"].is_empty():
				break
			var r = await decide(p, {"type": "invest", "done": done.duplicate(), "left": 2 - done.size(), "options": o})
			if abort:
				return
			var k: String = str(r.get("k", "pass")) if r is Dictionary else "pass"
			if k == "gate" and not o["gate"].is_empty():
				var s := int(r.get("space", -1))
				if not s in o["gate"]:
					s = o["gate"][0]
				pay(p, D.COST_GATE)
				_place_gate(p, s)
				log_msg("%s compra un cancello (10)." % pname(p))
				done.append("gate")
			elif k == "promoter" and o["promoter"]:
				pay(p, D.COST_PROMOTER)
				ps[p]["promoters"] += 1
				log_msg("%s ingaggia un promotore (7)." % pname(p))
				fx.emit("promoter", {"p": p})
				done.append("promoter")
			elif k == "temple" and o["temple"]:
				pay(p, D.COST_TEMPLE)
				_build_temple(p)
				log_msg("%s costruisce il Tempio della Fortuna (7)." % pname(p))
				done.append("temple")
			elif k == "spect" and str(r.get("id", "")) in o["spect"]:
				var id: String = r["id"]
				pay(p, D.spect(id)["cost"])
				display.erase(id)
				ps[p]["plan"].append(id)
				log_msg("%s pianifica «%s» (%d)." % [pname(p), D.spect(id)["name"], D.spect(id)["cost"]])
				fx.emit("spect", {"p": p, "id": id})
				done.append("spect")
			else:
				break
			changed.emit()
			await _pace(0.3)


func _build_temple(p: int) -> void:
	var spots: Array = layout.get("temples", [])
	var gp: Array = layout.get("gates", [])
	var c := Vector2.ZERO
	for g in ps[p]["gates"]:
		c += Vector2(gp[g][0], gp[g][1])
	c /= maxf(1.0, ps[p]["gates"].size())
	var best := -1
	var bd := 1e9
	for i in spots.size():
		if temple_spots.has(i):
			continue
		var d := c.distance_to(Vector2(spots[i][0], spots[i][1]))
		if d < bd:
			bd = d
			best = i
	if best < 0:
		best = 0
	temple_spots[best] = p
	ps[p]["temple"] = best
	fx.emit("temple", {"p": p, "spot": best})


# ---------------------------------------------------------------- fase 2: aste

func _phase_hire() -> void:
	phase = "hire"
	for a in order_from(first):
		active = a
		while not abort:
			var ready := []
			for m in 5:
				if market_ready(m):
					ready.append(m)
			if ready.is_empty() or budget(a) < D.MIN_BID:
				if ready.is_empty():
					log_msg("%s: nessun lotto disponibile." % pname(a))
				else:
					log_msg("%s non ha 8 monete per aprire un'asta." % pname(a))
				break
			var r = await decide(a, {"type": "auction", "markets": ready})
			if abort:
				return
			if not (r is Dictionary) or r.get("pass", false) or not int(r.get("m", -1)) in ready:
				log_msg("%s passa." % pname(a))
				break
			var m := int(r["m"])
			var bid := clampi(int(r.get("bid", D.MIN_BID)), D.MIN_BID, budget(a))
			var won := await _auction(a, m, bid)
			if abort:
				return
			if won == a:
				break
		# fine del turno: si riempiono i mercati e tutti riprendono il pilastro
		mercury = -1
		refill_markets()
		pillar_at.clear()
		for p in n:
			ps[p]["pillar"] = true
		changed.emit()
	active = -1


## Un'asta: restituisce il vincitore.
func _auction(a: int, m: int, bid: int) -> int:
	mercury = m
	high_bid = bid
	high_by = a
	log_msg("%s mette all'asta il lotto %s: %s (offerta %d)." % [pname(a), _mname(m), _lot_text(markets[m]), bid])
	changed.emit()
	var passed := {}
	for p in n:
		if not ps[p]["pillar"] or (p != a and budget(p) <= high_bid):
			passed[p] = true
	var i := (a + 1) % n
	var guard := 0
	while not abort and guard < 400:
		guard += 1
		var alive := []
		for p in n:
			if not passed.has(p):
				alive.append(p)
		if alive.size() <= 1 and (alive.is_empty() or alive[0] == high_by):
			break
		if alive.size() == 1 and alive[0] != high_by:
			# resta solo chi non ha la miglior offerta: può rilanciare o passare
			pass
		if not passed.has(i) and i != high_by:
			if budget(i) <= high_bid:
				passed[i] = true
			else:
				var r = await decide(i, {"type": "bid", "m": m, "high": high_bid, "by": high_by})
				if abort:
					return a
				var nb := int(r.get("bid", 0)) if r is Dictionary and not r.get("pass", false) else 0
				if nb > high_bid and nb <= budget(i):
					high_bid = nb
					high_by = i
					log_msg("  %s rilancia a %d." % [pname(i), nb])
					fx.emit("bid", {"p": i, "bid": nb})
				else:
					passed[i] = true
					log_msg("  %s passa." % pname(i))
				changed.emit()
		i = (i + 1) % n
	var w := high_by
	pay(w, high_bid)
	var lot: Array = markets[m]
	markets[m] = []
	for t in lot:
		add_tile(w, t)
		if t == D.AQUILA:
			log_msg("  %s riceve un'Aquila." % pname(w))
	ps[w]["pillar"] = false
	pillar_at[m] = w
	log_msg("%s si aggiudica il lotto per %d." % [pname(w), high_bid])
	fx.emit("won", {"p": w, "m": m, "lot": lot})
	update_stars()
	mercury = -1
	high_by = -1
	changed.emit()
	await _pace(0.5)
	return w


func _mname(m: int) -> String:
	return ["I", "II", "III", "IV", "V"][m]


func _lot_text(lot: Array) -> String:
	var parts := []
	for t in lot:
		parts.append(D.TYPE_ONE[t])
	return ", ".join(parts)


# ---------------------------------------------------------------- fase 3: scambi

const MAX_OFFERS := 6

func valid_offer(a: int, o: Dictionary) -> bool:
	var to := int(o.get("to", -1))
	if to < 0 or to >= n or to == a:
		return false
	var give: Dictionary = o.get("give", {})
	var get_: Dictionary = o.get("get", {})
	if give.is_empty() and get_.is_empty():
		return false
	return _has(a, give) and _has(to, get_)


func _has(p: int, items: Dictionary) -> bool:
	for k in items:
		var q := int(items[k])
		if q < 0:
			return false
		if k == "coins":
			if ps[p]["coins"] < q:
				return false
		elif k == "aquila":
			if ps[p]["aquila"] < q:
				return false
		elif int(ps[p]["tiles"].get(k, -999)) < q:
			return false
	return true


func _move_items(from: int, to: int, items: Dictionary) -> void:
	for k in items:
		var q := int(items[k])
		if q <= 0:
			continue
		if k == "coins":
			ps[from]["coins"] -= q
			ps[to]["coins"] += q
		elif k == "aquila":
			ps[from]["aquila"] -= q
			ps[to]["aquila"] += q
		else:
			remove_tile(from, k, q)
			add_tile(to, k, q)


func items_text(items: Dictionary) -> String:
	var parts := []
	for k in items:
		var q := int(items[k])
		if q <= 0:
			continue
		if k == "coins":
			parts.append("%d monet%s" % [q, "a" if q == 1 else "e"])
		elif k == "aquila":
			parts.append("%d Aquil%s" % [q, "a" if q == 1 else "e"])
		else:
			parts.append("%d %s" % [q, D.TYPE_ONE[k] if q == 1 else D.TYPE_NAME[k].to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "niente"


func _phase_trade() -> void:
	phase = "trade"
	for a in order_from(first):
		active = a
		var offers := 0
		while offers < MAX_OFFERS and not abort:
			var r = await decide(a, {"type": "trade", "offers": offers})
			if abort:
				return
			if not (r is Dictionary) or r.get("end", false) or not valid_offer(a, r):
				break
			offers += 1
			var to := int(r["to"])
			var give: Dictionary = r.get("give", {})
			var get_: Dictionary = r.get("get", {})
			log_msg("%s propone a %s: %s in cambio di %s." % [pname(a), pname(to), items_text(give), items_text(get_)])
			fx.emit("offer", {"from": a, "to": to, "give": give, "get": get_})
			var ans = await decide(to, {"type": "trade_answer", "from": a, "give": give, "get": get_})
			if abort:
				return
			if ans is Dictionary and ans.get("ok", false) and valid_offer(a, r):
				_move_items(a, to, give)
				_move_items(to, a, get_)
				log_msg("  %s accetta." % pname(to))
				fx.emit("trade", {"from": a, "to": to, "give": give, "get": get_})
				update_stars()
			else:
				log_msg("  %s rifiuta." % pname(to))
			changed.emit()
	active = -1


# ---------------------------------------------------------------- fase 4: spettacoli

## Le mosse dei dadi sono valide? moves = [[nobile, passi], …]
func valid_moves(moves: Array, d: Array, temple: bool) -> bool:
	if moves.size() == 1:
		var s := int(moves[0][1])
		var tot := int(d[0]) + int(d[1])
		return (s == tot) or (temple and s >= 2 and s <= tot)
	if moves.size() == 2:
		var a := int(moves[0][0])
		var b := int(moves[1][0])
		if a == b:
			return false
		var x := int(moves[0][1])
		var y := int(moves[1][1])
		for perm in [[d[0], d[1]], [d[1], d[0]]]:
			if temple:
				if x >= 1 and x <= int(perm[0]) and y >= 1 and y <= int(perm[1]):
					return true
			elif x == int(perm[0]) and y == int(perm[1]):
				return true
	return false


## tutti i piani di movimento possibili: [{moves, pos}] (posizioni finali dei nobili)
func move_plans(d: Array, temple: bool) -> Array:
	var out := []
	var seen := {}
	var singles := []
	var tot := int(d[0]) + int(d[1])
	if temple:
		for s in range(2, tot + 1):
			singles.append(s)
	else:
		singles.append(tot)
	for i in 6:
		for s in singles:
			_add_plan(out, seen, [[i, s]])
	var pairs := []
	if temple:
		for x in range(1, int(d[0]) + 1):
			for y in range(1, int(d[1]) + 1):
				pairs.append([x, y])
	else:
		pairs.append([int(d[0]), int(d[1])])
		if d[0] != d[1]:
			pairs.append([int(d[1]), int(d[0])])
	for i in 6:
		for j in 6:
			if i == j:
				continue
			for pr in pairs:
				_add_plan(out, seen, [[i, pr[0]], [j, pr[1]]])
	return out


func _add_plan(out: Array, seen: Dictionary, moves: Array) -> void:
	var pos := apply_moves(moves)
	var key := str(pos)
	if seen.has(key):
		return
	seen[key] = true
	out.append({"moves": moves, "pos": pos})


## posizioni dei nobili dopo le mosse (applicate in ordine)
func apply_moves(moves: Array, start: Array = []) -> Array:
	var pos: Array = start.duplicate() if not start.is_empty() else nobles.duplicate()
	for mv in moves:
		pos[int(mv[0])] = noble_dest(int(mv[0]), int(mv[1]), pos)
	return pos


func _phase_perform() -> void:
	phase = "perform"
	for p in n:
		ps[p]["cur"] = ""
		ps[p]["used"] = {}
	for p in order_from(first):
		active = p
		# 1. i nobili
		dice = [rng.randi_range(1, 6), rng.randi_range(1, 6)]
		var temple: bool = ps[p]["temple"] >= 0
		log_msg("%s tira i dadi: %d e %d%s." % [pname(p), dice[0], dice[1], " (Tempio della Fortuna)" if temple else ""])
		fx.emit("dice", {"p": p, "dice": dice.duplicate()})
		changed.emit()
		await _pace(0.6)
		var r = await decide(p, {"type": "nobles", "dice": dice.duplicate(), "temple": temple})
		if abort:
			return
		var moves: Array = r.get("moves", []) if r is Dictionary else []
		if not valid_moves(moves, dice, temple):
			moves = move_plans(dice, temple)[0]["moves"]
		for mv in moves:
			var i := int(mv[0])
			var path := noble_path(i, int(mv[1]))
			nobles[i] = path[-1]
			log_msg("  %s avanza di %d fino alla casella %d." % [D.NOBLE_CAP[i], int(mv[1]), nobles[i] + 1])
			fx.emit("noble", {"i": i, "path": path})
			changed.emit()
			await _pace(0.25 + 0.08 * path.size())
		for mv in moves:
			var i := int(mv[0])
			if is_aquila_space(nobles[i]):
				ps[p]["aquila"] += 1
				log_msg("  %s finisce su un'Aquila: %s ne prende una." % [D.NOBLE_CAP[i], pname(p)])
		# Aquile per spostare i nobili (anche all'indietro)
		var used := 0
		while ps[p]["aquila"] > 0 and used < 12 and not abort:
			var r2 = await decide(p, {"type": "aquila_move"})
			if abort:
				return
			if not (r2 is Dictionary) or r2.get("done", true) or not r2.has("noble"):
				break
			var i := clampi(int(r2["noble"]), 0, 5)
			var st := clampi(int(r2.get("steps", 0)), -3, 3)
			if st == 0:
				break
			ps[p]["aquila"] -= 1
			used += 1
			var path := noble_path(i, st)
			nobles[i] = path[-1]
			log_msg("  %s spende un'Aquila: %s %s di %d." % [pname(p), D.NOBLE_NAME[i], "avanza" if st > 0 else "torna indietro", absi(st)])
			fx.emit("noble", {"i": i, "path": path})
			changed.emit()
			await _pace(0.3 + 0.08 * path.size())
		# 2-3. scelta ed esibizione
		var opts := {}
		for id in all_spects(p):
			if can_perform(p, id):
				opts[id] = score(p, id)
		if opts.is_empty():
			log_msg("%s non può esibire nessuno spettacolo." % pname(p))
			continue
		var r3 = await decide(p, {"type": "perform", "options": opts})
		if abort:
			return
		var id: String = str(r3.get("id", "")) if r3 is Dictionary else ""
		if not opts.has(id):
			log_msg("%s non si esibisce." % pname(p))
			continue
		var aq := clampi(int(r3.get("aq", 0)), 0, ps[p]["aquila"])
		var sc: Dictionary = opts[id]
		var total: int = sc["total"] + 3 * aq
		ps[p]["aquila"] -= aq
		ps[p]["cur"] = id
		ps[p]["used"] = evaluate(p, id)["used"]
		ps[p]["plan"].erase(id)
		ps[p]["done"].erase(id)
		ps[p]["last"] = total
		var parts := ["spettacolo %d" % sc["base"]]
		for k in [["prev", "repliche"], ["stars", "stelle"], ["nobles", "nobili"], ["promoters", "promotori"], ["gifts", "doni"]]:
			if sc[k[0]] > 0:
				parts.append("%s %d" % [k[1], sc[k[0]]])
		if aq > 0:
			parts.append("aquile %d" % (3 * aq))
		log_msg("%s mette in scena «%s»: %d di Acclamazione (%s)." % [pname(p), D.spect(id)["name"], total, ", ".join(parts)])
		ps[p]["coins"] += total
		if total > ps[p]["acclaim"]:
			ps[p]["acclaim"] = total
			seq += 1
			ps[p]["aseq"] = seq
		fx.emit("perform", {"p": p, "id": id, "total": total, "score": sc, "aq": aq})
		changed.emit()
		await _pace(1.2)
	active = -1
	# Doni dell'Imperatore
	var top := leader()
	if gifts_left > 0:
		gifts_left -= 1
		ps[top]["gifts"] += 1
		log_msg("L'Imperatore premia %s con un Dono (+3 per le prossime esibizioni)." % pname(top))
		fx.emit("gift", {"p": top})
		changed.emit()
	else:
		_end_game()


## il più acclamato (a parità quello più in basso nella pila)
func leader() -> int:
	var best := 0
	for p in range(1, n):
		var a: int = ps[p]["acclaim"]
		var b: int = ps[best]["acclaim"]
		if a > b or (a == b and ps[p]["aseq"] < ps[best]["aseq"]):
			best = p
	return best


## il meno acclamato (a parità quello in cima alla pila)
func least() -> int:
	var w := 0
	for p in range(1, n):
		var a: int = ps[p]["acclaim"]
		var b: int = ps[w]["acclaim"]
		if a < b or (a == b and ps[p]["aseq"] > ps[w]["aseq"]):
			w = p
	return w


# ---------------------------------------------------------------- fase 5: cerimonie di chiusura

func _phase_closing() -> void:
	phase = "closing"
	for p in order_from(first):
		var id: String = ps[p]["cur"]
		if id == "":
			continue
		var opts := []
		for t in ps[p]["used"]:
			if int(ps[p]["tiles"].get(t, 0)) > 0:
				opts.append(t)
		if not opts.is_empty():
			var r = await decide(p, {"type": "retire", "options": opts, "id": id})
			if abort:
				return
			var t: String = str(r.get("t", "")) if r is Dictionary else ""
			if not t in opts:
				t = opts[0]
			remove_tile(p, t)
			log_msg("%s ritira un %s." % [pname(p), D.TYPE_ONE[t]])
			fx.emit("retire", {"p": p, "t": t})
		ps[p]["done"].append(id)
		ps[p]["cur"] = ""
		update_stars()
		changed.emit()
	var lo := least()
	var hi := leader()
	if lo != hi and tile_count(hi) > 0:
		var opts := []
		for t in ps[hi]["tiles"]:
			if int(ps[hi]["tiles"][t]) > 0:
				opts.append(t)
		var r = await decide(lo, {"type": "steal", "from": hi, "options": opts})
		if abort:
			return
		var t: String = str(r.get("t", "")) if r is Dictionary else ""
		if not t in opts:
			t = opts[0]
		remove_tile(hi, t)
		add_tile(lo, t)
		log_msg("%s, il meno acclamato, sottrae un %s a %s." % [pname(lo), D.TYPE_ONE[t], pname(hi)])
		fx.emit("steal", {"from": hi, "to": lo, "t": t})
		update_stars()
		changed.emit()
	var r2 = await decide(lo, {"type": "first"})
	if abort:
		return
	var f := int(r2.get("p", lo)) if r2 is Dictionary else lo
	first = clampi(f, 0, n - 1)
	log_msg("%s sceglie %s come primo giocatore." % [pname(lo), pname(first) if first != lo else "se stesso"])
	fx.emit("first", {"p": first})
	changed.emit()


func _end_game() -> void:
	over = true
	for p in n:
		if ps[p]["cur"] != "":
			ps[p]["done"].append(ps[p]["cur"])
			ps[p]["cur"] = ""
	for p in n:
		var a: int = ps[p]["aquila"]
		if a > 0:
			ps[p]["acclaim"] += 3 * a
			ps[p]["aquila"] = 0
			log_msg("%s restituisce %d Aquil%s: +%d di Acclamazione." % [pname(p), a, "a" if a == 1 else "e", 3 * a])
	var rank := range(n)
	rank.sort_custom(func(a, b):
		var x: Dictionary = ps[a]
		var y: Dictionary = ps[b]
		if x["acclaim"] != y["acclaim"]:
			return x["acclaim"] > y["acclaim"]
		if x["coins"] != y["coins"]:
			return x["coins"] > y["coins"]
		var sa := stars_of(a).size()
		var sb := stars_of(b).size()
		if sa != sb:
			return sa > sb
		return x["aseq"] < y["aseq"])
	var scores := []
	for p in n:
		scores.append(ps[p]["acclaim"])
	result = {"winner": rank[0], "rank": rank, "acclaim": scores}
	log_msg("Gran Impresario: %s con %d di Acclamazione!" % [pname(rank[0]), ps[rank[0]]["acclaim"]])


## impronta della partita (per verificare che due dispositivi online abbiano giocato la stessa)
func fingerprint() -> String:
	var s := ""
	for p in n:
		s += "%d/%d/%d;" % [ps[p]["acclaim"], ps[p]["coins"], tile_count(p)]
	return "%d|%d|%s" % [round_n, log_lines.size(), s]
