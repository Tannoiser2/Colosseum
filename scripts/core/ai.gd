class_name CSAI
extends RefCounted
## Intelligenza artificiale degli impresari. Ragiona in «monete equivalenti»: l'Acclamazione che conta è
## quella dell'esibizione migliore (il segnalino non torna mai indietro), quindi l'IA stima il punteggio
## dello spettacolo più forte che potrà mettere in scena con i suoi artisti, cancelli e Stelle, e confronta
## ogni scelta con quanto costa. Livelli: 0 facile (stime rumorose, poca lungimiranza), 1 normale, 2 difficile.

const D = preload("res://scripts/data/cs_data.gd")

var level := 1
var rng := RandomNumberGenerator.new()


func _init(lv := 1, seed_v := 0) -> void:
	level = lv
	if seed_v != 0:
		rng.seed = seed_v
	else:
		rng.randomize()


func decide(e: CSEngine, p: int, req: Dictionary):
	match req["type"]:
		"start_gates":
			return _start_gates(e, p, req)
		"invest":
			return _invest(e, p, req)
		"auction":
			return _auction(e, p, req)
		"bid":
			return _bid(e, p, req)
		"trade":
			return _trade(e, p, req)
		"trade_answer":
			return {"ok": accept_trade(e, p, int(req["from"]), req["give"], req["get"])}
		"nobles":
			return _nobles(e, p, req)
		"aquila_move":
			return _aquila_move(e, p)
		"perform":
			return _perform(e, p, req)
		"retire":
			return _retire(e, p, req)
		"steal":
			return _steal(e, p, req)
		"first":
			return {"p": p}
	return {}


func _noise(x: float) -> float:
	if level == 0:
		return x * rng.randf_range(0.6, 1.4) + rng.randf_range(-2.0, 2.0)
	if level == 1:
		return x * rng.randf_range(0.92, 1.08)
	return x


## giornate che restano, compresa quella in corso
func rounds_left(e: CSEngine) -> int:
	return maxi(1, D.ROUNDS - maxi(e.round_n, 1) + 1)


## Utilità di una moneta, misurata in punti di Acclamazione finale. Le monete servono a comprare
## Acclamazione nelle giornate successive (circa 2,5 monete per punto); dopo gli investimenti
## dell'ultima giornata valgono quasi nulla (contano solo per gli spareggi).
func cu(e: CSEngine) -> float:
	if e.round_n >= D.ROUNDS and e.phase in ["hire", "trade", "perform", "closing"]:
		return 0.04
	return 0.4


## Utilità di un aumento stabile dell'esibizione: conta nell'esibizione finale e, nelle giornate
## precedenti, come monete guadagnate.
func perf_util(e: CSEngine, delta: float) -> float:
	var r := rounds_left(e)
	if e.phase in ["perform", "closing"]:
		r -= 1
	return delta * (1.0 + 0.4 * maxf(0.0, r - 1))


## monete equivalenti a un aumento dell'esibizione
func conv(e: CSEngine) -> float:
	return perf_util(e, 1.0) / cu(e)


# ================================================================ stima delle esibizioni

## Acclamazione attesa di uno spettacolo con queste tessere. Prima dell'ultima giornata si considera che
## qualche artista mancante arriverà ancora (aste, scambi).
func spect_est(e: CSEngine, p: int, id: String, tiles: Dictionary, future := true) -> float:
	var s := D.spect(id)
	var ev := e.evaluate(p, id, tiles)
	var strip: Array = s["strip"]
	var slack: int = mini(strip.size(), D.SIZE_SLACK[s["size"]])
	var miss: float = ev["missing"]
	var fut := 0.0
	if future and e.phase != "perform":
		var r := rounds_left(e)
		# artisti che si possono ancora ottenere in questa e nelle prossime giornate
		fut = (1.6 if e.phase in ["setup", "invest", "hire"] else 0.6) + 1.4 * (r - 1)
		if level == 0:
			fut *= 0.6
	miss = maxf(0.0, miss - fut)
	var acc := 0.0
	if miss <= 0.0:
		acc = s["full"]
	elif miss <= slack:
		var lo := int(floor(miss))
		var hi := int(ceil(miss))
		var a: float = s["full"] if lo == 0 else float(strip[lo - 1])
		var b: float = float(strip[hi - 1])
		acc = lerpf(a, b, miss - lo)
	else:
		acc = maxf(0.0, float(strip[slack - 1]) - 4.0 * (miss - slack))
	# Stelle che si avrebbero con queste tessere
	for k in s["req"]:
		if _would_star(e, p, k, tiles):
			acc += 4
	return acc


func _would_star(e: CSEngine, p: int, t: String, tiles: Dictionary) -> bool:
	var mine := int(tiles.get(t, 0))
	if e.stars.get(t, -1) == p and mine >= 3:
		for q in e.n:
			if q != p and int(e.ps[q]["tiles"][t]) > mine:
				return false
		return true
	if mine < 3:
		return false
	for q in e.n:
		if q != p and int(e.ps[q]["tiles"][t]) >= mine:
			return false
	return true


## miglior esibizione stimata: fra gli spettacoli posseduti (e quelli `extra`), con i cancelli indicati
func best_perf(e: CSEngine, p: int, tiles: Dictionary, gates := -1, extra: Array = [], future := true) -> float:
	if gates < 0:
		gates = e.gates_of(p)
	var best := 0.0
	var ids: Array = e.all_spects(p)
	ids.append_array(extra)
	for id in ids:
		var s := D.spect(id)
		var need: int = D.SIZE_GATES[s["size"]]
		var v := spect_est(e, p, id, tiles, future)
		if gates < need:
			# si potrà comprare il cancello in una prossima giornata
			if rounds_left(e) > 1 and need - gates <= rounds_left(e) - 1 and not e.phase in ["perform", "closing"]:
				v -= 6.0 * (need - gates)
			else:
				continue
		if not id in e.ps[p]["done"]:
			v += 2.0 if rounds_left(e) > 1 else 0.0
		best = maxf(best, v)
	return best


func tiles_plus(tiles: Dictionary, items: Dictionary, sign := 1) -> Dictionary:
	var t := tiles.duplicate()
	for k in items:
		if k == "coins" or k == "aquila":
			continue
		t[k] = int(t.get(k, 0)) + sign * int(items[k])
	return t


## valore in monete di un gruppo di oggetti per il giocatore p
func items_value(e: CSEngine, p: int, items: Dictionary, sign := 1) -> float:
	var tiles: Dictionary = e.ps[p]["tiles"]
	var after := tiles_plus(tiles, items, sign)
	var d := best_perf(e, p, after, -1, [], false) - best_perf(e, p, tiles, -1, [], false)
	var v := d * conv(e) * float(sign)
	var ntiles := 0
	for k in items:
		var q := int(items[k])
		if k == "coins":
			v += q * float(sign) * _coin_value(e)
		elif k == "aquila":
			v += q * float(sign) * _aquila_value(e)
		else:
			ntiles += q
	# tessere in più servono comunque per scambi, furti e per le prossime giornate
	v += float(sign) * ntiles * ((1.0 + 0.8 * (rounds_left(e) - 1)) if cu(e) > 0.1 else 0.3)
	return v


## una moneta vale una moneta: l'unità di misura dell'IA
func _coin_value(_e: CSEngine) -> float:
	return 1.0


## un'Aquila: 6 monete, oppure 3 di Acclamazione finale
func _aquila_value(e: CSEngine) -> float:
	return maxf(6.0, 3.0 / cu(e))


# ================================================================ inizio

func _start_gates(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var best = req["pairs"][0]
	var bv := -1e9
	for pair in req["pairs"]:
		var v := 0.0
		for g in pair:
			for i in 6:
				var dist := posmod(int(g) - int(e.nobles[i]), D.TRACK)
				if dist >= 2 and dist <= 12:
					v += D.NOBLE_BONUS[i] * (1.0 - absf(dist - 7.0) / 8.0)
		v += rng.randf_range(0.0, 3.0 if level == 0 else 1.0)
		if v > bv:
			bv = v
			best = pair
	return {"pair": best}


# ================================================================ investimenti

func _invest(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var o: Dictionary = req["options"]
	var st: Dictionary = e.ps[p]
	var b := e.budget(p)
	var r := rounds_left(e)
	var last := r <= 1
	var reserve := 8 if last else 9
	var tiles: Dictionary = st["tiles"]
	var cur := best_perf(e, p, tiles, -1, [], last)
	var cands := []
	# promotore: +5 a ogni esibizione (anche l'ultima, che è quella che conta) e 5 monete ogni volta
	if o["promoter"]:
		var v := 5.0 * conv(e)
		cands.append({"k": "promoter", "v": _noise(v) - D.COST_PROMOTER, "cost": D.COST_PROMOTER})
	# cancello: abilita spettacoli più grandi e attira i nobili
	if not o["gate"].is_empty():
		var g := e.gates_of(p)
		var with_g := best_perf(e, p, tiles, g + 1, _affordable_display(e, p, b - D.COST_GATE))
		var without := best_perf(e, p, tiles, g, _affordable_display(e, p, b))
		var v := (with_g - without) * conv(e) + 3.0 * r
		# senza questo cancello uno spettacolo già pianificato non si può mettere in scena
		for id in st["plan"]:
			if D.SIZE_GATES[D.spect(id)["size"]] == g + 1 and spect_est(e, p, id, tiles, false) > 0.0:
				v += 25.0
		var space := _best_gate_space(e, p, o["gate"])
		cands.append({"k": "gate", "space": space, "v": _noise(v) - D.COST_GATE, "cost": D.COST_GATE})
	# tempio: più controllo sui nobili
	if o["temple"]:
		var v := (4.0 + 2.5 * r) if r > 1 else 3.0
		cands.append({"k": "temple", "v": _noise(v) - D.COST_TEMPLE, "cost": D.COST_TEMPLE})
	# spettacolo
	for id in o["spect"]:
		var s := D.spect(id)
		var need: int = D.SIZE_GATES[s["size"]]
		var g := e.gates_of(p) + (1 if "gate" in req["done"] else 0)
		if need > g + (r - 1) or (last and need > g):
			continue
		var est := spect_est(e, p, id, tiles)
		if need > g:
			est -= 5.0 * (need - g)
			# servono ancora cancelli: che restino i soldi per comprarli
			if b - int(s["cost"]) < 10 * (need - g) + 4 and not "gate" in req["done"]:
				continue
		var gain := maxf(0.0, est - cur) * conv(e)
		# uno spettacolo nuovo vale anche +5 nelle esibizioni successive
		if r > 1 and st["plan"].size() + st["done"].size() < 4:
			gain += 5.0 * conv(e) * 0.5
		var v: float = gain
		cands.append({"k": "spect", "id": id, "v": _noise(v) - s["cost"], "cost": s["cost"]})
	cands.sort_custom(func(a, c): return a["v"] > c["v"])
	if level == 0 and cands.size() > 1 and rng.randf() < 0.35:
		# l'IA facile a volte sceglie d'istinto
		var k: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
		cands.erase(k)
		cands.push_front(k)
	for c in cands:
		if c["v"] <= 0.0:
			break
		if b - int(c["cost"]) < reserve and not (c["k"] == "gate" and c["v"] > 25.0 and e.round_n >= 2):
			continue
		var out := {"k": c["k"]}
		if c.has("space"):
			out["space"] = c["space"]
		if c.has("id"):
			out["id"] = c["id"]
		return out
	return {"k": "pass"}


func _affordable_display(e: CSEngine, p: int, money: int) -> Array:
	var out := []
	for id in e.display:
		if D.spect(id)["cost"] <= money:
			out.append(id)
	return out


func _best_gate_space(e: CSEngine, p: int, opts: Array) -> int:
	var best: int = opts[0]
	var bv := -1e9
	for s in opts:
		var v := 0.0
		for i in 6:
			var dist := posmod(int(s) - int(e.nobles[i]), D.TRACK)
			if dist >= 1 and dist <= 12:
				v += D.NOBLE_BONUS[i] * (1.0 - absf(dist - 7.0) / 8.0)
		if v > bv:
			bv = v
			best = s
	return best


# ================================================================ aste

func lot_value(e: CSEngine, p: int, lot: Array) -> float:
	var items := {}
	var aq := 0
	for t in lot:
		if t == D.AQUILA:
			aq += 1
		else:
			items[t] = int(items.get(t, 0)) + 1
	var v := items_value(e, p, items)
	v += aq * _aquila_value(e)
	return _noise(v)


func _max_bid(e: CSEngine, p: int, m: int) -> int:
	var v := lot_value(e, p, e.markets[m])
	var last := rounds_left(e) <= 1
	var reserve := 0 if last else 2
	if level == 0:
		# l'IA facile non si svena: offre al massimo i due terzi del valore
		v *= 0.65
	elif level >= 2:
		# l'IA difficile considera anche quanto il lotto servirebbe al rivale più pericoloso
		var deny := 0.0
		for q in e.n:
			if q != p and e.ps[q]["pillar"] and e.budget(q) > D.MIN_BID:
				var gq := best_perf(e, q, tiles_plus(e.ps[q]["tiles"], _lot_items(e.markets[m])), -1, [], false) - best_perf(e, q, e.ps[q]["tiles"], -1, [], false)
				deny = maxf(deny, gq * (1.3 if q == e.leader() else 1.0))
		v += 0.25 * deny * conv(e) * (0.3 if last else 1.0)
	return int(minf(v, e.budget(p) - reserve))


func _lot_items(lot: Array) -> Dictionary:
	var items := {}
	for t in lot:
		if t != D.AQUILA:
			items[t] = int(items.get(t, 0)) + 1
	return items


func _auction(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var best := -1
	var bv := -1.0
	for m in req["markets"]:
		var v := float(_max_bid(e, p, m))
		if v > bv:
			bv = v
			best = m
	if best < 0 or bv < D.MIN_BID:
		return {"pass": true}
	# apertura: se nessuno può rilanciare basta il minimo
	var rivals := 0
	for q in e.n:
		if q != p and e.ps[q]["pillar"] and e.budget(q) > D.MIN_BID:
			rivals += 1
	var open := D.MIN_BID
	if rivals > 0 and level >= 2 and bv > 14:
		open = mini(int(bv * 0.6), int(bv))
	return {"m": best, "bid": clampi(open, D.MIN_BID, e.budget(p))}


func _bid(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var mx := _max_bid(e, p, int(req["m"]))
	var high := int(req["high"])
	if mx > high:
		var step := 1 if level < 2 else (1 if mx - high < 6 else 2)
		return {"bid": mini(high + step, e.budget(p))}
	return {"pass": true}


# ================================================================ scambi

## Valuta un'offerta ricevuta: give = ciò che riceve p, get = ciò che p cede.
func accept_trade(e: CSEngine, p: int, from: int, give: Dictionary, get_: Dictionary) -> bool:
	var mine := items_value(e, p, give, 1) + items_value(e, p, get_, -1)
	if mine <= 1.0:
		return false
	# non aiutare troppo chi è già in testa
	var theirs := items_value(e, from, get_, 1) + items_value(e, from, give, -1)
	if from == e.leader() and e.round_n > 1 and theirs > mine * 1.5 + 3.0:
		return false
	return true


func _trade(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	if level == 0 or int(req["offers"]) >= 3:
		return {"end": true}
	var mine: Dictionary = e.ps[p]["tiles"]
	var cur := best_perf(e, p, mine)
	# tipi che servono e tipi in esubero
	var want := []
	for t in D.TYPES + [D.WILD]:
		var d := best_perf(e, p, tiles_plus(mine, {t: 1})) - cur
		if d > 0.5:
			want.append([t, d])
	want.sort_custom(func(a, b): return a[1] > b[1])
	var spare := []
	for t in D.TYPES:
		if int(mine[t]) <= 0:
			continue
		var loss := cur - best_perf(e, p, tiles_plus(mine, {t: 1}, -1))
		if loss < 0.5:
			spare.append(t)
	var tried: Dictionary = e.get_meta("tried_%d" % p, {}) if e.has_meta("tried_%d" % p) else {}
	for w in want:
		var t: String = w[0]
		var gain: float = w[1] * conv(e)
		for q in e.order_from((p + 1) % e.n):
			if q == p or int(e.ps[q]["tiles"].get(t, 0)) <= 0:
				continue
			# prima prova a scambiare una tessera in esubero, poi con le monete
			var offers := []
			for s in spare:
				if s == t:
					continue
				offers.append({"to": q, "give": {s: 1}, "get": {t: 1}})
			var price := clampi(int(round(gain * 0.45)) + 2, 3, maxi(3, int(e.ps[p]["coins"]) - 4))
			if e.ps[p]["coins"] >= price:
				offers.append({"to": q, "give": {"coins": price}, "get": {t: 1}})
			for o in offers:
				var key := "%d-%s" % [e.round_n, var_to_str(o)]
				if tried.has(key):
					continue
				var my_gain := items_value(e, p, o["get"], 1) + items_value(e, p, o["give"], -1)
				if my_gain <= 1.0:
					continue
				# con l'IA si prova solo se probabilmente accetterà; con le persone si propone
				var ok := true
				if e.players[q]["ai"]:
					ok = accept_trade(e, q, p, o["give"], o["get"])
				tried[key] = true
				e.set_meta("tried_%d" % p, tried)
				if ok:
					return o
	return {"end": true}


# ================================================================ nobili

func _nobles(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var plans := e.move_plans(req["dice"], req["temple"])
	var best: Array = plans[0]["moves"]
	var bv := -1e9
	var later := _later_players(e, p)
	for pl in plans:
		var pos: Array = pl["pos"]
		var v := float(e.noble_bonus(p, pos))
		if level >= 1:
			for q in later:
				v -= (0.45 if level == 1 else 0.6) * e.noble_bonus(q, pos)
		for mv in pl["moves"]:
			if e.is_aquila_space(pos[int(mv[0])]):
				v += 2.5
		v += rng.randf_range(0.0, 0.4)
		if v > bv:
			bv = v
			best = pl["moves"]
	return {"moves": best}


func _later_players(e: CSEngine, p: int) -> Array:
	var out := []
	var started := false
	for q in e.order_from(e.first):
		if started:
			out.append(q)
		if q == p:
			started = true
	return out


func _aquila_move(e: CSEngine, p: int) -> Dictionary:
	if e.ps[p]["aquila"] <= 0:
		return {"done": true}
	var base := e.noble_bonus(p)
	var later := _later_players(e, p)
	var best := {}
	var bv := 0.0
	for i in 6:
		for s in [-3, -2, -1, 1, 2, 3]:
			var pos := e.nobles.duplicate()
			pos[i] = e.noble_dest(i, s, pos)
			var v := float(e.noble_bonus(p, pos) - base)
			for q in later:
				v -= 0.45 * (e.noble_bonus(q, pos) - e.noble_bonus(q))
			if v > bv:
				bv = v
				best = {"noble": i, "steps": s}
	# un'Aquila vale 6 monete o 3 di Acclamazione: la si spende solo per un nobile importante
	var thr := 4.5 if rounds_left(e) <= 1 else 4.0
	if level == 0:
		thr = 6.0
	if bv >= thr and not best.is_empty():
		best["done"] = false
		return best
	return {"done": true}


# ================================================================ esibizione e chiusura

func _perform(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var best := ""
	var bv := -1e9
	var r := rounds_left(e)
	for id in req["options"]:
		var sc: Dictionary = req["options"][id]
		var v: float = sc["total"]
		# meglio uno spettacolo mai fatto: darà +5 nelle prossime giornate
		if r > 1 and not id in e.ps[p]["done"]:
			v += 4.0
		if v > bv:
			bv = v
			best = id
	return {"id": best, "aq": 0}


func _retire(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var mine: Dictionary = e.ps[p]["tiles"]
	var best: String = req["options"][0]
	var bv := -1e9
	for t in req["options"]:
		var v := best_perf(e, p, tiles_plus(mine, {t: 1}, -1))
		if t == D.WILD:
			v -= 3.0
		if _would_star(e, p, t, mine) and not _would_star(e, p, t, tiles_plus(mine, {t: 1}, -1)):
			v -= 3.0
		if v > bv:
			bv = v
			best = t
	return {"t": best}


func _steal(e: CSEngine, p: int, req: Dictionary) -> Dictionary:
	var mine: Dictionary = e.ps[p]["tiles"]
	var victim := int(req["from"])
	var vt: Dictionary = e.ps[victim]["tiles"]
	var best: String = req["options"][0]
	var bv := -1e9
	var vcur := best_perf(e, victim, vt)
	for t in req["options"]:
		var v := best_perf(e, p, tiles_plus(mine, {t: 1}))
		v += 0.5 * (vcur - best_perf(e, victim, tiles_plus(vt, {t: 1}, -1)))
		if t == D.WILD:
			v += 1.5
		if v > bv:
			bv = v
			best = t
	return {"t": best}
