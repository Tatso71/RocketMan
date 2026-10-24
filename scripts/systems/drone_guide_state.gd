extends RefCounted

const Tutorial = preload("res://scripts/systems/ocra_tutorial.gd")
const MESSAGES := {
	"welcome": [10, "Atterraggio completato", "Siamo arrivati! Sei ancora in cabina: clic destro per gestire la nave. Scendi con la scala al letto, poi al laboratorio. Ogni stanza si illumina quando puoi usarla."],
	"bed_rest": [35, "Una pausa nel letto", "La stanza centrale e il nostro rifugio. Clic destro sul letto e Riposa: recuperi energia personale e integrita della tuta. La batteria della nave invece alimenta i laboratori e va gestita a parte."],
	"first_dig": [15, "Il primo scavo", "Punta il terreno e usa il raggio Pulse per scavare. Io ti seguo e trasporto il materiale che non entra nello zaino. Non allontaniamoci troppo dalla nave."],
	"lab_plan": [20, "Il primo cubo creatore", "Scava una stanza 4 x 3 con pavimento. Clic destro nel punto libero, scegli Laboratorio e posa il cubo. Avvicinandoti vedrai cosa manca: 6 pietra e 4 rame. Conferma il trasferimento per avviarlo."],
	"tutorial_collect": [65, "Prima il laboratorio", "Raccogli e porta sul posto 6 pietra e 4 rame per il laboratorio. Contano insieme il tuo zaino e il mio carico se sono vicino. Puoi anche prelevare le scorte dalla nave; la pietra nel terreno inizia a 5 m."],
	"tutorial_excavate": [65, "I materiali ci sono", "Hai le materie per il laboratorio! Ora libera una stanza larga 4 celle e alta 3, lasciando un pavimento solido. Ti avviso appena lo spazio e pronto per posare il cubo."],
	"tutorial_place": [70, "La stanza e abbastanza grande", "Qui entra un laboratorio! Clic destro nell'area, seleziona Laboratorio e Posiziona cubo. Sposta il cubo vicino al pavimento: tutto il rettangolo tratteggiato deve entrare nello spazio scavato. Poi fai clic."],
	"tutorial_fund": [65, "Riempiamo il cubo", "Il cubo e pronto. Porta 6 pietra e 4 rame tra zaino e Robbie, avvicinati e conferma il trasferimento. Le materie nella stiva non sono disponibili a distanza."],
	"tutorial_build": [60, "Sta prendendo forma", "Il laboratorio si sta aprendo! Quando la barra sara piena sbloccheremo luci, pompa e altre due rotte. Intanto mantieni una via di ritorno con le scale."],
	"pump_plan": [40, "Pompa di drenaggio", "La pompa dipende dal laboratorio. Il cubo occupa 2 x 2 m e costa 3 pietra e 4 rame. Puo stare nell'acqua: drena le celle collegate vicine, ma richiede laboratorio acceso e batteria della nave."],
	"pump_built": [45, "Pompa attiva", "La pompa sta drenando l'acqua vicina attraverso i passaggi aperti. Consuma la batteria della nave; non aspira attraverso la roccia e si ferma se il laboratorio non e alimentato."],
	"cargo_full": [80, "Carico pieno", "Non possiamo raccogliere altro. Raggiungi un laboratorio illuminato, clic destro e scegli Deposita materiali. Aspetta che sia vicino: solo cosi scarichi anche il mio carico."],
	"drone_unavailable": [70, "Devo avvicinarmi", "Il tuo zaino e pieno, ma io sono troppo lontano per aiutarti. Aspettami in un passaggio aperto, oppure rientra in officina e scarica il materiale."],
	"signal_limit": [75, "Limite del collegamento", "Sono al limite del segnale della nave. Da qui non posso trasportare o costruire con te. Torna verso di me: potremo ampliare il mio raggio con la ricerca."],
	"build_resources": [45, "Prima il cubo, poi le materie", "Puoi posare il cubo anche senza materiali. Il tratteggio riserva l'ingombro; quando gli vai vicino vedrai cosa manca. Il trasferimento avviene solo con la tua conferma, dal carico presente sul posto."],
	"build_space": [40, "La stanza del laboratorio", "Libera un rettangolo di 4 celle per 3, con pavimento sotto tutte e 4 le colonne. Puoi restare dentro mentre lo monto! Tienimi vicino ed evita acqua e gas."],
	"lab_built": [55, "Laboratorio attivo", "La barra e piena: il laboratorio ora funziona! Consuma la batteria della nave. Clic destro per usarlo o spegnerlo; dalla cabina puoi potenziare gli accumulatori della nave."],
	"lamp_crafted": [50, "Portiamo luce nelle gallerie", "Il kit luce e nel carico. Dal menu Costruisci scegli Luce sotto Laboratorio, poi Posiziona cubo. Cerca un pavimento libero nel raggio del laboratorio: 8 metri di base, di piu con i potenziamenti."],
	"lamp_plan": [30, "Un cubo per fare luce", "Clic destro su una cella libera con pavimento e scegli Luce. Anche lei nasce da un cubo: porta 1 terra e 1 rame, conferma il trasferimento e aspetta che si apra. Serve un laboratorio alimentato vicino."],
	"lamp_placed": [30, "Una luce che resta", "Questa luce rimane qui anche quando ci allontaniamo. Continuiamo ad ampliare le gallerie dal laboratorio, mantenendo una via di ritorno alla nave."],
	"deposited": [25, "Materiale al sicuro", "Carico scaricato! Il deposito e separato da cio che portiamo con noi. Clic destro sul laboratorio e Preleva materiali; a bordo nell'inventario trovi anche Prepara laboratorio per caricare le materie mancanti."],
	"gas_danger": [100, "Gas! Indietro!", "La nube sta danneggiando la tuta. Allontanati e torna in una zona pulita. In nave la tuta si ripristina; usa lo scanner prima di aprire nuove sacche."],
	"water_danger": [100, "Stai subendo danni!", "Sei sott'acqua e stai perdendo integrita! Risali subito con il comando di salita. Io resto fuori dall'acqua e lampeggio in rosso: non posso seguirti li. Una pompa puo asciugare la zona."],
	"gas_leak": [90, "Sacca di gas aperta", "Abbiamo aperto una sacca di gas! Allontaniamoci dalla nube: non possiamo rendere operativo un laboratorio in un'area contaminata."],
	"water_leak": [90, "Infiltrazione!", "L'acqua sta entrando nelle gallerie. Mantieni una via di risalita e proteggi il cantiere: serve una stanza asciutta per installare il laboratorio."],
	"energy_low": [85, "Batteria nave quasi scarica", "Il raggio e i laboratori usano la stessa batteria. Spegni le postazioni inutili e rientra in cabina: Batteria e potenziamenti permette di gestire gli accumulatori. Il letto non ricarica la nave."],
	"ladder_tip": [25, "Non dimenticare la risalita", "Con B costruisci subito una scala: costa 2 terra, senza cubi ne attese. La monti tu, anche senza drone, laboratorio o batteria. Manteniamo sempre una via di ritorno!"],
	"tools": [20, "Prima analizziamo", "Lo Scanner rivela il materiale del blocco e le sacche vicine. Alcune rocce richiedono strumenti migliori; i nuclei indistruttibili vanno aggirati."],
}
const REPEATING := ["cargo_full", "drone_unavailable", "signal_limit", "build_resources", "build_space", "gas_danger", "water_danger", "gas_leak", "water_leak", "energy_low"]
const PERSISTENT := {"tutorial_collect": 20.0, "tutorial_excavate": 20.0, "tutorial_place": 20.0, "tutorial_fund": 25.0, "water_danger": 10.0}
const FACTS := ["mined", "ladder", "lab_built", "lamp_crafted", "lamp_placed", "pump_built", "deposited"]
var seen: Array[String] = []
var facts: Dictionary = {}
var muted := false
var active_id := ""
var remaining := 0.0
var elapsed := 0.0
var gap := 1.0
var context_id := ""
var active_manual := false
var last_shown: Dictionary = {}
var latched: Array[String] = []
var ocra := Tutorial.new()

func message(id: String) -> Array:
	return MESSAGES[id] if MESSAGES.has(id) else ocra.message(id)

func recurring(id: String) -> bool:
	return id in REPEATING or PERSISTENT.has(id) or id.begins_with("ocra/")

func offer(id: String, manual: bool = false) -> bool:
	var entry := message(id)
	if entry.is_empty():
		return false
	if not manual:
		if muted or (gap > 0 and int(entry[0]) < 80) or (id in seen and not recurring(id)) or id in latched:
			return false
		if elapsed - float(last_shown.get(id, -100)) < (25.0 if id.begins_with("ocra/") else float(PERSISTENT.get(id, 35))):
			return false
		if not active_id.is_empty() and int(entry[0]) <= int(message(active_id)[0]):
			return false
	active_id = id
	active_manual = manual
	remaining = clampf(float(str(entry[2]).length()) / 17.0, 8, 18)
	if id not in seen:
		seen.append(id)
	if id in REPEATING and not PERSISTENT.has(id) and id not in latched:
		latched.append(id)
	last_shown[id] = elapsed
	return true

func tick(delta: float, current_context: String) -> void:
	elapsed += delta
	gap = maxf(0, gap - delta)
	# Re-arm a recurring hint only after its actual condition has cleared.
	for id: String in latched.duplicate():
		if id != current_context and id not in ["gas_leak", "water_leak"]:
			latched.erase(id)
	if recurring(active_id) and active_id != current_context and not active_manual and active_id not in ["gas_leak", "water_leak"]:
		dismiss()
	context_id = current_context
	remaining = maxf(0, remaining - delta)
	if remaining <= 0 and not active_id.is_empty():
		dismiss()

func dismiss() -> void:
	active_id = ""
	remaining = 0
	active_manual = false
	gap = 2

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		dismiss()

func snapshot() -> Dictionary:
	return {"seen": seen.duplicate(), "facts": facts.duplicate(), "muted": muted, "ocra": ocra.snapshot()}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("seen", []) is Array or not data.get("facts", {}) is Dictionary or not data.get("muted", false) is bool:
		return false
	var next_tutorial := Tutorial.new()
	if not next_tutorial.restore(data.get("ocra", {})):
		return false
	for id in data.get("seen", []):
		if not id is String or message(id).is_empty():
			return false
	for fact in data.get("facts", {}):
		if fact not in FACTS or not data.facts[fact] is bool:
			return false
	seen.assign(data.get("seen", []))
	facts = data.get("facts", {}).duplicate()
	ocra.restore(next_tutorial.snapshot())
	muted = data.get("muted", false)
	active_id = ""
	remaining = 0
	gap = 1
	latched.clear()
	last_shown.clear()
	return true
