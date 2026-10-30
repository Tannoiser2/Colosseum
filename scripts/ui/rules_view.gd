extends Control
## Le regole di Colosseum: The Grand Spectacle riassunte in italiano, con l'elenco degli spettacoli.

const D = preload("res://scripts/data/cs_data.gd")

var main
var popup := false

const TEXT := """[font_size=34][color=#f3cf72]Colosseum in breve[/color][/font_size]
Siete impresari romani che producono spettacoli nell'Anfiteatro Flavio. In [b]4 giornate[/b] investite, ingaggiate artisti all'asta, li scambiate e mettete in scena gli spettacoli. Vince chi ha più [b]Acclamazione[/b]: il segnalino sul tracciato segna la vostra [b]esibizione migliore[/b] e non torna mai indietro.
Si gioca in 3, 4 o 5. All'inizio ognuno ha 30 monete, due cancelli adiacenti (sulle caselle con i pallini del numero di giocatori, scelti in ordine inverso), due piccoli spettacoli e alcuni artisti iniziali (8 in tre, 7 in quattro, 6 in cinque).

[font_size=26][color=#e07a52]Fase 1 · Investimenti[/color][/font_size]
A turno ognuno fa fino a [b]2 investimenti diversi[/b]:
• [b]Cancello[/b] (10, al massimo 2 in più): in una casella libera accanto ai vostri cancelli. Servono [b]3 cancelli[/b] per gli spettacoli medi e [b]4[/b] per i grandi, e più cancelli attirano più nobili.
• [b]Promotore[/b] (7): +5 di Acclamazione in ogni esibizione (12 in tutto).
• [b]Pianificare uno spettacolo[/b] (il costo sulla moneta d'oro): uno dei medi (1-10) o grandi (11-22) in vendita.
• [b]Tempio della Fortuna[/b] (7, uno solo): i dadi dei nobili diventano un intervallo, da 1 al numero uscito.

[font_size=26][color=#e07a52]Fase 2 · Ingaggio degli artisti[/color][/font_size]
Nei 5 mercati dell'arena ci sono lotti di 3 tessere. Al vostro turno mettete all'asta un lotto con un'offerta di almeno [b]8[/b] (oppure passate). In senso orario chi ha ancora il [b]pilastro[/b] rilancia o passa; chi passa è fuori da quell'asta. Il vincitore paga, prende le tessere e posa il pilastro sul mercato vuoto: fino alla fine del turno non può più fare offerte.
Se vince l'impresario di turno il suo turno finisce; altrimenti può mettere all'asta un altro lotto. A fine turno i mercati vuoti si riempiono e tutti riprendono il pilastro.
Le [b]Aquile[/b] valgono 6 monete di credito nelle offerte; si spendono solo se le monete non bastano per pagare.

[font_size=26][color=#e07a52]Fase 3 · Scambi[/color][/font_size]
A turno ognuno è l'impresario attivo e propone scambi di artisti, monete e Aquile; ogni scambio deve coinvolgerlo e chi riceve la proposta può accettare o rifiutare. Spettacoli, Stelle, promotori, doni e Acclamazione non si scambiano.

[font_size=26][color=#e07a52]Fase 4 · Spettacoli[/color][/font_size]
A turno, dal primo giocatore:
[b]1. Nobili.[/b] Si tirano due dadi: un nobile si muove del primo e un altro del secondo, oppure uno solo della somma, sempre in senso orario. Le caselle occupate da altri nobili si saltano e non contano. Chi ferma un nobile su una casella con l'[b]Aquila[/b] ne prende una. Poi ogni Aquila spesa sposta un nobile fino a 3 caselle, anche all'indietro.
[b]2. Scelta.[/b] Uno spettacolo pianificato o già fatto, se avete i cancelli e abbastanza artisti: almeno 1 per i piccoli, al massimo 5 mancanti per i medi e 6 per i grandi. I [b]Balatroni[/b] sostituiscono qualunque artista.
[b]3. Acclamazione[/b], sommando:
• lo spettacolo: il valore pieno (corona d'alloro) o quello per gli artisti mancanti (−1, −2…);
• +5 per ogni spettacolo diverso già messo in scena nelle giornate precedenti;
• +4 per ogni [b]Stella[/b] di un tipo di artista presente nello spettacolo;
• i nobili davanti ai vostri cancelli: Imperatore +7, console +5, senatore +3;
• +5 per promotore, +3 per dono, +3 per ogni Aquila che decidete di spendere.
Il segnalino sale se il risultato è più alto; in ogni caso guadagnate tante monete quanta Acclamazione avete fatto.
Alla fine della fase l'impresario più acclamato riceve un [b]Dono[/b] dell'Imperatore (a parità chi è più in basso nella pila). Dopo la quarta giornata i doni sono finiti e la partita termina.

[font_size=26][color=#e07a52]Fase 5 · Cerimonie di chiusura[/color][/font_size]
Chi si è esibito ritira uno degli artisti usati; lo spettacolo resta scoperto e darà +5 nelle esibizioni successive. Il [b]meno acclamato[/b] (a parità chi è in cima alla pila) sottrae una tessera a scelta al più acclamato e sceglie il primo giocatore della giornata seguente.

[font_size=26][color=#e07a52]Stelle[/color][/font_size]
Chi ha almeno [b]3 tessere[/b] di un tipo e più di ogni altro prende la Stella di quel tipo (dal tabellone o da un avversario). La si perde quando qualcuno ne ha di più (se i nuovi primi sono a pari merito la Stella torna sul tabellone) o quando si scende a 2 o meno. I Balatroni non contano per le Stelle.

[font_size=26][color=#e07a52]Fine della partita[/color][/font_size]
Ogni Aquila rimasta vale 3 di Acclamazione. Vince chi ha più Acclamazione; a parità più monete, poi più Stelle, poi chi è più in basso nella pila.

[font_size=26][color=#e07a52]Note della versione digitale[/color][/font_size]
• Le tessere sono quelle del regolamento: 24 gladiatori, 12 per ogni altro tipo, 6 balatroni, 6 Aquile (le Aquile si trasformano subito in segnalini).
• I due piccoli spettacoli iniziali si distribuiscono in coppia come nel modulo per Tabletop Simulator: un cerchio bianco con un cerchio nero, oppure un triangolo bianco con un triangolo nero.
• In cinque i pallini stampati non bastano per cinque coppie di cancelli: quando non restano coppie con i pallini si sceglie una coppia libera lontana dai cancelli altrui.
• Gli scambi sono fra due impresari alla volta, con al massimo 6 proposte per turno. Il movimento dei nobili con i dadi è obbligatorio.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if popup:
		z_index = 30
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.82)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.dark_style(8, 0.97))
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_left = 80
	pc.offset_right = -80
	pc.offset_top = 40
	pc.offset_bottom = -40
	add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var hh := HBoxContainer.new()
	vb.add_child(hh)
	var t := UI.title("Regole", 44)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(t)
	var back := UI.primary(UI.button("Chiudi" if popup else "Torna al menu", 240, 52, 22))
	back.pressed.connect(func():
		if popup:
			queue_free()
		else:
			main.show_menu())
	hh.add_child(back)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	sc.add_child(inner)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.add_theme_font_size_override("bold_font_size", 22)
	rt.text = TEXT
	inner.add_child(rt)
	inner.add_child(UI.title("Gli spettacoli", 34))
	for size in 3:
		inner.add_child(UI.heading(["Piccoli (2 cancelli, distribuiti all'inizio)", "Medi (3 cancelli)", "Grandi (4 cancelli)"][size], 26))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		inner.add_child(flow)
		for s in D.SPECTACLES:
			if s["size"] != size:
				continue
			var v := VBoxContainer.new()
			var tx := UI.spect_tex(s["id"])
			v.add_child(UI.icon_rect(tx, Vector2(400, 400.0 * tx.get_height() / tx.get_width())))
			v.add_child(UI.label(s["name"] + ((" · costo %d" % s["cost"]) if s["cost"] > 0 else ""), 19, UI.STONE, UI.font_semi))
			flow.add_child(v)
	inner.add_child(UI.title("Gli artisti", 34))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 16)
	fl.add_theme_constant_override("v_separation", 10)
	inner.add_child(fl)
	for k in D.TYPES + [D.WILD, D.AQUILA]:
		var h := HBoxContainer.new()
		h.add_child(UI.icon_rect(UI.tile_tex(k), Vector2(56, 56)))
		if k in D.TYPES:
			h.add_child(UI.icon_rect(UI.star_tex(k), Vector2(48, 56)))
		h.add_child(UI.label("%s (%d)" % [D.TYPE_NAME[k], D.BAG_TOTAL[k]], 20, UI.STONE, UI.font_semi))
		fl.add_child(h)
