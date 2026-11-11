extends SceneTree

const Components = preload("res://scripts/data/component_catalog.gd")
const Industry = preload("res://scripts/data/industry_catalog.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Fluids = preload("res://scripts/data/fluid_catalog.gd")
const Modules = preload("res://scripts/data/ship_module_catalog.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")
const Outpost = preload("res://scripts/prototype/outpost_controller.gd")
const Gear = preload("res://scripts/prototype/expedition_gear.gd")
const Icons = preload("res://scripts/data/item_icon_catalog.gd")
const WaterCircuit = preload("res://scripts/systems/water_circuit.gd")
const Logistics = preload("res://scripts/systems/drone_logistics.gd")
const JSON_PATH := "res://design/generated/production-map.json"
const DOC_PATH := "res://docs/design/mappa-produzione.md"
const GROUPS := {"refining": "Semilavorati", "production": "Componenti e consumabili", "assembly": "Montaggio delle strutture", "infrastructure": "Scale tubi e cavi", "utilities": "Acqua gas ed energia", "agriculture": "Coltivazione", "upgrade": "Potenziamenti", "repair": "Riparazioni", "service": "Servizi provvisori della nave"}
var data := {"version": 1, "scope": "current_playable_prototype", "nodes": {}, "recipes": [], "used_by": {}, "planned": []}

# Query actual payment methods on an isolated model, never on a running campaign.
class ServiceProbe extends "res://scripts/systems/ship_state.gd":
	var quoted: Dictionary = {}
	func _pay(cost: Dictionary) -> bool:
		quoted = cost.duplicate()
		return true

func _initialize() -> void:
	run.call_deferred()

func node(id: String, title: String, category: String) -> void:
	data.nodes[id] = {"name": title, "category": category, "icon": Icons.path(id).trim_prefix("res://")}

func recipe(id: String, title: String, group: String, station: String, inputs: Dictionary, outputs: Dictionary, seconds: float = 0, energy: Dictionary = {}, notes: String = "") -> void:
	var icon_id: String = outputs.keys()[0] if not outputs.is_empty() else (inputs.keys()[0] if not inputs.is_empty() else "")
	data.recipes.append({"id": id, "name": title, "group": group, "station": station, "status": "implemented", "icon": Icons.path(icon_id).trim_prefix("res://"), "inputs": inputs.duplicate(), "outputs": outputs.duplicate(), "seconds": seconds, "energy": energy.duplicate(), "notes": notes})

func build() -> void:
	data.runtime_flags = {"natural_gas_pockets": Site.HazardLayout.gas_pockets_enabled, "local_industry_supply": "natural_gas" if Site.HazardLayout.gas_pockets_enabled else "paused_without_natural_gas"}
	var yields := {"1": 0, "2": 0, "3": 0}
	for roll in range(100):
		yields[str(Gear.yield_for_roll(roll))] += 1
	data.raw_extraction = {"pieces_percent": yields, "common_rock_cargo": false, "material": "same_as_mined_ore", "pickup": "physical_fragments_robbie_magnet"}
	data.raw_extraction.pure_blocks = {"mining_strength": Site.Geology.PURE_VEIN_COST, "ore_units": Site.Geology.PURE_VEIN_YIELD, "max_physical_bundles": 3, "finite": true}
	data.automatic_logistics = {"variant": "explorer", "processor": "ship_workshop", "component_buffer": Logistics.DEFAULT_BUFFER.duplicate(), "delivery": "physical_worker", "construction": "worker_on_site", "controlled_robbie": "manual"}
	var site := Site.new()
	for kind: String in Site.COST:
		var id: String = site.resource_yield(kind)
		if not id.is_empty():
			node(id, Cargo.NAMES[id], "raw")
	for id: String in Fluids.KINDS:
		node(id, Fluids.KINDS[id].name, "reservoir")
	for id: String in Components.COMPONENT_IDS:
		node(id, Cargo.NAMES[id], "component")
	node("bomb", "Bomba", "consumable")
	node("ship_energy", "Energia nave [kWh]", "energy")
	node("local_energy", "Energia locale [kWh]", "energy")
	node("stored_water", "Acqua nel serbatoio", "utility")
	node("ladder", "Scala", "infrastructure")
	var industry := Industry.load_data()
	for id: String in industry.smelting:
		var entry: Dictionary = industry.smelting[id]
		node(id, Cargo.NAMES[id], "semifinished")
		recipe("smelt_" + id, entry.name_it, "refining", "Fornace", entry.cost, {id: 1}, entry.seconds, {"local_energy": float(entry.power) * float(entry.seconds)}, "Fornace collegata a un convertitore gas tramite cavo; ritirare il prodotto.")
	for id: String in Components.RECIPE_IDS:
		var entry := Components.recipe(id)
		recipe("fabricate_" + id, entry.name_it, "production", "Laboratorio di bordo o da campo", entry.cost, {entry.output: entry.amount}, entry.seconds, {"ship_energy": entry.energy}, "Dopo il primo laboratorio da campo." if entry.advanced else ("Scorte bombe: massimo 4." if id == "bomb" else "Disponibile dal laboratorio iniziale della nave."))
	for id: String in Components.STRUCTURE_IDS:
		node(id, Buildings.NAMES[id], "structure")
		var size: Vector2i = Buildings.SIZES.get(id, Vector2i.ONE)
		var seconds := Buildings.build_seconds(id)
		recipe("assemble_" + id, Buildings.NAMES[id], "assembly", "Sul posto", Components.assembly_cost(id), {id: 1}, seconds, {"ship_energy": Buildings.power_draw({"id": id, "state": "building"}) * seconds}, "%d x %d m; componenti nel carico accessibile. %s" % [size.x, size.y, "Disponibile dall'inizio." if id == "laboratory" else "Sbloccato dopo il primo laboratorio da campo."])
		var repair_id := "repaired_" + id
		node(repair_id, "Ripristino: " + Buildings.NAMES[id], "state")
		recipe("repair_" + id, "Ripara " + Buildings.NAMES[id], "repair", "Installazione danneggiata", Buildings.repair_cost({"id": id}), {repair_id: 1}, 0, {}, "Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente.")
	recipe("place_ladder", "Posa scala", "infrastructure", "Sul posto", {}, {"ladder": 1}, 0, {}, "Posa e rimozione immediate e gratuite; restano i vincoli geometrici.")
	var outpost := Outpost.new()
	for kind: String in ["water", "gas", "energy"]:
		var id := kind + "_conduit"
		node(id, {"water": "Tubo acqua", "gas": "Tubo gas", "energy": "Cavo energia"}[kind], "infrastructure")
		recipe("place_" + id, data.nodes[id].name, "infrastructure", "Sul posto", outpost.conduit_cost(kind), {id: 1}, 0, {}, "Costo per segmento di 1 m; posa immediata, non una lavorazione in laboratorio.")
	outpost.free()
	node("valve", "Presa stagna", "infrastructure")
	node("outlet", "Terminale di scarico", "infrastructure")
	recipe("place_valve", "Monta presa stagna", "infrastructure", "Faccia di una roccia", WaterCircuit.VALVE_COST, {"valve": 1}, 0, {}, "Dopo il primo laboratorio; occupa 1 x 1 m libero. Perfora un solo blocco con il tool compatibile senza rimuoverlo. Apertura manuale; scollegare il tubo la chiude.")
	recipe("configure_outlet", "Configura terminale acqua", "infrastructure", "Su tubo acqua gia' posato", {}, {"outlet": 1}, 0, {}, "Terminale chiuso inizialmente; orientabile verso una cella libera. Clic destro: scarico oppure aspirazione da una vasca. Cambiare ruolo lo richiude. Scaricare versa acqua fisica, che puo' traboccare. Non e' un nuovo macchinario.")
	var conversion: Dictionary = industry.converter
	recipe("convert_gas", "Converti gas in energia locale", "utilities", "Convertitore gas", {"gas": 1}, {"local_energy": conversion.kwh_per_gas}, 1.0 / float(conversion.gas_per_second), {}, "Processo continuo: gas da una falda collegata con tubi; accumulo massimo %.0f kWh. Non ricarica automaticamente la nave." % conversion.capacity)
	recipe("pump_water", "Recupera acqua", "utilities", "Pompa acqua", {"water": 1}, {"stored_water": 1}, 1.0 / WaterCircuit.PUMP_RATE, {"ship_energy": Buildings.power_draw({"id": "pump", "state": "active"}) / WaterCircuit.PUMP_RATE}, "Presa stagna perforata e aperta, tubo fino all'ingresso; uscita separata verso serra o scarico. Buffer %.0f u; aspirazione e sollevamento entro %.0f m dalla pompa. Nessun drenaggio per raggio." % [WaterCircuit.capacity(), WaterCircuit.MAX_LIFT])
	recipe("gravity_water", "Trasferisci acqua per gravita'", "utilities", "Presa e scarico collegati", {"water": 1}, {"water": 1}, 1.0 / WaterCircuit.PASSIVE_RATE, {}, "Acqua spostata, non creata. Percorso sotto il livello della presa e scarico piu' basso. Cella ricevente piena o contaminata ferma il trasferimento.")
	recipe("vent_gas", "Rimuovi gas pericoloso", "utilities", "Ventilatore gas", {"gas": 1}, {}, 1.0 / Buildings.FAN_RATE, {"ship_energy": Buildings.power_draw({"id": "fan", "state": "active"}) / Buildings.FAN_RATE}, "Rimuove il gas dall'ambiente: non produce carburante o energia.")
	for id: String in Industry.CROP_IDS:
		var crop: Dictionary = industry.crops[id]
		node(id, crop.name_it, "food")
		node("seed_" + id, "Semi di " + crop.name_it.to_lower(), "seed")
		recipe("grow_" + id, crop.name_it, "agriculture", "Serra", {"seed_" + id: 1, "stored_water": crop.water}, {id: crop["yield"], "seed_" + id: crop.seeds}, crop.seconds, {"local_energy": float(crop.power) * float(crop.seconds)}, "Nave: 3 semi di patata iniziali." if id == "potato" else "Semi trovati nelle capsule dei pianeti; acqua da pompa e energia locale via cavi.")
	var ship := Ship.new()
	for module: Resource in Modules.all():
		for level in range(1, module.max_level):
			ship.modules[module.module_id] = level
			var id: String = "module_" + module.module_id + "_" + str(level + 1)
			node(id, module.display_name + " L" + str(level + 1), "upgrade")
			recipe("upgrade_" + id, "%s %d > %d" % [module.display_name, level, level + 1], "upgrade", "Officina della nave", ship.upgrade_cost(module.module_id), {id: 1}, 0, {}, module.description + (" Richiede il primo laboratorio da campo." if module.module_id in ["drill", "drone"] else ""))
	for level in range(1, Buildings.MAX_LAB_LEVEL):
		var id := "laboratory_level_" + str(level + 1)
		node(id, "Laboratorio L" + str(level + 1), "upgrade")
		recipe("upgrade_" + id, "Laboratorio %d > %d" % [level, level + 1], "upgrade", "Laboratorio di bordo o da campo", Buildings.upgrade_cost({"level": level}), {id: 1}, 0, {}, "Potenzia la singola postazione. Il laboratorio di bordo richiede prima il primo laboratorio da campo.")
	var service := ServiceProbe.new()
	service.hull = 0
	service.repair()
	node("hull_integrity", "Integrita' scafo", "state")
	recipe("repair_hull", "Ripara scafo", "repair", "Officina della nave", service.quoted, {"hull_integrity": service.hull}, 0, {}, "Il recupero e' limitato dall'integrita' massima.")
	service.fuel = 0
	service.refuel()
	node("ship_fuel", "Carburante nave", "utility")
	recipe("refuel_ship", "Rifornisci nave", "service", "Officina della nave", service.quoted, {"ship_fuel": service.fuel}, 0, {}, "Ricetta provvisoria del prototipo: il petrolio non viene ancora usato per il carburante.")
	service.energy = 0
	service.recharge()
	recipe("recharge_ship", "Ricarica batteria nave", "service", "Officina della nave", {}, {"ship_energy": service.energy}, 0, {}, "Servizio provvisorio senza ingredienti; non e' ancora una filiera energetica definitiva.")
	var gear := Gear.new()
	gear.repair_ship = true
	node("repaired_ship_workshop", "Officina di bordo riparata", "state")
	recipe("repair_ship_workshop", "Ripara officina di bordo", "repair", "Officina danneggiata", gear.repair_cost(), {"repaired_ship_workshop": 1})
	gear.free()
	data.planned = [
		{"id": "tool_fabrication", "name": "Fabbricazione dei singoli tool", "status": "planned", "note": "Ricette e costi da definire. Pulse, Scanner e Jetpack sono iniziali; Risonatore e Plasma si ottengono dal Banco strumenti."},
		{"id": "scanner_upgrades", "name": "Potenziamenti acquistabili dello scanner", "status": "planned", "note": "Proposta approvata: raggi 4/5/6/7 m e tracce solo sull'onda / 3 / 7 / 12 s. Acquisto e nuova curva non ancora implementati: oggi la persistenza e' 2 + 0.7 s per livello."},
		{"id": "oil_processing", "name": "Lavorazione del petrolio", "status": "planned", "note": "Petrolio e acido sono pericoli fisici, non ingredienti di ricette attuali. Nessun costo futuro inventato."},
		{"id": "onboard_encyclopedia", "name": "Enciclopedia del computer di bordo", "status": "planned", "note": "Usare gli stessi dati generati per cercare ingredienti, prodotti, stazioni, sblocchi e impieghi. La schermata nel gioco non esiste ancora."}
	]
	data.planned.append({"id": "ship_fluid_tanks", "name": "Serbatoi della nave e bocchettoni", "status": "planned", "note": "Serbatoi inizialmente vuoti e separati per acqua/gas/altri fluidi; carico e scarico fisici per trasportare risorse fra pianeti. Non implementati in questa tranche."})
	data.planned.append({"id": "construction_volumes", "name": "Pavimenti e volumi costruibili", "status": "planned", "note": "Possibilita' di creare appoggi e passaggi dopo scavi estesi; decisioni rinviate dal giocatore."})
	data.planned.append({"id": "additional_robbie", "name": "Fabbricazione di altri Robbie", "status": "planned", "note": "Futura squadra con incarichi e carichi separati. Il ciclo automatico attuale usa solo Robbie assistente dell'umano; costi, sblocchi e ricette degli ulteriori robot non sono ancora definiti."})
	data.planned.append({"id": "water_filters", "name": "Filtri per purificare l'acqua", "status": "planned", "note": "Fondamentali per le coltivazioni: le serre richiederanno acqua adatta all'irrigazione, non soltanto una quantita' disponibile; l'acqua contaminata dovra' essere filtrata. Modulo separato dalla pompa e collegato ai tubi prima dell'utilizzo o dello stoccaggio. Contaminanti, soglie di qualita', ricette, consumi e manutenzione da definire; nessuna purificazione attiva nel runtime attuale."})
	for entry: Dictionary in data.recipes:
		for id: String in entry.inputs.keys() + entry.energy.keys():
			if not data.used_by.has(id):
				data.used_by[id] = []
			if entry.id not in data.used_by[id]:
				data.used_by[id].append(entry.id)

func amount_text(stock: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in stock:
		parts.append("%s %s" % [number_text(float(stock[id])), data.nodes[id].name])
	return " + ".join(parts) if not parts.is_empty() else "Nessuno"

func number_text(value: float) -> String:
	return str(int(value)) if value == floor(value) else String.num(value, 3)

func markdown() -> String:
	var lines: Array[String] = ["# Mappa di produzione di RocketMan", "", "Questa e' la mappa del prototipo giocabile: cosa raccogliere, cosa trasformare e cosa costruire. Le proposte future sono separate dalle ricette realmente disponibili.", "", "Documento generato dai cataloghi e dalle funzioni di costo del gioco. Non modificare a mano le tabelle: aggiornare le fonti e rigenerare. [Dati strutturati per il futuro computer di bordo](../../design/generated/production-map.json).", "", "## La catena principale", "", "```text", "Materie prime -> Componenti -> Strutture, consumabili e potenziamenti", "        |             ^", "        +-> Semilavorati (facoltativi) --+", "```", "", "**Materie prime:** ferro, rame, cristalli, quarzo e cobalto. **Semilavorati:** lingotti di rame e vetro. **Componenti:** strutturali ed elettronici, versatili e impilabili (4 pezzi per unita' di carico). Terra e pietra comuni non entrano nel carico o nelle ricette.", "", "Il laboratorio di bordo e' gia' funzionante e parte senza scorte minerali. Nella modalita umano Robbie gestisce produzione, consegna e montaggio; nella variante Robbie pilotabile queste operazioni restano manuali. Non si trasportano cubi di stanze gia' scelte. Le scale sono gratuite e immediate.", "", "## Il primo laboratorio", "", "Scava i depositi iniziali di **8 ferro + 3 rame + 1 cristallo** e prepara una stanza supportata di **4 x 3 m**. Posa il progetto: Robbie raccoglie, torna alla nave, produce **4 strutturali + 2 elettronici**, li consegna e monta il laboratorio. Puoi continuare a scavare. Nella variante Robbie pilotabile ordini e ritiri manualmente i componenti al banco.", "", "Dopo il primo laboratorio da campo si sbloccano luci, pompe, ventilatori, fornaci, convertitori e serre, oltre alle ricette avanzate dei due componenti. I consumi della rete si aggiungono all'energia specifica riportata nelle tabelle."]
	lines.append_array(["", "## Logistica automatica", "", "Nella modalita umano Robbie raccoglie i frammenti e torna fisicamente alla nave quando il carico e' pieno o la raccolta si interrompe brevemente. Il banco di bordo produce automaticamente i componenti necessari ai progetti, mantenendo una piccola scorta di 4 strutturali e 2 elettronici quando ci sono ingredienti. Robbie consegna ai cantieri e resta sul posto durante il montaggio; il personaggio puo continuare a scavare altrove. Non occorrono ordini di scarico, produzione o prelievo. Le ricette e i tempi delle tabelle restano invariati. Nella variante Robbie pilotabile il flusso resta manuale.", "", "## Raccolta dalla roccia", "", "I depositi dispersi producono pezzi dello stesso minerale: **1 pezzo nel %d%%**, **2 pezzi nel %d%%**, **3 pezzi nel %d%%** dei casi. I nuovi filoni puri sono regioni irregolari solide e finite: ogni blocco richiede **10 punti di scavo** e rende **12 unita**, rappresentate da un massimo di tre frammenti fisici. La raccolta parziale conserva la quantita restante al suolo e nei salvataggi. Terra e pietra non producono carico." % [data.raw_extraction.pieces_percent["1"], data.raw_extraction.pieces_percent["2"], data.raw_extraction.pieces_percent["3"]], "", "Su Ocra rame e ferro si trovano subito a sinistra della scala della nave; tre blocchi di cristallo sono presenti poco oltre sullo stesso percorso, oltre ai cristalli a destra. Non serve attraversare una falda o raggiungere il sottosuolo profondo per il primo laboratorio. Questi depositi iniziali restano piu' teneri dei filoni puri."])
	for group: String in GROUPS:
		if group == "refining" and not Site.HazardLayout.gas_pockets_enabled:
			lines.append_array(["", "**Playtest: sacche di gas sospese.** Nei nuovi mondi non c'e' gas naturale, quindi la filiera energetica locale di convertitori, fornaci e serre e' in attesa di alimentazione. Le ricette sotto descrivono i sistemi implementati, non una nuova fonte gratuita di energia. Pompe e valvole acqua usano ancora la rete del laboratorio."])
		lines.append_array(["", "## " + GROUPS[group], "", "| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |", "| --- | --- | --- | --- | --- | --- | --- | --- |"])
		for entry: Dictionary in data.recipes:
			if entry.group != group:
				continue
			lines.append("| <img src=\"../../%s\" width=\"24\" height=\"24\" alt=\"\"> | %s | %s | %s | %s | %s s | %s | %s |" % [entry.icon, entry.name, entry.station, amount_text(entry.inputs), amount_text(entry.outputs), number_text(float(entry.seconds)), amount_text(entry.energy), entry.notes])
	lines.append_array(["", "## A cosa serve ogni materiale", "", "Indice inverso: le tabelle sopra contengono i costi; questo elenco indica dove viene utilizzata ogni risorsa.", ""])
	for id: String in data.used_by:
		var uses: Array[String] = []
		for recipe_id: String in data.used_by[id]:
			var entry: Dictionary = data.recipes.filter(func(item): return item.id == recipe_id)[0]
			uses.append(entry.name)
		lines.append("- <img src=\"../../%s\" width=\"24\" height=\"24\" alt=\"\"> **%s:** %s." % [data.nodes[id].icon, data.nodes[id].name, "; ".join(uses)])
	lines.append_array(["", "## Vincoli importanti", "", "- Il tempo dei lotti e' riferito a un laboratorio L1; i livelli superiori accelerano la produzione. Ingredienti ed energia del lotto si pagano all'avvio; output e avanzamento non si perdono chiudendo il menu.", "- Il montaggio consuma i componenti reali consegnati sul posto. Il totale informativo del deposito non e' un pagamento a distanza. Robbie deve raggiungere fisicamente il cantiere e rimanere presente durante il proprio lavoro; supporto, sicurezza ed energia restano obbligatori.", "- La fornace usa energia locale del convertitore, non direttamente la batteria della nave. La serra richiede anche acqua conservata dalla pompa: servono collegamenti reali.", "- Il laboratorio e i dispositivi alimentati dalla nave continuano a consumare durante l'uso: l'energia di montaggio non e' il loro intero costo di vita.", "- Le riparazioni elencate sono riparazioni di installazioni/scafo. La manutenzione di tuta e Robbie e il riposo non sono nuove ricette di costruzione.", "", "## Da progettare o completare", ""])
	for entry: Dictionary in data.planned:
		lines.append("- **%s:** %s" % [entry.name, entry.note])
	lines.append_array(["", "## Come tenere aggiornata la mappa", "", "```powershell", "godot --headless --path . -s res://tools/design/build-production-map.gd", "godot --headless --path . -s res://tools/design/build-production-map.gd -- --check", "```", "", "Il comando genera questo documento e il JSON della mappa. `--check` fallisce se uno dei due e' assente o non aggiornato. Le fonti sono `prototype_components.json`, `prototype_industry.json`, i cataloghi dei moduli e i metodi di costo di strutture, nave, condotti e riparazioni. Le proposte e le note editoriali si aggiornano nel generatore.", "", "**Computer di bordo, prossimo passo:** ricerca per nome; viste 'come si produce' e 'a cosa serve'; catena degli ingredienti; stazioni richieste; materiali posseduti/mancanti. Il documento di sviluppo mostra tutto, ma la futura vista del giocatore dovra' distinguere ricette note, sbloccate e ancora da scoprire.", ""])
	return "\n".join(lines)

func run() -> void:
	build()
	var outputs := {JSON_PATH: JSON.stringify(data, "\t", true) + "\n", DOC_PATH: markdown()}
	var check := "--check" in OS.get_cmdline_user_args()
	var failed := false
	for path: String in outputs:
		if check:
			if not FileAccess.file_exists(path) or FileAccess.get_file_as_string(path) != outputs[path]:
				push_error("Mappa di produzione non aggiornata: " + path)
				failed = true
		else:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				failed = true
			else:
				file.store_string(outputs[path])
	print("Production map: %d recipes, %d nodes; %s" % [data.recipes.size(), data.nodes.size(), "FAILED" if failed else ("up to date" if check else "generated")])
	quit(1 if failed else 0)
