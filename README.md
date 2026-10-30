# Colosseum — versione digitale (Godot 4)

Versione digitale di **Colosseum: The Grand Spectacle**, la nuova edizione del gioco di Wolfgang Kramer e
Markus Lübke: impresari romani che producono spettacoli nell'Anfiteatro Flavio. Tabellone, plance, tessere
e pedine vengono dal modulo Tabletop Simulator; le regole seguono il regolamento in bozza della seconda
edizione. Tema «Anfiteatro Flavio»: travertino, sabbia dell'arena, rosso pompeiano e oro delle corone d'alloro.
Caratteri liberi (OFL): Cinzel Decorative per il titolo, Cinzel per le intestazioni (le capitali romane delle
tessere), EB Garamond per i testi.

La pubblicazione non parte da sola: Actions → **Pubblica** → *Run workflow*
(ludoteca privata su `colosseum.ludoteca-digitale.com` con i segreti Cloudflare, e GitHub Pages finché il
repository è pubblico).

## Avvio
1. Apri Godot 4 (testato su 4.7) → *Importa* → seleziona `project.godot`.
2. Premi **F5**. F11 alterna schermo intero e finestra.

## Cosa c'è
- **Tutte le regole** della seconda edizione per 3, 4 o 5 impresari, in 4 giornate da 5 fasi:
  investimenti (cancelli, promotori, spettacoli da pianificare, Tempio della Fortuna), aste dei lotti di
  artisti con i pilastri e Mercurio (le Aquile valgono 6 monete di credito), scambi guidati dall'impresario
  attivo, movimento dei nobili con i dadi (caselle occupate saltate, Aquile sulle medaglie, Aquile spese per
  spostarli anche all'indietro), esibizioni con tutti i bonus (repliche, Stelle, nobili, promotori, doni,
  Aquile), Doni dell'Imperatore, cerimonie di chiusura (artista ritirato, furto del meno acclamato, scelta del
  primo giocatore), Stelle che passano di mano, fine partita con le Aquile e gli spareggi.
- **Tutti i 34 spettacoli** (12 piccoli, 10 medi, 12 grandi) con le illustrazioni originali: in mano si
  vede il lato da pianificare, quelli già messi in scena mostrano l'illustrazione.
- **Avversari IA** (facile, normale, difficile): stimano lo spettacolo migliore che potranno mettere in scena,
  danno un valore in monete a ogni lotto, cancello, promotore e scambio, scelgono le mosse dei nobili che
  portano più ospiti ai propri cancelli e meno a quelli degli avversari ancora da esibirsi. Propongono e
  valutano scambi anche con le persone. In ogni decisione c'è il pulsante **Decida l'IA**.
- **Tabellone 2D** come quello stampato, con le pedine originali (cancelli, pilastri, templi, corone,
  tessere degli artisti nei mercati) e i nobili come busti d'oro, d'argento e di bronzo; zoom con la rotella.
- **Tabellone 3D** girevole con i pezzi della **versione deluxe** del modulo TTS: busti dell'Imperatore, dei
  consoli e dei senatori, Mercurio, cancelli, pilastri e templi nel colore dell'impresario, segnalino del primo
  giocatore; le Stelle e i promotori sono sagome spesse come nel modulo, in piedi davanti ai cancelli di chi li
  possiede. Si passa dall'uno all'altro con **2D / 3D**.
- **Regole** in italiano con l'elenco illustrato degli spettacoli e degli artisti, dal menu e in partita.

## Comandi
- Le scelte sul tabellone (cancelli, lotti, nobili e caselle d'arrivo) si fanno toccando le caselle evidenziate.
- Tabellone 2D: rotella per lo zoom, trascina per spostare quando è ingrandito.
- Tabellone 3D: trascina per ruotare, tasto destro (o Maiusc + trascina) per spostare, rotella per lo zoom.
- Tocca la plancia di un impresario per vederne tessere, Stelle e spettacoli.
- **Spettacoli in vendita** mostra in ogni momento i medi e i grandi ancora da pianificare, con quanto
  renderebbero ora con i propri artisti.

## Gioco online
Dal menu, **Gioca online** (anche dalla versione web). Usa lo stesso progetto Firebase degli altri giochi
(Realtime Database), con le stanze sotto `colosseum/rooms`: la sezione generica `$game` delle regole del
database (già pubblicata con Titans, El Grande e Ghouls) lo copre, non serve toccare le regole.

- **Chi crea la stanza** è il Rosso: nel menu sceglie il numero di impresari e segna «Persona» i posti per
  gli amici (quelli segnati IA li gioca il computer), scrive il nome, preme *Crea una stanza* e comunica il
  codice di 4 lettere. Quando gli amici sono entrati preme *Inizia online*; i posti rimasti vuoti li gioca l'IA.
- **Gli amici** scrivono il nome e il codice e premono *Entra*.
- Ogni decisione è una mossa numerata nel database: tutti i dispositivi fanno girare lo stesso motore con lo
  stesso seme, quindi la partita è identica. Se cade la linea si rientra con lo stesso codice; se un giocatore
  tace per un minuto, al suo posto gioca l'IA finché non rientra. Gli scambi fra persone funzionano online:
  la proposta arriva a chi la riceve, che accetta o rifiuta.

## Interpretazioni
Dove il regolamento in bozza lascia spazio, la versione digitale fa così:
- tessere secondo il regolamento: 24 gladiatori, 12 per ogni altro tipo, 6 balatroni e 6 Aquile;
- i due piccoli spettacoli iniziali si distribuiscono in coppia come fa lo script del modulo TTS (cerchio
  bianco + cerchio nero, oppure triangolo bianco + triangolo nero);
- i cancelli di partenza si scelgono fra le coppie con i pallini del numero di giocatori; in cinque i pallini
  stampati non bastano, e quando non restano coppie si sceglie una coppia libera lontana dagli altri cancelli;
- il movimento dei nobili con i dadi è obbligatorio; il nobile si ferma dopo aver contato solo le caselle libere;
- gli scambi sono fra due impresari alla volta (niente triangolazioni), al massimo 6 proposte per turno;
- uno spettacolo piccolo si può mettere in scena con almeno un artista, purché i mancanti non superino la
  striscia stampata sulla tessera;
- a parità per il meno acclamato vale chi è in cima alla pila, per il più acclamato chi è in fondo.

## Struttura
- `scripts/core/engine.gd` — motore delle regole (senza grafica), `ai.gd` — l'IA.
- `scripts/data/cs_data.gd` — artisti, spettacoli, costi, nobili e colori; `data/layout.json` — le posizioni
  sul tabellone (tracciato dei nobili, cancelli, mercati, templi, Acclamazione), ricavate dai punti di aggancio
  del modulo TTS.
- `scripts/ui/` — menu, partita, tabellone 2D e 3D, regole.
- `scripts/net/` — Firebase e partita online in lockstep.
- `assets/` — immagini originali estratte dal modulo con `tools/estrai_materiale.py`; in `assets/modelli/` i
  modelli 3D deluxe (ricavati dagli asset bundle Unity del modulo e alleggeriti a qualche migliaio di triangoli)
  e le sagome estruse di Stelle e promotori (`tools/estrudi_sagome.py`).
- `tests/sim.gd` — partite IA contro IA senza grafica:
  `godot --headless --path . -s tests/sim.gd -- 4 8 1` (4 impresari, 8 partite, IA normale).
- `tests/online_play.gd` + `tests/firebase_mock.py` — partita online completa fra due istanze su un
  finto Firebase locale.
- `tests/shot.gd` — fotografie dell'interfaccia (serve un display, anche virtuale).
