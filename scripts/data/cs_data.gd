extends RefCounted
## Dati di Colosseum: The Grand Spectacle (regolamento in bozza della seconda edizione).
## Artisti (Performer), tessere Spettacolo, costi, nobili e colori dei giocatori.

## I 12 tipi di artisti con la loro Stella, nell'ordine della plancia dell'impresario.
const TYPES := ["gladiatore", "comico", "musico", "cavallo", "mangiafuoco", "sacerdote", "nave", "leone",
	"scenografo", "decoratore", "auriga", "elefante"]
const WILD := "balatro"
const AQUILA := "aquila"

const TYPE_NAME := {
	"gladiatore": "Gladiatori", "comico": "Comici", "musico": "Musici", "cavallo": "Cavalli",
	"mangiafuoco": "Mangiafuoco", "sacerdote": "Sacerdoti", "nave": "Navi", "leone": "Leoni",
	"scenografo": "Scenografi", "decoratore": "Decoratori", "auriga": "Aurighi", "elefante": "Elefanti",
	"balatro": "Balatroni", "aquila": "Aquila"}
const TYPE_ONE := {
	"gladiatore": "gladiatore", "comico": "comico", "musico": "musico", "cavallo": "cavallo",
	"mangiafuoco": "mangiafuoco", "sacerdote": "sacerdote", "nave": "nave", "leone": "leone",
	"scenografo": "scenografo", "decoratore": "decoratore", "auriga": "auriga", "elefante": "elefante",
	"balatro": "balatrone", "aquila": "aquila"}
## «la Stella dei …»
const TYPE_STAR := {
	"gladiatore": "dei Gladiatori", "comico": "dei Comici", "musico": "dei Musici", "cavallo": "dei Cavalli",
	"mangiafuoco": "dei Mangiafuoco", "sacerdote": "dei Sacerdoti", "nave": "delle Navi", "leone": "dei Leoni",
	"scenografo": "degli Scenografi", "decoratore": "dei Decoratori", "auriga": "degli Aurighi", "elefante": "degli Elefanti"}
## colore delle tessere (per i segnalini disegnati e i grafici)
const TYPE_COL := {
	"gladiatore": Color("#c0392b"), "comico": Color("#f1d331"), "musico": Color("#7cc242"), "cavallo": Color("#d9b98a"),
	"mangiafuoco": Color("#3b2f2a"), "sacerdote": Color("#e9e9e9"), "nave": Color("#62c6ee"), "leone": Color("#ef7d22"),
	"scenografo": Color("#1f4fa3"), "decoratore": Color("#16804a"), "auriga": Color("#7d5ba6"), "elefante": Color("#9a9a9a"),
	"balatro": Color("#b55fc4"), "aquila": Color("#b9c3cc")}

## Tessere nel sacchetto (regolamento: 24 gladiatori, 12 per ogni altro tipo, 6 balatroni, 6 aquile)
const BAG_TOTAL := {
	"gladiatore": 24, "comico": 12, "musico": 12, "cavallo": 12, "mangiafuoco": 12, "sacerdote": 12, "nave": 12,
	"leone": 12, "scenografo": 12, "decoratore": 12, "auriga": 12, "elefante": 12, "balatro": 6, "aquila": 6}
## Tessere iniziali (dorso scuro): 30, comprese nei totali qui sopra
const STARTING := {"gladiatore": 9, "comico": 3, "musico": 3, "cavallo": 3, "nave": 3, "leone": 3, "scenografo": 3,
	"decoratore": 3}
const START_DRAW := {3: 8, 4: 7, 5: 6}

const START_COINS := 30
const COST_GATE := 10
const COST_PROMOTER := 7
const COST_TEMPLE := 7
const AQUILA_COINS := 6
const MIN_BID := 8
const PROMOTERS := 12
const ROUNDS := 4
const GIFTS := 3

## Nobili: 0 imperatore (oro), 1-2 consoli (argento), 3-5 senatori (bronzo)
const NOBLE_KIND := ["imperatore", "console", "console", "senatore", "senatore", "senatore"]
const NOBLE_NAME := ["l'Imperatore", "un console", "un console", "un senatore", "un senatore", "un senatore"]
const NOBLE_CAP := ["L'Imperatore", "Un console", "Un console", "Un senatore", "Un senatore", "Un senatore"]
const NOBLE_DI := ["dell'Imperatore", "del console", "del console", "del senatore", "del senatore", "del senatore"]
const NOBLE_BONUS := [7, 5, 5, 3, 3, 3]
## caselle di partenza sul tracciato (indici 0-35, in senso orario dalla medaglia in alto)
const NOBLE_START := [0, 12, 24, 6, 18, 30]
const TRACK := 36

## Caselle di partenza dei cancelli: numero di giocatori ammessi (i pallini stampati sul tabellone)
const START_GATES := {3: [4], 4: [4], 8: [3, 4], 9: [3, 4], 14: [4, 5], 15: [4, 5], 20: [3, 4], 21: [3, 4, 5],
	22: [4], 26: [5], 27: [5], 32: [3, 4, 5], 33: [3, 4, 5]}

## Giocatori: colore, nome del colore, file della plancia e della corona
const COLORS := [
	{"key": "rosso", "name": "Rosso", "col": Color("#c8503a"), "dark": Color("#7a2a1d")},
	{"key": "azzurro", "name": "Azzurro", "col": Color("#4f8fc4"), "dark": Color("#24496b")},
	{"key": "bianco", "name": "Bianco", "col": Color("#efe9d6"), "dark": Color("#8f8a78")},
	{"key": "sabbia", "name": "Sabbia", "col": Color("#d9bf8c"), "dark": Color("#80653a")},
	{"key": "nero", "name": "Nero", "col": Color("#4b4544"), "dark": Color("#1c1a19")},
]

## Spettacoli. size: 0 piccolo (2 cancelli), 1 medio (3), 2 grande (4).
## req: artisti richiesti; full: Acclamazione piena; strip: Acclamazione con 1, 2, 3… artisti mancanti.
## set (solo piccoli): coppie distribuite all'inizio (cerchio bianco + cerchio nero, triangolo bianco + nero).
const SPECTACLES := [
	{"id": "p_amphitryon", "name": "Anfitrione", "orig": "Amphitryon", "size": 0, "num": 0, "cost": 0, "set": "wc",
		"req": {"comico": 2, "decoratore": 1}, "full": 7, "strip": [5, 3]},
	{"id": "p_pugnae", "name": "Pugnae Bestiae", "orig": "Pugnae Bestiae", "size": 0, "num": 0, "cost": 0, "set": "wc",
		"req": {"cavallo": 2, "leone": 2}, "full": 9, "strip": [7, 5, 3]},
	{"id": "p_giano", "name": "La corsa di Giano", "orig": "Race of Janus", "size": 0, "num": 0, "cost": 0, "set": "wc",
		"req": {"gladiatore": 2, "cavallo": 2}, "full": 9, "strip": [7, 5, 3]},
	{"id": "p_naumachia", "name": "Naumachia", "orig": "Naumachia", "size": 0, "num": 0, "cost": 0, "set": "wt",
		"req": {"gladiatore": 2, "nave": 2}, "full": 9, "strip": [7, 5, 3]},
	{"id": "p_aurora", "name": "Ode all'Aurora", "orig": "Ode to Aurora", "size": 0, "num": 0, "cost": 0, "set": "wt",
		"req": {"musico": 2, "scenografo": 1}, "full": 7, "strip": [5, 3]},
	{"id": "p_munus", "name": "Tributo a Munus", "orig": "Tribute to Munus", "size": 0, "num": 0, "cost": 0, "set": "wt",
		"req": {"gladiatore": 2, "decoratore": 1}, "full": 7, "strip": [5, 3]},
	{"id": "p_spartaco", "name": "La cavalleria di Spartaco", "orig": "Cavalry of Spartacus", "size": 0, "num": 0, "cost": 0,
		"set": "bt", "req": {"gladiatore": 3, "cavallo": 3}, "full": 12, "strip": [10, 8, 5, 2]},
	{"id": "p_venatio", "name": "Venatio", "orig": "Venatio", "size": 0, "num": 0, "cost": 0, "set": "bt",
		"req": {"cavallo": 2, "leone": 2, "elefante": 1}, "full": 11, "strip": [9, 7, 5, 2]},
	{"id": "p_drama", "name": "Drama Ultima", "orig": "Drama Ultima", "size": 0, "num": 0, "cost": 0, "set": "bt",
		"req": {"comico": 3, "mangiafuoco": 1, "scenografo": 2}, "full": 12, "strip": [10, 8, 5, 2]},
	{"id": "p_cupido", "name": "Inno a Cupido", "orig": "Anthem to Cupidon", "size": 0, "num": 0, "cost": 0, "set": "bc",
		"req": {"comico": 1, "musico": 3, "scenografo": 1, "decoratore": 1}, "full": 12, "strip": [10, 8, 5, 2]},
	{"id": "p_navi", "name": "Le navi", "orig": "The Ships", "size": 0, "num": 0, "cost": 0, "set": "bc",
		"req": {"gladiatore": 3, "nave": 2}, "full": 11, "strip": [9, 7, 5, 2]},
	{"id": "p_sanniti", "name": "L'ultimo dei Sanniti", "orig": "The Last of the Samnites", "size": 0, "num": 0, "cost": 0,
		"set": "bc", "req": {"gladiatore": 3, "scenografo": 1, "decoratore": 1}, "full": 11, "strip": [9, 7, 5, 2]},

	{"id": "m01", "name": "L'ira di Anfitrite", "orig": "Amphitrite's Anger", "size": 1, "num": 1, "cost": 25,
		"req": {"gladiatore": 3, "nave": 3, "decoratore": 2}, "full": 17, "strip": [14, 11, 8, 5, 2]},
	{"id": "m02", "name": "Cave Leonem Cruciatum", "orig": "Cave Leonem Cruciatum", "size": 1, "num": 2, "cost": 13,
		"req": {"gladiatore": 3, "leone": 3, "elefante": 2}, "full": 17, "strip": [14, 11, 8, 5, 2]},
	{"id": "m03", "name": "Reziario contro Secutore", "orig": "Retiarus vs. Secutor", "size": 1, "num": 3, "cost": 14,
		"req": {"gladiatore": 2, "cavallo": 2, "scenografo": 1, "decoratore": 1, "auriga": 2}, "full": 18, "strip": [15, 12, 9, 6, 3]},
	{"id": "m04", "name": "Il Satyricon di Momo", "orig": "Satyricon of Momus", "size": 1, "num": 4, "cost": 14,
		"req": {"comico": 2, "mangiafuoco": 2, "sacerdote": 2, "scenografo": 1, "decoratore": 1}, "full": 18, "strip": [15, 12, 9, 6, 3]},
	{"id": "m05", "name": "Le lire di Mercurio", "orig": "Lyres of Mercury", "size": 1, "num": 5, "cost": 17,
		"req": {"musico": 3, "mangiafuoco": 2, "sacerdote": 1, "decoratore": 2, "auriga": 1}, "full": 20, "strip": [17, 14, 11, 7, 3]},
	{"id": "m06", "name": "I pony di Epona", "orig": "The Ponies of Epona", "size": 1, "num": 6, "cost": 20,
		"req": {"gladiatore": 3, "cavallo": 3, "sacerdote": 1, "scenografo": 2}, "full": 23, "strip": [20, 16, 12, 8, 4]},
	{"id": "m07", "name": "Bacco e le Ninfe", "orig": "Bacchus and the Nymphs", "size": 1, "num": 7, "cost": 21,
		"req": {"musico": 2, "mangiafuoco": 3, "sacerdote": 3, "scenografo": 1}, "full": 25, "strip": [22, 18, 14, 10, 5]},
	{"id": "m08", "name": "Mare Spielbergus", "orig": "Mare Spielbergus", "size": 1, "num": 8, "cost": 22,
		"req": {"gladiatore": 3, "nave": 3, "scenografo": 1, "elefante": 2}, "full": 27, "strip": [24, 20, 16, 12, 6]},
	{"id": "m09", "name": "La processione dei leoni", "orig": "Lion's Procession", "size": 1, "num": 9, "cost": 24,
		"req": {"comico": 1, "musico": 2, "leone": 2, "decoratore": 1, "elefante": 2}, "full": 30, "strip": [26, 22, 18, 14, 9, 4]},
	{"id": "m10", "name": "Circus Maximus", "orig": "Circus Maximus", "size": 1, "num": 10, "cost": 25,
		"req": {"gladiatore": 3, "cavallo": 3, "scenografo": 3, "decoratore": 1}, "full": 32, "strip": [28, 24, 20, 15, 10, 5]},

	{"id": "g11", "name": "I dialoghi di Plutone", "orig": "The Dialogues of Pluto", "size": 2, "num": 11, "cost": 25,
		"req": {"comico": 2, "mangiafuoco": 1, "scenografo": 2, "auriga": 2, "elefante": 3}, "full": 33, "strip": [29, 25, 20, 15, 10, 5]},
	{"id": "g12", "name": "E Tellure creò il mondo", "orig": "And Tellus Created the World", "size": 2, "num": 12, "cost": 26,
		"req": {"comico": 2, "musico": 1, "mangiafuoco": 2, "sacerdote": 3, "decoratore": 2, "auriga": 1}, "full": 35, "strip": [30, 25, 20, 15, 10, 5]},
	{"id": "g13", "name": "Safari Optimus Maximus", "orig": "Safari Optimus Maximus", "size": 2, "num": 13, "cost": 27,
		"req": {"gladiatore": 4, "leone": 3, "scenografo": 2, "elefante": 2}, "full": 36, "strip": [31, 26, 21, 16, 11, 5]},
	{"id": "g14", "name": "Le galee di Apollo", "orig": "The Galleys of Apollo", "size": 2, "num": 14, "cost": 28,
		"req": {"gladiatore": 4, "comico": 1, "mangiafuoco": 1, "nave": 4, "decoratore": 1}, "full": 38, "strip": [33, 28, 23, 18, 12, 6]},
	{"id": "g15", "name": "I leggendari cacciatori di leoni", "orig": "Legendary Lion Hunters", "size": 2, "num": 15, "cost": 29,
		"req": {"gladiatore": 3, "comico": 1, "mangiafuoco": 1, "leone": 3, "scenografo": 2, "decoratore": 1, "elefante": 2},
		"full": 42, "strip": [37, 32, 27, 21, 15, 8]},
	{"id": "g16", "name": "La cavalcata equestre di Venere", "orig": "Venus's Equestrian Cavalcade", "size": 2, "num": 16, "cost": 32,
		"req": {"comico": 1, "musico": 3, "cavallo": 3, "mangiafuoco": 1, "sacerdote": 1, "scenografo": 1, "auriga": 3},
		"full": 44, "strip": [39, 33, 27, 21, 15, 8]},
	{"id": "g17", "name": "La furia di Nettuno", "orig": "Neptune's Fury", "size": 2, "num": 17, "cost": 35,
		"req": {"gladiatore": 3, "comico": 2, "mangiafuoco": 2, "sacerdote": 1, "nave": 4, "decoratore": 1},
		"full": 45, "strip": [40, 34, 28, 22, 15, 8]},
	{"id": "g18", "name": "I segreti svelati di Iside", "orig": "Isis's Revealed Secrets", "size": 2, "num": 18, "cost": 35,
		"req": {"comico": 3, "musico": 3, "mangiafuoco": 2, "sacerdote": 2, "scenografo": 2, "decoratore": 1},
		"full": 45, "strip": [40, 34, 28, 22, 15, 8]},
	{"id": "g19", "name": "Le grandi profezie di Giove", "orig": "Great Prophecies of Jupiter", "size": 2, "num": 19, "cost": 37,
		"req": {"gladiatore": 1, "musico": 1, "cavallo": 1, "mangiafuoco": 3, "sacerdote": 3, "scenografo": 2, "decoratore": 2},
		"full": 47, "strip": [42, 37, 31, 25, 18, 8]},
	{"id": "g20", "name": "La marcia trionfale di Cesare", "orig": "Caesar's Triumphal March", "size": 2, "num": 20, "cost": 40,
		"req": {"gladiatore": 2, "comico": 2, "musico": 2, "cavallo": 3, "mangiafuoco": 2, "sacerdote": 1, "decoratore": 1, "auriga": 3},
		"full": 50, "strip": [45, 40, 34, 28, 20, 10]},
	{"id": "g21", "name": "Le nozze del figlio dell'Imperatore", "orig": "Wedding of the Emperor's Son", "size": 2, "num": 21, "cost": 43,
		"req": {"gladiatore": 3, "musico": 2, "cavallo": 4, "mangiafuoco": 3, "sacerdote": 3, "scenografo": 1, "decoratore": 2},
		"full": 53, "strip": [48, 43, 37, 29, 21, 11]},
	{"id": "g22", "name": "L'incoronazione dell'Imperatore", "orig": "The Emperor's Coronation Ceremonies", "size": 2, "num": 22, "cost": 46,
		"req": {"gladiatore": 4, "musico": 2, "sacerdote": 2, "nave": 3, "leone": 3, "scenografo": 2, "decoratore": 1, "elefante": 3},
		"full": 56, "strip": [51, 45, 38, 30, 21, 11]},
]

const SIZE_NAME := ["piccolo", "medio", "grande"]
const SIZE_GATES := [2, 3, 4]
## artisti che possono mancare al massimo: piccolo = ne basta 1, medio = 5 in meno, grande = 6 in meno
const SIZE_SLACK := [99, 5, 6]

static var _by_id := {}


static func spect(id: String) -> Dictionary:
	if _by_id.is_empty():
		for s in SPECTACLES:
			_by_id[s["id"]] = s
	return _by_id[id]


static func req_total(s: Dictionary) -> int:
	var n := 0
	for k in s["req"]:
		n += int(s["req"][k])
	return n
