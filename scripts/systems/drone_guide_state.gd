extends RefCounted

const MESSAGES := {
	"welcome": [10, "Da qui parte tutto", "Ciao! La nave e la nostra prima casa. Apri la botola con E e scendi: il terreno sotto di noi e ancora intatto."],
	"first_dig": [15, "Il primo scavo", "Punta il terreno e usa il raggio Pulse per scavare. Io ti seguo e trasporto il materiale che non entra nello zaino. Non allontaniamoci troppo dalla nave."],
	"lab_plan": [20, "Prepariamo il laboratorio", "Ci servono 6 pietra e 4 rame. In officina apri Inventario: scarica la terra, poi scegli Prepara laboratorio. Scaviamo una stanza larga 4 celle e alta 3, con pavimento solido."],
	"cargo_full": [80, "Carico pieno", "Non possiamo raccogliere altro. Torna in officina, apri Inventario e scegli Scarica tutto. Aspetta che sia vicino: solo cosi scarichi anche il mio carico."],
	"drone_unavailable": [70, "Devo avvicinarmi", "Il tuo zaino e pieno, ma io sono troppo lontano per aiutarti. Aspettami in un passaggio aperto, oppure rientra in officina e scarica il materiale."],
	"signal_limit": [75, "Limite del collegamento", "Sono al limite del segnale della nave. Da qui non posso trasportare o costruire con te. Torna verso di me: potremo ampliare il mio raggio con la ricerca."],
	"build_resources": [45, "Servono i materiali giusti", "Zaino pieno non significa materiali giusti! Nel Cantiere vedi quanto manca di ogni risorsa. La stiva non si usa a distanza: preleva in officina con Prepara laboratorio."],
	"build_space": [40, "La stanza del laboratorio", "Libera un rettangolo di 4 celle per 3, con pavimento sotto tutte e 4 le colonne. Puoi restare dentro mentre lo monto! Tienimi vicino ed evita acqua e gas."],
	"lab_built": [55, "Laboratorio pronto", "Ottimo, ora abbiamo un punto di appoggio! Qui puoi scaricare il materiale e fabbricare luci: ogni kit costa 1 terra e 1 rame. La ricerca sblocca anche i nostri miglioramenti."],
	"lamp_crafted": [50, "Portiamo luce nelle gallerie", "Il kit luce e nel carico. Seleziona Luce nel Cantiere e posala su un pavimento libero, entro 8 metri da un laboratorio operativo."],
	"lamp_plan": [30, "Fabbrichiamo le luci", "Raggiungi il laboratorio e apri Inventario. Con 1 terra e 1 rame puoi fabbricare una luce portatile, poi posarla nelle gallerie entro 8 metri dal laboratorio."],
	"lamp_placed": [30, "Una luce che resta", "Questa luce rimane qui anche quando ci allontaniamo. Continuiamo ad ampliare le gallerie dal laboratorio, mantenendo una via di ritorno alla nave."],
	"deposited": [25, "Materiale al sicuro", "Carico scaricato! Il deposito e separato da cio che portiamo con noi. Prima di ripartire preleva i materiali per costruire, oppure usa Prepara laboratorio."],
	"gas_danger": [100, "Gas! Indietro!", "La nube sta danneggiando la tuta. Allontanati e torna in una zona pulita. In nave la tuta si ripristina; usa lo scanner prima di aprire nuove sacche."],
	"water_danger": [100, "Stiamo andando sotto!", "La tuta perde integrita sott'acqua. Risali con il comando di salita e cerca un tratto asciutto. Non scavare una sacca senza una via di fuga verso l'alto."],
	"gas_leak": [90, "Sacca di gas aperta", "Abbiamo aperto una sacca di gas! Allontaniamoci dalla nube: non possiamo rendere operativo un laboratorio in un'area contaminata."],
	"water_leak": [90, "Infiltrazione!", "L'acqua sta entrando nelle gallerie. Mantieni una via di risalita e proteggi il cantiere: serve una stanza asciutta per installare il laboratorio."],
	"energy_low": [85, "Energia quasi esaurita", "Il raggio consuma la batteria della nave. Rientra in officina e apri Nave per ricaricarla prima di continuare lo scavo."],
	"ladder_tip": [25, "Non dimenticare la risalita", "Prima di scendere ancora, lascia una via di ritorno. Puoi montare una scala con B: costa 2 terra e non richiede il laboratorio."],
	"tools": [20, "Prima analizziamo", "Lo Scanner rivela il materiale del blocco e le sacche vicine. Alcune rocce richiedono strumenti migliori; i nuclei indistruttibili vanno aggirati."],
}
const REPEATING := ["cargo_full", "drone_unavailable", "signal_limit", "build_resources", "build_space", "gas_danger", "water_danger", "gas_leak", "water_leak", "energy_low"]
const FACTS := ["mined", "ladder", "lab_built", "lamp_crafted", "lamp_placed", "deposited"]
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

func offer(id: String, manual: bool = false) -> bool:
	if not MESSAGES.has(id):
		return false
	if not manual:
		if muted or (gap > 0 and int(MESSAGES[id][0]) < 80) or (id in seen and id not in REPEATING) or id in latched:
			return false
		if elapsed - float(last_shown.get(id, -100)) < 35:
			return false
		if not active_id.is_empty() and int(MESSAGES[id][0]) <= int(MESSAGES[active_id][0]):
			return false
	active_id = id
	active_manual = manual
	remaining = clampf(float(str(MESSAGES[id][2]).length()) / 15.0, 9, 18)
	if id not in seen:
		seen.append(id)
	if id in REPEATING and id not in latched:
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
	if active_id in REPEATING and active_id != current_context and not active_manual and active_id not in ["gas_leak", "water_leak"]:
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
	return {"seen": seen.duplicate(), "facts": facts.duplicate(), "muted": muted}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("seen", []) is Array or not data.get("facts", {}) is Dictionary or not data.get("muted", false) is bool:
		return false
	for id in data.get("seen", []):
		if not id is String or not MESSAGES.has(id):
			return false
	for fact in data.get("facts", {}):
		if fact not in FACTS or not data.facts[fact] is bool:
			return false
	seen.assign(data.get("seen", []))
	facts = data.get("facts", {}).duplicate()
	muted = data.get("muted", false)
	active_id = ""
	remaining = 0
	gap = 1
	latched.clear()
	last_shown.clear()
	return true
